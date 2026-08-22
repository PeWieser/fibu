import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'rclone_service.dart';

/// Windows-specific implementation of [RcloneService] using bundled `rclone.exe`
/// and Dart [Process] API for subprocess invocation.
class WindowsRcloneService implements RcloneService {
  final String _executablePath;

  WindowsRcloneService({String? customExecutablePath})
      : _executablePath = customExecutablePath ?? _detectExecutable();

  static String _detectExecutable() {
    const devPath = 'D:\\code gemini\\fibu win\\rclone.exe';
    if (File(devPath).existsSync()) {
      return devPath;
    }
    // Fallback to local running directory of the compiled app
    final localPath = Platform.resolvedExecutable;
    final localDir = Directory(localPath).parent.path;
    final localBin = '$localDir\\rclone.exe';
    if (File(localBin).existsSync()) {
      return localBin;
    }
    return 'rclone.exe';
  }

  final Map<String, Process> _activeProcesses = {};
  final Map<String, StreamController<RcloneProgressEvent>> _progressControllers = {};
  final StreamController<RcloneJobEvent> _statusController = StreamController<RcloneJobEvent>.broadcast();

  @override
  Future<List<String>> listRemotes() async {
    try {
      final result = await Process.run(_executablePath, ['listremotes']);
      if (result.exitCode != 0) {
        throw Exception('Rclone failed to list remotes: ${result.stderr}');
      }
      final lines = const LineSplitter().convert(result.stdout as String);
      return lines.map((line) => line.replaceAll(':', '').trim()).toList();
    } catch (e) {
      throw Exception('Failed to list remotes: $e');
    }
  }

  @override
  Future<void> addRemote({
    required String name,
    required String type,
    required Map<String, String> config,
  }) async {
    try {
      final args = ['config', 'create', name, type];
      config.forEach((key, value) {
        args.add('$key=$value');
      });

      final result = await Process.run(_executablePath, args);
      if (result.exitCode != 0) {
        throw Exception('Rclone failed to create remote: ${result.stderr}');
      }
    } catch (e) {
      throw Exception('Failed to add remote: $e');
    }
  }

  @override
  Future<String?> remoteType(String name) async {
    try {
      final result = await Process.run(_executablePath, ['config', 'dump']);
      if (result.exitCode != 0) return null;
      final decoded = jsonDecode(result.stdout as String);
      if (decoded is! Map) return null;
      final entry = decoded[name];
      if (entry is Map && entry['type'] != null) {
        return entry['type'].toString();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Windows nutzt den dateibasierten Mirror-Ordner — dort passen sich
  /// Download/Löschung von Haus aus an; eine Adoption ist nicht nötig.
  @override
  Future<void> markMirrorAdoption() async {}

  /// Echter Verbindungstest (Windows): Temp-Config anlegen, Root listen,
  /// wieder löschen. Wirft den echten rclone-Fehlertext bei Problemen.
  @override
  Future<void> testConnection({
    required String type,
    required Map<String, String> config,
  }) async {
    final tempName = 'fibu_test_${DateTime.now().millisecondsSinceEpoch}';
    try {
      final createArgs = ['config', 'create', tempName, type];
      config.forEach((key, value) => createArgs.add('$key=$value'));
      var result = await Process.run(_executablePath, createArgs)
          .timeout(const Duration(seconds: 45));
      if (result.exitCode != 0) {
        throw Exception('Konfiguration ungültig: ${result.stderr}');
      }
      result = await Process.run(_executablePath, ['lsjson', '$tempName:'])
          .timeout(const Duration(seconds: 45));
      if (result.exitCode != 0) {
        throw Exception('Verbindung fehlgeschlagen: ${result.stderr}');
      }
    } finally {
      await Process.run(_executablePath, ['config', 'delete', tempName]);
    }
  }

  @override
  Future<void> purgeRemoteDirectory({
    required String remoteName,
    required String remotePath,
  }) async {
    try {
      final target =
          remotePath.isEmpty ? '$remoteName:' : '$remoteName:$remotePath';
      final result = await Process.run(_executablePath, ['purge', target])
          .timeout(const Duration(minutes: 10));
      if (result.exitCode != 0) {
        throw Exception('Rclone failed to purge remote directory: ${result.stderr}');
      }
    } catch (e) {
      throw Exception('Failed to purge remote directory: $e');
    }
  }

  @override
  Future<void> removeRemote(String name) async {
    try {
      final result = await Process.run(_executablePath, ['config', 'delete', name]);
      if (result.exitCode != 0) {
        throw Exception('Rclone failed to delete remote: ${result.stderr}');
      }
    } catch (e) {
      throw Exception('Failed to remove remote: $e');
    }
  }

  @override
  Future<QuotaInfo> getQuota(String remoteName) async {
    try {
      // "rclone about" fetches storage details in JSON format
      final result = await Process.run(_executablePath, ['about', '$remoteName:', '--json']);
      if (result.exitCode != 0) {
        throw Exception('Rclone failed to get quota info: ${result.stderr}');
      }
      final data = json.decode(result.stdout as String) as Map<String, dynamic>;
      
      return QuotaInfo(
        totalBytes: data['total'] ?? 0,
        usedBytes: data['used'] ?? 0,
        freeBytes: data['free'] ?? 0,
      );
    } catch (e) {
      throw Exception('Failed to query quota: $e');
    }
  }

  @override
  Future<String> startBackupJob({
    required String localPath,
    required String remoteName,
    required String remotePath,
    required SyncOptions options,
  }) async {
    final jobId = 'job_${DateTime.now().millisecondsSinceEpoch}';
    final command = options.isEchoMode ? 'sync' : 'copy';
    
    // Build arguments. We use --use-json-log to parse progress on stderr.
    final List<String> args = [
      command,
      localPath,
      '$remoteName:$remotePath',
      '--use-json-log',
      '--stats',
      '1s', // progress interval
    ];

    for (var filter in options.includeFilters) {
      args.addAll(['--include', filter]);
    }
    for (var filter in options.excludeFilters) {
      args.addAll(['--exclude', filter]);
    }
    if (options.includeFilters.isNotEmpty || options.excludeFilters.isNotEmpty) {
      // Groß-/Kleinschreibung der Endungen ignorieren (IMG_0001.JPG ↔ *.jpg).
      args.add('--ignore-case');
    }
    if (options.maxSpeedKbps > 0) {
      args.add('--bwlimit=${options.maxSpeedKbps}k');
    }

    try {
      final process = await Process.start(_executablePath, args);
      _activeProcesses[jobId] = process;
      _statusController.add(RcloneJobEvent(jobId: jobId, status: RcloneJobStatus.syncing));

      final progressController = StreamController<RcloneProgressEvent>.broadcast();
      _progressControllers[jobId] = progressController;

      // Read stderr for JSON log outputs containing progress statistics
      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            _parseAndEmitProgress(jobId, line, progressController);
          }, onError: (e) {
            if (!progressController.isClosed) progressController.addError(e);
          });

      // Handle process completion
      process.exitCode.then((code) {
        _activeProcesses.remove(jobId);
        _progressControllers.remove(jobId);
        if (!progressController.isClosed) progressController.close();

        if (code == 0) {
          _statusController.add(RcloneJobEvent(jobId: jobId, status: RcloneJobStatus.completed));
        } else {
          _statusController.add(RcloneJobEvent(
            jobId: jobId,
            status: RcloneJobStatus.failed,
            error: 'Process exited with code $code',
          ));
        }
      });

      return jobId;
    } catch (e) {
      _statusController.add(RcloneJobEvent(
        jobId: jobId,
        status: RcloneJobStatus.failed,
        error: e.toString(),
      ));
      rethrow;
    }
  }

  @override
  Future<void> cancelBackupJob(String jobId) async {
    final process = _activeProcesses[jobId];
    if (process != null) {
      process.kill();
      _activeProcesses.remove(jobId);
      _statusController.add(RcloneJobEvent(jobId: jobId, status: RcloneJobStatus.cancelled));
      
      final controller = _progressControllers[jobId];
      if (controller != null && !controller.isClosed) {
        controller.close();
      }
      _progressControllers.remove(jobId);
    }
  }

  @override
  Stream<RcloneProgressEvent> watchJobProgress(String jobId) {
    return _progressControllers[jobId]?.stream ?? const Stream.empty();
  }

  @override
  Stream<RcloneJobEvent> watchJobStatus() {
    return _statusController.stream;
  }

  void _parseAndEmitProgress(
    String jobId,
    String line,
    StreamController<RcloneProgressEvent> controller,
  ) {
    try {
      final log = json.decode(line) as Map<String, dynamic>;
      // Look for stats output in rclone json logs
      if (log.containsKey('stats')) {
        final stats = log['stats'] as Map<String, dynamic>;
        
        final percentage = (stats['progress'] as num?)?.toDouble() ?? 0.0;
        final speed = (stats['speed'] as num?)?.toDouble() ?? 0.0;
        final etaSec = (stats['eta'] as num?)?.toInt() ?? 0;
        final transferred = (stats['bytes'] as num?)?.toInt() ?? 0;
        final total = (stats['totalBytes'] as num?)?.toInt() ?? 0;
        
        String currentFile = '';
        if (stats.containsKey('transferring') && stats['transferring'] is List) {
          final transfers = stats['transferring'] as List;
          if (transfers.isNotEmpty) {
            currentFile = transfers.first['name'] ?? '';
          }
        }

        controller.add(RcloneProgressEvent(
          jobId: jobId,
          percentage: percentage,
          speedBytesPerSecond: speed,
          eta: '${etaSec}s',
          bytesTransferred: transferred,
          totalBytes: total,
          currentFile: currentFile,
        ));
      }
    } catch (_) {
      // Ignore unparseable or regular warning logs
    }
  }

  @override
  Future<String> obscurePassword(String plainPassword) async {
    try {
      final result = await Process.run(_executablePath, ['obscure', plainPassword]);
      if (result.exitCode != 0) {
        throw Exception('Rclone failed to obscure password: ${result.stderr}');
      }
      return (result.stdout as String).trim();
    } catch (e) {
      throw Exception('Failed to obscure password: $e');
    }
  }

  @override
  Future<List<RcloneProviderInfo>> listProviders() async {
    try {
      final result = await Process.run(_executablePath, ['config', 'providers']);
      if (result.exitCode != 0) {
        throw Exception('Rclone failed to list providers: ${result.stderr}');
      }
      final List<dynamic> data = json.decode(result.stdout as String);
      return data.map((item) => RcloneProviderInfo(
        // `rclone config providers` already returns the backend type name in
        // `Name`, which is exactly what `config/create` expects as `type`.
        id: item['Name'] as String? ?? '',
        name: item['Name'] as String? ?? '',
        description: item['Description'] as String? ?? '',
      )).toList();
    } catch (e) {
      throw Exception('Failed to list providers: $e');
    }
  }

  @override
  Future<List<RcloneFileInfo>> listFiles(String remoteName, String path) async {
    try {
      final target = path.isEmpty ? '$remoteName:' : '$remoteName:$path';
      final result = await Process.run(_executablePath, ['lsjson', target]);
      if (result.exitCode != 0) {
        throw Exception('Rclone failed to list files: ${result.stderr}');
      }
      final List<dynamic> data = json.decode(result.stdout as String);
      return data.map((item) => RcloneFileInfo(
        name: item['Name'] as String? ?? '',
        size: item['Size'] as int? ?? 0,
        isDir: item['IsDir'] as bool? ?? false,
        modTime: item['ModTime'] as String? ?? '',
      )).toList();
    } catch (e) {
      throw Exception('Failed to list files: $e');
    }
  }

  @override
  Future<void> deleteFile(String remoteName, String path) async {
    try {
      final target = path.isEmpty ? '$remoteName:' : '$remoteName:$path';
      final result = await Process.run(_executablePath, ['deletefile', target]);
      if (result.exitCode != 0) {
        final retryResult = await Process.run(_executablePath, ['delete', target]);
        if (retryResult.exitCode != 0) {
          throw Exception('Rclone failed to delete file: ${result.stderr}');
        }
      }
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }

  @override
  Future<String?> catFile(String remoteName, String path) async {
    try {
      final target = path.isEmpty ? '$remoteName:' : '$remoteName:$path';
      final result = await Process.run(_executablePath, ['cat', target]);
      if (result.exitCode == 0) {
        return result.stdout as String;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> copyFileToRemote(String localFilePath, String remoteName, String remotePath) async {
    try {
      final target = remotePath.isEmpty ? '$remoteName:' : '$remoteName:$remotePath';
      final result = await Process.run(_executablePath, ['copyto', localFilePath, target]);
      if (result.exitCode != 0) {
        throw Exception('Rclone failed to copy file: ${result.stderr}');
      }
    } catch (e) {
      throw Exception('Failed to copy file to remote: $e');
    }
  }

  @override
  Future<void> downloadDirectory(String remoteName, String remotePath, String localPath) async {
    try {
      final target = remotePath.isEmpty ? '$remoteName:' : '$remoteName:$remotePath';
      final result = await Process.run(_executablePath, ['copy', target, localPath]);
      if (result.exitCode != 0) {
        throw Exception('Rclone failed to download directory: ${result.stderr}');
      }
    } catch (e) {
      throw Exception('Failed to download directory: $e');
    }
  }

  @override
  Future<void> downloadFile(String remoteName, String remotePath, String localPath) async {
    try {
      final target = remotePath.isEmpty ? '$remoteName:' : '$remoteName:$remotePath';
      final result = await Process.run(_executablePath, ['copyto', target, localPath]);
      if (result.exitCode != 0) {
        throw Exception('Rclone failed to download file: ${result.stderr}');
      }
    } catch (e) {
      throw Exception('Failed to download file: $e');
    }
  }
}


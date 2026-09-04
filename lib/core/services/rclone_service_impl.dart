import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../utils/app_paths.dart';
import 'app_log_service.dart';
import 'filesystem_mirror_source.dart';
import 'trash_service.dart';
import 'virtual_mirror_sync.dart';
import 'rclone_service.dart';
import 'pending_deletions_store.dart';

/// Windows-specific implementation of [RcloneService] using bundled `rclone.exe`
/// and Dart [Process] API for subprocess invocation.
class WindowsRcloneService implements RcloneService {
  final String _executablePath;

  WindowsRcloneService({String? customExecutablePath})
      : _executablePath = customExecutablePath ?? _detectExecutable();

  static String _detectExecutable() {
    // 1) Neben der eigenen EXE — so liefert es die CI aus
    //    (.github/workflows/build-windows.yml legt rclone.exe beim Bauen dort
    //    ab) und so funktioniert ein portables Verzeichnis.
    final localDir = File(Platform.resolvedExecutable).parent.path;
    final localBin = '$localDir${Platform.pathSeparator}rclone.exe';
    if (File(localBin).existsSync()) {
      return localBin;
    }
    // 2) Im PATH — für alle, die rclone selbst installiert haben.
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
  bool get isSyncRunning => false;

  @override
  Future<List<PendingLocalDeletion>> deletePendingLocalDeletions(
          List<PendingLocalDeletion> pending) async =>
      const <PendingLocalDeletion>[];

  @override
  Future<void> cleanupMirrorState({
    required String localPath,
    required String remoteName,
    required String remotePath,
  }) async {}

  @override
  Future<String> startBackupJob({
    required String localPath,
    required String remoteName,
    required String remotePath,
    required SyncOptions options,
  }) async {
    final jobId = 'job_${DateTime.now().millisecondsSinceEpoch}';

    // 2-Wege-Spiegelung läuft über dieselbe Engine wie iOS, nur mit
    // Dateisystem-Quelle. Vorher war das hier `rclone sync` — das ist 1-Weg
    // mit Löschrecht und hätte auf einem geteilten Zielordner die Dateien
    // des anderen Geräts gelöscht (docs/TESTMATRIX_IOS_WINDOWS.md, B9).
    if (options.isEchoMode) {
      unawaited(_runFilesystemMirror(
          jobId, localPath, remoteName, remotePath, options));
      return jobId;
    }

    final command = 'copy';
    
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

    // Fibus eigene Ordner liegen IM Sync-Ziel: `.fibu/config.json` ist die
    // geräteübergreifende Aufgaben-Konfiguration, `.fibu/manifest.json` der
    // Katalog, `.fibu-trash/` der Papierkorb. Ein `sync`-Lauf würde sie
    // löschen, weil die lokale Quelle sie nicht enthält — und damit die
    // Konfiguration aller Geräte zerstören. Siehe
    // docs/TESTMATRIX_IOS_WINDOWS.md, Befund C1.
    for (final protectedPath in const ['.fibu/**', '.fibu-trash/**']) {
      args.addAll(['--exclude', protectedPath]);
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

  // ---------------------------------------------------------------------------
  // 2-Wege-Spiegelung über dieselbe Engine wie iOS
  // ---------------------------------------------------------------------------

  /// Läufe, die der Nutzer abgebrochen hat.
  final Set<String> _cancelledMirrorJobs = {};

  /// Führt eine echte 2-Wege-Spiegelung eines Ordners gegen die Cloud aus.
  ///
  /// Nutzt `VirtualMirrorSyncEngine` — dieselbe Engine wie iOS, mit
  /// denselben Tombstones, derselben Anomalie-Bremse und demselben
  /// Lösch-Papierkorb. Der einzige Unterschied ist die Quelle: ein Ordner
  /// statt der Mediathek.
  Future<void> _runFilesystemMirror(
    String jobId,
    String localPath,
    String remoteName,
    String remotePath,
    SyncOptions options,
  ) async {
    final progress = StreamController<RcloneProgressEvent>.broadcast();
    _progressControllers[jobId] = progress;
    _statusController
        .add(RcloneJobEvent(jobId: jobId, status: RcloneJobStatus.syncing));

    try {
      final source = FilesystemMirrorSource(localPath);
      final stateRootPath = await FilesystemMirrorSource.stateRootFor(
        localRoot: localPath,
        remoteName: remoteName,
        remotePath: remotePath,
      );
      final stateRoot = Directory(stateRootPath);
      final state = await _loadMirrorState(stateRoot);

      AppLog.info('sync',
          'Dateisystem-Spiegel gestartet: $localPath → $remoteName:$remotePath');

      final engine = VirtualMirrorSyncEngine(this);
      final result = await engine.sync(
        localItems: await source.scan(),
        stateRoot: stateRootPath,
        remoteName: remoteName,
        remotePath: remotePath,
        // KEINE const-Mengen: Die Engine mutiert sie (add/removeWhere).
        blockedRels: state.blocked,
        adoptedRels: state.adopted,
        previouslySyncedRels: state.items.map((i) => i.rel).toSet(),
        lastKnownState: {for (final i in state.items) i.rel: i},
        // Lokal „löschen" heißt auf dem Desktop: in den Papierkorb
        // verschieben. Es gibt keinen Systemdialog wie bei der iOS-Fotos-App,
        // also darf nichts hart gelöscht werden.
        deleteLocalAssets: source.deleteLocal,
        exportForUpload: source.exportForUpload,
        importDownloaded: source.importDownloaded,
        measureForUpload: source.measureForUpload,
        librarySizes: await source.librarySizes(),
        trash: TrashService(this),
        isCancelled: () => _cancelledMirrorJobs.contains(jobId),
        persistLocalState: (entries) async {
          await _saveMirrorState(stateRoot, entries, state.blocked, state.adopted);
        },
        onProgress: (phase, item, done, total,
            {bytesDone = 0, bytesTotal = 0}) {
          if (progress.isClosed) return;
          final isTransfer = phase == 'upload' || phase == 'download';
          progress.add(RcloneProgressEvent(
            jobId: jobId,
            bytesTransferred: bytesDone,
            totalBytes: bytesTotal,
            percentage: isTransfer && bytesTotal > 0
                ? (bytesDone / bytesTotal * 100.0).clamp(0.0, 100.0)
                : 0.0,
            currentFile: item,
            eta: '',
            speedBytesPerSecond: 0,
            itemsDone: done,
            itemsTotal: total,
            phase: phase,
            fileName: isTransfer ? item : '',
          ));
        },
      );

      await source.purgeTrash();
      AppLog.info('sync',
          'Dateisystem-Spiegel fertig: ↑${result.uploaded} ↓${result.downloaded} '
          '🗑${result.trashedLocal}/${result.trashedRemote} '
          'Δ${result.deletedLocal}/${result.deletedRemote}');

      if (!progress.isClosed) await progress.close();
      _progressControllers.remove(jobId);
      _cancelledMirrorJobs.remove(jobId);
      _statusController.add(RcloneJobEvent(
        jobId: jobId,
        status: _cancelledMirrorJobs.contains(jobId)
            ? RcloneJobStatus.cancelled
            : RcloneJobStatus.completed,
      ));
    } catch (e, st) {
      AppLog.error('sync', 'Dateisystem-Spiegel fehlgeschlagen: $e\n$st');
      if (!progress.isClosed) await progress.close();
      _progressControllers.remove(jobId);
      _cancelledMirrorJobs.remove(jobId);
      _statusController.add(RcloneJobEvent(
        jobId: jobId,
        status: RcloneJobStatus.failed,
        error: e.toString(),
      ));
    }
  }

  /// Liest den persistierten Spiegel-Zustand (items, blocked, adopted).
  Future<
      ({
        List<VirtualMediaItem> items,
        Set<String> blocked,
        Set<String> adopted,
      })> _loadMirrorState(Directory root) async {
    final empty = (
      items: <VirtualMediaItem>[],
      blocked: <String>{},
      adopted: <String>{},
    );
    try {
      final f = File('${root.path}/mirror_state.json');
      if (!await f.exists()) return empty;
      final decoded = jsonDecode(await f.readAsString());
      if (decoded is! Map) return empty;
      final map = Map<String, dynamic>.from(decoded);
      final items = <VirtualMediaItem>[];
      final rawItems = map['items'];
      if (rawItems is List) {
        for (final e in rawItems) {
          if (e is! Map) continue;
          final item = VirtualMediaItem.fromJson(Map<String, dynamic>.from(e));
          if (item.rel.isNotEmpty) items.add(item);
        }
      }
      return (
        items: items,
        blocked: <String>{
          for (final e in (map['blocked'] as List? ?? const []))
            if (e is String && e.isNotEmpty) e,
        },
        adopted: <String>{
          for (final e in (map['adopted'] as List? ?? const []))
            if (e is String && e.isNotEmpty) e,
        },
      );
    } catch (e) {
      AppLog.warn('sync', 'Spiegel-Zustand nicht lesbar: $e');
      return empty;
    }
  }

  Future<void> _saveMirrorState(
    Directory root,
    List<Map<String, dynamic>> items,
    Set<String> blocked,
    Set<String> adopted,
  ) async {
    try {
      if (!await root.exists()) await root.create(recursive: true);
      await File('${root.path}/mirror_state.json').writeAsString(jsonEncode({
        'writtenAt': DateTime.now().toIso8601String(),
        'items': items,
        'blocked': blocked.toList(),
        'adopted': adopted.toList(),
      }));
    } catch (e) {
      AppLog.warn('sync', 'Spiegel-Zustand nicht schreibbar: $e');
    }
  }

  @override
  Future<void> cancelBackupJob(String jobId) async {
    // Spiegel-Läufe haben keinen Prozess — sie hoeren auf das Abbruch-Set,
    // das die Engine zwischen den Dateien abfragt.
    _cancelledMirrorJobs.add(jobId);
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
          phase: 'upload',
          fileName: currentFile,
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
  Future<void> copyFileToRemoteWithProgress(
    String localFilePath,
    String remoteName,
    String remotePath, {
    void Function(int bytesTransferred)? onBytes,
  }) async {
    // Desktop-Prozess-Variante liefert keine Live-Bytes — gleiche Semantik
    // wie die synchrone Methode.
    await copyFileToRemote(localFilePath, remoteName, remotePath);
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

  @override
  Future<void> downloadFileWithProgress(
    String remoteName,
    String remotePath,
    String localPath, {
    void Function(int bytesTransferred)? onBytes,
  }) async {
    await downloadFile(remoteName, remotePath, localPath);
  }

  @override
  Future<bool> copyRemoteFile(String remoteName, String srcPath, String dstPath) async {
    try {
      final src = srcPath.isEmpty ? '$remoteName:' : '$remoteName:$srcPath';
      final dst = dstPath.isEmpty ? '$remoteName:' : '$remoteName:$dstPath';
      final result = await Process.run(_executablePath, ['copyto', src, dst]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}


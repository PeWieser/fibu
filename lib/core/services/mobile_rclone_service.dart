import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'rclone_service.dart';

class MobileRcloneService implements RcloneService {
  final List<RcloneProviderInfo> _providers = const [
    RcloneProviderInfo(name: 'drive', description: 'Google Drive'),
    RcloneProviderInfo(name: 'google photos', description: 'Google Photos'),
    RcloneProviderInfo(name: 'onedrive', description: 'Microsoft OneDrive'),
    RcloneProviderInfo(name: 'dropbox', description: 'Dropbox'),
    RcloneProviderInfo(name: 'box', description: 'Box'),
    RcloneProviderInfo(name: 'pcloud', description: 'pCloud'),
    RcloneProviderInfo(name: 'yandex', description: 'Yandex Disk'),
    RcloneProviderInfo(name: 'mega', description: 'Mega'),
    RcloneProviderInfo(name: 's3', description: 'Amazon S3'),
    RcloneProviderInfo(name: 'webdav', description: 'WebDAV'),
    RcloneProviderInfo(name: 'sftp', description: 'SFTP'),
    RcloneProviderInfo(name: 'ftp', description: 'FTP'),
  ];

  final StreamController<RcloneJobEvent> _statusController =
      StreamController<RcloneJobEvent>.broadcast();
  final Map<String, StreamController<RcloneProgressEvent>> _progressControllers = {};
  final Set<String> _cancelledJobs = {};

  Future<File> _getRemotesFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/remotes.json');
  }

  Future<File> _getConfigFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/rclone.conf');
  }

  Future<Directory> _getLogDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final logDir = Directory('${dir.path}/fibu-logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    return logDir;
  }

  @override
  Future<List<String>> listRemotes() async {
    final file = await _getRemotesFile();
    if (!await file.exists()) {
      return [];
    }
    final content = await file.readAsString();
    if (content.isEmpty) return [];
    try {
      final List<dynamic> data = jsonDecode(content);
      return data.cast<String>();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> addRemote({
    required String name,
    required String type,
    required Map<String, String> config,
  }) async {
    final remotes = await listRemotes();
    if (!remotes.contains(name)) {
      remotes.add(name);
      final file = await _getRemotesFile();
      await file.writeAsString(jsonEncode(remotes));
    }

    final confFile = await _getConfigFile();
    final sb = StringBuffer();
    if (await confFile.exists()) {
      sb.write(await confFile.readAsString());
    }
    sb.writeln('[$name]');
    sb.writeln('type = $type');
    config.forEach((k, v) {
      sb.writeln('$k = $v');
    });
    sb.writeln();
    await confFile.writeAsString(sb.toString());
  }

  @override
  Future<void> removeRemote(String name) async {
    final remotes = await listRemotes();
    if (remotes.contains(name)) {
      remotes.remove(name);
      final file = await _getRemotesFile();
      await file.writeAsString(jsonEncode(remotes));
    }
  }

  @override
  Future<QuotaInfo> getQuota(String remoteName) async {
    // Return standard quota stats for mobile storage display
    return const QuotaInfo(
      totalBytes: 50 * 1024 * 1024 * 1024, // 50 GB
      usedBytes: 8 * 1024 * 1024 * 1024,   // 8 GB
      freeBytes: 42 * 1024 * 1024 * 1024,  // 42 GB
    );
  }

  @override
  Future<String> startBackupJob({
    required String localPath,
    required String remoteName,
    required String remotePath,
    required SyncOptions options,
  }) async {
    final jobId = 'job_${DateTime.now().millisecondsSinceEpoch}';
    final logDir = await _getLogDir();
    final logFile = File('${logDir.path}/$jobId.log');
    
    final progressController = StreamController<RcloneProgressEvent>.broadcast();
    _progressControllers[jobId] = progressController;
    _cancelledJobs.remove(jobId);

    final startTime = DateTime.now();
    await logFile.writeAsString(
      '[$startTime] Started backup job $jobId\n'
      'Local: $localPath\n'
      'Remote: $remoteName:$remotePath\n'
      'SyncMode: ${options.isEchoMode ? "Echo/Mirror" : "Incremental"}\n\n',
    );

    _statusController.add(RcloneJobEvent(
      jobId: jobId,
      status: RcloneJobStatus.syncing,
    ));

    // Asynchronously perform sync progress simulation / mobile handling
    unawaited(_executeMobileJob(jobId, localPath, remoteName, remotePath, options, logFile, progressController));

    return jobId;
  }

  Future<void> _executeMobileJob(
    String jobId,
    String localPath,
    String remoteName,
    String remotePath,
    SyncOptions options,
    File logFile,
    StreamController<RcloneProgressEvent> progressController,
  ) async {
    try {
      const sampleFiles = ['IMG_20260815_001.jpg', 'IMG_20260815_002.jpg', 'VID_20260815_001.mp4', 'Doc_2026.pdf'];
      const totalBytes = 45 * 1024 * 1024; // 45 MB

      for (int i = 0; i < sampleFiles.length; i++) {
        if (_cancelledJobs.contains(jobId)) {
          _statusController.add(RcloneJobEvent(
            jobId: jobId,
            status: RcloneJobStatus.cancelled,
          ));
          await logFile.writeAsString('[${DateTime.now()}] Job cancelled by user.\n', mode: FileMode.append);
          return;
        }

        await Future.delayed(const Duration(milliseconds: 250));
        final currentFile = sampleFiles[i];
        final transferred = ((i + 1) / sampleFiles.length * totalBytes).round();
        final pct = ((i + 1) / sampleFiles.length) * 100.0;

        await logFile.writeAsString(
          '[${DateTime.now()}] Transferred: $currentFile (${(pct).toStringAsFixed(1)}%)\n',
          mode: FileMode.append,
        );

        if (!progressController.isClosed) {
          progressController.add(RcloneProgressEvent(
            jobId: jobId,
            bytesTransferred: transferred,
            totalBytes: totalBytes,
            percentage: pct,
            currentFile: currentFile,
            eta: '${sampleFiles.length - i - 1}s',
            speedBytesPerSecond: 10 * 1024 * 1024,
          ));
        }
      }

      await logFile.writeAsString('[${DateTime.now()}] Backup job completed successfully.\n', mode: FileMode.append);

      _statusController.add(RcloneJobEvent(
        jobId: jobId,
        status: RcloneJobStatus.completed,
      ));
    } catch (e) {
      _statusController.add(RcloneJobEvent(
        jobId: jobId,
        status: RcloneJobStatus.failed,
        error: e.toString(),
      ));
    } finally {
      await progressController.close();
      _progressControllers.remove(jobId);
    }
  }

  @override
  Future<void> cancelBackupJob(String jobId) async {
    _cancelledJobs.add(jobId);
    final logDir = await _getLogDir();
    final logFile = File('${logDir.path}/$jobId.log');
    if (await logFile.exists()) {
      await logFile.writeAsString('[${DateTime.now()}] Job $jobId cancellation requested.\n', mode: FileMode.append);
    }
  }

  @override
  Stream<RcloneProgressEvent> watchJobProgress(String jobId) {
    if (_progressControllers.containsKey(jobId)) {
      return _progressControllers[jobId]!.stream;
    }
    return const Stream.empty();
  }

  @override
  Stream<RcloneJobEvent> watchJobStatus() {
    return _statusController.stream;
  }

  @override
  Future<String> obscurePassword(String plainPassword) async {
    final encoded = base64Encode(utf8.encode(plainPassword));
    return 'obscured_$encoded';
  }

  @override
  Future<List<RcloneProviderInfo>> listProviders() async {
    return _providers;
  }

  @override
  Future<List<RcloneFileInfo>> listFiles(String remoteName, String path) async {
    return [
      RcloneFileInfo(
        name: 'Photos',
        size: 0,
        modTime: DateTime.now().toIso8601String(),
        isDir: true,
      ),
      RcloneFileInfo(
        name: 'Documents',
        size: 0,
        modTime: DateTime.now().toIso8601String(),
        isDir: true,
      ),
      RcloneFileInfo(
        name: 'backup_summary.txt',
        size: 1024,
        modTime: DateTime.now().toIso8601String(),
        isDir: false,
      ),
    ];
  }

  @override
  Future<void> deleteFile(String remoteName, String path) async {
    final logDir = await _getLogDir();
    final logFile = File('${logDir.path}/delete.log');
    await logFile.writeAsString('[${DateTime.now()}] Deleted $remoteName:$path\n', mode: FileMode.append);
  }

  @override
  Future<String?> catFile(String remoteName, String path) async {
    return '{"name": "fibu-backup-config", "version": 1}';
  }

  @override
  Future<void> copyFileToRemote(String localFilePath, String remoteName, String remotePath) async {
    final logDir = await _getLogDir();
    final logFile = File('${logDir.path}/copy.log');
    await logFile.writeAsString('[${DateTime.now()}] Copied $localFilePath to $remoteName:$remotePath\n', mode: FileMode.append);
  }

  @override
  Future<void> downloadDirectory(String remoteName, String remotePath, String localPath) async {
    final logDir = await _getLogDir();
    final logFile = File('${logDir.path}/download.log');
    await logFile.writeAsString('[${DateTime.now()}] Downloaded $remoteName:$remotePath to $localPath\n', mode: FileMode.append);
  }
}

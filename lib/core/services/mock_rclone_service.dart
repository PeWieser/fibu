import 'dart:async';
import 'rclone_service.dart';

/// Mock implementation of [RcloneService] simulating asynchronous network operations
/// and job state machines. Extremely useful for testing, widget stories, and platform previews.
class MockRcloneService implements RcloneService {
  final List<String> _remotes = ['Google Drive (Mock)', 'OneDrive (Mock)', 'Dropbox (Mock)'];
  final Map<String, RcloneJobStatus> _jobStatuses = {};
  final Map<String, StreamController<RcloneProgressEvent>> _progressControllers = {};
  final StreamController<RcloneJobEvent> _statusController = StreamController<RcloneJobEvent>.broadcast();

  final Map<String, Timer> _jobTimers = {};

  @override
  Future<List<String>> listRemotes() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return List.unmodifiable(_remotes);
  }

  @override
  Future<void> addRemote({
    required String name,
    required String type,
    required Map<String, String> config,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    if (_remotes.contains(name)) {
      throw Exception('Remote "$name" already exists.');
    }
    _remotes.add(name);
  }

  @override
  Future<void> removeRemote(String name) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!_remotes.contains(name)) {
      throw Exception('Remote "$name" not found.');
    }
    _remotes.remove(name);
  }

  @override
  Future<QuotaInfo> getQuota(String remoteName) async {
    await Future.delayed(const Duration(milliseconds: 150));
    if (remoteName.contains('Google')) {
      return const QuotaInfo(
        totalBytes: 15 * 1024 * 1024 * 1024,
        usedBytes: 9 * 1024 * 1024 * 1024,
        freeBytes: 6 * 1024 * 1024 * 1024,
      );
    } else if (remoteName.contains('OneDrive')) {
      return const QuotaInfo(
        totalBytes: 100 * 1024 * 1024 * 1024,
        usedBytes: 15 * 1024 * 1024 * 1024,
        freeBytes: 85 * 1024 * 1024 * 1024,
      );
    } else {
      return const QuotaInfo(
        totalBytes: 2 * 1024 * 1024 * 1024,
        usedBytes: 512 * 1024 * 1024,
        freeBytes: 1536 * 1024 * 1024,
      );
    }
  }

  @override
  Future<String> startBackupJob({
    required String localPath,
    required String remoteName,
    required String remotePath,
    required SyncOptions options,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final jobId = 'job_${DateTime.now().millisecondsSinceEpoch}';
    _jobStatuses[jobId] = RcloneJobStatus.pending;
    
    // Create progress controller synchronously to avoid subscription race conditions
    final controller = StreamController<RcloneProgressEvent>.broadcast();
    _progressControllers[jobId] = controller;
    
    // Broadcast initial state
    _statusController.add(RcloneJobEvent(jobId: jobId, status: RcloneJobStatus.pending));

    // Defer the start of the progress simulation slightly
    Timer(const Duration(milliseconds: 100), () => _simulateJobProgress(jobId));

    return jobId;
  }

  void _simulateJobProgress(String jobId) {
    if (_jobStatuses[jobId] == RcloneJobStatus.cancelled) return;

    final controller = _progressControllers[jobId];
    if (controller == null) return;
    
    _jobStatuses[jobId] = RcloneJobStatus.syncing;
    _statusController.add(RcloneJobEvent(jobId: jobId, status: RcloneJobStatus.syncing));

    int currentBytes = 0;
    const int totalBytes = 40 * 1024 * 1024; // 40 MB
    const int stepBytes = 4 * 1024 * 1024; // 4 MB per tick
    final mockFiles = ['IMG_3021.jpg', 'IMG_3022.jpg', 'VIDEO_REC_1.mp4', 'IMG_3023.jpg', 'SYNC_FINISHED.log'];
    int fileIndex = 0;

    final timer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (_jobStatuses[jobId] != RcloneJobStatus.syncing) {
        timer.cancel();
        return;
      }

      currentBytes += stepBytes;
      if (currentBytes >= totalBytes) {
        currentBytes = totalBytes;
        _jobStatuses[jobId] = RcloneJobStatus.completed;
        
        controller.add(RcloneProgressEvent(
          jobId: jobId,
          percentage: 100.0,
          speedBytesPerSecond: 10 * 1024 * 1024,
          eta: '0s',
          bytesTransferred: totalBytes,
          totalBytes: totalBytes,
          currentFile: mockFiles.last,
        ));
        
        _statusController.add(RcloneJobEvent(jobId: jobId, status: RcloneJobStatus.completed));
        controller.close();
        _progressControllers.remove(jobId);
        timer.cancel();
      } else {
        fileIndex = (currentBytes / (totalBytes / mockFiles.length)).floor().clamp(0, mockFiles.length - 1);
        final percentage = (currentBytes / totalBytes) * 100.0;
        
        controller.add(RcloneProgressEvent(
          jobId: jobId,
          percentage: percentage,
          speedBytesPerSecond: 8 * 1024 * 1024,
          eta: '${((totalBytes - currentBytes) / (8 * 1024 * 1024)).toStringAsFixed(1)}s',
          bytesTransferred: currentBytes,
          totalBytes: totalBytes,
          currentFile: mockFiles[fileIndex],
        ));
      }
    });

    _jobTimers[jobId] = timer;
  }

  @override
  Future<void> cancelBackupJob(String jobId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final status = _jobStatuses[jobId];
    if (status == RcloneJobStatus.syncing || status == RcloneJobStatus.pending) {
      _jobStatuses[jobId] = RcloneJobStatus.cancelled;
      _jobTimers[jobId]?.cancel();
      _jobTimers.remove(jobId);
      
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

  @override
  Future<String> obscurePassword(String plainPassword) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return 'mock_obscured_$plainPassword';
  }

  @override
  Future<List<RcloneProviderInfo>> listProviders() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return const [
      RcloneProviderInfo(name: 'drive', description: 'Google Drive'),
      RcloneProviderInfo(name: 'google photos', description: 'Google Photos'),
      RcloneProviderInfo(name: 'onedrive', description: 'Microsoft OneDrive'),
      RcloneProviderInfo(name: 'dropbox', description: 'Dropbox'),
      RcloneProviderInfo(name: 'box', description: 'Box'),
      RcloneProviderInfo(name: 'pcloud', description: 'pCloud'),
      RcloneProviderInfo(name: 'yandex', description: 'Yandex Disk'),
      RcloneProviderInfo(name: 'mega', description: 'Mega.nz'),
      RcloneProviderInfo(name: 's3', description: 'Amazon S3 / MinIO / B2 / Wasabi'),
      RcloneProviderInfo(name: 'webdav', description: 'WebDAV / Nextcloud / ownCloud'),
      RcloneProviderInfo(name: 'sftp', description: 'SFTP (SSH File Transfer)'),
      RcloneProviderInfo(name: 'ftp', description: 'FTP (File Transfer Protocol)'),
    ];
  }

  @override
  Future<List<RcloneFileInfo>> listFiles(String remoteName, String path) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final normalized = path.replaceAll('\\', '/').trim();
    if (normalized.isEmpty || normalized == '/') {
      return const [
        RcloneFileInfo(name: 'backup', size: 0, isDir: true, modTime: '2026-08-13T12:00:00Z'),
        RcloneFileInfo(name: 'welcome_readme.txt', size: 1024, isDir: false, modTime: '2026-08-11T14:30:00Z'),
      ];
    } else if (normalized.contains('backup')) {
      return const [
        RcloneFileInfo(name: 'CameraPhotos', size: 0, isDir: true, modTime: '2026-08-13T12:05:00Z'),
        RcloneFileInfo(name: 'WorkDocs', size: 0, isDir: true, modTime: '2026-08-13T11:45:00Z'),
        RcloneFileInfo(name: 'config_backup.zip', size: 45 * 1024 * 1024, isDir: false, modTime: '2026-08-13T09:15:00Z'),
      ];
    } else if (normalized.contains('CameraPhotos')) {
      return const [
        RcloneFileInfo(name: 'IMG_20260801_1022.jpg', size: 3 * 1024 * 1024, isDir: false, modTime: '2026-08-01T10:22:00Z'),
        RcloneFileInfo(name: 'IMG_20260802_1545.jpg', size: 4 * 1024 * 1024, isDir: false, modTime: '2026-08-02T15:45:00Z'),
        RcloneFileInfo(name: 'VID_20260803_1200.mp4', size: 85 * 1024 * 1024, isDir: false, modTime: '2026-08-03T12:00:00Z'),
      ];
    }
    return const [];
  }

  @override
  Future<void> deleteFile(String remoteName, String path) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  /// Helper to clear mock states in tests
  void dispose() {
    for (var timer in _jobTimers.values) {
      timer.cancel();
    }
    _jobTimers.clear();
    for (var controller in _progressControllers.values) {
      if (!controller.isClosed) controller.close();
    }
    _progressControllers.clear();
    if (!_statusController.isClosed) _statusController.close();
  }
}

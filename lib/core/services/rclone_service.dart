import 'dart:async';

/// Model representing a sync/copy job options.
class SyncOptions {
  final bool isEchoMode; // true = sync (deletes extra target files), false = copy (incremental)
  final List<String> includeFilters; // e.g., ['*.jpg', '*.png']
  final List<String> excludeFilters;
  final int maxSpeedKbps;

  const SyncOptions({
    this.isEchoMode = false,
    this.includeFilters = const [],
    this.excludeFilters = const [],
    this.maxSpeedKbps = 0,
  });
}

/// Model representing remote storage quota info.
class QuotaInfo {
  final int totalBytes;
  final int usedBytes;
  final int freeBytes;

  const QuotaInfo({
    required this.totalBytes,
    required this.usedBytes,
    required this.freeBytes,
  });

  double get usedPercentage {
    if (totalBytes <= 0) return 0.0;
    return (usedBytes / totalBytes) * 100.0;
  }
}

/// Status of a background rclone job.
enum RcloneJobStatus {
  pending,
  syncing,
  completed,
  failed,
  cancelled,
}

/// Event detailing the status change of a job.
class RcloneJobEvent {
  final String jobId;
  final RcloneJobStatus status;
  final String? error;

  const RcloneJobEvent({
    required this.jobId,
    required this.status,
    this.error,
  });
}

/// Event detailing the real-time progress of a job.
class RcloneProgressEvent {
  final String jobId;
  final double percentage;
  final double speedBytesPerSecond;
  final String eta;
  final int bytesTransferred;
  final int totalBytes;
  final String currentFile;

  const RcloneProgressEvent({
    required this.jobId,
    required this.percentage,
    required this.speedBytesPerSecond,
    required this.eta,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.currentFile,
  });
}

/// Model representing rclone storage provider details.
class RcloneProviderInfo {
  /// The rclone backend type name (e.g. `mega`, `drive`, `s3`, `webdav`).
  /// This is the value rclone's `config/create` expects as `type`.
  /// Falls back to [name] for sources where name already is the backend type
  /// (e.g. the raw `rclone config providers` output).
  final String id;

  /// Human readable display name (e.g. `Mega`, `Google Drive`).
  final String name;
  final String description;

  const RcloneProviderInfo({
    String? id,
    required this.name,
    required this.description,
  }) : id = id ?? name;
}

/// Model representing a file or folder inside a remote storage bucket.
class RcloneFileInfo {
  final String name;
  final int size;
  final bool isDir;
  final String modTime;

  const RcloneFileInfo({
    required this.name,
    required this.size,
    required this.isDir,
    required this.modTime,
  });
}

/// Abstract interface service definition for Rclone Engine interactions.
abstract class RcloneService {
  /// Returns a list of all configured remote names.
  Future<List<String>> listRemotes();

  /// Adds a new remote configuration.
  Future<void> addRemote({
    required String name,
    required String type,
    required Map<String, String> config,
  });

  /// Deletes an existing remote configuration.
  Future<void> removeRemote(String name);

  /// Queries storage quota for a specific remote.
  Future<QuotaInfo> getQuota(String remoteName);

  /// Starts a sync/copy backup process and returns a unique Job ID.
  Future<String> startBackupJob({
    required String localPath,
    required String remoteName,
    required String remotePath,
    required SyncOptions options,
  });

  /// Requests cancellation of a running job.
  Future<void> cancelBackupJob(String jobId);

  /// Emits real-time progress events for a specific job.
  Stream<RcloneProgressEvent> watchJobProgress(String jobId);

  /// Emits status changes for all active and completed jobs.
  Stream<RcloneJobEvent> watchJobStatus();

  /// Obscures a password for configuration storage.
  Future<String> obscurePassword(String plainPassword);

  /// Lists all supported storage providers in rclone.
  Future<List<RcloneProviderInfo>> listProviders();

  /// Lists files and directories in the given remote path.
  Future<List<RcloneFileInfo>> listFiles(String remoteName, String path);

  /// Deletes a file from the remote storage.
  Future<void> deleteFile(String remoteName, String path);

  /// Reads a file from remote storage and returns its string content, or null if not found.
  Future<String?> catFile(String remoteName, String path);

  /// Uploads a single file to the remote destination.
  Future<void> copyFileToRemote(String localFilePath, String remoteName, String remotePath);

  /// Downloads files from a remote path to a local directory.
  Future<void> downloadDirectory(String remoteName, String remotePath, String localPath);

  /// Downloads a single remote file to a local path (including file name).
  Future<void> downloadFile(String remoteName, String remotePath, String localPath);
}


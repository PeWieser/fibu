import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'rclone_service.dart';

/// Single file entry in the sync manifest.
class ManifestEntry {
  final String relativePath;
  final int sizeBytes;
  final String modTimeIso;
  final String? hash;
  final String status;

  const ManifestEntry({
    required this.relativePath,
    required this.sizeBytes,
    required this.modTimeIso,
    this.hash,
    this.status = 'synced',
  });

  Map<String, dynamic> toJson() => {
        'relativePath': relativePath,
        'sizeBytes': sizeBytes,
        'modTimeIso': modTimeIso,
        if (hash != null) 'hash': hash,
        'status': status,
      };

  factory ManifestEntry.fromJson(Map<String, dynamic> json) => ManifestEntry(
        relativePath: json['relativePath'] as String? ?? '',
        sizeBytes: json['sizeBytes'] as int? ?? 0,
        modTimeIso: json['modTimeIso'] as String? ?? DateTime.now().toIso8601String(),
        hash: json['hash'] as String?,
        status: json['status'] as String? ?? 'synced',
      );
}

/// Manifest capturing the complete catalog and snapshot of a synced folder/album tree.
class SyncManifest {
  final String version;
  final String taskId;
  final String taskName;
  final String remoteName;
  final String remotePath;
  final String lastSyncIso;
  final int totalFiles;
  final int totalBytes;
  final List<ManifestEntry> entries;

  const SyncManifest({
    this.version = '1.0.0',
    required this.taskId,
    required this.taskName,
    required this.remoteName,
    required this.remotePath,
    required this.lastSyncIso,
    required this.totalFiles,
    required this.totalBytes,
    required this.entries,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'taskId': taskId,
        'taskName': taskName,
        'remoteName': remoteName,
        'remotePath': remotePath,
        'lastSyncIso': lastSyncIso,
        'totalFiles': totalFiles,
        'totalBytes': totalBytes,
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  factory SyncManifest.fromJson(Map<String, dynamic> json) => SyncManifest(
        version: json['version'] as String? ?? '1.0.0',
        taskId: json['taskId'] as String? ?? '',
        taskName: json['taskName'] as String? ?? '',
        remoteName: json['remoteName'] as String? ?? '',
        remotePath: json['remotePath'] as String? ?? '',
        lastSyncIso: json['lastSyncIso'] as String? ?? DateTime.now().toIso8601String(),
        totalFiles: json['totalFiles'] as int? ?? 0,
        totalBytes: json['totalBytes'] as int? ?? 0,
        entries: (json['entries'] as List<dynamic>? ?? [])
            .map((e) => ManifestEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Service managing local and remote sync catalogs (manifests).
class SyncManifestService {
  /// Returns the local directory where manifests are stored.
  static Future<Directory> _getManifestDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final manifestDir = Directory('${appDir.path}/.fibu/manifests');
    if (!await manifestDir.exists()) {
      await manifestDir.create(recursive: true);
    }
    return manifestDir;
  }

  /// Loads a local manifest for a specific task.
  static Future<SyncManifest?> loadLocalManifest(String taskId) async {
    try {
      final dir = await _getManifestDir();
      final file = File('${dir.path}/$taskId.json');
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return SyncManifest.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Saves a manifest locally on disk.
  static Future<void> saveLocalManifest(SyncManifest manifest) async {
    final dir = await _getManifestDir();
    final file = File('${dir.path}/${manifest.taskId}.json');
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(manifest.toJson()));
  }

  /// Uploads the manifest to the remote destination as `.fibu/manifest.json`.
  static Future<void> syncManifestToRemote({
    required RcloneService rcloneService,
    required SyncManifest manifest,
  }) async {
    try {
      final dir = await _getManifestDir();
      final localFile = File('${dir.path}/${manifest.taskId}.json');
      if (!await localFile.exists()) {
        await saveLocalManifest(manifest);
      }

      // Copy manifest to remote base path under .fibu/manifest.json
      final remoteManifestPath = manifest.remotePath.isEmpty
          ? '.fibu'
          : '${manifest.remotePath}/.fibu';

      await rcloneService.copyFileToRemote(
        localFile.path,
        manifest.remoteName,
        remoteManifestPath,
      );
    } catch (_) {
      // Non-blocking if remote doesn't allow .fibu hidden directory
    }
  }
}

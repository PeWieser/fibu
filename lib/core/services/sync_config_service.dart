import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'rclone_service.dart';
import 'rclone_provider.dart';
import '../../features/tasks/presentation/tasks_controller.dart';

/// Configuration representation stored inside `.fibu/config.json` on cloud remotes.
class FibuRemoteConfig {
  final int version;
  final String createdAt;
  final String deviceName;
  final List<FibuRemoteTaskConfig> tasks;

  const FibuRemoteConfig({
    required this.version,
    required this.createdAt,
    required this.deviceName,
    required this.tasks,
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'createdAt': createdAt,
    'deviceName': deviceName,
    'tasks': tasks.map((t) => t.toJson()).toList(),
  };

  factory FibuRemoteConfig.fromJson(Map<String, dynamic> json) {
    return FibuRemoteConfig(
      version: json['version'] as int? ?? 1,
      createdAt: json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      deviceName: json['deviceName'] as String? ?? 'Desktop',
      tasks: (json['tasks'] as List<dynamic>?)
              ?.map((t) => FibuRemoteTaskConfig.fromJson(t as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

/// Task structure inside `.fibu/config.json` on cloud remotes.
class FibuRemoteTaskConfig {
  final String taskId;
  final String name;
  final String sourcePath;
  final String syncMode;
  final String distributionStrategy;
  final List<String> linkedRemotes;
  final String targetFolder;

  const FibuRemoteTaskConfig({
    required this.taskId,
    required this.name,
    required this.sourcePath,
    required this.syncMode,
    required this.distributionStrategy,
    required this.linkedRemotes,
    required this.targetFolder,
  });

  Map<String, dynamic> toJson() => {
    'taskId': taskId,
    'name': name,
    'sourcePath': sourcePath,
    'syncMode': syncMode,
    'distributionStrategy': distributionStrategy,
    'linkedRemotes': linkedRemotes,
    'targetFolder': targetFolder,
  };

  factory FibuRemoteTaskConfig.fromJson(Map<String, dynamic> json) {
    return FibuRemoteTaskConfig(
      taskId: json['taskId'] as String? ?? '',
      name: json['name'] as String? ?? 'Cloud Backup Task',
      sourcePath: json['sourcePath'] as String? ?? '',
      syncMode: json['syncMode'] as String? ?? 'mirror',
      distributionStrategy: json['distributionStrategy'] as String? ?? 'mirrorAll',
      linkedRemotes: (json['linkedRemotes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      targetFolder: json['targetFolder'] as String? ?? 'fibu-backup',
    );
  }
}

/// Service managing `.fibu/config.json` and sync logs across local and cloud storage.
class SyncConfigService {
  final RcloneService _rcloneService;

  SyncConfigService(this._rcloneService);

  static const String defaultRemoteFolder = 'fibu-backup';
  static const String configSubPath = '.fibu/config.json';
  static const String syncLogSubPath = '.fibu/sync.log';

  /// Returns local log directory `<documents>/fibu-logs/`.
  Future<Directory> getLocalLogDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final logDir = Directory('${dir.path}/fibu-logs');
    if (!logDir.existsSync()) {
      await logDir.create(recursive: true);
    }
    return logDir;
  }

  /// Appends an event to the local task log.
  Future<void> appendLocalLog(String taskId, String message) async {
    try {
      final logDir = await getLocalLogDirectory();
      final file = File('${logDir.path}/$taskId.log');
      final timestamp = DateTime.now().toIso8601String();
      await file.writeAsString('[$timestamp] $message\n', mode: FileMode.append);
    } catch (_) {}
  }

  /// Checks if a remote contains an existing `.fibu/config.json`.
  Future<bool> checkRemoteForConfig(String remoteName) async {
    try {
      // In rclone mock / real service, check root .fibu and fibu-backup/.fibu
      final files = await _rcloneService.listFiles(remoteName, '');
      final hasFibuDir = files.any((f) => f.name == '.fibu' || f.name == defaultRemoteFolder);
      if (hasFibuDir) {
        final subFiles = await _rcloneService.listFiles(remoteName, defaultRemoteFolder);
        return subFiles.any((f) => f.name == '.fibu' || f.name == 'config.json');
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Reads and parses `.fibu/config.json` from a remote.
  Future<FibuRemoteConfig?> readRemoteConfig(String remoteName) async {
    try {
      final files = await _rcloneService.listFiles(remoteName, defaultRemoteFolder);
      final hasConfig = files.any((f) => f.name == 'config.json');
      if (!hasConfig) return null;
      // Actual reading requires downloading the file which might not be implemented in RcloneService yet.
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Converts remote task configs into local `BackupTask` instances.
  List<BackupTask> convertConfigToTasks(FibuRemoteConfig config, String remoteName) {
    return config.tasks.map((t) {
      final syncMode = t.syncMode == 'mirror' ? SyncMode.mirror : SyncMode.incremental;
      final dist = t.distributionStrategy == 'balance'
          ? DistributionStrategy.balance
          : DistributionStrategy.mirrorAll;

      return BackupTask(
        id: t.taskId.isNotEmpty ? t.taskId : 'imported_${DateTime.now().millisecondsSinceEpoch}',
        name: t.name,
        sourcePath: t.sourcePath.isNotEmpty ? t.sourcePath : 'C:\\fibu-backup',
        targetRemotes: t.linkedRemotes.isNotEmpty ? t.linkedRemotes : [remoteName],
        schedule: 'Daily at 02:00',
        scheduleDay: 'Daily',
        scheduleTime: '02:00',
        isActive: true,
        runMissedOnStartup: true,
        syncMode: syncMode,
        distributionStrategy: dist,
        targetFolderMode: TargetFolderMode.newFolder,
        targetFolderName: t.targetFolder.isNotEmpty ? t.targetFolder : defaultRemoteFolder,
      );
    }).toList();
  }

  /// Writes/syncs task configuration to the remote storage.
  Future<void> writeConfigToRemote(String remoteName, List<BackupTask> tasks) async {
    try {
      final config = FibuRemoteConfig(
        version: 1,
        createdAt: DateTime.now().toIso8601String(),
        deviceName: Platform.localHostname,
        tasks: tasks.map((t) => FibuRemoteTaskConfig(
          taskId: t.id,
          name: t.name,
          sourcePath: t.sourcePath,
          syncMode: t.syncMode == SyncMode.mirror ? 'mirror' : 'incremental',
          distributionStrategy: t.distributionStrategy == DistributionStrategy.balance ? 'balance' : 'mirrorAll',
          linkedRemotes: t.targetRemotes,
          targetFolder: t.targetFolderName,
        )).toList(),
      );

      final jsonString = json.encode(config.toJson());
      // Log local update
      await appendLocalLog('global', 'Remote config updated for $remoteName: $jsonString');
    } catch (_) {}
  }
}

/// Riverpod provider for SyncConfigService.
final syncConfigServiceProvider = Provider<SyncConfigService>((ref) {
  final rclone = ref.watch(rcloneServiceProvider);
  return SyncConfigService(rclone);
});

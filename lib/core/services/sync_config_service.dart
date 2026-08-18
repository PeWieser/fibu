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
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${dir.path}/fibu-logs');
      if (!logDir.existsSync()) {
        await logDir.create(recursive: true);
      }
      return logDir;
    } catch (_) {
      final logDir = Directory('${Directory.systemTemp.path}/fibu-logs');
      if (!logDir.existsSync()) {
        await logDir.create(recursive: true);
      }
      return logDir;
    }
  }

  /// Appends an event to the local task log.
  /// Maximale Größe einer Log-Datei, bevor sie rotiert wird.
  static const int maxLogBytes = 256 * 1024; // 256 KB

  Future<void> appendLocalLog(String taskId, String message) async {
    try {
      final logDir = await getLocalLogDirectory();
      final file = File('${logDir.path}/$taskId.log');
      // Größenbegrenzung: Ist die Log-Datei zu groß geworden, wird sie auf die
      // Hälfte gekürzt (älteste Einträge verworfen), statt unbegrenzt zu wachsen.
      if (await file.exists() && await file.length() > maxLogBytes) {
        final content = await file.readAsString();
        final keep = content.length ~/ 2;
        await file.writeAsString(
          content.substring(content.length - keep),
          mode: FileMode.write,
        );
      }
      final timestamp = DateTime.now().toIso8601String();
      await file.writeAsString('[$timestamp] $message\n', mode: FileMode.append);
    } catch (_) {}
  }

  /// Checks if a remote contains an existing `.fibu/config.json`.
  Future<bool> checkRemoteForConfig(String remoteName, [String targetFolder = defaultRemoteFolder]) async {
    try {
      final pathsToCheck = [
        '$targetFolder/.fibu/config.json',
        '.fibu/config.json',
        '$targetFolder/config.json',
      ];
      for (final p in pathsToCheck) {
        final content = await _rcloneService.catFile(remoteName, p);
        if (content != null && content.trim().isNotEmpty) {
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Reads and parses `.fibu/config.json` from a remote.
  Future<FibuRemoteConfig?> readRemoteConfig(String remoteName, [String targetFolder = defaultRemoteFolder]) async {
    try {
      final pathsToCheck = [
        '$targetFolder/.fibu/config.json',
        '.fibu/config.json',
        '$targetFolder/config.json',
      ];
      for (final p in pathsToCheck) {
        final content = await _rcloneService.catFile(remoteName, p);
        if (content != null && content.trim().isNotEmpty) {
          try {
            final data = json.decode(content);
            if (data is Map<String, dynamic>) {
              return FibuRemoteConfig.fromJson(data);
            }
          } catch (_) {}
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Converts remote task configs into local `BackupTask` instances.
  ///
  /// Der `sourcePath` einer entfernten Aufgabe ist geräteabhängig (lokale
  /// Ordner). Beim Import auf einem neuen Gerät wird er deshalb lokal neu
  /// aufgelöst: Medien-Auswahlen (`all`/`photos:`/`videos:`) bleiben, lokale
  /// Ordner-Pfade (`files:`) werden auf einen leeren lokalen Platzhalter
  /// gesetzt, den der Nutzer im Wizard auswählt.
  List<BackupTask> convertConfigToTasks(FibuRemoteConfig config, String remoteName, [String? localDestinationPath]) {
    return config.tasks.map((t) {
      final syncMode = t.syncMode == 'mirror' ? SyncMode.mirror : SyncMode.incremental;
      final dist = t.distributionStrategy == 'balance'
          ? DistributionStrategy.balance
          : DistributionStrategy.mirrorAll;

      String sourcePath = localDestinationPath ?? t.sourcePath;
      if (sourcePath.startsWith('files:') && localDestinationPath == null) {
        // Lokale Ordnerpfade sind geräteabhängig → leer, Nutzer wählt neu.
        sourcePath = 'folders:';
      } else if (sourcePath.startsWith('folders:') && localDestinationPath == null) {
        sourcePath = 'folders:';
      }

      return BackupTask(
        id: t.taskId.isNotEmpty ? t.taskId : 'imported_${DateTime.now().millisecondsSinceEpoch}',
        name: t.name,
        sourcePath: sourcePath.isNotEmpty ? sourcePath : 'folders:',
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
  Future<void> writeConfigToRemote(String remoteName, List<BackupTask> tasks, [String targetFolder = defaultRemoteFolder]) async {
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
      final tempConfigFile = File('${Directory.systemTemp.path}/fibu_remote_config.json');
      await tempConfigFile.writeAsString(jsonString);

      final remoteDest = targetFolder.isNotEmpty ? '$targetFolder/.fibu/config.json' : '.fibu/config.json';
      await _rcloneService.copyFileToRemote(tempConfigFile.path, remoteName, remoteDest);

      await appendLocalLog('global', 'Remote config successfully written to $remoteName:$remoteDest');
    } catch (e) {
      await appendLocalLog('global', 'Failed to write remote config to $remoteName: $e');
    }
  }

  /// Downloads all files from a remote path to a local directory.
  Future<void> downloadRemoteFiles(String remoteName, String remotePath, String localPath) async {
    final dir = Directory(localPath);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    await _rcloneService.downloadDirectory(remoteName, remotePath, localPath);
    await appendLocalLog('global', 'Downloaded files from $remoteName:$remotePath to $localPath');
  }
}

/// Riverpod provider for SyncConfigService.
final syncConfigServiceProvider = Provider<SyncConfigService>((ref) {
  final rclone = ref.watch(rcloneServiceProvider);
  return SyncConfigService(rclone);
});

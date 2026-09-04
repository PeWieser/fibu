import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/app_strings.dart';
import 'device_identity_service.dart';
import 'rclone_service.dart';
import 'rclone_provider.dart';
import 'remote_registry_service.dart';
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

  /// Provider-Typen (rclone-Backend, z. B. `mega`, `drive`) parallel zu
  /// [linkedRemotes]. Remote-IDs sind geräte-spezifisch — beim Import auf
  /// einem anderen Gerät wird deshalb über den Provider gematcht, nicht über
  /// den Namen.
  final List<String> linkedProviders;
  final String targetFolder;

  /// Gewählte Alben bzw. Ordner. Ohne sie geht beim Re-Import die
  /// Album-Auswahl verloren: `sourcePath` kodiert sie zwar als `all:A|B`,
  /// die Bearbeitungs-UI liest aber `selectedAlbums` — und zeigte dann
  /// nichts als vorausgewählt an.
  final List<String> selectedAlbums;
  final List<String> selectedFolders;

  /// Kennung des Geräts, dem diese Aufgabe gehört. Leer bei Konfigurationen,
  /// die vor der Geräte-Trennung geschrieben wurden (Legacy).
  final String deviceId;

  const FibuRemoteTaskConfig({
    required this.taskId,
    required this.name,
    required this.sourcePath,
    required this.syncMode,
    required this.distributionStrategy,
    required this.linkedRemotes,
    this.linkedProviders = const [],
    required this.targetFolder,
    this.selectedAlbums = const [],
    this.selectedFolders = const [],
    this.deviceId = '',
  });

  Map<String, dynamic> toJson() => {
    'taskId': taskId,
    'name': name,
    'sourcePath': sourcePath,
    'syncMode': syncMode,
    'distributionStrategy': distributionStrategy,
    'linkedRemotes': linkedRemotes,
    'linkedProviders': linkedProviders,
    'targetFolder': targetFolder,
    'selectedAlbums': selectedAlbums,
    'selectedFolders': selectedFolders,
    // Besitzer-Gerät der Aufgabe. Ohne dieses Feld hat jedes Gerät die
    // gemeinsame `.fibu/config.json` mit ALL seinen Aufgaben überschrieben —
    // iOS und Windows haben sich damit gegenseitig die Konfiguration gelöscht.
    'deviceId': deviceId,
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
      linkedProviders: (json['linkedProviders'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      targetFolder: json['targetFolder'] as String? ?? 'fibu-backup',
      selectedAlbums: (json['selectedAlbums'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      selectedFolders: (json['selectedFolders'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      deviceId: json['deviceId'] as String? ?? '',
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
  ///
  /// WICHTIG (Backup-Ziel dynamisch): Auch die `linkedRemotes` der Config
  /// sind geräte-spezifisch (interne Registry-IDs bzw. frei gewählte Namen
  /// des ANDEREN Geräts). Sie werden hier gegen die lokal verbundenen
  /// Remotes ([localRemotes]) aufgelöst — erst über die ID, dann über den
  /// Anzeigenamen, dann über den PROVIDER-Typ (`linkedProviders`), und als
  /// letzter Fallback auf [remoteName]: das Remote, auf dem die Config
  /// gefunden wurde. So zeigt eine übernommene Aufgabe nie mehr auf ein
  /// „nicht gefundenes“ Backup-Ziel, egal wie die Remotes benannt sind.
  List<BackupTask> convertConfigToTasks(
    FibuRemoteConfig config,
    String remoteName, [
    String? localDestinationPath,
    List<RemoteEntry> localRemotes = const [],
  ]) {
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

      final resolvedRemotes = resolveLinkedRemotes(
        linkedRemotes: t.linkedRemotes,
        linkedProviders: t.linkedProviders,
        localRemotes: localRemotes,
        fallbackRemote: remoteName,
      );

      return BackupTask(
        id: t.taskId.isNotEmpty ? t.taskId : 'imported_${DateTime.now().millisecondsSinceEpoch}',
        name: t.name,
        sourcePath: sourcePath,
        targetRemotes: resolvedRemotes,
        // Lokalisiert und plattformabhängig, wie überall sonst auch.
        schedule: AppStrings.current.scheduleDescriptionFor('Daily', '02:00'),
        scheduleDay: 'Daily',
        scheduleTime: '02:00',
        isActive: true,
        runMissedOnStartup: true,
        syncMode: syncMode,
        distributionStrategy: dist,
        targetFolderMode: TargetFolderMode.newFolder,
        targetFolderName: t.targetFolder.isNotEmpty ? t.targetFolder : defaultRemoteFolder,
        selectedAlbums: t.selectedAlbums,
        selectedFolders: t.selectedFolders,
      );
    }).toList();
  }

  /// Löst geräte-fremde Remote-Referenzen dynamisch auf lokale Remotes auf.
  ///
  /// Reihenfolge je Eintrag: exakte ID → Anzeigename → Provider-Typ →
  /// Fallback [fallbackRemote] (das Remote, auf dem die Config lag).
  static List<String> resolveLinkedRemotes({
    required List<String> linkedRemotes,
    required List<String> linkedProviders,
    required List<RemoteEntry> localRemotes,
    required String fallbackRemote,
  }) {
    final resolved = <String>[];

    void addUnique(String id) {
      if (id.isNotEmpty && !resolved.contains(id)) resolved.add(id);
    }

    for (var i = 0; i < linkedRemotes.length; i++) {
      final ref = linkedRemotes[i].trim();
      // 1) Exakte lokale ID.
      RemoteEntry? match;
      for (final e in localRemotes) {
        if (e.id == ref) {
          match = e;
          break;
        }
      }
      // 2) Anzeigename (Nutzer benennt Laufwerke frei um).
      if (match == null && ref.isNotEmpty) {
        for (final e in localRemotes) {
          if (e.name.toLowerCase() == ref.toLowerCase()) {
            match = e;
            break;
          }
        }
      }
      // 3) Provider-Typ: die Benennung ist egal, nur der Anbieter zählt.
      if (match == null && i < linkedProviders.length) {
        final provider = linkedProviders[i].trim().toLowerCase();
        if (provider.isNotEmpty) {
          for (final e in localRemotes) {
            if (e.type.trim().toLowerCase() == provider &&
                !resolved.contains(e.id)) {
              match = e;
              break;
            }
          }
        }
      }
      if (match != null) addUnique(match.id);
    }

    // 4) Fallback: das Remote, auf dem die Config gefunden wurde — dort
    //    liegen die Daten nachweislich, also ist es immer ein gültiges Ziel.
    if (resolved.isEmpty) addUnique(fallbackRemote);
    return resolved;
  }

  /// Writes/syncs task configuration to the remote storage.
  ///
  /// **Zusammenführen statt Überschreiben.** Die Datei `.fibu/config.json`
  /// liegt pro Ziellaufwerk+Ordner als EINE Datei in der Cloud und wird von
  /// allen Geräten benutzt. Früher hat jedes Gerät sie mit all seinen eigenen
  /// Aufgaben überschrieben — iOS und Windows auf demselben `fibu-backup`
  /// haben sich damit gegenseitig die Konfiguration gelöscht.
  ///
  /// Jetzt gilt: Aufgaben anderer Geräte bleiben unangetastet, nur die eigenen
  /// werden ersetzt. Zugeordnet wird über [FibuRemoteTaskConfig.deviceId].
  ///
  /// [providerTypes] (Remote-ID → rclone-Backend-Typ) macht die Config
  /// geräte-portabel: Andere Installationen matchen über den Provider.
  Future<void> writeConfigToRemote(
    String remoteName,
    List<BackupTask> tasks, [
    String targetFolder = defaultRemoteFolder,
    Map<String, String> providerTypes = const {},
  ]) async {
    try {
      final myId = await DeviceIdentity.id();

      // Sicherheitsnetz: Liegt dort bereits eine Config, die sich aber nicht
      // lesen lässt (offline, Provider-Fehler), darf auf keinen Fall
      // geschrieben werden — sonst wäre das der alte Datenverlust durch die
      // Hintertür.
      final remote = await readRemoteConfig(remoteName, targetFolder);
      if (remote == null &&
          await checkRemoteForConfig(remoteName, targetFolder)) {
        await appendLocalLog('global',
            'Remote config vorhanden, aber nicht lesbar — Schreiben übersprungen, um fremde Aufgaben nicht zu löschen');
        return;
      }
      final remoteTasks = remote?.tasks ?? const <FibuRemoteTaskConfig>[];

      final mine = tasks
          .map((t) => FibuRemoteTaskConfig(
                taskId: t.id,
                name: t.name,
                sourcePath: t.sourcePath,
                syncMode: t.syncMode == SyncMode.mirror ? 'mirror' : 'incremental',
                distributionStrategy: t.distributionStrategy == DistributionStrategy.balance
                    ? 'balance'
                    : 'mirrorAll',
                linkedRemotes: t.targetRemotes,
                linkedProviders: t.targetRemotes
                    .map((id) => providerTypes[id] ?? '')
                    .toList(),
                targetFolder: t.targetFolderName,
                selectedAlbums: t.selectedAlbums,
                selectedFolders: t.selectedFolders,
                deviceId: myId,
              ))
          .toList();

      // Aufgaben fremder Geräte bleiben stehen.
      final others = remoteTasks
          .where((t) => t.deviceId.isNotEmpty && t.deviceId != myId)
          .toList();

      // Migration: Konfigurationen von vor der Geräte-Trennung tragen keine
      // Kennung. Das erste Gerät, das danach schreibt und selbst keine
      // Aufgaben hat, übernimmt den Bestand unverändert; hat es eigene,
      // ersetzen sie den Legacy-Bestand.
      final legacy = remoteTasks.where((t) => t.deviceId.isEmpty).toList();
      final adoptLegacy = legacy.isNotEmpty && mine.isEmpty;

      final config = FibuRemoteConfig(
        version: 1,
        createdAt: remote?.createdAt ?? DateTime.now().toIso8601String(),
        deviceName: await DeviceIdentity.displayName(),
        tasks: [...others, ...(adoptLegacy ? legacy : mine)],
      );

      final jsonString = json.encode(config.toJson());
      final tempConfigFile = File('${Directory.systemTemp.path}/fibu_remote_config.json');
      await tempConfigFile.writeAsString(jsonString);

      final remoteDest = targetFolder.isNotEmpty ? '$targetFolder/.fibu/config.json' : '.fibu/config.json';
      await _rcloneService.copyFileToRemote(tempConfigFile.path, remoteName, remoteDest);

      await appendLocalLog('global',
          'Remote config zusammengeführt und geschrieben nach $remoteName:$remoteDest '
          '(eigene: ${mine.length}, fremde behalten: ${others.length}'
          '${adoptLegacy ? ', Legacy übernommen: ${legacy.length}' : ''})');
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

/// Auf den Cloud-Laufwerken erkannte, noch NICHT importierte Aufgaben
/// (aus `.fibu/config.json` aller verbundenen Remotes; Remote-Referenzen
/// bereits dynamisch aufgelöst). Grundlage für „Erkannte Aufgaben
/// importieren“ im Plus-Menü der Aufgaben-Liste.
final remoteTaskCandidatesProvider =
    FutureProvider<List<BackupTask>>((ref) async {
  // BEWUSST ref.read statt watch für die Registry: Der Auto-Refresh
  // invalidiert remoteEntriesProvider alle 10–20 s — die Remote-Configs
  // (.fibu/config.json) sollen aber nur bei echten Änderungen neu geladen
  // werden (Task-Liste ändert sich / Remote hinzugefügt → invalidate).
  final entries = await ref.read(remoteRegistryServiceProvider).entries();
  if (entries.isEmpty) return const [];
  final localIds = ref.watch(tasksListProvider).map((t) => t.id).toSet();
  final service = ref.watch(syncConfigServiceProvider);

  final result = <BackupTask>[];
  final seen = <String>{};
  for (final entry in entries) {
    final config = await service.readRemoteConfig(entry.id);
    if (config == null) continue;
    for (final task
        in service.convertConfigToTasks(config, entry.id, null, entries)) {
      if (localIds.contains(task.id)) continue;
      if (!seen.add(task.id)) continue;
      result.add(task);
    }
  }
  return result;
});

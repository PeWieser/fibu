import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Backup synchronization mode.
enum SyncMode {
  incremental, // Only upload new/modified files; preserve cloud-only files.
  mirror,      // Exact 2-way mirror; deletes in cloud and downloads new cloud files locally.
}

/// Distribution strategy when multiple cloud drives are selected for a task.
enum DistributionStrategy {
  mirrorAll, // Full redundancy: every file is uploaded to all selected remotes.
  balance,   // Space balancing: files are distributed across remotes based on available free space.
}

/// Mode for specifying where files are stored in the cloud remote.
enum TargetFolderMode {
  root,      // Root directory (/)
  custom,    // Existing folder (e.g. backup/media)
  newFolder, // Create and use a new folder
}

/// Model representing a user-configured backup job/task.
class BackupTask {
  final String id;
  final String name;
  final String sourcePath;
  final List<String> _targetRemotes;
  final String _targetRemote;
  final String schedule; // Formatted description string, e.g. "Daily at 02:00"
  final String scheduleDay; // "Daily", "Monday", "Tuesday", "iOS System", etc.
  final String scheduleTime; // "HH:MM" (e.g. "02:00")
  final bool isActive;
  final bool runMissedOnStartup; // Catch-up task flag
  final List<String> excludedFiles; // Files excluded from backup (e.g. deleted from cloud)
  final SyncMode syncMode; // Incremental vs Mirror (2-Way Echo)
  final DistributionStrategy distributionStrategy; // Mirror all vs Balance
  final TargetFolderMode targetFolderMode; // Root vs Custom vs New Folder
  final String targetFolderName; // Subfolder path (e.g. "backup/pictures")
  final bool wifiOnly; // Sync restricted to Wi-Fi only (no cellular data)
  final List<String> selectedAlbums; // Album-Namen für "Fotos & Videos"; leer = alle
  final List<String> selectedFolders; // Lokale Ordnerpfade für den Reiter "Dateien"

  const BackupTask({
    required this.id,
    required this.name,
    required this.sourcePath,
    List<String> targetRemotes = const [],
    String targetRemote = '',
    required this.schedule,
    this.scheduleDay = 'Daily',
    this.scheduleTime = '02:00',
    required this.isActive,
    this.runMissedOnStartup = true,
    this.excludedFiles = const [],
    this.syncMode = SyncMode.incremental,
    this.distributionStrategy = DistributionStrategy.mirrorAll,
    this.targetFolderMode = TargetFolderMode.newFolder,
    this.targetFolderName = 'fibu-backup',
    this.wifiOnly = true,
    this.selectedAlbums = const [],
    this.selectedFolders = const [],
  })  : _targetRemotes = targetRemotes,
        _targetRemote = targetRemote;

  /// Kurze, menschenlesbare Beschreibung der Quelle für die Liste/Detail-Ansicht.
  String get sourceDescription {
    if (sourcePath.startsWith('files:')) {
      return 'Dateien (${selectedFolders.length})';
    }
    if (sourcePath.startsWith('all:')) return 'Fotos & Videos (${selectedAlbums.length})';
    if (sourcePath.startsWith('photos:')) return 'Fotos (${selectedAlbums.length})';
    if (sourcePath.startsWith('videos:')) return 'Videos (${selectedAlbums.length})';
    switch (sourcePath) {
      case 'all':
        return 'Fotos & Videos (alle)';
      case 'photos':
        return 'Alle Fotos';
      case 'videos':
        return 'Alle Videos';
      case 'files':
        return 'Dateien & Ordner';
      default:
        return sourcePath;
    }
  }

  List<String> get targetRemotes => _targetRemotes.isNotEmpty
      ? _targetRemotes
      : (_targetRemote.isNotEmpty ? [_targetRemote] : const []);

  String get targetRemote => _targetRemote.isNotEmpty
      ? _targetRemote
      : (_targetRemotes.isNotEmpty ? _targetRemotes.first : '');

  String get scheduleDescription {
    if (scheduleDay == 'iOS System' || scheduleDay == 'System') {
      return 'Automatisch (iOS System)';
    } else if (scheduleDay == 'Daily') {
      return 'Daily at $scheduleTime';
    } else if (scheduleDay == 'Manual') {
      return 'Manual';
    } else {
      return 'Weekly on ${scheduleDay}s at $scheduleTime';
    }
  }

  static BackupTask createMediaMirrorPresetTask({
    required String remoteName,
    bool isIOS = false,
  }) {
    return BackupTask(
      id: 'media_mirror_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Mediathek-Spiegelung (Fotos & Videos)',
      sourcePath: 'all',
      targetRemotes: remoteName.isNotEmpty ? [remoteName] : const [],
      schedule: isIOS ? 'Automatisch (iOS System)' : 'Daily at 02:00',
      scheduleDay: isIOS ? 'iOS System' : 'Daily',
      scheduleTime: '02:00',
      isActive: true,
      syncMode: SyncMode.mirror,
      distributionStrategy: DistributionStrategy.mirrorAll,
      targetFolderMode: TargetFolderMode.newFolder,
      targetFolderName: 'fibu-backup/Photos',
      wifiOnly: true,
    );
  }

  static BackupTask createMediaIncrementalPresetTask({
    required String remoteName,
    bool isIOS = false,
  }) {
    return BackupTask(
      id: 'media_backup_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Medien-Sicherung (Inkrementell)',
      sourcePath: 'all',
      targetRemotes: remoteName.isNotEmpty ? [remoteName] : const [],
      schedule: isIOS ? 'Automatisch (iOS System)' : 'Daily at 02:00',
      scheduleDay: isIOS ? 'iOS System' : 'Daily',
      scheduleTime: '02:00',
      isActive: true,
      syncMode: SyncMode.incremental,
      distributionStrategy: DistributionStrategy.mirrorAll,
      targetFolderMode: TargetFolderMode.newFolder,
      targetFolderName: 'fibu-backup/Photos',
      wifiOnly: true,
    );
  }

  static BackupTask createDocumentsPresetTask({
    required String remoteName,
    bool isIOS = false,
  }) {
    return BackupTask(
      id: 'docs_backup_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Dokumente & Dateien Backup',
      sourcePath: 'documents',
      targetRemotes: remoteName.isNotEmpty ? [remoteName] : const [],
      schedule: isIOS ? 'Automatisch (iOS System)' : 'Daily at 02:00',
      scheduleDay: isIOS ? 'iOS System' : 'Daily',
      scheduleTime: '02:00',
      isActive: true,
      syncMode: SyncMode.incremental,
      distributionStrategy: DistributionStrategy.mirrorAll,
      targetFolderMode: TargetFolderMode.newFolder,
      targetFolderName: 'fibu-backup/Dateien',
      wifiOnly: true,
    );
  }

  static BackupTask createMediaBackupTask({
    required String remoteName,
    bool isIOS = false,
  }) {
    return createMediaMirrorPresetTask(remoteName: remoteName, isIOS: isIOS);
  }

  static BackupTask createDocumentsBackupTask({
    required String remoteName,
    bool isIOS = false,
  }) {
    return createDocumentsPresetTask(remoteName: remoteName, isIOS: isIOS);
  }

  BackupTask copyWith({
    String? name,
    String? sourcePath,
    List<String>? targetRemotes,
    String? schedule,
    String? scheduleDay,
    String? scheduleTime,
    bool? isActive,
    bool? runMissedOnStartup,
    List<String>? excludedFiles,
    SyncMode? syncMode,
    DistributionStrategy? distributionStrategy,
    TargetFolderMode? targetFolderMode,
    String? targetFolderName,
    bool? wifiOnly,
    List<String>? selectedAlbums,
    List<String>? selectedFolders,
  }) {
    return BackupTask(
      id: id,
      name: name ?? this.name,
      sourcePath: sourcePath ?? this.sourcePath,
      targetRemotes: targetRemotes ?? this.targetRemotes,
      schedule: schedule ?? this.schedule,
      scheduleDay: scheduleDay ?? this.scheduleDay,
      scheduleTime: scheduleTime ?? this.scheduleTime,
      isActive: isActive ?? this.isActive,
      runMissedOnStartup: runMissedOnStartup ?? this.runMissedOnStartup,
      excludedFiles: excludedFiles ?? this.excludedFiles,
      syncMode: syncMode ?? this.syncMode,
      distributionStrategy: distributionStrategy ?? this.distributionStrategy,
      targetFolderMode: targetFolderMode ?? this.targetFolderMode,
      targetFolderName: targetFolderName ?? this.targetFolderName,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      selectedAlbums: selectedAlbums ?? this.selectedAlbums,
      selectedFolders: selectedFolders ?? this.selectedFolders,
    );
  }
}

/// State notifier managing the list of user-configured backup tasks.
/// Persists tasks locally to a JSON file with NO mock dummy data.
class TasksListNotifier extends StateNotifier<List<BackupTask>> {
  TasksListNotifier() : super(const []) {
    _loadTasks();
  }

  Future<File> _getTasksFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/tasks.json');
  }

  Future<void> _loadTasks() async {
    try {
      final file = await _getTasksFile();
      if (file.existsSync()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = json.decode(content);
        state = jsonList.map((j) {
          SyncMode mode = SyncMode.incremental;
          if (j['syncMode'] == 'mirror') {
            mode = SyncMode.mirror;
          }

          DistributionStrategy dist = DistributionStrategy.mirrorAll;
          if (j['distributionStrategy'] == 'balance') {
            dist = DistributionStrategy.balance;
          }

          TargetFolderMode folderMode = TargetFolderMode.custom;
          if (j['targetFolderMode'] == 'root') {
            folderMode = TargetFolderMode.root;
          } else if (j['targetFolderMode'] == 'newFolder') {
            folderMode = TargetFolderMode.newFolder;
          }

          List<String> remotes = [];
          if (j['targetRemotes'] != null) {
            remotes = (j['targetRemotes'] as List<dynamic>).map((e) => e.toString()).toList();
          } else if (j['targetRemote'] != null) {
            final tr = j['targetRemote'].toString().split(':').first;
            if (tr.isNotEmpty) remotes = [tr];
          }

          return BackupTask(
            id: j['id'] as String,
            name: j['name'] as String,
            sourcePath: j['sourcePath'] as String,
            targetRemotes: remotes,
            schedule: j['schedule'] as String,
            scheduleDay: j['scheduleDay'] as String? ?? 'Daily',
            scheduleTime: j['scheduleTime'] as String? ?? '02:00',
            isActive: j['isActive'] as bool? ?? true,
            runMissedOnStartup: j['runMissedOnStartup'] as bool? ?? true,
            excludedFiles: (j['excludedFiles'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
            syncMode: mode,
            distributionStrategy: dist,
            targetFolderMode: folderMode,
            targetFolderName: j['targetFolderName'] as String? ?? 'backup/media',
            wifiOnly: j['wifiOnly'] as bool? ?? true,
            selectedAlbums: (j['selectedAlbums'] as List<dynamic>?)?.cast<String>() ?? const [],
            selectedFolders: (j['selectedFolders'] as List<dynamic>?)?.cast<String>() ?? const [],
          );
        }).toList();
      }
    } catch (_) {
      // Catch exceptions silently in unit tests (e.g. MissingPluginException for path_provider)
    }
  }

  Future<void> _saveTasks() async {
    try {
      final file = await _getTasksFile();
      final List<Map<String, dynamic>> jsonList = state.map((t) => {
        'id': t.id,
        'name': t.name,
        'sourcePath': t.sourcePath,
        'targetRemotes': t.targetRemotes,
        'targetRemote': t.targetRemote,
        'schedule': t.schedule,
        'scheduleDay': t.scheduleDay,
        'scheduleTime': t.scheduleTime,
        'isActive': t.isActive,
        'runMissedOnStartup': t.runMissedOnStartup,
        'excludedFiles': t.excludedFiles,
        'syncMode': t.syncMode == SyncMode.mirror ? 'mirror' : 'incremental',
        'distributionStrategy': t.distributionStrategy == DistributionStrategy.balance ? 'balance' : 'mirrorAll',
        'targetFolderMode': t.targetFolderMode == TargetFolderMode.root
            ? 'root'
            : (t.targetFolderMode == TargetFolderMode.newFolder ? 'newFolder' : 'custom'),
        'targetFolderName': t.targetFolderName,
        'wifiOnly': t.wifiOnly,
        'selectedAlbums': t.selectedAlbums,
        'selectedFolders': t.selectedFolders,
      }).toList();
      await file.writeAsString(json.encode(jsonList));
    } catch (_) {
      // Ignore write errors in test settings
    }
  }

  void addTask(BackupTask task) {
    state = [...state, task];
    _saveTasks();
  }

  /// Imports multiple tasks and appends them to state.
  void importTasks(List<BackupTask> newTasks) {
    state = [...state, ...newTasks];
    _saveTasks();
  }

  void updateTask(String id, BackupTask updatedTask) {
    state = [
      for (final t in state)
        if (t.id == id) updatedTask else t
    ];
    _saveTasks();
  }

  void removeTask(String id) {
    state = state.where((t) => t.id != id).toList();
    _saveTasks();
  }

  void toggleTaskActive(String id) {
    state = [
      for (final t in state)
        if (t.id == id) t.copyWith(isActive: !t.isActive) else t
    ];
    _saveTasks();
  }

  /// Adds an exclusion rule for a file path across all tasks targeting this remote or containing the path.
  void addExcludeRule(String remote, String filePath) {
    state = [
      for (final t in state)
        if (t.targetRemotes.contains(remote) || t.targetRemote.contains(remote))
          t.copyWith(
            excludedFiles: {...t.excludedFiles, filePath}.toList(),
          )
        else
          t
    ];
    _saveTasks();
  }
}

/// Riverpod provider for the tasks list.
final tasksListProvider = StateNotifierProvider<TasksListNotifier, List<BackupTask>>((ref) {
  return TasksListNotifier();
});

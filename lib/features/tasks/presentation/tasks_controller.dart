import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Model representing a user-configured backup job/task.
class BackupTask {
  final String id;
  final String name;
  final String sourcePath;
  final String targetRemote;
  final String schedule; // Formatted description string, e.g. "Daily at 02:00"
  final String scheduleDay; // "Daily", "Monday", "Tuesday", etc.
  final String scheduleTime; // "HH:MM" (e.g. "02:00")
  final bool isActive;
  final bool runMissedOnStartup; // Catch-up task flag
  final List<String> excludedFiles; // Files excluded from backup (e.g. deleted from cloud)

  const BackupTask({
    required this.id,
    required this.name,
    required this.sourcePath,
    required this.targetRemote,
    required this.schedule,
    this.scheduleDay = 'Daily',
    this.scheduleTime = '02:00',
    required this.isActive,
    this.runMissedOnStartup = true,
    this.excludedFiles = const [],
  });

  String get scheduleDescription {
    if (scheduleDay == 'Daily') {
      return 'Daily at $scheduleTime';
    } else if (scheduleDay == 'Manual') {
      return 'Manual';
    } else {
      return 'Weekly on ${scheduleDay}s at $scheduleTime';
    }
  }

  BackupTask copyWith({
    String? name,
    String? sourcePath,
    String? targetRemote,
    String? schedule,
    String? scheduleDay,
    String? scheduleTime,
    bool? isActive,
    bool? runMissedOnStartup,
    List<String>? excludedFiles,
  }) {
    return BackupTask(
      id: id,
      name: name ?? this.name,
      sourcePath: sourcePath ?? this.sourcePath,
      targetRemote: targetRemote ?? this.targetRemote,
      schedule: schedule ?? this.schedule,
      scheduleDay: scheduleDay ?? this.scheduleDay,
      scheduleTime: scheduleTime ?? this.scheduleTime,
      isActive: isActive ?? this.isActive,
      runMissedOnStartup: runMissedOnStartup ?? this.runMissedOnStartup,
      excludedFiles: excludedFiles ?? this.excludedFiles,
    );
  }
}

/// State notifier managing the list of user-configured backup tasks.
/// Persists tasks locally to a JSON file.
class TasksListNotifier extends StateNotifier<List<BackupTask>> {
  TasksListNotifier()
      : super(const [
          BackupTask(
            id: 'task_1',
            name: 'Camera Photos Backup',
            sourcePath: 'C:\\Users\\User\\Pictures\\Camera',
            targetRemote: 'GoogleDrive_Backup:backup/pictures',
            schedule: 'Daily at 02:00',
            scheduleDay: 'Daily',
            scheduleTime: '02:00',
            isActive: true,
            runMissedOnStartup: true,
          ),
          BackupTask(
            id: 'task_2',
            name: 'GoPro Videos Archive',
            sourcePath: 'D:\\Videos\\GoPro',
            targetRemote: 'OneDrive_Backup:backup/videos',
            schedule: 'Weekly on Sundays at 04:00',
            scheduleDay: 'Sunday',
            scheduleTime: '04:00',
            isActive: true,
            runMissedOnStartup: true,
          ),
          BackupTask(
            id: 'task_3',
            name: 'Work Documents Sync',
            sourcePath: 'C:\\Users\\User\\Documents\\Work',
            targetRemote: 'Dropbox_Backup:backup/documents',
            schedule: 'Manual',
            scheduleDay: 'Manual',
            scheduleTime: '12:00',
            isActive: false,
            runMissedOnStartup: true,
          ),
        ]) {
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
        state = jsonList.map((j) => BackupTask(
          id: j['id'] as String,
          name: j['name'] as String,
          sourcePath: j['sourcePath'] as String,
          targetRemote: j['targetRemote'] as String,
          schedule: j['schedule'] as String,
          scheduleDay: j['scheduleDay'] as String? ?? 'Daily',
          scheduleTime: j['scheduleTime'] as String? ?? '02:00',
          isActive: j['isActive'] as bool? ?? true,
          runMissedOnStartup: j['runMissedOnStartup'] as bool? ?? true,
          excludedFiles: (j['excludedFiles'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
        )).toList();
      } else {
        await _saveTasks();
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
        'targetRemote': t.targetRemote,
        'schedule': t.schedule,
        'scheduleDay': t.scheduleDay,
        'scheduleTime': t.scheduleTime,
        'isActive': t.isActive,
        'runMissedOnStartup': t.runMissedOnStartup,
        'excludedFiles': t.excludedFiles,
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
        if (t.targetRemote.startsWith('$remote:') || t.targetRemote.contains(remote))
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

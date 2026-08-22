import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/app_paths.dart';
import 'package:workmanager/workmanager.dart';

import 'ios_rclone_service.dart';
import 'rclone_service.dart';
import 'settings_service.dart';
import 'widget_status_service.dart';

/// Identifier registered in iOS `BGTaskSchedulerPermittedIdentifiers`
/// (see ios/Runner/Info.plist) and with Workmanager.
const String fibuBgTaskIdentifier = 'workmanager.background.task';

/// Callback entry point invoked by Workmanager in the background.
///
/// This must be a top-level function annotated with `@pragma('vm:entry-point')`
/// so it survives tree-shaking in release builds.
@pragma('vm:entry-point')
void fibuCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await SchedulerService.runScheduledSync();
      // Danach: Sync-Bedarf neu bewerten und in die Homescreen-Widgets
      // pushen — so bleiben Widgets auch ohne App-Start aktuell.
      try {
        await WidgetStatusNotifier.refreshInBackground();
      } catch (_) {}
      return true;
    } catch (_) {
      // A failed background run is reported as "did not finish cleanly".
      return false;
    }
  });
}

/// Schedules Fibu backup tasks in the background (iOS BGTaskScheduler /
/// Android WorkManager) using the selected schedule from each [BackupTask].
class SchedulerService {
  SchedulerService._();

  /// Registers the periodic background task.
  ///
  /// iOS runs a `BGProcessingTask` (wifi + charging friendly) roughly every
  /// two hours; actual per-task schedules are evaluated in [runScheduledSync].
  static Future<void> initialize() async {
    try {
      await Workmanager().initialize(fibuCallbackDispatcher);
      await Workmanager().registerPeriodicTask(
        fibuBgTaskIdentifier,
        fibuBgTaskIdentifier,
        frequency: const Duration(hours: 2),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingWorkPolicy.keep,
      );
    } catch (_) {
      // Background scheduling is best-effort; it must never crash the UI.
    }
  }

  /// Runs every scheduled, active backup task against the real rclone engine.
  ///
  /// Reads the persisted `tasks.json` (source of truth for user tasks) and
  /// starts only those tasks whose schedule is due right now.
  ///
  /// Netzwerkregeln sind global: Die WLAN-only-Option kommt aus den
  /// App-Einstellungen (nicht mehr pro Task), Offline blockiert komplett.
  static Future<void> runScheduledSync() async {
    final tasks = await _loadTasks();
    if (tasks.isEmpty) return;

    // Globale WLAN-only-Einstellung einmalig lesen.
    var wifiOnly = true;
    try {
      final settings = await SettingsService.loadSettings();
      if (settings != null) wifiOnly = settings.wifiOnlySync;
    } catch (_) {}

    final engine = IosRcloneService();
    final now = DateTime.now();
    for (final task in tasks) {
      if (!(task['isActive'] as bool? ?? false)) continue;
      if (!_isScheduleDue(task, now)) continue;

      final sourcePath = task['sourcePath'] as String? ?? 'all';
      final remotes = (task['targetRemotes'] as List<dynamic>? ?? const [])
          .cast<String>()
          .toList();
      final remoteName = remotes.isNotEmpty ? remotes.first : null;
      if (remoteName == null) continue;

      // Netzwerk-Guard (global): Offline → überspringen; WLAN-only → nur Wi-Fi.
      try {
        final conn = await Connectivity().checkConnectivity();
        if (!conn.any((r) => r != ConnectivityResult.none)) continue;
        if (wifiOnly && !conn.contains(ConnectivityResult.wifi)) continue;
      } catch (_) {
        // Konnte der Status nicht gelesen werden, lieber nicht syncen.
        continue;
      }

      final targetFolder = task['targetFolderName'] as String? ?? 'fibu-backup';
      final isEcho = task['syncMode'] == 'mirror';

      try {
        await engine.startBackupJob(
          localPath: sourcePath,
          remoteName: remoteName,
          remotePath: targetFolder,
          options: SyncOptions(isEchoMode: isEcho),
        );
      } catch (_) {
        // Keep trying the remaining tasks.
      }
    }
  }

  /// Bewertet, ob der Zeitplan einer Aufgabe jetzt ausgelöst werden soll.
  ///
  /// `scheduleDay`: 'Daily' | 'Monday'..'Sunday' | 'Manual' | 'iOS System'
  /// `scheduleTime`: 'HH:MM' (optional; ohne = zu jeder Ausführung).
  /// Ein Toleranzfenster verhindert Mehrfach-Ausführung bei den periodischen
  /// (2-stündigen) BG-Aufrufen.
  static bool _isScheduleDue(Map<String, dynamic> task, DateTime now) {
    final day = task['scheduleDay'] as String? ?? 'Daily';
    final time = task['scheduleTime'] as String?;

    switch (day) {
      case 'Manual':
        // Manuelle Aufgaben laufen nicht automatisch im Hintergrund.
        return false;
      case 'iOS System':
      case 'System':
        // Automatisch (BGProcessingTask) – bei jedem periodischen Aufruf.
        return _isWithinWindow(task, now);
      case 'Daily':
        if (time == null || !time.contains(':')) return true;
        return _matchesTime(time, now);
      default:
        // 'Monday'..'Sunday'
        final int weekday = _weekdayIndex(day);
        if (weekday != now.weekday) return false;
        if (time == null || !time.contains(':')) return true;
        return _matchesTime(time, now);
    }
  }

  static bool _isWithinWindow(Map<String, dynamic> task, DateTime now) {
    final last = _lastRun[task['id']];
    // Mindestens 2 h Abstand zwischen Hintergrund-Syncs je Task.
    if (last != null && now.difference(last).inHours < 2) return false;
    _lastRun[task['id']] = now;
    return true;
  }

  static bool _matchesTime(String time, DateTime now) {
    final parts = time.split(':');
    if (parts.length != 2) return true;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final target = DateTime(now.year, now.month, now.day, h, m);
    // Toleranz: innerhalb der Stunde nach der geplanten Zeit ausführen.
    return !now.isBefore(target) && now.difference(target).inHours < 1;
  }

  static int _weekdayIndex(String day) {
    switch (day) {
      case 'Monday':
        return DateTime.monday;
      case 'Tuesday':
        return DateTime.tuesday;
      case 'Wednesday':
        return DateTime.wednesday;
      case 'Thursday':
        return DateTime.thursday;
      case 'Friday':
        return DateTime.friday;
      case 'Saturday':
        return DateTime.saturday;
      case 'Sunday':
        return DateTime.sunday;
      default:
        return -1;
    }
  }

  static final Map<String, DateTime> _lastRun = {};

  static Future<List<Map<String, dynamic>>> _loadTasks() async {
    try {
      final file = await privateAppFile('tasks.json');
      if (!await file.exists()) return const [];
      final content = await file.readAsString();
      if (content.isEmpty) return const [];
      final decoded = jsonDecode(content);
      return (decoded as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (_) {
      return const [];
    }
  }
}

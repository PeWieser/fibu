import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../utils/app_paths.dart';
import 'package:workmanager/workmanager.dart';

import 'app_log_service.dart';
import 'rclone_provider.dart';
import 'rclone_service.dart';
import 'scheduler_run_log.dart';
import 'sync_lock_service.dart';
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
  ///
  /// **Windows/Android:** `workmanager` hat dort keine bzw. eine andere
  /// Implementierung. Früher lief der Aufruf trotzdem und die
  /// `MissingPluginException` wurde still verschluckt — die Oberfläche zeigte
  /// einen Zeitplan, der nie ausgeführt wurde. Auf Windows übernimmt jetzt
  /// [startWindowsTimer] das Scheduling im laufenden Prozess.
  static Future<void> initialize() async {
    final platform = defaultTargetPlatform;
    if (kIsWeb ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux ||
        platform == TargetPlatform.macOS) {
      startWindowsTimer();
      return;
    }
    // Auch mobil: Was das Betriebssystem nicht auslösen konnte (Gerät aus,
    // kein Netz, BGTaskScheduler zu selten), wird beim App-Start nachgeholt.
    unawaited(runMissedSyncs());
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
    } catch (e) {
      // Hintergrund-Scheduling ist best-effort und darf die UI nie kippen —
      // aber still darf es nicht mehr sein.
      AppLog.warn('scheduler',
          'Hintergrund-Planer nicht verfügbar: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Desktop-Planer (Windows)
  // -------------------------------------------------------------------------

  static Timer? _desktopTimer;

  /// Startet den Planer im laufenden Prozess.
  ///
  /// Zusammen mit dem Autostart ([AutostartService]) ergibt das einen echten
  /// Zeitplan: Die App startet mit Windows, bleibt ohne Fenster offen und
  /// prüft alle [tickInterval], ob eine Aufgabe fällig ist. Was während
  /// ausgeschaltetem Rechner oder ohne Netz verpasst wurde, holt
  /// [runMissedSyncs] beim Start nach.
  static const Duration tickInterval = Duration(minutes: 5);

  static void startWindowsTimer() {
    if (_desktopTimer != null) return;
    AppLog.info('scheduler',
        'Desktop-Planer gestartet (Prüfung alle ${tickInterval.inMinutes} Minuten)');
    // Sofort einmal nachholen, was seit dem letzten Lauf verpasst wurde —
    // sonst wartet der erste Sync bis zum nächsten vollen Intervall.
    unawaited(runMissedSyncs());
    _desktopTimer = Timer.periodic(tickInterval, (_) {
      unawaited(runDueSyncs());
    });
  }

  static void stopWindowsTimer() {
    _desktopTimer?.cancel();
    _desktopTimer = null;
  }

  /// Prüft alle aktiven Aufgaben und startet die fälligen.
  ///
  /// Gemeinsamer Einstieg für den Desktop-Timer und den mobilen
  /// Hintergrund-Callback.
  static Future<void> runDueSyncs() => runScheduledSync();

  // -------------------------------------------------------------------------
  // Nachholen verpasster Läufe
  // -------------------------------------------------------------------------

  /// Holt Läufe nach, die seit dem letzten Erfolg fällig gewesen wären.
  ///
  /// Genau der Fall, den ein reiner Intervall-Timer nicht abdeckt: Rechner
  /// aus, kein Netz, WLAN-only bei Mobilfunk — der Slot war da, der Sync fand
  /// nicht statt. Beim nächsten Start wird verglichen, wann die Aufgabe
  /// zuletzt *hätte* laufen sollen, und gegen den letzten Erfolg gestellt.
  static Future<void> runMissedSyncs() async {
    final tasks = await _loadTasks();
    if (tasks.isEmpty) return;

    var started = 0;
    for (final task in tasks) {
      if (!(task['isActive'] as bool? ?? false)) continue;
      final id = task['id'] as String? ?? '';
      if (id.isEmpty) continue;

      final slot = mostRecentScheduledSlot(task, DateTime.now());
      if (slot == null) continue; // 'Manual' oder kein Zeitplan

      final lastSuccess = await SchedulerRunLog.lastSuccess(id);
      if (lastSuccess != null && !lastSuccess.isBefore(slot)) {
        continue; // Der letzte fällige Slot wurde erfolgreich bedient.
      }

      AppLog.info('scheduler',
          'Aufgabe „${task['name']}": Lauf von '
          '${_hhmm(slot)} wurde verpasst (letzter Erfolg: '
          '${lastSuccess == null ? 'nie' : _hhmm(lastSuccess)}) — wird nachgeholt');
      if (await _runOneTask(task, reason: 'missed')) started++;
    }
    if (started > 0) {
      AppLog.info('scheduler', '$started verpasste Läufe nachgeholt');
    }
  }

  /// Wann hätte diese Aufgabe zuletzt laufen sollen? Null, wenn sie keinen
  /// automatischen Zeitplan hat.
  static DateTime? mostRecentScheduledSlot(
      Map<String, dynamic> task, DateTime now) {
    final day = task['scheduleDay'] as String? ?? 'Daily';
    final time = task['scheduleTime'] as String?;

    int hour = 0, minute = 0;
    if (time != null && time.contains(':')) {
      final parts = time.split(':');
      hour = int.tryParse(parts[0]) ?? 0;
      minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    }

    switch (day) {
      case 'Manual':
        return null;
      case 'iOS System':
      case 'System':
        // Vom Betriebssystem getriggert, kein eigener Slot.
        return null;
      case 'Daily':
        final today = DateTime(now.year, now.month, now.day, hour, minute);
        return now.isBefore(today) ? today.subtract(const Duration(days: 1)) : today;
      default:
        final weekday = _weekdayIndex(day);
        if (weekday < 0) return null;
        // Tage zurückgehen, bis der gesuchte Wochentag erreicht ist.
        var candidate = DateTime(now.year, now.month, now.day, hour, minute);
        for (var i = 0; i <= 7; i++) {
          if (candidate.weekday == weekday && !candidate.isAfter(now)) {
            return candidate;
          }
          candidate = candidate.subtract(const Duration(days: 1));
        }
        return null;
    }
  }

  static String _hhmm(DateTime t) =>
      '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}. '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

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

    final now = DateTime.now();
    for (final task in tasks) {
      if (!(task['isActive'] as bool? ?? false)) continue;
      if (!_isScheduleDue(task, now)) continue;
      await _runOneTask(task, reason: 'scheduled');
    }
  }

  /// Führt eine einzelne Aufgabe aus und notiert den Ausgang im persistenten
  /// Laufprotokoll — die Grundlage für [runMissedSyncs].
  ///
  /// Liefert true, wenn der Sync tatsächlich gestartet wurde.
  static Future<bool> _runOneTask(
    Map<String, dynamic> task, {
    required String reason,
  }) async {
    final id = task['id'] as String? ?? '';
    final name = task['name'] as String? ?? '(ohne Namen)';

    final sourcePath = task['sourcePath'] as String? ?? '';
    // Importierte Aufgaben können ohne Quelle dastehen (Quelle eines anderen
    // Geräts). Ohne Prüfung würde der Sync still nichts tun und als Erfolg
    // verbucht — genau das verbietet das Laufprotokoll.
    if (sourcePath.trim().isEmpty) {
      AppLog.warn('scheduler',
          'Aufgabe „$name" übersprungen ($reason): keine Quelle gewählt');
      if (id.isNotEmpty) {
        await SchedulerRunLog.record(id, success: false, error: 'skipped');
      }
      return false;
    }

    final remotes = (task['targetRemotes'] as List<dynamic>? ?? const [])
        .cast<String>()
        .toList();
    final remoteName = remotes.isNotEmpty ? remotes.first : null;
    if (remoteName == null) {
      AppLog.warn('scheduler',
          'Aufgabe „$name" übersprungen ($reason): kein Ziellaufwerk');
      if (id.isNotEmpty) {
        await SchedulerRunLog.record(id, success: false, error: 'skipped');
      }
      return false;
    }

    // Netzwerk-Guard (global): Offline → überspringen; WLAN-only → nur Wi-Fi.
    // Wichtig: Ein übersprungener Lauf wird NICHT als Erfolg gebucht, damit
    // [runMissedSyncs] ihn beim nächsten Start nachholt.
    var wifiOnly = true;
    try {
      final settings = await SettingsService.loadSettings();
      if (settings != null) wifiOnly = settings.wifiOnlySync;
    } catch (_) {}
    try {
      final conn = await Connectivity().checkConnectivity();
      if (!conn.any((r) => r != ConnectivityResult.none)) {
        AppLog.info('scheduler',
            'Aufgabe „$name" übersprungen ($reason): offline — wird nachgeholt');
        if (id.isNotEmpty) {
          await SchedulerRunLog.record(id, success: false, error: 'skipped');
        }
        return false;
      }
      if (wifiOnly && !conn.contains(ConnectivityResult.wifi)) {
        AppLog.info('scheduler',
            'Aufgabe „$name" übersprungen ($reason): nur WLAN erlaubt — wird nachgeholt');
        if (id.isNotEmpty) {
          await SchedulerRunLog.record(id, success: false, error: 'skipped');
        }
        return false;
      }
    } catch (_) {
      // Konnte der Status nicht gelesen werden, lieber nicht syncen.
      if (id.isNotEmpty) {
        await SchedulerRunLog.record(id, success: false, error: 'skipped');
      }
      return false;
    }

    // Plattformgerecht — auf Windows ist das die EXE-basierte Engine, nicht
    // der librclone-MethodChannel.
    final engine = createRcloneServiceForPlatform();
    // Kein Start, solange ein anderer Lauf aktiv ist (manuell ausgelöst
    // oder eine frühere Aufgabe dieser Runde) — sonst überlappen sich
    // zwei Syncs auf demselben Mirror-Zustand.
    if (engine.isSyncRunning) {
      AppLog.info('scheduler',
          'Aufgabe „$name" übersprungen ($reason): Es läuft bereits ein Sync');
      return false;
    }

    final targetFolder = task['targetFolderName'] as String? ?? 'fibu-backup';
    final isEcho = task['syncMode'] == 'mirror';

    // Geräteübergreifende Sperre — dieselbe wie beim manuellen Lauf.
    // Ohne sie würde ein geplanter Hintergrund-Lauf auf einem Gerät einem
    // manuellen Lauf auf einem anderen in denselben Zielordner schreiben.
    // Bei einem Spiegel mit Löschrecht zieht sich das gegenseitig die
    // Dateien weg (docs/TESTMATRIX_IOS_WINDOWS.md, B14).
    final lockHolder =
        await SyncLock.acquire(engine, remoteName, targetFolder);
    if (lockHolder != null) {
      AppLog.info('scheduler',
          'Aufgabe „$name" übersprungen ($reason): $lockHolder synct gerade');
      if (id.isNotEmpty) {
        await SchedulerRunLog.record(id, success: false, error: 'skipped');
      }
      return false;
    }

    try {
      await engine.startBackupJob(
        localPath: sourcePath,
        remoteName: remoteName,
        remotePath: targetFolder,
        options: SyncOptions(isEchoMode: isEcho, isBackground: true),
      );
      if (id.isNotEmpty) await SchedulerRunLog.record(id, success: true);
      AppLog.info('scheduler', 'Aufgabe „$name" ausgeführt ($reason)');
      return true;
    } catch (e) {
      if (id.isNotEmpty) {
        await SchedulerRunLog.record(id, success: false, error: '$e');
      }
      AppLog.warn('scheduler', 'Aufgabe „$name" fehlgeschlagen ($reason): $e');
      return false;
    } finally {
      await SyncLock.release(engine, remoteName, targetFolder);
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

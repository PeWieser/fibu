import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../utils/app_paths.dart';
import 'app_log_service.dart';

/// Zustand eines einzelnen Backup-Tasks für das iOS-Homescreen-Widget.
class WidgetTaskState {
  final String taskId;
  final String name;

  /// 'ok' | 'error' | 'never' | 'pending'
  final String status;
  final String lastSyncIso;
  final int mediaCountAtLastSync;

  const WidgetTaskState({
    required this.taskId,
    required this.name,
    required this.status,
    required this.lastSyncIso,
    this.mediaCountAtLastSync = 0,
  });

  Map<String, dynamic> toJson() => {
        'taskId': taskId,
        'name': name,
        'status': status,
        'lastSyncIso': lastSyncIso,
        'mediaCountAtLastSync': mediaCountAtLastSync,
      };

  factory WidgetTaskState.fromJson(Map<String, dynamic> j) => WidgetTaskState(
        taskId: j['taskId'] as String? ?? '',
        name: j['name'] as String? ?? '',
        status: j['status'] as String? ?? 'never',
        lastSyncIso: j['lastSyncIso'] as String? ?? '',
        mediaCountAtLastSync: (j['mediaCountAtLastSync'] as num?)?.toInt() ?? 0,
      );
}

/// Vollständiger Widget-Datensatz (wird als JSON in die App-Group geschrieben).
class WidgetStatusData {
  final String lastSyncIso;
  final bool needsSync;
  final String lastError;
  final int activeTaskCount;
  final List<WidgetTaskState> tasks;

  const WidgetStatusData({
    this.lastSyncIso = '',
    this.needsSync = false,
    this.lastError = '',
    this.activeTaskCount = 0,
    this.tasks = const [],
  });

  Map<String, dynamic> toJson() => {
        'lastSyncIso': lastSyncIso,
        'needsSync': needsSync,
        'lastError': lastError,
        'activeTaskCount': activeTaskCount,
        'tasks': tasks.map((t) => t.toJson()).toList(),
      };

  factory WidgetStatusData.fromJson(Map<String, dynamic> j) =>
      WidgetStatusData(
        lastSyncIso: j['lastSyncIso'] as String? ?? '',
        needsSync: j['needsSync'] as bool? ?? false,
        lastError: j['lastError'] as String? ?? '',
        activeTaskCount: (j['activeTaskCount'] as num?)?.toInt() ?? 0,
        tasks: (j['tasks'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((m) => WidgetTaskState.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );

  WidgetStatusData copyWith({
    String? lastSyncIso,
    bool? needsSync,
    String? lastError,
    int? activeTaskCount,
    List<WidgetTaskState>? tasks,
  }) =>
      WidgetStatusData(
        lastSyncIso: lastSyncIso ?? this.lastSyncIso,
        needsSync: needsSync ?? this.needsSync,
        lastError: lastError ?? this.lastError,
        activeTaskCount: activeTaskCount ?? this.activeTaskCount,
        tasks: tasks ?? this.tasks,
      );
}

/// Notifier zum Widget-Status: liest den persistierten Zustand, berechnet
/// „aktuelle vs. gesyncte Medien-Anzahl" (billig, ohne Asset-Export) für
/// `needsSync` und pusht alles via MethodChannel `fibu/widget` in die
/// App-Group Extension.
class WidgetStatusNotifier extends StateNotifier<WidgetStatusData> {
  WidgetStatusNotifier() : super(const WidgetStatusData()) {
    ready = _load();
  }

  /// Abgeschlossen, sobald der persistierte Zustand gelesen UND die erste
  /// Neubewertung gepusht wurde (wichtig für den Hintergrund-Lauf).
  late final Future<void> ready;

  /// Für den Workmanager-Hintergrund-Lauf (eigenes Isolate, kein Riverpod):
  /// Zustand laden, Sync-Bedarf neu bewerten, in die Widgets pushen.
  static Future<void> refreshInBackground() async {
    final notifier = WidgetStatusNotifier();
    try {
      await notifier.ready;
    } finally {
      notifier.dispose();
    }
  }

  static const _channel = MethodChannel('fibu/widget');

  bool get _useChannel =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<File> _file() async => File(
      '${(await appSupportRoot()).path}/fibu_state/widget_status.json');

  Future<void> _load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        final data = jsonDecode(await f.readAsString());
        if (data is Map) {
          state = WidgetStatusData.fromJson(Map<String, dynamic>.from(data));
        }
      }
    } catch (_) {}
    await recomputeAndPush();
  }

  Future<void> _persist() async {
    try {
      final f = await _file();
      if (!await f.parent.exists()) await f.parent.create(recursive: true);
      await f.writeAsString(jsonEncode(state.toJson()));
    } catch (_) {}
  }

  Future<void> _pushToWidget() async {
    if (!_useChannel) return;
    try {
      await _channel.invokeMethod<void>('setStatus', state.toJson());
    } catch (e) {
      AppLog.warn('widget', 'Widget-Status konnte nicht gepusht werden: $e');
    }
  }

  /// Zählt Medien EINMAL über das „Alle Fotos“-Album — niemals Summe über
  /// alle Alben (sonst Mehrfachzählung + schwankende Zahlen → falsches
  /// „Sync fällig“ alle paar Minuten).
  Future<int> _scanMediaCount() async {
    try {
      final ps = await PhotoManager.requestPermissionExtend();
      if (!ps.isAuth && !ps.hasAccess) return 0;
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        hasAll: true,
        onlyAll: true,
      );
      if (paths.isEmpty) return 0;
      // onlyAll:true → genau ein Eintrag („Recents“ / „Alle Fotos“).
      return await paths.first.assetCountAsync;
    } catch (_) {
      return 0;
    }
  }

  /// Volle Neubewertung: nach App-Start, nach Onboarding, insgeheim nach Sync.
  Future<void> recomputeAndPush() async {
    try {
      final tasksFile = await privateAppFile('tasks.json');
      List<Map<String, dynamic>> rawTasks = const [];
      if (await tasksFile.exists()) {
        final decoded = jsonDecode(await tasksFile.readAsString());
        if (decoded is List) {
          rawTasks = [
            for (final e in decoded)
              if (e is Map) Map<String, dynamic>.from(e),
          ];
        }
      }
      final activeTasks =
          rawTasks.where((t) => t['isActive'] as bool? ?? false).toList();

      final countNow = await _scanMediaCount();
      final tasks = <WidgetTaskState>[];
      var needsSync = false;

      for (final t in activeTasks) {
        final id = t['id'] as String? ?? '';
        final name = t['name'] as String? ?? '';
        final taskSrc = (t['sourcePath'] as String? ?? '').toLowerCase();
        final isMedia = taskSrc.startsWith('all') ||
            taskSrc.startsWith('photos') ||
            taskSrc.startsWith('videos') ||
            taskSrc == 'media' ||
            taskSrc == 'alle fotos' ||
            taskSrc == 'alle videos' ||
            taskSrc == 'alles';

        final existing = state.tasks.where((s) => s.taskId == id);
        if (existing.isNotEmpty) {
          var st = existing.first;
          // Nie gelaufen / Fehler → Sync-Bedarf.
          // „pending“ allein bleibt NICHT ewig hängen: nur wenn die
          // Medienzählung sich wirklich geändert hat (sonst bliebe das
          // Banner nach einem Fehl-Recompute dauerhaft orange).
          if (st.status == 'never' || st.status == 'error') {
            needsSync = true;
          }
          if (isMedia && st.mediaCountAtLastSync != countNow) {
            // Bibliothek hat sich seit dem letzten erfolgreichen Sync geändert.
            needsSync = true;
            if (st.status == 'ok' || st.status == 'pending') {
              st = WidgetTaskState(
                taskId: st.taskId,
                name: st.name,
                status: 'pending',
                lastSyncIso: st.lastSyncIso,
                mediaCountAtLastSync: st.mediaCountAtLastSync,
              );
            }
          } else if (st.status == 'pending' &&
              isMedia &&
              st.mediaCountAtLastSync == countNow &&
              st.lastSyncIso.isNotEmpty) {
            // Count wieder stabil und es gab schon einen Lauf → zurück auf ok.
            st = WidgetTaskState(
              taskId: st.taskId,
              name: st.name,
              status: 'ok',
              lastSyncIso: st.lastSyncIso,
              mediaCountAtLastSync: st.mediaCountAtLastSync,
            );
          } else if (st.status == 'pending') {
            // Noch pending und Count unklar/anders → Sync-Bedarf anzeigen.
            needsSync = true;
          }
          tasks.add(st);
        } else {
          // Nie gesynct → Widget zeigt „ausstehend“.
          needsSync = true;
          tasks.add(WidgetTaskState(
            taskId: id,
            name: name,
            status: 'never',
            lastSyncIso: '',
            mediaCountAtLastSync: 0,
          ));
        }
      }

      // Fehler am NEUEN Task-Stand messen (nicht am veralteten state.tasks).
      final hasError = tasks.any((t) => t.status == 'error');
      state = state.copyWith(
        tasks: tasks,
        activeTaskCount: activeTasks.length,
        needsSync: needsSync || hasError,
      );
      if (!hasError) state = state.copyWith(lastError: '');
      AppLog.info('widget',
          'Widget-Status: ${state.activeTaskCount} aktive Tasks, needsSync=${state.needsSync}, mediaCount=$countNow');
      await _persist();
      await _pushToWidget();
    } catch (e) {
      AppLog.warn('widget', 'Widget-Recompute fehlgeschlagen: $e');
    }
  }

  /// Wird nach jedem abgeschlossenen Task-Run aufgerufen (Erfolg oder Fehler).
  Future<void> reportTaskRun(String taskId, String taskName,
      {String? error}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final countNow = await _scanMediaCount();

    final updated = [...state.tasks];
    final idx = updated.indexWhere((t) => t.taskId == taskId);
    final item = WidgetTaskState(
      taskId: taskId,
      name: taskName.isNotEmpty ? taskName : taskId,
      status: error == null ? 'ok' : 'error',
      lastSyncIso: now,
      mediaCountAtLastSync: countNow,
    );
    if (idx >= 0) {
      updated[idx] = item;
    } else {
      updated.add(item);
    }

    // needsSync über ALLE Tasks bewerten — ein erfolgreicher Einzel-Lauf
    // darf andere ausstehende Tasks nicht als „alles aktuell“ maskieren.
    // „pending“ zählt nur, wenn der Count noch abweicht (sonst greift
    // recomputeAndPush und räumt auf).
    final stillNeeds = error != null ||
        updated.any((t) {
          if (t.status == 'never' || t.status == 'error') return true;
          if (t.status == 'pending' &&
              t.mediaCountAtLastSync != countNow) {
            return true;
          }
          return false;
        });

    state = state.copyWith(
      tasks: updated,
      lastSyncIso: now,
      lastError: error ?? '',
      needsSync: stillNeeds,
    );
    await _persist();
    await _pushToWidget();
  }
}

/// Zentraler Provider für den Widget-Status.
final widgetStatusProvider =
    StateNotifierProvider<WidgetStatusNotifier, WidgetStatusData>((ref) {
  return WidgetStatusNotifier();
});

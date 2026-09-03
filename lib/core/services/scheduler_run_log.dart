import 'dart:convert';

import '../utils/app_paths.dart';
import 'app_log_service.dart';

/// Ein gespeicherter Lauf einer Aufgabe.
class SchedulerRun {
  /// Letzter Versuch — unabhängig vom Ausgang.
  final DateTime lastAttemptAt;

  /// Letzter erfolgreicher Lauf. Null, wenn die Aufgabe noch nie durchlief.
  final DateTime? lastSuccessAt;

  /// `ok` | `error` | `skipped`.
  final String lastResult;
  final String lastError;

  const SchedulerRun({
    required this.lastAttemptAt,
    this.lastSuccessAt,
    this.lastResult = 'ok',
    this.lastError = '',
  });

  Map<String, dynamic> toJson() => {
        'lastAttemptAt': lastAttemptAt.toIso8601String(),
        if (lastSuccessAt != null)
          'lastSuccessAt': lastSuccessAt!.toIso8601String(),
        'lastResult': lastResult,
        if (lastError.isNotEmpty) 'lastError': lastError,
      };

  factory SchedulerRun.fromJson(Map<String, dynamic> json) => SchedulerRun(
        lastAttemptAt:
            DateTime.tryParse(json['lastAttemptAt'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
        lastSuccessAt:
            DateTime.tryParse(json['lastSuccessAt'] as String? ?? ''),
        lastResult: json['lastResult'] as String? ?? 'ok',
        lastError: json['lastError'] as String? ?? '',
      );
}

/// Persistente Lauf-Historie des Planers.
///
/// **Warum das nötig ist:** Ohne sie kann die App nicht wissen, ob ein
/// geplanter Lauf stattgefunden hat. Der alte Stand hielt `_lastRun` nur im
/// Speicher — nach jedem Neustart war das Wissen weg, und ein verpasster Lauf
/// (PC aus, kein Netz) wurde nie nachgeholt.
///
/// Liegt im privaten App-Support-Ordner (`scheduler_runs.json`).
class SchedulerRunLog {
  SchedulerRunLog._();

  static const String _fileName = 'scheduler_runs.json';

  static Map<String, SchedulerRun>? _cache;

  static Future<Map<String, SchedulerRun>> _read() async {
    final cached = _cache;
    if (cached != null) return cached;
    try {
      final file = await privateAppFile(_fileName);
      if (!await file.exists()) return _cache = {};
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return _cache = {};
      final out = <String, SchedulerRun>{};
      for (final entry in decoded.entries) {
        if (entry.value is Map) {
          out[entry.key] =
              SchedulerRun.fromJson(Map<String, dynamic>.from(entry.value));
        }
      }
      return _cache = out;
    } catch (e) {
      AppLog.warn('scheduler', 'Laufprotokoll nicht lesbar: $e');
      return _cache = {};
    }
  }

  static Future<void> _write(Map<String, SchedulerRun> runs) async {
    try {
      final file = await privateAppFile(_fileName);
      await file.writeAsString(jsonEncode(
          runs.map((k, v) => MapEntry(k, v.toJson()))));
      _cache = runs;
    } catch (e) {
      AppLog.warn('scheduler', 'Laufprotokoll nicht schreibbar: $e');
    }
  }

  static Future<SchedulerRun?> get(String taskId) async {
    final runs = await _read();
    return runs[taskId];
  }

  static Future<DateTime?> lastSuccess(String taskId) async {
    return (await get(taskId))?.lastSuccessAt;
  }

  /// Notiert einen Lauf. Bei Erfolg wird [SchedulerRun.lastSuccessAt]
  /// nachgezogen — das ist der Wert, gegen den die Nachhol-Prüfung läuft.
  static Future<void> record(
    String taskId, {
    required bool success,
    String error = '',
    DateTime? at,
  }) async {
    final runs = Map<String, SchedulerRun>.from(await _read());
    final previous = runs[taskId];
    final now = (at ?? DateTime.now());
    runs[taskId] = SchedulerRun(
      lastAttemptAt: now,
      lastSuccessAt: success ? now : previous?.lastSuccessAt,
      lastResult: success ? 'ok' : (error == 'skipped' ? 'skipped' : 'error'),
      lastError: success ? '' : error,
    );
    await _write(runs);
  }

  /// Entfernt Einträge gelöschter Aufgaben, damit die Datei nicht wächst.
  static Future<void> retainOnly(Set<String> taskIds) async {
    final runs = Map<String, SchedulerRun>.from(await _read());
    final before = runs.length;
    runs.removeWhere((id, _) => !taskIds.contains(id));
    if (runs.length != before) await _write(runs);
  }
}

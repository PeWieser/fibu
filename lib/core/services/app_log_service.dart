import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/app_paths.dart';

/// Schweregrad eines Protokolleintrags.
enum AppLogLevel { info, warning, error }

/// Ein Eintrag im App-weiten Diagnose-Protokoll.
class AppLogEntry {
  final DateTime time;
  final AppLogLevel level;

  /// Kurz-Kategorie, z. B. `engine`, `sync`, `remote`, `media`, `net`.
  final String tag;
  final String message;

  const AppLogEntry({
    required this.time,
    required this.level,
    required this.tag,
    required this.message,
  });

  String get levelLabel {
    switch (level) {
      case AppLogLevel.info:
        return 'INFO';
      case AppLogLevel.warning:
        return 'WARN';
      case AppLogLevel.error:
        return 'ERROR';
    }
  }

  /// Formatierter Eintrag für Anzeige/Export, z. B.
  /// `[14:03:55] INFO  [sync] Task "Fotos" gestartet`.
  String format() {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '[$h:$m:$s] ${levelLabel.padRight(5)} [$tag] $message';
  }
}

/// Ringpuffer (neueste Einträge zuerst) für den App-Log.
class AppLogNotifier extends StateNotifier<List<AppLogEntry>> {
  AppLogNotifier() : super(const []);

  static const int maxEntries = 300;

  void add(AppLogLevel level, String tag, String message) {
    final entry = AppLogEntry(
      time: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
    );
    final next = [entry, ...state];
    state = next.length > maxEntries ? next.sublist(0, maxEntries) : next;
  }

  void clear() => state = const [];
}

/// Zentraler Provider für das Diagnose-Protokoll (UI: DebugLogScreen,
/// Sync-Logs-Dialog).
final appLogProvider =
    StateNotifierProvider<AppLogNotifier, List<AppLogEntry>>((ref) {
  return AppLogNotifier();
});

/// Persistente Logdatei `<Dokumente>/fibu.log` wird durch den Notifier
/// bei jedem Eintrag asynchron mitgeschrieben (siehe [AppLog.attachFileSink]).
File? _logFile;

void _appendToLogFile(String line) {
  final file = _logFile;
  if (file == null) return;
  // Best-effort, niemals blockierend und niemals werfend.
  Future(() async {
    try {
      if (await file.length() > 256 * 1024) {
        // Ring-Schnitt: bei 256 KB wird auf die letzten 1000 Zeilen gekürzt.
        final lines = await file.readAsLines();
        final tail = lines.length > 1000 ? lines.sublist(lines.length - 1000) : lines;
        await file.writeAsString('${tail.join('\n')}\n', flush: false);
      }
      await file.writeAsString('$line\n', mode: FileMode.append, flush: false);
    } catch (_) {
      // Logging darf nie crashen.
    }
  });
}

/// Statische Fassade, damit Services ohne Riverpod-Ref loggen können.
/// Das Attachment passiert einmalig im App-Root (FibuApp).
///
/// Sicherheit: Es werden NIEMALS Passwörter/Tokens oder Zugangsdaten geloggt –
/// Aufrufer loggen nur Methodennamen, Remote-Namen und Zähler.
class AppLog {
  AppLog._();

  static AppLogNotifier? _notifier;

  /// Pfad zur persistenten Logdatei (im privaten App-Support-Ordner).
  static String? get logFilePath => _logFile?.path;

  /// Verbindet die Fassade mit dem Provider-Notifier (App-Start).
  static void attach(WidgetRef ref) {
    _notifier = ref.read(appLogProvider.notifier);
  }

  /// Aktiviert die persistente Logdatei.
  ///
  /// Sie liegt bewusst im PRIVATEN App-Support-Ordner, nicht im
  /// Dokumente-Ordner: `UIFileSharingEnabled` macht den Dokumente-Ordner in
  /// der Dateien-App („Auf meinem iPhone") sichtbar und exportierbar, und das
  /// Protokoll enthält personenbezogene Daten — Dateinamen, Albennamen und
  /// Remote-Pfade (Art. 4 Nr. 1 DSGVO). Zugangsdaten werden ohnehin nie
  /// geloggt. Eine alte Logdatei im Dokumente-Ordner wird von
  /// [privateAppFile] einmalig übernommen und dort gelöscht.
  static Future<void> attachFileSink() async {
    try {
      final file = await privateAppFile('fibu.log');
      if (!await file.exists()) await file.create();
      _logFile = file;
      AppLog.info('app', 'Logdatei aktiv: ${file.path}');
    } catch (_) {}
  }

  static void info(String tag, String message) {
    _notifier?.add(AppLogLevel.info, tag, message);
    _appendToLogFile(_formatRaw(AppLogLevel.info, tag, message));
  }

  static void warn(String tag, String message) {
    _notifier?.add(AppLogLevel.warning, tag, message);
    _appendToLogFile(_formatRaw(AppLogLevel.warning, tag, message));
  }

  static void error(String tag, String message) {
    _notifier?.add(AppLogLevel.error, tag, message);
    _appendToLogFile(_formatRaw(AppLogLevel.error, tag, message));
  }

  static String _formatRaw(AppLogLevel level, String tag, String message) {
    final p = AppLogEntry(
      time: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
    );
    return p.format();
  }

  /// Kompletter Export als Text (z. B. für die Zwischenablage).
  static String exportAll(List<AppLogEntry> entries) =>
      entries.reversed.map((e) => e.format()).join('\n');
}

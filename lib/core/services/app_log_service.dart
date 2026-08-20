import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Statische Fassade, damit Services ohne Riverpod-Ref loggen können.
/// Das Attachment passiert einmalig im App-Root (FibuApp).
///
/// Sicherheit: Es werden NIEMALS Passwörter/Tokens oder Zugangsdaten geloggt –
/// Aufrufer loggen nur Methodennamen, Remote-Namen und Zähler.
class AppLog {
  AppLog._();

  static AppLogNotifier? _notifier;

  /// Verbindet die Fassade mit dem Provider-Notifier (App-Start).
  static void attach(WidgetRef ref) {
    _notifier = ref.read(appLogProvider.notifier);
  }

  static void info(String tag, String message) =>
      _notifier?.add(AppLogLevel.info, tag, message);

  static void warn(String tag, String message) =>
      _notifier?.add(AppLogLevel.warning, tag, message);

  static void error(String tag, String message) =>
      _notifier?.add(AppLogLevel.error, tag, message);

  /// Kompletter Export als Text (z. B. für die Zwischenablage).
  static String exportAll(List<AppLogEntry> entries) =>
      entries.reversed.map((e) => e.format()).join('\n');
}

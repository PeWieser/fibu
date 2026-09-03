import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_log_service.dart';

/// Autostart für Windows über den Run-Schlüssel des aktuellen Benutzers.
///
/// `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` braucht **keine**
/// Administratorrechte und betrifft nur das eigene Benutzerkonto — im
/// Gegensatz zu `HKLM`, das alle Nutzer ändern würde.
///
/// Der Eintrag startet `fibu.exe --background`. Der native Startup-Pfad
/// (`windows/runner/flutter_window.cpp`) lässt das Fenster dann zu; der
/// Prozess läuft weiter und bedient den Zeitplan.
///
/// Andere Plattformen: iOS und Android haben keinen Autostart im Sinn von
/// „Prozess beim Hochfahren starten". Dort übernimmt das Betriebssystem das
/// Scheduling (BGTaskScheduler / WorkManager), und [isEnabled] liefert false,
/// damit die Einstellung gar nicht erst angeboten wird.
class AutostartService {
  AutostartService._();

  static const String _valueName = 'Fibu';
  static const String _runKey =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';

  /// Flag, mit dem die App im Hintergrund startet.
  static const String backgroundFlag = '--background';

  /// `Platform.isWindows` ist im Web false, braucht also keinen eigenen
  /// Web-Guard.
  static bool get isSupported => Platform.isWindows;

  /// Liegt ein Autostart-Eintrag vor?
  static Future<bool> isEnabled() async {
    if (!isSupported) return false;
    try {
      final result = await Process.run(
          'reg', ['query', _runKey, '/v', _valueName]);
      return result.exitCode == 0;
    } catch (e) {
      AppLog.warn('autostart', 'Status nicht lesbar: $e');
      return false;
    }
  }

  /// Trägt die App in den Autostart ein. Liefert true bei Erfolg.
  static Future<bool> enable() async {
    if (!isSupported) return false;
    final exe = Platform.resolvedExecutable;
    if (!File(exe).existsSync()) {
      AppLog.warn('autostart',
          'Autostart nicht eingerichtet: $exe existiert nicht');
      return false;
    }
    try {
      // Pfad in Anführungszeichen (Leerzeichen im Installationspfad sind die
      // Regel), Schalter dahinter.
      final command = '"$exe" $backgroundFlag';
      final result = await Process.run('reg', [
        'add',
        _runKey,
        '/v',
        _valueName,
        '/t',
        'REG_SZ',
        '/d',
        command,
        '/f',
      ]);
      if (result.exitCode != 0) {
        AppLog.warn('autostart',
            'Eintragen fehlgeschlagen: ${result.stderr}');
        return false;
      }
      AppLog.info('autostart', 'Autostart eingerichtet: $command');
      return true;
    } catch (e) {
      AppLog.warn('autostart', 'Eintragen fehlgeschlagen: $e');
      return false;
    }
  }

  /// Entfernt den Autostart-Eintrag. Fehlt er bereits, gilt das als Erfolg.
  static Future<bool> disable() async {
    if (!isSupported) return false;
    try {
      final result = await Process.run(
          'reg', ['delete', _runKey, '/v', _valueName, '/f']);
      // exitCode 1 = Schlüssel war nicht vorhanden — Zielzustand erreicht.
      final ok = result.exitCode == 0 || !await isEnabled();
      if (ok) AppLog.info('autostart', 'Autostart entfernt');
      return ok;
    } catch (e) {
      AppLog.warn('autostart', 'Entfernen fehlgeschlagen: $e');
      return false;
    }
  }
}

/// Zustand des Autostart-Schalters für die Oberfläche.
///
/// Ein `FutureProvider` statt eines reinen bools: Der Wert kommt aus der
/// Registry, also asynchron. Die UI zeigt solange den letzten bekannten
/// Zustand und aktualisiert sich nach dem Lesen.
final autostartEnabledProvider =
    FutureProvider<bool>((ref) => AutostartService.isEnabled());

/// Schaltet den Autostart um und aktualisiert [autostartEnabledProvider].
Future<void> setAutostartEnabled(WidgetRef ref, bool value) async {
  final ok = value ? await AutostartService.enable() : await AutostartService.disable();
  // Nur bei Erfolg den Zustand fortschreiben — sonst würde der Schalter eine
  // Änderung anzeigen, die in der Registry nie angekommen ist.
  if (ok) ref.invalidate(autostartEnabledProvider);
}

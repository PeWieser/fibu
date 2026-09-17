import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_log_service.dart';

/// Hält Bildschirm/System während eines Laufs wach — ohne UI und ohne
/// Meldung, rein funktional: beim Start aktivieren, am Ende wieder lösen.
///
/// Hintergrund: iOS suspendiert eine App im Standby nach kurzer Zeit — ein
/// manueller Sync würde mitten im Transfer einfrieren. Mit aktiviertem
/// Idle-Timer-Verbot bleibt das Gerät wach, solange der Lauf läuft
/// (Anfrage 2026-09-17). Für geplante Hintergrundläufe ist es wirkungslos,
/// aber harmlos: Ein BGProcessingTask läuft ohnehin nur, wenn das System
/// den Lauf zulässt.
///
/// Referenzzähler statt Schalter: Der Dienst wird aus mehreren
/// Einstiegspunkten (beide Engines) bedient; ausgeschaltet wird erst, wenn
/// der letzte Lauf fertig ist.
class KeepAwakeService {
  KeepAwakeService._();

  static const MethodChannel _channel = MethodChannel('fibu/system');
  static int _active = 0;
  static bool _engaged = false;

  /// Ein Lauf beginnt.
  static void enter() {
    _active++;
    if (!_engaged) {
      _engaged = true;
      _set(on: true);
    }
  }

  /// Ein Lauf ist zu Ende (auch bei Fehler/Abbruch — die Aufrufer nutzen
  /// dieselben `whenComplete`/`finally`-Pfade wie der SyncRunGuard).
  static void exit() {
    if (_active > 0) _active--;
    if (_active == 0 && _engaged) {
      _engaged = false;
      _set(on: false);
    }
  }

  static void _set({required bool on}) {
    try {
      if (kIsWeb) return;
      if (Platform.isIOS) {
        _channel
            .invokeMethod<void>('setIdleTimerDisabled', {'disabled': on})
            .catchError((Object e) {
          AppLog.warn('keepawake', 'Idle-Timer konnte nicht gesetzt werden: $e');
        });
        return;
      }
      if (Platform.isWindows) {
        _setWindows(on);
      }
      // Android: ohne native Fibu-Brücke kein Kanal — bewusst No-Op.
    } catch (e) {
      AppLog.warn('keepawake', 'Wachhalten fehlgeschlagen: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Windows: SetThreadExecutionState (kernel32) über dart:ffi — ohne
  // Zusatzpaket. Der Zustand gilt für den (lebenden) Hauptthread und wird
  // am Laufende mit ES_CONTINUOUS allein zurückgesetzt.
  // -------------------------------------------------------------------------

  static int Function(int)? _setThreadExecutionState;

  static void _setWindows(bool on) {
    const esContinuous = 0x80000000;
    const esSystemRequired = 0x00000001;
    const esDisplayRequired = 0x00000002;
    try {
      final fn = _setThreadExecutionState ??= DynamicLibrary.open('kernel32.dll')
          .lookup<NativeFunction<Uint32 Function(Uint32)>>(
              'SetThreadExecutionState')
          .asFunction<int Function(int)>();
      fn(on
          ? (esContinuous | esSystemRequired | esDisplayRequired)
          : esContinuous);
    } catch (e) {
      AppLog.warn('keepawake', 'Windows-Wachhalten fehlgeschlagen: $e');
    }
  }
}

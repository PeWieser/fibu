import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../utils/app_paths.dart';
import 'app_log_service.dart';

/// Stabile Kennung dieses Geräts.
///
/// Wird beim ersten Start erzeugt und danach nie mehr geändert. Sie liegt im
/// privaten App-Support-Ordner (`device.json`) und verlässt das Gerät nur in
/// der Cloud-Konfiguration `.fibu/config.json`, damit mehrere Geräte dieselbe
/// Datei teilen können, ohne sich gegenseitig die Aufgaben zu überschreiben.
///
/// Bewusst eine Zufallskennung und kein Hardware-Merkmal: Sie muss nur
/// eindeutig und stabil sein, nicht zurückverfolgbar.
class DeviceIdentity {
  DeviceIdentity._();

  static const String _fileName = 'device.json';

  static String? _cached;

  /// Kennung dieses Geräts; wird beim ersten Aufruf erzeugt und gespeichert.
  static Future<String> id() async {
    final cached = _cached;
    if (cached != null) return cached;

    try {
      final file = await privateAppFile(_fileName);
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          final existing = decoded['deviceId'] as String? ?? '';
          if (existing.isNotEmpty) {
            _cached = existing;
            return existing;
          }
        }
      }
      final fresh = _generate();
      await file.writeAsString(jsonEncode({
        'deviceId': fresh,
        'createdAt': DateTime.now().toIso8601String(),
        'hostname': Platform.localHostname,
      }));
      _cached = fresh;
      AppLog.info('device', 'Gerätekennung erzeugt: $fresh');
      return fresh;
    } catch (e) {
      // Ohne Persistenz trotzdem eine Kennung liefern — sonst bricht das
      // Zusammenführen der Cloud-Konfiguration komplett weg. Sie ist dann
      // eben nur für diese Sitzung stabil.
      AppLog.warn('device', 'Gerätekennung konnte nicht gespeichert werden: $e');
      return _cached ??= _generate();
    }
  }

  /// Menschenlesbarer Gerätename für Anzeigen.
  static Future<String> displayName() async {
    try {
      final file = await privateAppFile(_fileName);
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          final name = decoded['hostname'] as String? ?? '';
          if (name.isNotEmpty) return name;
        }
      }
    } catch (_) {}
    return Platform.localHostname;
  }

  static String _generate() {
    final rand = Random.secure();
    final bytes = List<int>.generate(8, (_) => rand.nextInt(256));
    return 'dev-${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }
}

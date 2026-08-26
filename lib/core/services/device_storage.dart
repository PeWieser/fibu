import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Kleiner Geräte-Speicher-Helfer für die Sync-Vorabprüfungen.
///
/// Liefert den freien Speicherplatz des App-Volumes in Bytes. Auf iOS wird
/// dafür der native `fibu/system`-Channel genutzt (NSFileManager); auf allen
/// anderen Plattformen wird 0 geliefert (= unbekannt → Prüfung übersprungen).
class DeviceStorage {
  const DeviceStorage._();

  static const _channel = MethodChannel('fibu/system');

  /// Freier Speicher in Bytes, 0 = unbekannt/nicht verfügbar.
  static Future<int> freeBytes() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return 0;
    try {
      return await _channel.invokeMethod<int>('freeDiskSpace') ?? 0;
    } catch (_) {
      return 0;
    }
  }
}

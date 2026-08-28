import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mockt die `path_provider`-Method-Channels für Widget-Tests.
///
/// Ohne das werfen `getApplicationSupportDirectory()` und
/// `getApplicationDocumentsDirectory()` in Tests eine
/// `MissingPluginException`, weil kein echtes Plugin registriert ist. Die
/// Bildschirme lesen darüber `tasks.json`, `settings.json` und den
/// Mirror-Zustand — mit dem Mock landen sie in einem Temp-Ordner.
///
/// Bewusst ohne neue Abhängigkeit implementiert (nur `flutter_test`), damit
/// nichts an `pubspec.yaml` geändert werden muss.
Future<Directory> installPathProviderMock() async {
  final Directory dir = await Directory.systemTemp.createTemp('fibu_test_');
  // setMockMethodCallHandler liefert void zurück — kein await.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (MethodCall call) async {
      switch (call.method) {
        case 'getTemporaryDirectory':
        case 'getApplicationDocumentsDirectory':
        case 'getApplicationSupportDirectory':
        case 'getApplicationCacheDirectory':
        case 'getLibraryDirectory':
        case 'getDownloadsDirectory':
          return dir.path;
        case 'getExternalStorageDirectories':
        case 'getExternalCacheDirectories':
          return <String>[dir.path];
        default:
          return dir.path;
      }
    },
  );
  return dir;
}

/// Entfernt den Mock wieder und räumt den Temp-Ordner auf.
Future<void> removePathProviderMock(Directory dir) async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    null,
  );
  try {
    if (await dir.exists()) await dir.delete(recursive: true);
  } catch (_) {
    // Temp-Ordner räumt das Betriebssystem notfalls selbst auf.
  }
}

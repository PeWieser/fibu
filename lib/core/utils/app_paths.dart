import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Liefert den PRIVATEN App-Support-Ordner (iOS: Library/Application Support).
///
/// Nutzer sehen diesen Inhalt NICHT in der Dateien-App (im Gegensatz zum
/// Dokumente-Ordner, der wegen `UIFileSharingEnabled` dort sichtbar ist).
/// Genau deshalb wandern Config- und State-Dateien hierhin.
Future<Directory> appSupportRoot() async {
  final dir = await getApplicationSupportDirectory();
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

/// Liefert eine Datei im privaten App-Support-Ordner.
///
/// Existiert eine Alt-Datei gleichen Namens im öffentlichen Dokumente-Ordner
/// (von älteren App-Versionen), wird sie einmalig kopiert und danach dort
/// gelöscht – Nutzer sehen nur noch die Log-Datei in „Auf meinem iPhone".
Future<File> privateAppFile(String name) async {
  final support = await appSupportRoot();
  final target = File('${support.path}/$name');
  try {
    if (!await target.exists()) {
      final docs = await getApplicationDocumentsDirectory();
      final legacy = File('${docs.path}/$name');
      if (await legacy.exists()) {
        await legacy.copy(target.path);
        await legacy.delete();
      }
    }
  } catch (_) {
    // Migration best-effort: bei Fehlern einfach am Ziel weiterarbeiten.
  }
  return target;
}

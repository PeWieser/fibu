import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

/// Mediathek-first Brücke zwischen der iOS-Foto-Bibliothek (PhotoKit) und dem
/// lokalen FibuMirror-Spiegel.
///
/// Aufgaben:
///  - [listLibrarySnapshot]: Liest die aktuelle Mediathek (Asset-ID → Pfad) und
///    speichert einen persistenten Snapshot. Ein Vergleich mit dem VORHERIGEN
///    Snapshot erkennt lokal gelöschte Fotos („Mediathek-first"-Lösch-Erkennung),
///    die dann als Tombstones ins Löschprotokoll wandern.
///  - [importIntoLibrary]: Schreibt eine heruntergeladene Datei (Bild/Video) in
///    die Mediathek zurück, damit sie in der Fotos-App erscheint.
///
/// Hinweis: Apples „Zuletzt gelöscht"-Ordner ist für Apps nicht lesbar; die
/// Lösch-Erkennung basiert daher auf Snapshot-Diff, und Löschungen gehen über
/// den eigenen Papierkorb (TrashService), nicht über PhotoKit.
class PhotoKitBridge {
  static const String snapshotSubPath = '.fibu/photokit_snapshot.json';

  /// Liest die Mediathek und liefert Asset-ID → relativer Pfad
  /// (Photos/<Album>/<datei>).
  Future<Map<String, String>> listLibrarySnapshot() async {
    final result = <String, String>{};
    final ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth && !ps.hasAccess) return result;

    final paths = await PhotoManager.getAssetPathList(type: RequestType.common, hasAll: true);
    for (final album in paths) {
      final albumName = album.name.replaceAll(RegExp(r'[/\\:]'), '_');
      final count = await album.assetCountAsync;
      if (count == 0) continue;
      const batch = 100;
      for (int start = 0; start < count; start += batch) {
        final assets = await album.getAssetListRange(
          start: start,
          end: (start + batch).clamp(0, count),
        );
        for (final asset in assets) {
          final file = await asset.file;
          if (file == null) continue;
          final name = asset.title ?? file.path.split('/').last;
          final rel = 'Photos/$albumName/$name';
          result[asset.id] = rel;
        }
      }
    }
    return result;
  }

  /// Lädt den zuletzt gespeicherten Snapshot (Asset-ID → Pfad).
  Future<Map<String, String>> loadSnapshot(String localRoot) async {
    try {
      final f = File('${localRoot}${Platform.pathSeparator}$snapshotSubPath');
      if (!await f.exists()) return {};
      final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return data.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      return {};
    }
  }

  /// Speichert den aktuellen Snapshot.
  Future<void> saveSnapshot(String localRoot, Map<String, String> snapshot) async {
    try {
      final dir = Directory('${localRoot}${Platform.pathSeparator}.fibu');
      if (!await dir.exists()) await dir.create(recursive: true);
      final f = File('${localRoot}${Platform.pathSeparator}$snapshotSubPath');
      await f.writeAsString(jsonEncode(snapshot));
    } catch (_) {}
  }

  /// Ermittelt die lokal gelöschten Pfade (im vorherigen Snapshot, aber nicht
  /// mehr in der Mediathek). Rückgabe: relative Pfade der gelöschten Dateien.
  Future<List<String>> detectLocalDeletions(String localRoot) async {
    final before = await loadSnapshot(localRoot);
    if (before.isEmpty) {
      // Erster Lauf: Snapshot anlegen, nichts als gelöscht melden.
      final current = await listLibrarySnapshot();
      await saveSnapshot(localRoot, current);
      return [];
    }
    final now = await listLibrarySnapshot();
    final beforePaths = before.values.toSet();
    final nowPaths = now.values.toSet();
    // Pfade, die im alten Snapshot waren, jetzt aber fehlen = lokal gelöscht.
    final deleted = beforePaths.difference(nowPaths).toList();
    await saveSnapshot(localRoot, now);
    return deleted;
  }

  /// Importiert eine heruntergeladene Datei in die Mediathek (Fotos-App).
  /// [file] ist die Datei im FibuMirror; [mimeHint] hilft Bild vs. Video.
  Future<bool> importIntoLibrary(File file, {String mimeHint = 'image'}) async {
    try {
      final ps = await PhotoManager.requestPermissionExtend();
      if (!ps.isAuth && !ps.hasAccess) return false;

      if (mimeHint.startsWith('video')) {
        final saved = await PhotoManager.editor.saveVideo(file);
        return saved != null;
      }
      final saved = await PhotoManager.editor.saveImageWithPath(file.path, title: file.path.split('/').last);
      return saved != null;
    } catch (_) {
      return false;
    }
  }

  /// Schätzt den Medientyp einer Datei anhand der Endung.
  static String mimeHintFor(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    const videos = {'mp4', 'mov', 'm4v', 'avi', 'mkv', 'webm', '3gp'};
    if (videos.contains(ext)) return 'video';
    return 'image';
  }
}

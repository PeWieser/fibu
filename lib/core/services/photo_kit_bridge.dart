import 'dart:convert';
import 'dart:io';

import 'package:photo_manager/photo_manager.dart';

import 'app_log_service.dart';

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

  /// Liest den lokalen Fibu-Spiegel per Dateisystem ein und liefert
  /// Pfad (relativ zu [localRoot]) → Pfad. Blitzschnell – KEINE
  /// PhotoKit-Asset-Exporte mehr (\`asset.file\` pro Foto war zuvor das
  /// Performance-Nadelöhr und hat den Mirror-Start blockiert).
  Future<Map<String, String>> listLibrarySnapshot(String localRoot) async {
    final result = <String, String>{};
    final photos = Directory('$localRoot${Platform.pathSeparator}Photos');
    if (!await photos.exists()) return result;
    await for (final entity in photos.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      var rel = entity.path.substring(localRoot.length);
      rel = rel.replaceFirst(RegExp(r'^[/\\]'), '').replaceAll('\\', '/');
      if (rel.startsWith('.fibu')) continue; // Meta-Ordner nie Teil des Snapshots
      result[rel] = rel;
    }
    return result;
  }

  /// Lädt den zuletzt gespeicherten Snapshot (Asset-ID → Pfad).
  Future<Map<String, String>> loadSnapshot(String localRoot) async {
    try {
      final f = File('$localRoot${Platform.pathSeparator}$snapshotSubPath');
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
      final dir = Directory('$localRoot${Platform.pathSeparator}.fibu');
      if (!await dir.exists()) await dir.create(recursive: true);
      final f = File('$localRoot${Platform.pathSeparator}$snapshotSubPath');
      await f.writeAsString(jsonEncode(snapshot));
    } catch (_) {}
  }

  /// Ermittelt die lokal gelöschten Pfade (im vorherigen Snapshot, aber nicht
  /// mehr in der Mediathek). Rückgabe: relative Pfade der gelöschten Dateien.
  Future<List<String>> detectLocalDeletions(String localRoot,
      {void Function(String label)? onProgress}) async {
    AppLog.info('media', 'Lösch-Erkennung: lokalen Spiegel einlesen …');
    onProgress?.call('Lokale Spiegel-Analyse läuft');
    final before = await loadSnapshot(localRoot);
    final now = await listLibrarySnapshot(localRoot);
    if (before.isEmpty) {
      // Erster Lauf: Snapshot anlegen, nichts als gelöscht melden.
      await saveSnapshot(localRoot, now);
      AppLog.info('media', 'Erst-Snapshot mit ${now.length} Medien angelegt');
      return [];
    }
    final beforePaths = before.values.toSet();
    final nowPaths = now.values.toSet();
    // Pfade, die im alten Snapshot waren, jetzt aber fehlen = lokal gelöscht.
    final deleted = beforePaths.difference(nowPaths).toList();

    // Sicherheitsbremse: Wenn auf einmal mehr als die Hälfte aller bekannten
    // Pfade „fehlt", ist das ein Formatwechsel (z. B. Umstieg auf das FS-
    // basierte Snapshotting), kein echtes Massen-Löschen – der Snapshot wird
    // neu aufgebaut, aber NICHTS wird als Löschung propagiert.
    if (beforePaths.length >= 10 && deleted.length * 2 > beforePaths.length) {
      await saveSnapshot(localRoot, now);
      AppLog.warn('media',
          'Snapshot-Diff zu groß (${deleted.length}/${beforePaths.length}) → Formatwechsel erkannt, wird NICHT als Löschung propagiert (Snapshot neu aufgebaut)');
      return [];
    }

    if (deleted.isNotEmpty) {
      AppLog.info('media',
          '${deleted.length} lokal gelöschte Medien erkannt → als Tombstones propagieren');
    }
    await saveSnapshot(localRoot, now);
    return deleted;
  }

  /// Importiert eine heruntergeladene Datei in die Mediathek (Fotos-App).
  /// [file] ist die Datei im FibuMirror; [mimeHint] hilft Bild vs. Video.
  /// [albumName]: Album aus dem Cloud-Pfad (`Photos/<Album>/…`) — das Asset
  /// wird dem gleichnamigen Album zugeordnet (bei Bedarf wird es angelegt),
  /// statt nur unter „Zuletzt“ zu erscheinen.
  Future<bool> importIntoLibrary(File file,
      {String mimeHint = 'image', String? albumName}) async {
    try {
      final ps = await PhotoManager.requestPermissionExtend();
      if (!ps.isAuth && !ps.hasAccess) return false;

      final title = file.path.split('/').last;
      final AssetEntity? asset;
      if (mimeHint.startsWith('video')) {
        asset = await PhotoManager.editor.saveVideo(file, title: title);
      } else {
        asset =
            await PhotoManager.editor.saveImageWithPath(file.path, title: title);
      }
      if (asset == null) return false;

      final album = albumName?.trim();
      if (album != null && album.isNotEmpty && Platform.isIOS) {
        await _assignToAlbum(asset, album);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Ordnet ein frisch importiertes Asset dem Album [albumName] zu.
  /// Existiert kein passendes Nutzer-Album, wird eines angelegt.
  /// Smart-Alben (Zuletzt, Favoriten …) lassen sich nicht befüllen —
  /// Fehler werden geschluckt, der Import selbst bleibt erfolgreich.
  Future<void> _assignToAlbum(AssetEntity asset, String albumName) async {
    try {
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        hasAll: false,
      );
      AssetPathEntity? album;
      for (final p in paths) {
        if (p.isAll) continue;
        if (p.name.trim().toLowerCase() == albumName.toLowerCase()) {
          album = p;
          break;
        }
      }
      album ??= await PhotoManager.editor.darwin.createAlbum(albumName);
      if (album == null) return;
      await PhotoManager.editor.copyAssetToPath(
        asset: asset,
        pathEntity: album,
      );
      AppLog.info('media', 'Import „${asset.title ?? asset.id}“ → Album „$albumName“');
    } catch (e) {
      AppLog.warn('media',
          'Album-Zuordnung „$albumName“ fehlgeschlagen (Import bleibt in der Mediathek): $e');
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

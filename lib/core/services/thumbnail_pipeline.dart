import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../utils/app_paths.dart';
import 'app_log_service.dart';
import 'rclone_service.dart';
import 'thumbnail_creator.dart';
import 'thumbnail_service.dart';

/// Ordnet eine gesicherte Aufnahme ihrer lokalen Quelle zu.
///
/// **Lokal vor Cloud** (`docs/PHASE5_FOTOS_NIVEAU.md` §2.1): Was noch auf dem
/// Gerät liegt, wird nicht aus der Cloud geholt — weder für die Kachel noch
/// für die Vollbild-Ansicht.
///
/// Zwei Wege, je Plattform:
///  * iOS/Android: `fibu_state/<scope>/mirror_state.json` bildet den
///    Spiegel-Pfad auf die `photo_manager`-Asset-ID ab.
///  * Windows: die `assetId` des Spiegels ist der absolute Pfad der
///    Quelldatei (`filesystem_mirror_source.dart:60`).
class LocalMediaResolver {
  const LocalMediaResolver._();

  /// rel → Asset-ID aus allen Spiegel-Zuständen.
  ///
  /// Bewusst über alle Scopes gelesen und nicht über den Slug nachgebaut:
  /// Die Benennung der Scope-Ordner gehört den Engines, und sie hier zu
  /// duplizieren wäre eine zweite Wahrheit, die auseinanderlaufen kann.
  static Future<Map<String, String>> loadAssetIds() async {
    final result = <String, String>{};
    try {
      final support = await appSupportRoot();
      final base = Directory('${support.path}/fibu_state');
      if (!await base.exists()) return result;
      await for (final scope in base.list(followLinks: false)) {
        if (scope is! Directory) continue;
        final file = File('${scope.path}/mirror_state.json');
        if (!await file.exists()) continue;
        try {
          final decoded = jsonDecode(await file.readAsString());
          if (decoded is! Map) continue;
          final items = decoded['items'];
          if (items is! List) continue;
          for (final entry in items) {
            if (entry is! Map) continue;
            final rel = entry['rel'];
            final id = entry['assetId'];
            if (rel is String && rel.isNotEmpty && id is String && id.isNotEmpty) {
              result[rel] = id;
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
    return result;
  }

  /// Lokale Datei für einen Spiegel-Pfad — der Weg über Quellordner.
  static Future<File?> localFile(String rel, List<String> sourceFolders) async {
    final relative = rel.replaceAll('/', Platform.pathSeparator);
    for (final folder in sourceFolders) {
      if (folder.isEmpty) continue;
      final file = File('$folder${Platform.pathSeparator}$relative');
      try {
        if (await file.exists()) return file;
      } catch (_) {}
    }
    return null;
  }

  /// Vorschaubild aus der lokalen Quelle einer Aufnahme — nie aus der Cloud.
  ///
  /// [assetId] ist je Plattform eine `photo_manager`-ID oder ein absoluter
  /// Pfad; beides wird probiert, und `null` heißt „lokal nicht verfügbar".
  static Future<Uint8List?> create({
    required String assetId,
    List<String> sourceFolders = const [],
  }) async {
    if (assetId.isEmpty) return null;
    try {
      final asFile = File(assetId);
      if (await asFile.exists()) {
        final bytes = await ThumbnailCreator.fromFile(asFile);
        if (bytes != null) return bytes;
      }
    } catch (_) {}
    return ThumbnailCreator.fromAsset(assetId);
  }
}

/// Erzeugt Vorschaubilder und legt sie nach `.fibu/thumbs/`.
///
/// **Streng additiv.** Jeder Fehler wird protokolliert und übersprungen —
/// ein Vorschaubild ist niemals ein Grund, einen Lauf abzubrechen oder einen
/// Dialog zu zeigen.
class ThumbnailPipeline {
  const ThumbnailPipeline._();

  /// Verarbeitet [rels] der Reihe nach. Liefert die Zahl der hochgeladenen
  /// Vorschaubilder.
  ///
  /// [createFor] entscheidet, woher die Bytes kommen — der Aufrufer kennt
  /// seine Plattform. Das hält diese Klasse testbar: Ein Test gibt eine
  /// Fake-Erzeugung mit und prüft Ablage, Hochladen und Abbruch.
  static Future<int> run({
    required RcloneService rclone,
    required String remoteName,
    required List<String> rels,
    required ThumbnailCache cache,
    required Future<Uint8List?> Function(String rel) createFor,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    var uploaded = 0;
    final total = rels.length;
    for (var i = 0; i < rels.length; i++) {
      if (isCancelled?.call() ?? false) break;
      final rel = rels[i];
      try {
        final bytes = await createFor(rel);
        if (bytes != null) {
          await cache.write(rel, bytes);
          final local = await cache.fileFor(rel);
          await rclone.copyFileToRemote(
              local.path, remoteName, await ThumbnailService.cloudPath(rel));
          uploaded++;
        }
      } catch (e) {
        AppLog.warn('thumbs', 'Vorschaubild für „$rel" übersprungen: $e');
      } finally {
        onProgress?.call(i + 1, total);
      }
    }
    try {
      await cache.prune();
    } catch (_) {}
    return uploaded;
  }

  /// Was in `.fibu/thumbs/` liegt — eine Auflistung, kein Index.
  static Future<Set<String>> listCloudThumbs(
      RcloneService rclone, String remoteName) async {
    try {
      final files =
          await rclone.listFiles(remoteName, ThumbnailService.cloudFolder);
      return {
        for (final f in files)
          if (!f.isDir) f.name,
      };
    } catch (_) {
      // Kein Listen-Recht oder Ordner fehlt: ohne Vorschaubilder weiter.
      return const {};
    }
  }
}

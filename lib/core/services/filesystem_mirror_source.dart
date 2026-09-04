import 'dart:io';

import '../utils/app_paths.dart';
import 'app_log_service.dart';
import 'virtual_mirror_sync.dart';

/// Dateisystem-Quelle für die Spiegel-Engine.
///
/// **Warum das überhaupt geht.** `VirtualMirrorSyncEngine` ist bereits über
/// Callbacks von der Mediathek entkoppelt: Sie weiß nichts über PhotoKit,
/// sondern verlangt nur „gib mir die lokale Liste", „gib mir die Datei zum
/// Hochladen", „nimm diese Dateien entgegen" und „lösche diese lokal".
/// `assetId` wird von der Engine intern nie gelesen — nur die iOS-Callbacks
/// nutzen es für den On-Demand-Export.
///
/// Auf dem Desktop ist die Quelle ein Ordner. Damit wird dieselbe Engine mit
/// denselben Tombstones, derselben Anomalie-Bremse und demselben
/// 2-Wege-Verhalten nutzbar — statt `rclone sync`, das 1-Weg mit Löschrecht
/// ist (docs/TESTMATRIX_IOS_WINDOWS.md, Abschnitt 0).
class FilesystemMirrorSource {
  FilesystemMirrorSource(this.root);

  /// Absoluter Pfad des Quellordners.
  final String root;

  /// Unterordner, in den lokal „gelöschte" Dateien wandern.
  ///
  /// Bewusst kein hartes Löschen: Auf dem Desktop gibt es keinen Systemdialog
  /// wie bei der iOS-Fotos-App, der eine Cloud-Löschung noch abfangen könnte.
  /// Also wandert alles in einen Papierkorb mit Aufbewahrungsfrist.
  static const String trashSubFolder = '.fibu-trash';

  /// Wie lange der lokale Papierkorb aufbewahrt wird.
  static const Duration trashRetention = Duration(days: 30);

  /// Läuft den Ordner rekursiv ab und liefert rel → Metadaten.
  ///
  /// `assetId` ist hier der absolute Pfad — die Engine nutzt ihn nicht, aber
  /// die Callbacks brauchen eine Möglichkeit, die Datei wiederzufinden.
  Future<Map<String, VirtualMediaItem>> scan() async {
    final result = <String, VirtualMediaItem>{};
    final rootDir = Directory(root);
    if (!await rootDir.exists()) {
      AppLog.warn('mirror', 'Quellordner existiert nicht: $root');
      return result;
    }

    await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final abs = entity.path;
      final rel = _toRel(abs);
      // Papierkorb und Fibu-eigene Dateien nie als Quelle behandeln.
      if (rel.startsWith(trashSubFolder)) continue;
      if (rel.startsWith('.fibu')) continue;
      if (rel.contains('/.fibu')) continue;
      try {
        final stat = await entity.stat();
        result[rel] = VirtualMediaItem(
          rel: rel,
          assetId: abs,
          modifiedMs: stat.modified.millisecondsSinceEpoch,
          sizeBytes: stat.size,
        );
      } catch (e) {
        AppLog.warn('mirror', 'Datei nicht lesbar, übersprungen: $rel ($e)');
      }
    }
    return result;
  }

  /// Dateiname (klein) → bekannte Größen. Derselbe Schutz wie auf iOS gegen
  /// gleichnamige, aber unterschiedliche Dateien.
  Future<Map<String, Set<int>>> librarySizes() async {
    final items = await scan();
    final out = <String, Set<int>>{};
    for (final item in items.values) {
      final base = item.rel.split('/').last.toLowerCase();
      (out[base] ??= <int>{}).add(item.sizeBytes);
    }
    return out;
  }

  /// Die Datei zum Hochladen. Auf dem Desktop ist das die Datei selbst —
  /// kein Export, keine Temp-Kopie, anders als bei der Mediathek.
  Future<File?> exportForUpload(VirtualMediaItem item) async {
    final f = File(_toAbs(item.rel));
    return await f.exists() ? f : null;
  }

  /// Größe messen, ohne die Datei zu öffnen.
  Future<int> measureForUpload(VirtualMediaItem item) async {
    try {
      final f = File(_toAbs(item.rel));
      return await f.exists() ? await f.length() : 0;
    } catch (_) {
      return 0;
    }
  }

  /// Heruntergeladene Dateien in den Ordner schreiben.
  ///
  /// Die Engine liefert Temp-Dateien; sie werden an ihren Zielplatz
  /// verschoben. Existiert dort schon etwas, wird es überschrieben — die
  /// Engine hat vorher entschieden, dass die Cloud-Fassung die neuere ist.
  Future<void> importDownloaded(List<File> files, List<String> rels) async {
    var ok = 0;
    for (var i = 0; i < files.length && i < rels.length; i++) {
      try {
        final dest = File(_toAbs(rels[i]));
        await dest.parent.create(recursive: true);
        if (await dest.exists()) await dest.delete();
        await files[i].rename(dest.path);
        ok++;
      } catch (e) {
        AppLog.warn('mirror', 'Import fehlgeschlagen: ${rels[i]} ($e)');
      }
    }
    AppLog.info('mirror', '$ok/${files.length} Dateien in den Ordner importiert');
  }

  /// Lokal „löschen" = in den Papierkorb verschieben.
  ///
  /// Liefert die tatsächlich verschobenen rel-Pfade, damit die Engine sie als
  /// erledigt verbuchen kann.
  Future<List<String>> deleteLocal(List<VirtualMediaItem> items) async {
    final done = <String>[];
    for (final item in items) {
      try {
        final src = File(_toAbs(item.rel));
        if (!await src.exists()) continue;
        final stamp = DateTime.now().millisecondsSinceEpoch;
        final safeName = item.rel.replaceAll(RegExp(r'[/\\]'), '__');
        final dest = File('$root${Platform.pathSeparator}$trashSubFolder'
            '${Platform.pathSeparator}${stamp}_$safeName');
        await dest.parent.create(recursive: true);
        await src.rename(dest.path);
        done.add(item.rel);
      } catch (e) {
        AppLog.warn('mirror',
            'Lokales Verschieben in den Papierkorb fehlgeschlagen: ${item.rel} ($e)');
      }
    }
    if (done.isNotEmpty) {
      AppLog.info('mirror',
          '${done.length} lokale Dateien in den Papierkorb verschoben (Aufbewahrung ${trashRetention.inDays} Tage)');
    }
    return done;
  }

  /// Räumt den lokalen Papierkorb gemäß [trashRetention] auf.
  Future<int> purgeTrash() async {
    final dir = Directory('$root${Platform.pathSeparator}$trashSubFolder');
    if (!await dir.exists()) return 0;
    final cutoff = DateTime.now().subtract(trashRetention);
    var removed = 0;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      try {
        final stat = await entity.stat();
        if (stat.modified.isBefore(cutoff)) {
          await entity.delete();
          removed++;
        }
      } catch (_) {}
    }
    if (removed > 0) {
      AppLog.info('mirror', '$removed Papierkorb-Einträge endgültig entfernt');
    }
    return removed;
  }

  /// Absoluter Pfad aus einem rel-Pfad (immer mit `/` als Trenner).
  String _toAbs(String rel) {
    final parts = rel.split('/').where((p) => p.isNotEmpty);
    return '$root${Platform.pathSeparator}${parts.join(Platform.pathSeparator)}';
  }

  /// rel-Pfad (mit `/`) aus einem absoluten Pfad.
  String _toRel(String abs) {
    var rel = abs;
    final prefix = root.endsWith(Platform.pathSeparator)
        ? root
        : '$root${Platform.pathSeparator}';
    if (rel.startsWith(prefix)) rel = rel.substring(prefix.length);
    return rel.replaceAll(Platform.pathSeparator, '/');
  }

  /// Zustandsordner für diese Quelle — je (Ordner, Ziel) getrennt, damit zwei
  /// Aufgaben auf demselben Cloud-Ziel sich nicht in die Quere kommen.
  static Future<String> stateRootFor({
    required String localRoot,
    required String remoteName,
    required String remotePath,
  }) async {
    final base = await appSupportRoot();
    String slug(String s) => s
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final dir = Directory(
        '${base.path}/fibu_state/fs_${slug(localRoot)}_${slug(remoteName)}_${slug(remotePath)}');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }
}

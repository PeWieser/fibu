import 'dart:convert';
import 'dart:io';

import '../localization/app_strings.dart';
import 'app_log_service.dart';
import 'mirror_sync_engine.dart';
import 'rclone_service.dart';
import 'trash_service.dart';

/// Ein Medien-Eintrag aus der lokalen Bibliothek – nur Metadaten,
/// KEINE lokal persistierte Datei (Kern von Option 3 „manifest-only mirror").
class VirtualMediaItem {
  /// Relativer Spiegel-Pfad (z. B. „Photos/Favorites/IMG_1.HEIC").
  final String rel;

  /// photo_manager Asset-ID (wird für den On-Demand-Export gebraucht).
  final String assetId;

  /// letzte Änderung (Millisekunden seit Epoch) – Konflikt-/Neuigkeitsvergleich.
  final int modifiedMs;

  const VirtualMediaItem({
    required this.rel,
    required this.assetId,
    required this.modifiedMs,
  });

  Map<String, dynamic> toJson() => {
        'rel': rel,
        'assetId': assetId,
        'modifiedMs': modifiedMs,
      };

  factory VirtualMediaItem.fromJson(Map<String, dynamic> json) =>
      VirtualMediaItem(
        rel: json['rel'] as String? ?? '',
        assetId: json['assetId'] as String? ?? '',
        modifiedMs: (json['modifiedMs'] as num?)?.toInt() ?? 0,
      );
}

/// Virtueller 2-Wege-Mirror („manifest-only"): Die lokale Seite ist nur eine
/// Zustands-DB (rel → Geändert-Zeit/Asset-ID); Dateien existieren lokal nie
/// dauerhaft. Uploads exportieren genau DAS eine Asset; Downloads gehen in den
/// Temp-Ordner und sofort zurück in die Mediathek.
///
/// Zustand/Tombstones liegen in [stateRoot] (iOS: Library/Application Support —
/// von Nutzern über die Dateien-App NICHT sichtbar).
class VirtualMirrorSyncEngine {
  final RcloneService _rclone;

  VirtualMirrorSyncEngine(this._rclone);

  static const String tombstonesFileName = 'tombstones.json';

  /// [localItems]: rel → VirtualMediaItem (Metadaten, kein Dateiinhalt).
  /// [exportForUpload]: ein Asset on-demand als echte (temporäre) Datei liefern.
  /// [persistLocalState]: Zustandsliste speichern.
  /// [blockedRels]: Pfade, die nie mehr hochgeladen werden sollen (remote
  /// gelöscht; wir löschen Nutzer-Mediathekeninhalte absichtlich nie).
  /// [adoptedRels]: persistente Menge von Cloud-Dateien, die als adoptiert
  /// gelten (nur-remote, aber bewusst NICHT herunterladen/löschen — entsteht
  /// beim Moduswechsel Inkrementell → Spiegelung).
  /// [adoptOrphans]: einmaliger Baseline-Lauf — alle Cloud-only-Dateien in
  /// [adoptedRels] aufnehmen statt sie herunterzuladen.
  /// Rückgabewert: MirrorSyncResult (gleiche Zähler wie bei FS-Mirror).
  Future<MirrorSyncResult> sync({
    required Map<String, VirtualMediaItem> localItems,
    required String stateRoot,
    required String remoteName,
    required String remotePath,
    required Set<String> blockedRels,
    Set<String>? adoptedRels,
    bool adoptOrphans = false,
    required Future<File?> Function(VirtualMediaItem item) exportForUpload,
    required Future<void> Function(List<File> files, List<String> rels) importDownloaded,
    required Future<void> Function(List<Map<String, dynamic>> state) persistLocalState,
    TrashService? trash,
    MirrorProgressCallback? onProgress,
  }) async {
    onProgress?.call('scan', AppStrings.current.syncStartAnalysis, 0, 0);
    // Die Mengen werden direkt mutiert (blockedRels.add / adoptedRels.add …) und
    // vom Aufrufer über die persist-Callback zurückgeschrieben — sie MÜSSEN also
    // growable sein. `_loadVirtualState` liefert daher bewusst keine const-Sets.
    final remoteFiles = await _listRemoteRecursive(remoteName, remotePath, onProgress: onProgress);
    AppLog.info('sync',
        'Virtual-Mirror-Analyse fertig: ${localItems.length} lokale Medien / ${remoteFiles.length} Cloud-Dateien');

    final localTombs = await _readTombs(_tombstoneFile(stateRoot));
    final remoteContent = await _safeCat(remoteName, remotePath);
    final remoteTombs = _parseTombs(remoteContent);

    var uploaded = 0, downloaded = 0, deletedLocal = 0, deletedRemote = 0, trashedLocal = 0, trashedRemote = 0;
    final downloadedPaths = <String>[];
    final merged = <String, Tombstone>{};

    // ---------- 1) Upload: lokal neu/neuer & remote fehlt/älter ----------
    final toUpload = localItems.values
        .where((item) => !blockedRels.contains(item.rel))
        .where((item) {
          final remote = remoteFiles[item.rel];
          if (remote == null) return true;
          final rMod = DateTime.tryParse(remote.modTime);
          if (rMod == null) return remote.size <= 0;
          return DateTime.fromMillisecondsSinceEpoch(item.modifiedMs)
              .isAfter(rMod.add(const Duration(seconds: 5)));
        })
        .toList();
    if (toUpload.isNotEmpty) {
      AppLog.info('sync', 'Virtual-Mirror Upload: ${toUpload.length} Dateien → $remoteName:$remotePath');
    }
    var up = 0;
    for (final item in toUpload) {
      up++;
      onProgress?.call('upload', item.rel, up, toUpload.length);
      File? tmp;
      try {
        tmp = await exportForUpload(item);
        if (tmp == null || !await tmp.exists()) continue;
        await _rclone.copyFileToRemote(tmp.path, remoteName, _joinRemote(remotePath, item.rel));
        uploaded++;
      } catch (e) {
        AppLog.warn('sync', 'Upload fehlgeschlagen: ${item.rel} → $e');
      } finally {
        // Export-Datei niemals liegen lassen (manifest-only!).
        try {
          final f = tmp;
          if (f != null && await f.exists()) await f.delete();
          final parent = tmp?.parent;
          if (parent != null && await parent.exists() &&
              parent.path.contains('fibu_export_')) {
            await parent.delete(recursive: true);
          }
        } catch (_) {}
      }
    }

    // ---------- 2) Lokale Tombstones remote ausführen (Lokal hat Vorrang) ----
    var tb = 0;
    for (final tomb in localTombs) {
      tb++;
      onProgress?.call('tombstones', tomb.path, tb, localTombs.length);
      if (remoteFiles.containsKey(tomb.path)) {
        var ok = false;
        if (trash != null) {
          ok = await trash.moveToRemoteTrash(
            remoteName: remoteName, remotePath: remotePath, rel: tomb.path);
          if (ok) trashedRemote++;
        }
        if (!ok) {
          try {
            await _rclone.deleteFile(remoteName, _joinRemote(remotePath, tomb.path));
            deletedRemote++;
          } catch (_) {}
        }
      }
      merged[tomb.path] = tomb;
    }

    // ---------- 3) Remote-Tombstones: lokale Mediathekeninhalte NIE löschen --
    for (final tomb in remoteTombs) {
      final existing = merged[tomb.path];
      if (existing == null || tomb.deletedAt.isAfter(existing.deletedAt)) {
        merged[tomb.path] = tomb;
      }
      final item = localItems[tomb.path];
      if (item == null) continue;
      // Sicherheit: Wir löschen keine Assets aus der echten Fotos-Mediathek.
      blockedRels.add(item.rel);
      AppLog.warn('sync',
          'Remote-Löschung für ${item.rel} empfangen → wird blockiert (Fibu löscht nie Inhalte aus der Mediathek) und wird nicht mehr hochgeladen');
    }

    // ---------- 4) Cloud-only-Dateien herunterladen --------------------------
    final toDownload = <MapEntry<String, RcloneFileInfo>>[];
    var adoptedNow = 0;
    for (final entry in remoteFiles.entries) {
      final rel = entry.key;
      if (entry.value.isDir) continue;
      if (rel.startsWith('.fibu') || rel.startsWith("$remotePath/.fibu")) continue;
      if (merged.containsKey(rel)) continue;
      if (localItems.containsKey(rel)) continue;
      // Adoptierte Dateien: nur-remote ist OK — nie laden, nie anfassen.
      if (adoptedRels != null && adoptedRels.contains(rel)) continue;
      if (adoptOrphans && adoptedRels != null) {
        adoptedRels.add(rel);
        adoptedNow++;
        continue;
      }
      toDownload.add(entry);
    }
    if (adoptedNow > 0) {
      AppLog.info('sync',
          'Adoption (Moduswechsel): $adoptedNow bestehende Cloud-Dateien übernommen — kein Download in die Mediathek');
    }
    // Adoptionsliste aufräumen: verschwundene, tombstonierte oder inzwischen
    // lokal vorhandene Einträge verlassen die Liste wieder.
    adoptedRels?.removeWhere((rel) =>
        !remoteFiles.containsKey(rel) ||
        merged.containsKey(rel) ||
        localItems.containsKey(rel));
    if (toDownload.isNotEmpty) {
      AppLog.info('sync', 'Virtual-Mirror Download: ${toDownload.length} Dateien ← $remoteName:$remotePath');
    }
    var dl = 0;
    final tmpFiles = <File>[];
    final tmpRels = <String>[];
    for (final entry in toDownload) {
      final rel = entry.key;
      dl++;
      onProgress?.call('download', rel, dl, toDownload.length);
      try {
        final tmpRoot = await Directory.systemTemp.createTemp('fibu_import_');
        final dest = File('${tmpRoot.path}/${entry.value.name}');
        await _rclone.downloadFile(remoteName, _joinRemote(remotePath, rel), dest.path);
        if (await dest.exists() && await dest.length() > 0) {
          tmpFiles.add(dest);
          tmpRels.add(rel);
          downloaded++;
          downloadedPaths.add(rel);
        }
      } catch (e) {
        AppLog.warn('sync', 'Download fehlgeschlagen: $rel ← $e');
      }
    }
    if (tmpFiles.isNotEmpty) {
      try {
        await importDownloaded(tmpFiles, tmpRels);
      } catch (e) {
        AppLog.warn('sync', 'Import in die Mediathek fehlgeschlagen: $e');
      }
      // Temp-Downloads aufräumen (manifest-only: nichts bleibt liegen).
      for (final f in tmpFiles) {
        try {
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      for (final d in tmpFiles.map((f) => f.parent).toSet()) {
        try {
          if (await d.exists() && d.path.contains('fibu_import_')) {
            await d.delete(recursive: true);
          }
        } catch (_) {}
      }
    }

    // ---------- 5) Tombstones + Zustand persistieren -------------------------
    await _writeTombs(_tombstoneFile(stateRoot), merged.values.toList());
    await _writeRemoteTombs(remoteName, remotePath, merged.values.toList());
    await persistLocalState(
        localItems.values.map((i) => i.toJson()).toList());

    return MirrorSyncResult(
      uploaded: uploaded,
      downloaded: downloaded,
      deletedLocal: deletedLocal,
      deletedRemote: deletedRemote,
      trashedLocal: trashedLocal,
      trashedRemote: trashedRemote,
      downloadedPaths: downloadedPaths,
    );
  }

  // ------------------------------------------------------------------
  // Remote-Rekursion (wie die FS-Engine, mit Fortschritt + lautem Fehler)
  // ------------------------------------------------------------------
  Future<Map<String, RcloneFileInfo>> _listRemoteRecursive(
      String remoteName, String remotePath,
      {MirrorProgressCallback? onProgress}) async {
        final result = <String, RcloneFileInfo>{};
    var dirsScanned = 0;
    final prefix = remotePath.isEmpty ? '' : '$remotePath/';

    Future<void> walk(String dir) async {
      final items = await _rclone.listFiles(remoteName, dir);
      dirsScanned++;
      onProgress?.call('scan', dir, dirsScanned, 0);
      for (final item in items) {
        final fullRel = dir.isEmpty ? item.name : '$dir/${item.name}';
        // WICHTIG: rel muss RELATIV zu remotePath sein (wird später wieder mit
        // _joinRemote geprefixt) — sonst entsteht „fibu-backup/fibu-backup/…"
        // und Downloads schlagen mit 404 fehl (im echten Log beobachtet).
        final rel = prefix.isNotEmpty && fullRel.startsWith(prefix)
            ? fullRel.substring(prefix.length)
            : fullRel;
        // Meta-Ordner (Löschprotokoll, Remote-Papierkorb) nie als Inhalt
        // behandeln — sonst würden sie lokal neu heruntergeladen.
        if (item.isDir && (item.name == '.fibu' || item.name == '.fibu-trash')) {
          continue;
        }
        result[rel] = item;
        if (item.isDir) {
          await walk(fullRel);
        }
      }
    }

    try {
      await walk(remotePath);
    } catch (e) {
      // Erster Lauf: Der Zielordner existiert remote noch nicht → das ist
      // KEIN Fehler, sondern eine leere Cloud-Seite. Alles andere bleibt laut.
      if (_isDirNotFound(e)) {
        AppLog.info('sync',
            'Zielordner $remoteName:$remotePath existiert noch nicht → Cloud-Seite leer (wird beim Upload angelegt)');
        return result;
      }
      AppLog.error('sync', 'Cloud-Scan fehlgeschlagen ($remoteName:$remotePath): $e');
      rethrow;
    }
    return result;
  }

  /// rclone-Fehlertexte für „Verzeichnis existiert nicht“ (Erst-Sync).
  static bool _isDirNotFound(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('directory not found') ||
        msg.contains('object not found') ||
        msg.contains("doesn't exist") ||
        msg.contains('does not exist');
  }

  /// Remote-Tombstones lesen (fehlende Datei = keine Tombstones).
  Future<String?> _safeCat(String remoteName, String remotePath) async {
    try {
      return await _rclone.catFile(
          remoteName, _joinRemote(remotePath, '.fibu/$tombstonesFileName'));
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeRemoteTombs(String remoteName, String remotePath, List<Tombstone> tombs) async {
    try {
      final tmp = await Directory.systemTemp.createTemp('fibu_tombs_');
      final file = File('${tmp.path}/tombstones.json');
      await file.writeAsString(_encodeTombs(tombs));
      await _rclone.copyFileToRemote(
          file.path, remoteName, _joinRemote(remotePath, '.fibu/$tombstonesFileName'));
      await tmp.delete(recursive: true);
    } catch (_) {}
  }

  File _tombstoneFile(String stateRoot) =>
      File('$stateRoot${Platform.pathSeparator}.fibu${Platform.pathSeparator}$tombstonesFileName');

  Future<List<Tombstone>> _readTombs(File file) async {
    try {
      if (!await file.exists()) return [];
      final content = (await file.readAsString()).trim();
      if (content.isEmpty) return [];
      final list = jsonDecode(content);
      if (list is! List) return [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(Tombstone.fromJson)
          .where((t) => t.path.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeTombs(File file, List<Tombstone> tombs) async {
    try {
      if (!await file.parent.exists()) await file.parent.create(recursive: true);
      await file.writeAsString(_encodeTombs(tombs));
    } catch (_) {}
  }

  List<Tombstone> _parseTombs(String? content) {
    if (content == null || content.trim().isEmpty) return [];
    try {
      final list = jsonDecode(content);
      if (list is! List) return [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(Tombstone.fromJson)
          .where((t) => t.path.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  String _encodeTombs(List<Tombstone> tombs) =>
      const JsonEncoder.withIndent('  ').convert(tombs.map((t) => t.toJson()).toList());

  String _joinRemote(String remotePath, String rel) {
    if (remotePath.isEmpty) return rel;
    return '$remotePath/$rel';
  }
}

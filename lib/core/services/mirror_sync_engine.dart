import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'rclone_service.dart';
import 'trash_service.dart';

/// Ein Lösch-Eintrag (Tombstone) im Löschprotokoll.
///
/// Dokumentiert, dass eine Datei (relativ zum Sync-Stamm) zu einem Zeitpunkt
/// auf einem Gerät gelöscht wurde. Lokale Tombstones haben Vorrang vor remote.
class Tombstone {
  final String path;
  final DateTime deletedAt;
  final String deviceId;

  const Tombstone({
    required this.path,
    required this.deletedAt,
    required this.deviceId,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'deletedAt': deletedAt.toIso8601String(),
        'deviceId': deviceId,
      };

  factory Tombstone.fromJson(Map<String, dynamic> json) => Tombstone(
        path: json['path'] as String? ?? '',
        deletedAt: DateTime.tryParse(json['deletedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        deviceId: json['deviceId'] as String? ?? '',
      );
}

/// Fortschritts-Callback des Mirror-Sync (Apple-konforme Zwischenstände).
///
/// [phase] ist einer der stabilen Schlüssel `scan`, `upload`, `tombstones`
/// oder `download`; [item] der relative Pfad der aktuellen Datei (kann leer
/// sein); [done]/[total] der Zählerstand der aktuellen Phase
/// (0/0 = keine Zähler-Info für diese Phase).
typedef MirrorProgressCallback = void Function(
  String phase,
  String item,
  int done,
  int total,
);

/// Ergebnis eines Mirror-Sync-Laufs.
class MirrorSyncResult {
  final int uploaded;
  final int downloaded;
  final int deletedLocal;
  final int deletedRemote;
  final int trashedLocal;
  final int trashedRemote;
  final List<String> downloadedPaths;

  const MirrorSyncResult({
    this.uploaded = 0,
    this.downloaded = 0,
    this.deletedLocal = 0,
    this.deletedRemote = 0,
    this.trashedLocal = 0,
    this.trashedRemote = 0,
    this.downloadedPaths = const [],
  });

  bool get hasChanges =>
      uploaded > 0 ||
      downloaded > 0 ||
      deletedLocal > 0 ||
      deletedRemote > 0 ||
      trashedLocal > 0 ||
      trashedRemote > 0;
}

/// Löschprotokoll-basierter bidirektionaler Sync („iCloud-Mirror").
///
/// Ablauf pro Lauf:
///  1. Neue/geänderte lokale Dateien werden nach remote hochgeladen (copy).
///  2. Lokale Tombstones werden remote ausgeführt (Lösch-Priorität lokal) —
///     bei aktiviertem Papierkorb in den Remote-Papierkorb statt hart löschen.
///  3. Remote-Tombstones (von anderen Geräten) werden lokal angewendet,
///     außer die Datei wurde lokal wieder neu/geändert (lokale Priorität) —
///     bei aktiviertem Papierkorb in den lokalen Papierkorb statt hart löschen.
///  4. Neue remote-Dateien werden in die entsprechenden lokalen Alben/Ordner
///     heruntergeladen.
///
/// Tombstones werden lokal und remote unter `.fibu/tombstones.json` geführt.
class MirrorSyncEngine {
  final RcloneService _rclone;
  final String deviceId;

  MirrorSyncEngine(this._rclone, {String? deviceId})
      : deviceId = deviceId ?? 'device_${DateTime.now().millisecondsSinceEpoch}';

  static const String tombstonesSubPath = '.fibu/tombstones.json';

  /// Synchronisiert den persistenten lokalen Spiegel [localRoot] mit dem
  /// Remote-Verzeichnis [remoteName]:[remotePath].
  ///
  /// [onProgress] liefert während des Laufs Zwischenstände (Scan, Upload,
  /// Tombstones/Deletes, Download) für die UI.
  Future<MirrorSyncResult> sync({
    required String localRoot,
    required String remoteName,
    required String remotePath,
    TrashService? trash,
    MirrorProgressCallback? onProgress,
  }) async {
    // --- Scan beide Seiten ---
    final localFiles = await _walkLocal(localRoot);
    final remoteFiles = await _listRemoteRecursive(remoteName, remotePath);
    onProgress?.call(
        'scan', '', localFiles.length + remoteFiles.length, 0);

    // --- Löschprotokolle lesen ---
    final localTombs = await _readLocalTombstones(localRoot);
    final remoteTombs = await _readRemoteTombstones(remoteName, remotePath);
    final appliedLocal = <Tombstone>[]; // lokal bereits remote ausgeführt
    final merged = <String, Tombstone>{}; // union local+remote (neueste je Pfad)

    int uploaded = 0;
    int downloaded = 0;
    int deletedLocal = 0;
    int deletedRemote = 0;
    int trashedLocal = 0;
    int trashedRemote = 0;
    final downloadedPaths = <String>[];

    // =====================================================================
    // 1. Lokale Dateien hochladen — nur wenn remote fehlt ODER die lokale
    //    Version neuer ist (Modtime). Verhindert Größen-Ping-Pong zwischen
    //    Geräten: die zuletzt geänderte Version gewinnt, nicht der zuletzt
    //    synchronisierende Gerät.
    // =====================================================================
    final toUpload = localFiles.entries
        .where((entry) =>
            remoteFiles[entry.key] == null ||
            _localIsNewer(entry.value, remoteFiles[entry.key]!))
        .toList();
    var up = 0;
    for (final entry in toUpload) {
      final rel = entry.key;
      final file = entry.value;
      up++;
      onProgress?.call('upload', rel, up, toUpload.length);
      try {
        await _rclone.copyFileToRemote(
          file.path,
          remoteName,
          _joinRemote(remotePath, rel),
        );
        uploaded++;
      } catch (_) {
        // Einzelner Upload-Fehler: weiter mit den übrigen Dateien.
      }
    }

    // =====================================================================
    // 2. Lokale Tombstones remote ausführen (Lokal hat Vorrang).
    // =====================================================================
    var tb = 0;
    for (final tomb in localTombs) {
      tb++;
      onProgress?.call('tombstones', tomb.path, tb, localTombs.length);
      if (remoteFiles.containsKey(tomb.path)) {
        bool ok = false;
        if (trash != null) {
          // In Remote-Papierkorb statt hart löschen (wiederherstellbar).
          ok = await trash.moveToRemoteTrash(
            remoteName: remoteName,
            remotePath: remotePath,
            rel: tomb.path,
          );
          if (ok) trashedRemote++;
        }
        if (!ok) {
          try {
            await _rclone.deleteFile(remoteName, _joinRemote(remotePath, tomb.path));
            deletedRemote++;
          } catch (_) {}
        }
      }
      appliedLocal.add(tomb);
      merged[tomb.path] = tomb;
    }

    // =====================================================================
    // 3. Remote-Tombstones lokal anwenden, außer lokal neu/geändert.
    // =====================================================================
    for (final tomb in remoteTombs) {
      final existing = merged[tomb.path];
      // Neueste Tombstone je Pfad gewinnt fürs zusammengeführte Protokoll.
      if (existing == null || tomb.deletedAt.isAfter(existing.deletedAt)) {
        merged[tomb.path] = tomb;
      }

      final localFile = localFiles[tomb.path];
      if (localFile == null) continue;

      // Lokale Priorität: Wenn die Datei lokal nach der Tombstone wieder
      // neu erstellt/geändert wurde, bleibt sie lokal und wird oben (1)
      // bereits wieder hochgeladen.
      final localMod = localFile.statSync().modified;
      final wasLocalTomb = localTombs.any((t) => t.path == tomb.path);
      if (wasLocalTomb || localMod.isAfter(tomb.deletedAt)) {
        continue;
      }
      try {
        if (trash != null) {
          // In lokalen Papierkorb statt hart löschen (wiederherstellbar).
          final moved = await trash.moveToLocalTrash(localRoot, tomb.path);
          if (moved.isNotEmpty) {
            trashedLocal++;
          } else {
            await localFile.delete();
            deletedLocal++;
          }
        } else {
          await localFile.delete();
          deletedLocal++;
        }
      } catch (_) {}
    }

    // =====================================================================
    // 4. Neue remote-Dateien in die lokalen Alben/Ordner downloaden.
    // =====================================================================
    final toDownload = remoteFiles.entries
        .where((entry) =>
            !entry.value.isDir &&
            // Tombstoned (und nicht lokal wiederbelebt) → nicht erneut laden.
            !merged.containsKey(entry.key) &&
            !localFiles.containsKey(entry.key))
        .toList();
    var dl = 0;
    for (final entry in toDownload) {
      final rel = entry.key;
      dl++;
      onProgress?.call('download', rel, dl, toDownload.length);
      final dest = File('$localRoot${Platform.pathSeparator}${_localRel(rel)}');
      try {
        await dest.parent.create(recursive: true);
        await _rclone.downloadFile(remoteName, _joinRemote(remotePath, rel), dest.path);
        downloaded++;
        downloadedPaths.add(rel);
      } catch (_) {}
    }

    // =====================================================================
    // 5. Zusammengeführtes Löschprotokoll lokal + remote schreiben.
    // =====================================================================
    await _writeLocalTombstones(localRoot, merged.values.toList());
    await _writeRemoteTombstones(remoteName, remotePath, merged.values.toList());

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

  // -------------------------------------------------------------------------
  // Scan-Helfer
  // -------------------------------------------------------------------------

  Future<Map<String, File>> _walkLocal(String root) async {
    final result = <String, File>{};
    final rootDir = Directory(root);
    if (!await rootDir.exists()) return result;
    await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final rel = _relPath(entity.path, root);
      if (rel.startsWith('.fibu')) continue; // Meta-Ordner nicht syncen
      result[rel] = entity;
    }
    return result;
  }

  /// Rekursive Remote-Listung; relative Pfade mit '/'.
  Future<Map<String, RcloneFileInfo>> _listRemoteRecursive(
    String remoteName,
    String remotePath,
  ) async {
    final result = <String, RcloneFileInfo>{};
    Future<void> walk(String dir) async {
      final items = await _rclone.listFiles(remoteName, dir);
      for (final item in items) {
        final rel = dir.isEmpty ? item.name : '$dir/${item.name}';
        // Meta-Ordner (Löschprotokoll, Remote-Papierkorb) nie als Inhalt
        // behandeln — sonst würden sie lokal neu heruntergeladen.
        if (item.isDir && (item.name == '.fibu' || item.name == '.fibu-trash')) {
          continue;
        }
        result[rel] = item;
        if (item.isDir) {
          await walk(rel);
        }
      }
    }

    try {
      await walk(remotePath);
    } catch (_) {}
    return result;
  }

  // -------------------------------------------------------------------------
  // Löschprotokoll (lokal + remote)
  // -------------------------------------------------------------------------

  Future<File> _localTombstoneFile(String localRoot) async {
    final dir = Directory('$localRoot${Platform.pathSeparator}.fibu');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}tombstones.json');
  }

  Future<List<Tombstone>> _readLocalTombstones(String localRoot) async {
    return _readTombstoneFile(await _localTombstoneFile(localRoot));
  }

  Future<void> _writeLocalTombstones(String localRoot, List<Tombstone> tombs) async {
    await _writeTombstoneFile(await _localTombstoneFile(localRoot), tombs);
  }

  Future<List<Tombstone>> _readRemoteTombstones(
    String remoteName,
    String remotePath,
  ) async {
    try {
      final content =
          await _rclone.catFile(remoteName, _joinRemote(remotePath, tombstonesSubPath));
      if (content == null || content.trim().isEmpty) return [];
      return _parseTombs(content);
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeRemoteTombstones(
    String remoteName,
    String remotePath,
    List<Tombstone> tombs,
  ) async {
    try {
      // Tombstones lokal temporär ablegen und per copyFileToRemote hochladen.
      final tmp = await getTemporaryDirectory();
      final file = File('${tmp.path}/fibu_tombstones.json');
      await file.writeAsString(_encodeTombs(tombs));
      await _rclone.copyFileToRemote(file.path, remoteName, _joinRemote(remotePath, tombstonesSubPath));
    } catch (_) {}
  }

  Future<List<Tombstone>> _readTombstoneFile(File file) async {
    try {
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      return _parseTombs(content);
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeTombstoneFile(File file, List<Tombstone> tombs) async {
    try {
      await file.writeAsString(_encodeTombs(tombs));
    } catch (_) {}
  }

  List<Tombstone> _parseTombs(String content) {
    final list = jsonDecode(content);
    if (list is! List) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(Tombstone.fromJson)
        .where((t) => t.path.isNotEmpty)
        .toList();
  }

  String _encodeTombs(List<Tombstone> tombs) =>
      const JsonEncoder.withIndent('  ').convert(tombs.map((t) => t.toJson()).toList());

  // -------------------------------------------------------------------------
  // Pfad-Helfer
  // -------------------------------------------------------------------------

  /// True, wenn die lokale Datei gegenüber der remote Version neuer ist.
  ///
  /// Vergleich auf Basis der Modtime (nicht Größe). Bei fehlender/ungültiger
  /// remote-Modtime gilt eine Größenabweichung als "neuer", damit Änderungen
  /// nicht fälschlich übersprungen werden. Eine kleine Toleranz verhindert
  /// Ping-Pong durch leichte Uhrzeit-Drift zwischen Geräten.
  bool _localIsNewer(File local, RcloneFileInfo remote) {
    final remoteMod = DateTime.tryParse(remote.modTime);
    if (remoteMod == null) {
      // Remote-Modtime unbekannt → anhand der Größe entscheiden.
      return remote.size != local.lengthSync();
    }
    final localMod = local.statSync().modified;
    // Nur als "neuer" gelten, wenn klar neuer (Toleranz ~5s).
    return localMod.difference(remoteMod).inSeconds > 5;
  }

  String _relPath(String path, String root) {
    var rel = path.substring(root.length);
    rel = rel.replaceFirst(RegExp(r'^[/\\]'), '');
    return rel.replaceAll('\\', '/');
  }

  String _localRel(String rel) => rel.replaceAll('/', Platform.pathSeparator);

  String _joinRemote(String remotePath, String rel) {
    if (remotePath.isEmpty) return rel;
    return '$remotePath/$rel';
  }
}

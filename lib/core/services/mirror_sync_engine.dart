import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../localization/app_strings.dart';
import '../utils/format.dart';
import 'app_log_service.dart';
import 'device_storage.dart';
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
///
/// [bytesDone]/[bytesTotal] beschreiben optional die bereits übertragene
/// bzw. insgesamt zu übertragende Datenmenge der aktuellen Transfer-Phase.
/// Damit der Fortschrittsbalken in der UI echten Bytes folgt (nicht der
/// Dateianzahl), werden diese in upload-/download-Phasen befüllt; für
/// Scan- und Löschphasen bleiben sie 0.
typedef MirrorProgressCallback = void Function(
  String phase,
  String item,
  int done,
  int total, {
  int bytesDone,
  int bytesTotal,
});

/// Ergebnis eines Mirror-Sync-Laufs.
class MirrorSyncResult {
  final int uploaded;
  final int downloaded;
  final int deletedLocal;
  final int deletedRemote;
  final int trashedLocal;
  final int trashedRemote;
  final List<String> downloadedPaths;

  /// Nicht-blockierende Warnungen des Laufs (z. B. „Cloud voll“ / „Gerät
  /// voll“ — Transfers wurden dann vorsorglich übersprungen). Leer = keine.
  final List<String> warnings;

  const MirrorSyncResult({
    this.uploaded = 0,
    this.downloaded = 0,
    this.deletedLocal = 0,
    this.deletedRemote = 0,
    this.trashedLocal = 0,
    this.trashedRemote = 0,
    this.downloadedPaths = const [],
    this.warnings = const [],
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
  /// [localDeletions]: relative Pfade, die VOR diesem Lauf als lokal gelöscht
  /// erkannt wurden (Mediathek-Snapshot-Diff). Werden als Tombstones behandelt,
  /// damit die Cloud-Kopie entfernt und nicht erneut heruntergeladen wird.
  ///
  /// [onProgress] liefert während des Laufs Zwischenstände (Scan, Upload,
  /// Tombstones/Deletes, Download) für die UI.
  Future<MirrorSyncResult> sync({
    required String localRoot,
    required String remoteName,
    required String remotePath,
    List<String> localDeletions = const [],
    TrashService? trash,
    MirrorProgressCallback? onProgress,
  }) async {
    // --- Scan beide Seiten ---
    onProgress?.call('scan', 'Starte Analyse …', 0, 0);
    final localFiles = await _walkLocal(localRoot);
    final remoteFiles =
        await _listRemoteRecursive(remoteName, remotePath, onProgress: onProgress);
    AppLog.info('sync',
        'Mirror-Analyse fertig: ${localFiles.length} lokale / ${remoteFiles.length} Cloud-Dateien');
    onProgress?.call('scan', '', localFiles.length + remoteFiles.length, 0);

    // --- Löschprotokolle lesen ---
    final localTombs = await _readLocalTombstones(localRoot);
    final remoteTombs = await _readRemoteTombstones(remoteName, remotePath);
    final appliedLocal = <Tombstone>[]; // lokal bereits remote ausgeführt
    final merged = <String, Tombstone>{}; // union local+remote (neueste je Pfad)

    // Mediathek-first / explizite lokale Löschungen → Tombstones.
    // Ohne diesen Schritt würde Phase 4 die noch remote vorhandene Datei
    // sofort wieder herunterladen („Löschen → Sync → kommt zurück“).
    if (localDeletions.isNotEmpty) {
      final known = localTombs.map((t) => t.path).toSet();
      final now = DateTime.now();
      var added = 0;
      for (final rel in localDeletions) {
        final path = rel.replaceAll('\\', '/');
        if (path.isEmpty || known.contains(path)) continue;
        if (localFiles.containsKey(path)) continue; // doch noch lokal
        localTombs.add(Tombstone(
          path: path,
          deletedAt: now,
          deviceId: deviceId,
        ));
        known.add(path);
        added++;
      }
      if (added > 0) {
        AppLog.info('sync',
            '$added lokale Löschungen als Tombstones übernommen (Cloud-Löschung, kein Re-Download)');
      }
    }

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
    // Basename-Index für Pfad-Mismatch (lokal A/x, remote B/x).
    final remoteByBase = <String, List<MapEntry<String, RcloneFileInfo>>>{};
    for (final e in remoteFiles.entries) {
      if (e.value.isDir) continue;
      final base = e.key.split('/').last.toLowerCase();
      if (base.isEmpty) continue;
      (remoteByBase[base] ??= []).add(e);
    }

    final candidates = localFiles.entries.toList();
    final needUpload = <MapEntry<String, File>>[];
    final needDownloadReplace = <MapEntry<String, RcloneFileInfo>>[];
    if (candidates.isNotEmpty) {
      onProgress?.call('scan', '', 0, candidates.length);
    }
    var checked = 0;
    for (final entry in candidates) {
      final rel = entry.key;
      final file = entry.value;
      checked++;
      if (checked == 1 || checked == candidates.length || checked % 25 == 0) {
        onProgress?.call('scan', '', checked, candidates.length);
      }
      try {
        final localSize = file.lengthSync();
        if (localSize <= 0) continue;

        RcloneFileInfo? remote = remoteFiles[rel];
        String? remoteRel = remote != null && !remote.isDir ? rel : null;
        if (remote == null || remote.isDir) {
          final base = rel.split('/').last.toLowerCase();
          final hits = remoteByBase[base];
          if (hits != null) {
            for (final h in hits) {
              if (h.value.isDir) continue;
              remote = h.value;
              remoteRel = h.key;
              if (h.key == rel) break;
            }
          }
        }

        if (remote == null || remote.isDir) {
          needUpload.add(entry); // remote fehlt
          continue;
        }
        // Inhalts-Diff: NUR bei Größenänderung Replace/Upload.
        // mtime allein lügt (lokal Dateisystem vs. Cloud-Upload-Zeit).
        final rMod = DateTime.tryParse(remote.modTime);
        final lMod = file.statSync().modified;
        final sizeDiff = remote.size > 0 && remote.size != localSize;
        if (!sizeDiff) {
          // gleiche Bytes → fertig
          continue;
        }
        if (rMod != null) {
          final delta = lMod.difference(rMod).inSeconds;
          if (delta < -60) {
            // Remote klar neuer + andere Größe → ersetzen
            needDownloadReplace.add(MapEntry(remoteRel ?? rel, remote));
          } else {
            // lokal neuer oder unklar → Upload (lokal Vorrang)
            needUpload.add(entry);
          }
        } else {
          needUpload.add(entry);
        }
      } catch (e) {
        AppLog.warn('sync', 'Scan fehlgeschlagen: $rel → $e');
      }
    }

    final uploadTotal = needUpload.length;
    final uploadTotalBytes = needUpload.fold<int>(
      0,
      (sum, e) => sum + (e.value.lengthSyncSafe()),
    );
    final warnings = <String>[];
    // Vorab-Prüfung: Reicht der freie Cloud-Speicher für den Upload? (Nur
    // wenn der Provider eine Quota kennt — freeBytes > 0.) Sonst werden die
    // Uploads übersprungen, statt einzeln mit Quota-Fehlern zu scheitern.
    var skipUploads = false;
    if (uploadTotalBytes > 0) {
      try {
        final quota = await _rclone.getQuota(remoteName);
        final free = quota.freeBytes;
        if (free > 0 && uploadTotalBytes > free) {
          skipUploads = true;
          final msg = '${AppStrings.current.syncRemoteFullWarning} '
              '(${formatBytes(uploadTotalBytes)} benötigt, '
              '${formatBytes(free)} frei).';
          warnings.add(msg);
          AppLog.warn('sync', msg);
        }
      } catch (e) {
        AppLog.warn('sync', 'Quota-Vorabprüfung nicht möglich: $e');
      }
    }
    if (uploadTotal > 0) {
      AppLog.info('sync',
          'Mirror-Phase Upload: $uploadTotal Dateien → $remoteName:$remotePath${skipUploads ? ' (ÜBERSPRUNGEN: Cloud voll)' : ''}');
    }
    var uploadedBytes = 0;
    for (final entry in needUpload) {
      if (skipUploads) break; // Cloud voll → keine Upload-Versuche
      final rel = entry.key;
      final file = entry.value;
      try {
        final size = file.lengthSyncSafe();
        onProgress?.call(
          'upload',
          rel,
          uploaded,
          uploadTotal,
          bytesDone: uploadedBytes,
          bytesTotal: uploadTotalBytes,
        );
        // Live-Bytes: Der Balken folgt in Echtzeit den übertragenen Bytes
        // (auch innerhalb großer Dateien), nicht nur Datei-Sprüngen.
        await _rclone.copyFileToRemoteWithProgress(
          file.path,
          remoteName,
          _joinRemote(remotePath, rel),
          onBytes: (bytes) {
            onProgress?.call(
              'upload',
              rel,
              uploaded,
              uploadTotal,
              bytesDone: uploadedBytes + bytes,
              bytesTotal: uploadTotalBytes,
            );
          },
        );
        uploaded++;
        uploadedBytes += size;
        onProgress?.call(
          'upload',
          rel,
          uploaded,
          uploadTotal,
          bytesDone: uploadedBytes,
          bytesTotal: uploadTotalBytes,
        );
      } catch (e) {
        AppLog.warn('sync', 'Upload fehlgeschlagen: $rel → $e');
      }
    }

    if (localTombs.isNotEmpty) {
      AppLog.info('sync',
          'Mirror-Phase Löschprotokoll: ${localTombs.length} lokale Lösch-Einträge remote ausführen');
    }

    // =====================================================================
    // 2. Lokale Tombstones remote ausführen (Lokal hat Vorrang).
    // Parallel mit begrenzter Nebenläufigkeit — pro Tombstone laufen sonst
    // 2-3 sequenzielle Netzwerk-Calls (Server-Kopie + Delete bzw. Fallback
    // Download+Upload+Delete), das dauert bei vielen Löschungen sehr lange.
    // =====================================================================
    final tombQueue = Queue<Tombstone>.of(localTombs);
    var tb = 0;
    const tombWorkers = 5;
    Future<void> tombWorker() async {
      while (tombQueue.isNotEmpty) {
        final tomb = tombQueue.removeFirst();
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
              ok = true;
            } catch (e) {
              AppLog.warn('sync', 'Remote-Löschung fehlgeschlagen: ${tomb.path} → $e');
            }
          }
          // Aus In-Memory-Remote-Liste nehmen, damit Phase 4 nicht re-downloaded.
          if (ok) remoteFiles.remove(tomb.path);
        }
        appliedLocal.add(tomb);
        merged[tomb.path] = tomb;
      }
    }
    await Future.wait(List.generate(tombWorkers, (_) => tombWorker()));

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
    final localBases = <String>{
      for (final rel in localFiles.keys) rel.split('/').last.toLowerCase(),
    };
    final toDownload = remoteFiles.entries
        .where((entry) =>
            !entry.value.isDir &&
            !merged.containsKey(entry.key) &&
            !localFiles.containsKey(entry.key) &&
            !localBases.contains(entry.key.split('/').last.toLowerCase()))
        .toList();
    // Remote-Inhalt neuer → ersetzen.
    toDownload.addAll(needDownloadReplace);
    final seen = <String>{};
    toDownload.retainWhere((e) => seen.add(e.key));
    final downloadTotal = toDownload.length;
    final downloadTotalBytes = toDownload.fold<int>(
      0,
      (sum, e) => sum + (e.value.size > 0 ? e.value.size : 0),
    );
    // Vorab-Prüfung: Reicht der freie Gerätespeicher für den Download?
    // (Nur wenn messbar — iOS; sonst 0 = unbekannt → keine Prüfung.)
    var skipDownloads = false;
    if (downloadTotalBytes > 0) {
      final freeLocal = await DeviceStorage.freeBytes();
      if (freeLocal > 0 && downloadTotalBytes > freeLocal) {
        skipDownloads = true;
        final msg = '${AppStrings.current.syncLocalFullWarning} '
            '(${formatBytes(downloadTotalBytes)} benötigt, '
            '${formatBytes(freeLocal)} frei).';
        warnings.add(msg);
        AppLog.warn('sync', msg);
      }
    }
    if (downloadTotal > 0) {
      AppLog.info('sync',
          'Mirror-Phase Download: $downloadTotal Dateien ← $remoteName:$remotePath${skipDownloads ? ' (ÜBERSPRUNGEN: Gerät voll)' : ''}');
    }
    var dl = 0;
    var downloadedBytes = 0;
    for (final entry in toDownload) {
      if (skipDownloads) break; // Gerät voll → keine Download-Versuche
      final rel = entry.key;
      dl++;
      final size = entry.value.size > 0 ? entry.value.size : 0;
      onProgress?.call(
        'download',
        rel,
        dl - 1,
        downloadTotal,
        bytesDone: downloadedBytes,
        bytesTotal: downloadTotalBytes,
      );
      final dest = File('$localRoot${Platform.pathSeparator}${_localRel(rel)}');
      try {
        await dest.parent.create(recursive: true);
        // Live-Bytes: Fortschritt folgt den tatsächlich geladenen Bytes.
        await _rclone.downloadFileWithProgress(
          remoteName,
          _joinRemote(remotePath, rel),
          dest.path,
          onBytes: (bytes) {
            onProgress?.call(
              'download',
              rel,
              dl - 1,
              downloadTotal,
              bytesDone: downloadedBytes + bytes,
              bytesTotal: downloadTotalBytes,
            );
          },
        );
        downloaded++;
        downloadedPaths.add(rel);
        downloadedBytes += size;
        onProgress?.call(
          'download',
          rel,
          dl,
          downloadTotal,
          bytesDone: downloadedBytes,
          bytesTotal: downloadTotalBytes,
        );
      } catch (e) {
        AppLog.warn('sync', 'Download fehlgeschlagen: $rel ← $e');
      }
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
      warnings: warnings,
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
  ///
  /// Ordner werden mit einer kleinen Worker-Pool-Nebenläufigkeit parallel
  /// gelistet (Alben nacheinander war bei vielen Ordnern sehr langsam).
  Future<Map<String, RcloneFileInfo>> _listRemoteRecursive(
    String remoteName,
    String remotePath, {
    MirrorProgressCallback? onProgress,
  }) async {
    final result = <String, RcloneFileInfo>{};
    var dirsScanned = 0;
    final prefix = remotePath.isEmpty ? '' : '$remotePath/';

    final queue = Queue<String>.of([remotePath]);
    Object? firstError;
    const workers = 6;

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final dir = queue.removeFirst();
        List<RcloneFileInfo> items;
        try {
          items = await _rclone.listFiles(remoteName, dir);
        } catch (e) {
          firstError ??= e;
          return;
        }
        dirsScanned++;
        onProgress?.call('scan', dir, dirsScanned, 0);
        for (final item in items) {
          final fullRel = dir.isEmpty ? item.name : '$dir/${item.name}';
          // WICHTIG: rel muss RELATIV zu remotePath sein (wird später wieder
          // mit _joinRemote geprefixt) — sonst entsteht „fibu-backup/fibu-backup/…"
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
            queue.add(fullRel);
          }
        }
      }
    }

    await Future.wait(List.generate(workers, (_) => worker()));

    if (firstError != null) {
      // Erster Lauf: Zielordner existiert remote noch nicht → leere
      // Cloud-Seite, kein Fehler. Alles andere weiterhin laut scheitern.
      if (_isDirNotFound(firstError!)) {
        AppLog.info('sync',
            'Zielordner $remoteName:$remotePath existiert noch nicht → Cloud-Seite leer (wird beim Upload angelegt)');
        return result;
      }
      AppLog.error('sync', 'Cloud-Scan fehlgeschlagen ($remoteName:$remotePath): $firstError');
      throw firstError!;
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
    // jsonDecode liefert oft Map<dynamic,dynamic> — whereType<Map<String,dynamic>>
    // würde dann ALLE Einträge verwerfen (stille Tombstone-Amnesie).
    final out = <Tombstone>[];
    for (final raw in list) {
      if (raw is! Map) continue;
      final t = Tombstone.fromJson(Map<String, dynamic>.from(raw));
      if (t.path.isNotEmpty) out.add(t);
    }
    return out;
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
    // Nur bei Größen-Diff und nicht klar remote-neuer.
    final localSize = local.lengthSync();
    if (remote.size <= 0 || remote.size == localSize) return false;
    final remoteMod = DateTime.tryParse(remote.modTime);
    if (remoteMod == null) return true;
    final localMod = local.statSync().modified;
    // Remote klar neuer → nicht „lokal neuer“
    if (localMod.difference(remoteMod).inSeconds < -60) return false;
    return true;
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

/// Robuster Dateigrößen-Zugriff: Liefert 0 statt zu werfen, wenn die Datei
/// im Moment des Scan verschwindet (z. B. parallele Mediathek-Änderung).
extension on File {
  int lengthSyncSafe() {
    try {
      return lengthSync();
    } catch (_) {
      return 0;
    }
  }
}

import 'dart:collection';
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

  /// Bekannte Dateigröße in Bytes (0 = unbekannt, z. B. vor erstem Export).
  /// Nach Upload/Download gesetzt — ermöglicht Inhalts-Diff ohne Full-Hash.
  final int sizeBytes;

  const VirtualMediaItem({
    required this.rel,
    required this.assetId,
    required this.modifiedMs,
    this.sizeBytes = 0,
  });

  Map<String, dynamic> toJson() => {
        'rel': rel,
        'assetId': assetId,
        'modifiedMs': modifiedMs,
        'sizeBytes': sizeBytes,
      };

  factory VirtualMediaItem.fromJson(Map<String, dynamic> json) =>
      VirtualMediaItem(
        rel: json['rel'] as String? ?? '',
        assetId: json['assetId'] as String? ?? '',
        modifiedMs: (json['modifiedMs'] as num?)?.toInt() ?? 0,
        sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      );

  VirtualMediaItem copyWith({int? modifiedMs, int? sizeBytes, String? rel}) =>
      VirtualMediaItem(
        rel: rel ?? this.rel,
        assetId: assetId,
        modifiedMs: modifiedMs ?? this.modifiedMs,
        sizeBytes: sizeBytes ?? this.sizeBytes,
      );

  /// Kompakter Fingerprint für Hintergrund-Vergleich (kein Datei-Inhalt).
  String get contentKey => '$rel|$sizeBytes|$modifiedMs';
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
  /// [previouslySyncedRels]: Pfade, die beim LETZTEN Lauf nachweislich in der
  /// Cloud lagen. Fehlt so ein Pfad jetzt remote (ohne Tombstone), wurde er
  /// dort gelöscht → [deleteLocalAssets] löscht ihn lokal (iOS-Systemdialog).
  /// [deleteLocalAssets]: löscht die übergebenen Medien aus der Mediathek und
  /// liefert die tatsächlich gelöschten rel-Pfade zurück (Nutzer kann im
  /// Systemdialog ablehnen).
  /// Rückgabewert: MirrorSyncResult (gleiche Zähler wie bei FS-Mirror).
  Future<MirrorSyncResult> sync({
    required Map<String, VirtualMediaItem> localItems,
    required String stateRoot,
    required String remoteName,
    required String remotePath,
    required Set<String> blockedRels,
    Set<String>? adoptedRels,
    bool adoptOrphans = false,
    Set<String>? previouslySyncedRels,
    Future<List<String>> Function(List<VirtualMediaItem> items)?
        deleteLocalAssets,
    required Future<File?> Function(VirtualMediaItem item) exportForUpload,
    required Future<void> Function(List<File> files, List<String> rels) importDownloaded,
    required Future<void> Function(List<Map<String, dynamic>> state) persistLocalState,
    TrashService? trash,
    MirrorProgressCallback? onProgress,

    /// Billiger Größen-Mess-Callback für die Upload-Vorabvermessung
    /// (z. B. `asset.file` ohne Temp-Kopie). Fehlt er, wird über
    /// [exportForUpload] gemessen (teurer).
    Future<int> Function(VirtualMediaItem item)? measureForUpload,
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
    // Erfolgreich hochgeladene Pfade dieses Laufs (für den „gesynct“-Zustand).
    final uploadedRels = <String>{};

    // ---------- 0a) Lokale Löschungen → Tombstones (Mirror: lokal → Cloud) ---
    // Pfade, die zuletzt nachweislich gesynct waren und jetzt lokal fehlen,
    // sind lokale Löschungen. Tombstones werden HIER erzeugt (nicht nur
    // vorab in der Datei) — sonst holt die Download-Phase die Cloud-Kopie
    // sofort wieder in die Mediathek.
    if (previouslySyncedRels != null && previouslySyncedRels.isNotEmpty) {
      final knownTombs = localTombs.map((t) => t.path).toSet();
      final missingLocal = previouslySyncedRels
          .where((rel) => !localItems.containsKey(rel) && !knownTombs.contains(rel))
          .toList();
      final prevCount = previouslySyncedRels.length;
      // Sicherheitsbremse: massiver Schwund = Formatwechsel, keine Lösch-Welle.
      final localDeleteAnomaly = prevCount >= 10 && missingLocal.length * 2 > prevCount;
      if (localDeleteAnomaly) {
        AppLog.warn('sync',
            'Lokale Löschungen (${missingLocal.length}/$prevCount) wirken wie Formatwechsel → keine Tombstones (nächster Lauf prüft erneut)');
      } else if (missingLocal.isNotEmpty) {
        final now = DateTime.now();
        for (final rel in missingLocal) {
          localTombs.add(Tombstone(
            path: rel,
            deletedAt: now,
            deviceId: 'local',
          ));
        }
        AppLog.info('sync',
            '${missingLocal.length} lokal gelöschte Medien → Tombstones (Cloud-Löschung, kein Re-Download)');
      }
    }

    // ---------- 0b) Remote-Löschungen erkennen (Mirror: Cloud → lokal) -------
    // Ein Pfad, der beim letzten Lauf in der Cloud lag, jetzt aber weder
    // remote existiert noch ein Tombstone hat, wurde direkt in der Cloud
    // gelöscht. Diese Kandidaten dürfen NICHT wieder hochgeladen werden —
    // sie werden (nach Sicherheitsbremse) lokal gelöscht.
    final tombPaths = <String>{
      for (final t in localTombs) t.path,
      for (final t in remoteTombs) t.path,
    };
    final remoteDeletedCandidates = <VirtualMediaItem>[];
    if (previouslySyncedRels != null && deleteLocalAssets != null) {
      for (final item in localItems.values) {
        if (!previouslySyncedRels.contains(item.rel)) continue;
        if (remoteFiles.containsKey(item.rel)) continue;
        if (tombPaths.contains(item.rel)) continue;
        if (blockedRels.contains(item.rel)) continue;
        if (adoptedRels != null && adoptedRels.contains(item.rel)) continue;
        remoteDeletedCandidates.add(item);
      }
    }
    final remoteDeletedRels =
        remoteDeletedCandidates.map((i) => i.rel).toSet();

    // Index remote files by basename for path-mismatch tolerance
    // (lokal Photos/A/x.jpg, remote Photos/B/x.jpg → gilt als vorhanden).
    final remoteByBase = <String, List<MapEntry<String, RcloneFileInfo>>>{};
    for (final e in remoteFiles.entries) {
      if (e.value.isDir) continue;
      final base = e.key.split('/').last.toLowerCase();
      if (base.isEmpty) continue;
      (remoteByBase[base] ??= []).add(e);
    }

    /// Findet den besten Remote-Treffer zu einem lokalen Item.
    ({String rel, RcloneFileInfo info})? matchRemote(VirtualMediaItem item) {
      final exact = remoteFiles[item.rel];
      if (exact != null && !exact.isDir) {
        return (rel: item.rel, info: exact);
      }
      final base = item.rel.split('/').last.toLowerCase();
      final hits = remoteByBase[base];
      if (hits == null || hits.isEmpty) return null;
      MapEntry<String, RcloneFileInfo>? best;
      for (final h in hits) {
        if (h.value.isDir) continue;
        best ??= h;
        if (h.key == item.rel) return (rel: h.key, info: h.value);
      }
      return best == null ? null : (rel: best.key, info: best.value);
    }

    /// Inhalts-Diff ohne Full-Hash.
    ///
    /// WICHTIG (iOS-Fotos): `AssetEntity.modifiedDateTime` ist oft die
    /// **Aufnahmezeit**, während die Cloud die **Upload-Zeit** speichert.
    /// Deshalb darf „remote mtime neuer“ allein NIEMALS einen Replace
    /// (löschen + neu laden) auslösen — das erzeugte die Endlos-Schleife
    /// „alles löschen und neu herunterladen“.
    ///
    /// Regeln:
    ///  * Größe gleich (und bekannt) → gleich (0), mtime ignorieren
    ///  * Größe anders + lokal mtime klar neuer → Upload (1)
    ///  * Größe anders + remote mtime klar neuer + lokale Größe bekannt → Replace (-1)
    ///  * Größe anders, Zeiten unklar → lokal Vorrang Upload (1)
    ///  * lokale Größe unbekannt (0) → nach Export nochmal prüfen (hier 0/1 vorsichtig)
    ///
    /// Rückgabe: <0 remote neuer, 0 gleich, >0 lokal neuer.
    int contentCmp(VirtualMediaItem local, RcloneFileInfo remote, int localSize) {
      final rSize = remote.size;
      final sizeKnown = rSize > 0 && localSize > 0;
      final sizeSame = sizeKnown && rSize == localSize;
      final sizeDiffers = sizeKnown && rSize != localSize;

      // Gleiche Bytes → inhaltlich am Ziel, fertig (mtime von iOS vs Cloud lügen).
      if (sizeSame) return 0;

      final rMod = DateTime.tryParse(remote.modTime);
      final lMod = DateTime.fromMillisecondsSinceEpoch(local.modifiedMs);

      // Lokale Größe noch unbekannt: nur bei klar neuerer lokaler mtime pushen,
      // sonst als „vermutlich ok“ werten und nach Export nachmessen.
      if (localSize <= 0) {
        if (rMod != null &&
            lMod.isAfter(rMod.add(const Duration(seconds: 60)))) {
          return 1;
        }
        return 0;
      }

      // Remote-Größe unbekannt: nur hochladen wenn lokal klar neuer.
      if (rSize <= 0) {
        if (rMod != null &&
            lMod.isAfter(rMod.add(const Duration(seconds: 60)))) {
          return 1;
        }
        return 0;
      }

      // Ab hier: Größen differieren → echter Inhalts-Unterschied möglich.
      if (!sizeDiffers) return 0;

      if (rMod == null) {
        // Keine Remote-Zeit: lokal hat Vorrang (Upload).
        return 1;
      }
      final delta = lMod.difference(rMod).inSeconds;
      if (delta > 60) return 1; // lokal klar neuer (Crop/Edit)
      if (delta < -60) return -1; // remote klar neuer + andere Größe
      // Zeiten nah, Größe anders: lokal Vorrang (kein aggressives Replace).
      return 1;
    }

    // Größen nach erfolgreichem Transfer in localItems schreiben.
    final sizeUpdates = <String, int>{};

    // ---------- 1) Upload: fehlt remote ODER lokal-Inhalt neuer --------------
    // UI: „upload“ erst beim echten Transfer; Abgleich bleibt „scan“.
    final candidates = localItems.values
        .where((item) => !blockedRels.contains(item.rel))
        .where((item) => !remoteDeletedRels.contains(item.rel))
        .toList();
    // Zuerst billig entscheiden, welche wirklich hoch müssen (ohne Export).
    final needUpload = <VirtualMediaItem>[];
    final needDownloadReplace = <({VirtualMediaItem local, String remoteRel, RcloneFileInfo remote})>[];
    if (candidates.isNotEmpty) {
      onProgress?.call('scan', AppStrings.current.syncPhaseScan, 0, candidates.length);
    }
    var checked = 0;
    for (final item in candidates) {
      checked++;
      if (checked == 1 || checked == candidates.length || checked % 10 == 0) {
        onProgress?.call(
            'scan', AppStrings.current.syncPhaseScan, checked, candidates.length);
      }
      final m = matchRemote(item);
      if (m == null) {
        needUpload.add(item); // remote fehlt
        continue;
      }
      // Bekannte Größe aus State, sonst 0 → nach Export nachmessen.
      final knownSize = item.sizeBytes;
      final cmp = contentCmp(item, m.info, knownSize);
      if (cmp == 0) {
        uploadedRels.add(item.rel);
        continue;
      }
      if (cmp > 0) {
        needUpload.add(item);
      } else {
        // Remote neuer + andere Größe → später ersetzen (Download + Import).
        needDownloadReplace.add((local: item, remoteRel: m.rel, remote: m.info));
        uploadedRels.add(item.rel); // gilt als „paired“, kein Neu-Upload
      }
    }

    // Echte Uploads. Die Gesamtgröße wird VOR dem ersten Transfer einmal
    // vermessen (billiger asset.file-Callback bzw. Export-Fallback), damit
    // die 100%-Basis von Anfang an feststeht — kein „Gesamt-MB wächst nach"
    // und kein Zurückspringen des Balkens mehr.
    final uploadTotal = needUpload.length;
    var uploadTotalBytes = 0;
    if (uploadTotal > 0) {
      AppLog.info('sync', 'Virtual-Mirror Upload: $uploadTotal Dateien → $remoteName:$remotePath');
      onProgress?.call('scan', AppStrings.current.syncPhaseScan, 0, uploadTotal);
      var measured = 0;
      for (final item in needUpload) {
        measured++;
        if (measured == 1 || measured == uploadTotal || measured % 10 == 0) {
          onProgress?.call(
              'scan', AppStrings.current.syncPhaseScan, measured, uploadTotal);
        }
        var size = 0;
        try {
          if (measureForUpload != null) {
            size = await measureForUpload(item);
          } else {
            final f = await exportForUpload(item);
            if (f != null && await f.exists()) size = await f.length();
            try {
              if (f != null && await f.exists()) await f.delete();
              final parent = f?.parent;
              if (parent != null &&
                  await parent.exists() &&
                  parent.path.contains('fibu_export_')) {
                await parent.delete(recursive: true);
              }
            } catch (_) {}
          }
        } catch (_) {}
        if (size < 0) size = 0;
        uploadTotalBytes += size;
      }
      AppLog.info('sync',
          'Upload-Vermessung fertig: $uploadTotal Dateien / $uploadTotalBytes Bytes');
    }

    var uploadedBytes = 0;
    for (final item in needUpload) {
      File? tmp;
      try {
        tmp = await exportForUpload(item);
        if (tmp == null || !await tmp.exists()) continue;
        final localSize = await tmp.length();
        if (localSize <= 0) continue;

        // Nach Export: nochmal gegen remote prüfen (jetzt mit echter Größe).
        final m = matchRemote(item);
        if (m != null) {
          final cmp = contentCmp(item, m.info, localSize);
          if (cmp == 0) {
            sizeUpdates[item.rel] = localSize;
            uploadedRels.add(item.rel);
            continue;
          }
          if (cmp < 0) {
            // Remote doch neuer + andere Größe → Download-Replace statt Upload.
            needDownloadReplace.add((local: item, remoteRel: m.rel, remote: m.info));
            sizeUpdates[item.rel] = localSize;
            uploadedRels.add(item.rel);
            continue;
          }
        }

        onProgress?.call(
          'upload',
          item.rel,
          uploaded,
          uploadTotal,
          bytesDone: uploadedBytes,
          bytesTotal: uploadTotalBytes,
        );
        // Live-Bytes: Der Balken folgt in Echtzeit den übertragenen Bytes.
        await _rclone.copyFileToRemoteWithProgress(
          tmp.path,
          remoteName,
          _joinRemote(remotePath, item.rel),
          onBytes: (bytes) {
            onProgress?.call(
              'upload',
              item.rel,
              uploaded,
              uploadTotal,
              bytesDone: uploadedBytes + bytes,
              bytesTotal: uploadTotalBytes,
            );
          },
        );
        uploaded++;
        uploadedBytes += localSize;
        onProgress?.call(
          'upload',
          item.rel,
          uploaded,
          uploadTotal,
          bytesDone: uploadedBytes,
          bytesTotal: uploadTotalBytes,
        );
        uploadedRels.add(item.rel);
        sizeUpdates[item.rel] = localSize;
      } catch (e) {
        AppLog.warn('sync', 'Upload fehlgeschlagen: ${item.rel} → $e');
      } finally {
        try {
          final f = tmp;
          if (f != null && await f.exists()) await f.delete();
          final parent = tmp?.parent;
          if (parent != null &&
              await parent.exists() &&
              parent.path.contains('fibu_export_')) {
            await parent.delete(recursive: true);
          }
        } catch (_) {}
      }
    }

    // ---------- 2) Lokale Tombstones remote ausführen (Lokal hat Vorrang) ----
    // Parallel mit begrenzter Nebenläufigkeit: pro Tombstone laufen sonst
    // 2-3 sequenzielle Netzwerk-Calls (Server-Kopie + Delete bzw. Fallback
    // Download+Upload+Delete) — bei vielen Löschungen sehr langsam.
    final tombQueue = Queue<Tombstone>.of(localTombs);
    var tb = 0;
    const tombWorkers = 5;
    Future<void> tombWorker() async {
      while (tombQueue.isNotEmpty) {
        final tomb = tombQueue.removeFirst();
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
              ok = true;
            } catch (e) {
              AppLog.warn('sync', 'Remote-Löschung fehlgeschlagen: ${tomb.path} → $e');
            }
          }
          // Auch bei Erfolg aus der In-Memory-Liste nehmen, damit Phase 4
          // (Download) die Datei nicht aus dem Scan-Stand von Laufbeginn holt.
          if (ok) remoteFiles.remove(tomb.path);
        }
        // Tombstone gilt IMMER — blockiert Re-Download, auch wenn Delete noch
        // scheitert (nächster Lauf versucht erneut, holt aber nichts zurück).
        merged[tomb.path] = tomb;
      }
    }
    await Future.wait(List.generate(tombWorkers, (_) => tombWorker()));

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

    // ---------- 3b) Direkte Cloud-Löschungen lokal ausführen ----------------
    // (Nutzer hat Dateien unmittelbar in der Cloud gelöscht — kein Tombstone.)
    // iOS zeigt beim Löschen aus der Mediathek IMMER den Systemdialog mit
    // Vorschau; lehnt der Nutzer ab, wird der Pfad blockiert (bleibt lokal,
    // wird aber nicht wieder hochgeladen und nicht erneut nachgefragt).
    if (remoteDeletedCandidates.isNotEmpty && deleteLocalAssets != null) {
      final prevCount = previouslySyncedRels?.length ?? 0;
      // Sicherheitsbremse: leere/implausible Cloud-Listen (Ordner nicht
      // gefunden, Ausfall) dürfen niemals die halbe Mediathek löschen.
      final anomaly = remoteFiles.isEmpty ||
          (prevCount >= 10 &&
              remoteDeletedCandidates.length * 2 > prevCount);
      if (anomaly) {
        AppLog.warn('sync',
            'Remote-Löschungen (${remoteDeletedCandidates.length}/$prevCount) wirken wie ein Ausfall/Formatwechsel → lokale Löschung übersprungen (nächster Lauf prüft erneut)');
      } else {
        AppLog.info('sync',
            '${remoteDeletedCandidates.length} in der Cloud gelöschte Dateien → lokale Löschung (Systemdialog)');
        onProgress?.call('delete-local', '', 0, remoteDeletedCandidates.length);
        final deletedRels = await deleteLocalAssets(remoteDeletedCandidates);
        final deletedSet = deletedRels.toSet();
        deletedLocal += deletedSet.length;
        for (final rel in deletedSet) {
          localItems.remove(rel);
        }
        // Vom Nutzer im Systemdialog abgelehnt → behalten, aber blockieren.
        for (final item in remoteDeletedCandidates) {
          if (!deletedSet.contains(item.rel)) {
            blockedRels.add(item.rel);
            AppLog.info('sync',
                'Lokale Löschung abgelehnt: ${item.rel} bleibt lokal erhalten und wird nicht erneut hochgeladen');
          }
        }
      }
    }

    // ---------- 4) Downloads: Cloud-only + Remote-neuer (Inhalt) -------------
    final toDownload = <MapEntry<String, RcloneFileInfo>>[];
    var adoptedNow = 0;
    final localBases = <String>{
      for (final rel in localItems.keys) rel.split('/').last.toLowerCase(),
    };
    for (final entry in remoteFiles.entries) {
      final rel = entry.key;
      if (entry.value.isDir) continue;
      if (rel.startsWith('.fibu') || rel.startsWith("$remotePath/.fibu")) continue;
      if (merged.containsKey(rel)) continue;
      if (blockedRels.contains(rel)) continue;
      if (adoptedRels != null && adoptedRels.contains(rel)) continue;
      if (adoptOrphans && adoptedRels != null) {
        // Nur adoptieren, wenn lokal kein Basename-Pendant existiert.
        final base = rel.split('/').last.toLowerCase();
        if (!localBases.contains(base)) {
          adoptedRels.add(rel);
          adoptedNow++;
        }
        continue;
      }
      // Lokal vorhanden (exakt oder Basename) → nur via needDownloadReplace.
      if (localItems.containsKey(rel)) continue;
      final base = rel.split('/').last.toLowerCase();
      if (localBases.contains(base)) continue;
      toDownload.add(entry);
    }
    // Remote-Inhalt neuer als lokal → ersetzen (Download + Import).
    for (final r in needDownloadReplace) {
      toDownload.add(MapEntry(r.remoteRel, r.remote));
    }
    if (adoptedNow > 0) {
      AppLog.info('sync',
          'Adoption (Moduswechsel): $adoptedNow bestehende Cloud-Dateien übernommen — kein Download in die Mediathek');
    }
    adoptedRels?.removeWhere((rel) =>
        !remoteFiles.containsKey(rel) ||
        merged.containsKey(rel) ||
        localItems.containsKey(rel));
    // Dedup remote rels
    final seenDl = <String>{};
    toDownload.retainWhere((e) => seenDl.add(e.key));
    // Remote-neuer: lokale Version zuerst entfernen (Replace), sonst Duplikate.
    if (needDownloadReplace.isNotEmpty && deleteLocalAssets != null) {
      final toReplace = needDownloadReplace.map((r) => r.local).toList();
      onProgress?.call('delete-local', '', 0, toReplace.length);
      try {
        final gone = await deleteLocalAssets(toReplace);
        for (final rel in gone) {
          localItems.remove(rel);
          deletedLocal++;
        }
        AppLog.info('sync',
            'Replace: ${gone.length}/${toReplace.length} lokale Versionen entfernt vor Download');
      } catch (e) {
        AppLog.warn('sync', 'Replace-Löschung fehlgeschlagen: $e');
      }
    }

    final downloadTotal = toDownload.length;
    final downloadTotalBytes = toDownload.fold<int>(
      0,
      (sum, e) => sum + (e.value.size > 0 ? e.value.size : 0),
    );
    if (downloadTotal > 0) {
      AppLog.info('sync',
          'Virtual-Mirror Download: $downloadTotal Dateien ← $remoteName:$remotePath');
    }
    var dl = 0;
    var downloadedBytes = 0;
    final tmpFiles = <File>[];
    final tmpRels = <String>[];
    for (final entry in toDownload) {
      final rel = entry.key;
      final size = entry.value.size > 0 ? entry.value.size : 0;
      dl++;
      onProgress?.call(
        'download',
        rel,
        dl - 1,
        downloadTotal,
        bytesDone: downloadedBytes,
        bytesTotal: downloadTotalBytes,
      );
      try {
        final tmpRoot = await Directory.systemTemp.createTemp('fibu_import_');
        final dest = File('${tmpRoot.path}/${entry.value.name}');
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
        if (await dest.exists() && await dest.length() > 0) {
          tmpFiles.add(dest);
          tmpRels.add(rel);
          downloaded++;
          downloadedPaths.add(rel);
          final actualSize = size > 0 ? size : await dest.length();
          downloadedBytes += actualSize;
          sizeUpdates[rel] = actualSize;
          onProgress?.call(
            'download',
            rel,
            dl,
            downloadTotal,
            bytesDone: downloadedBytes,
            bytesTotal: downloadTotalBytes > 0 ? downloadTotalBytes : downloadedBytes,
          );
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
    // Nur NACHWEISLICH gesyncte Pfade persistieren (jetzt hochgeladen oder
    // remote vorhanden). Fehlgeschlagene Uploads bleiben draußen und werden
    // beim nächsten Lauf erneut hochgeladen — und ein nie hochgeladener Pfad
    // kann so niemals fälschlich als „remote gelöscht“ gelten.
    final syncedNow = <String>{
      ...uploadedRels,
      for (final rel in localItems.keys)
        if (remoteFiles.containsKey(rel) ||
            localBases.contains(rel.split('/').last.toLowerCase()))
          rel,
    };
    // Größen aus Transfers in den persistierten State schreiben.
    for (final e in sizeUpdates.entries) {
      final cur = localItems[e.key];
      if (cur != null) {
        localItems[e.key] = cur.copyWith(sizeBytes: e.value);
      }
    }
    await persistLocalState(localItems.values
        .where((i) => syncedNow.contains(i.rel))
        .map((i) {
          // Remote-Größe als Baseline, falls wir sie kennen (Inhalt synced).
          final m = remoteFiles[i.rel];
          if (m != null && !m.isDir && m.size > 0 && i.sizeBytes <= 0) {
            return i.copyWith(sizeBytes: m.size).toJson();
          }
          return i.toJson();
        })
        .toList());

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

    // Ordner parallel mit kleiner Nebenläufigkeit listen (Alben nacheinander
    // war bei vielen Ordnern sehr langsam).
    final queue = Queue<String>([remotePath]);
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
      // Erster Lauf: Der Zielordner existiert remote noch nicht → das ist
      // KEIN Fehler, sondern eine leere Cloud-Seite. Alles andere bleibt laut.
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
      return _parseTombs(content);
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
      // jsonDecode liefert oft Map<dynamic,dynamic> — whereType<Map<String,dynamic>>
      // würde dann ALLE Tombstones verwerfen → Re-Download-Bug nach lokaler Löschung.
      final out = <Tombstone>[];
      for (final raw in list) {
        if (raw is! Map) continue;
        final t = Tombstone.fromJson(Map<String, dynamic>.from(raw));
        if (t.path.isNotEmpty) out.add(t);
      }
      return out;
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

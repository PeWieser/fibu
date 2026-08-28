import 'dart:io';

import 'package:fibu/core/services/mirror_sync_engine.dart';
import 'package:fibu/core/services/mock_rclone_service.dart';
import 'package:fibu/core/services/rclone_service.dart';
import 'package:fibu/core/services/virtual_mirror_sync.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake-Remote, die die Aufrufreihenfolge protokolliert.
///
/// [MockRcloneService] wird erweitert statt neu implementiert, damit der Test
/// gegen dieselbe Schnittstelle läuft wie die App.
class _RecordingRclone extends MockRcloneService {
  _RecordingRclone({required this.remote});

  /// rel → Dateigröße der „Cloud".
  final Map<String, int> remote;

  final List<String> calls = <String>[];

  /// Abgesetzte List-Aufrufe — damit „nichts geladen"-Tests nicht leer
  /// durchlaufen, wenn die Remote-Liste versehentlich leer ist.
  final List<String> listedPaths = <String>[];
  final List<String> uploaded = <String>[];
  final List<String> downloaded = <String>[];

  @override
  /// Bildet den Zielordner als echten Verzeichnisbaum ab.
  ///
  /// rclone liefert pro Aufruf nur die UNMITTELBAREN Kinder — Namen dürfen
  /// also kein `/` enthalten. Die Schlüssel in [remote] sind relativ zum
  /// Zielordner des Tests (`fibu-backup`); Zwischenordner werden deshalb als
  /// `isDir: true` synthesisiert, damit die Engine korrekt rekursiert und
  /// die Zieldatei am Ende einen einfachen Dateinamen hat.
  Future<List<RcloneFileInfo>> listFiles(String remoteName, String path) async {
    listedPaths.add(path);
    const String root = 'fibu-backup';
    final String rel = path == root
        ? ''
        : (path.startsWith('$root/') ? path.substring(root.length + 1) : path);
    final String prefix = rel.isEmpty ? '' : '$rel/';
    const String modTime = '2024-01-01T00:00:00.000Z';
    final Map<String, RcloneFileInfo> children = <String, RcloneFileInfo>{};
    for (final MapEntry<String, int> e in remote.entries) {
      if (!e.key.startsWith(prefix)) continue;
      final String rest = e.key.substring(prefix.length);
      final int slash = rest.indexOf('/');
      if (slash < 0) {
        children[rest] = RcloneFileInfo(
            name: rest, size: e.value, modTime: modTime, isDir: false);
      } else {
        final String dir = rest.substring(0, slash);
        children.putIfAbsent(
            dir,
            () => RcloneFileInfo(
                name: dir, size: 0, modTime: modTime, isDir: true));
      }
    }
    return children.values.toList();
  }

  @override
  Future<String?> catFile(String remoteName, String path) async => null;

  @override
  Future<QuotaInfo> getQuota(String remoteName) async =>
      const QuotaInfo(totalBytes: 0, usedBytes: 0, freeBytes: 0);

  @override
  Future<void> copyFileToRemoteWithProgress(
    String localFilePath,
    String remoteName,
    String remotePath, {
    void Function(int bytesTransferred)? onBytes,
  }) async {
    calls.add('upload');
    uploaded.add(remotePath);
    onBytes?.call(1);
  }

  @override
  Future<void> downloadFileWithProgress(
    String remoteName,
    String remotePath,
    String localPath, {
    void Function(int bytesTransferred)? onBytes,
  }) async {
    calls.add('download');
    downloaded.add(remotePath);
    await File(localPath).writeAsBytes(List<int>.filled(8, 1));
    onBytes?.call(8);
  }
}

VirtualMediaItem _item(String rel) => VirtualMediaItem(
      rel: rel,
      assetId: 'id_${rel.replaceAll(RegExp(r'\W'), '_')}',
      modifiedMs: DateTime(2024, 1, 1).millisecondsSinceEpoch,
      sizeBytes: 8,
    );

void main() {
  late Directory stateRoot;
  late Directory localFile;

  setUp(() async {
    stateRoot = await Directory.systemTemp.createTemp('fibu_test_state_');
    localFile = await Directory.systemTemp.createTemp('fibu_test_asset_');
  });

  tearDown(() async {
    if (await stateRoot.exists()) await stateRoot.delete(recursive: true);
    if (await localFile.exists()) await localFile.delete(recursive: true);
  });

  /// Führt einen virtuellen Mirror-Lauf mit einem lokalen und einem
  /// Cloud-only Medium aus.
  Future<({MirrorSyncResult result, _RecordingRclone rclone, List<String> phases})>
      run({
    required Map<String, int> remote,
    required Map<String, VirtualMediaItem> localItems,
    Map<String, Set<int>>? librarySizes,
    Set<String>? previouslySyncedRels,
    bool Function()? isCancelled,
  }) async {
    final _RecordingRclone rclone = _RecordingRclone(remote: remote);
    final List<String> phases = <String>[];

    // Wie in der App: Jeder Export liefert eine EIGENE temporäre Datei.
    // Der Vermessungs-Durchlauf löscht seine Kopie wieder — eine geteilte
    // Datei wäre danach für den Upload weg.
    var exportCounter = 0;
    Future<File> exportOnce(VirtualMediaItem item) async {
      exportCounter++;
      final File copy = File('${localFile.path}/export_$exportCounter.bin');
      return copy..writeAsBytesSync(List<int>.filled(8, 2));
    }

    final MirrorSyncResult result = await VirtualMirrorSyncEngine(rclone).sync(
      localItems: localItems,
      stateRoot: stateRoot.path,
      remoteName: 'cloud',
      remotePath: 'fibu-backup',
      blockedRels: <String>{},
      previouslySyncedRels: previouslySyncedRels,
      librarySizes: librarySizes,
      isCancelled: isCancelled,
      exportForUpload: exportOnce,
      importDownloaded: (List<File> files, List<String> rels) async {},
      persistLocalState: (List<Map<String, dynamic>> state) async {},
      onProgress: (String phase, String item, int done, int total,
          {int bytesDone = 0, int bytesTotal = 0}) {
        phases.add(phase);
      },
    );
    return (result: result, rclone: rclone, phases: phases);
  }

  group('Sync-Reihenfolge', () {
    test('Upload läuft immer vor Download', () async {
      // Lokal: A (fehlt in der Cloud → Upload).
      // Cloud: B (fehlt lokal → Download).
      final run1 = await run(
        remote: <String, int>{'Photos/Album/B.heic': 8},
        localItems: <String, VirtualMediaItem>{
          'Photos/Album/A.heic': _item('Photos/Album/A.heic'),
        },
      );

      expect(run1.result.uploaded, 1, reason: 'A muss hochgeladen werden');
      expect(run1.result.downloaded, 1, reason: 'B muss geladen werden');

      final int lastUpload = run1.rclone.calls.lastIndexOf('upload');
      final int firstDownload = run1.rclone.calls.indexOf('download');
      expect(lastUpload, lessThan(firstDownload),
          reason: 'Alle Uploads müssen vor dem ersten Download abgeschlossen '
              'sein (Reihenfolge: erst hochladen, dann laden). Aufrufe: '
              '${run1.rclone.calls}');
    });
  });

  group('Abbruch', () {
    test('Abbruch stoppt den Download-Lauf', () async {
      // Nach der ersten Datei wird abgebrochen — der Rest darf nicht mehr
      // geladen werden. Vor dem Fix lief ein „abgebrochener“ Spiegel-Sync
      // unsichtbar bis zum Ende weiter.
      var calls = 0;
      final run1 = await run(
        remote: <String, int>{
          'Photos/Album/A.heic': 8,
          'Photos/Album/B.heic': 8,
          'Photos/Album/C.heic': 8,
        },
        localItems: <String, VirtualMediaItem>{},
        isCancelled: () => calls++ > 0,
      );
      expect(run1.rclone.listedPaths, isNotEmpty,
          reason: 'Remote-Scan muss stattgefunden haben');
      expect(run1.rclone.downloaded.length, lessThan(3),
          reason: 'Abbruch muss den Lauf vor dem Ende beenden');
    });

    test('ohne Abbruchsignal läuft alles durch', () async {
      final run1 = await run(
        remote: <String, int>{
          'Photos/Album/A.heic': 8,
          'Photos/Album/B.heic': 8,
          'Photos/Album/C.heic': 8,
        },
        localItems: <String, VirtualMediaItem>{},
      );
      expect(run1.result.downloaded, 3);
    });
  });

  group('Re-Download-Schutz', () {
    test('Medium aus anderem Album wird nicht erneut geladen', () async {
      // Die Cloud-Datei liegt lokal bereits vor — aber in einem Album, das
      // der Task-Filter nicht scannt. Ohne geräteweite Prüfung galt sie als
      // „neu“ und wurde doppelt in die Mediathek importiert.
      final run1 = await run(
        remote: <String, int>{'Photos/Urlaub/IMG_1.heic': 8},
        localItems: <String, VirtualMediaItem>{},
        librarySizes: <String, Set<int>>{'img_1.heic': <int>{8}},
      );
      expect(run1.rclone.listedPaths, isNotEmpty,
          reason: 'Remote-Scan muss stattgefunden haben');
      expect(run1.result.downloaded, 0,
          reason: 'Bereits lokal vorhanden (gleicher Name, gleiche Größe)');
      expect(run1.rclone.downloaded, isEmpty);
    });

    test('gleicher Name mit anderer Größe ist eine andere Datei', () async {
      // Zweites Gerät: dessen IMG_1.heic heißt gleich, ist aber ein anderes
      // Foto (andere Bytezahl) → muss geladen werden, nicht übersprungen.
      final run1 = await run(
        remote: <String, int>{'Photos/Urlaub/IMG_1.heic': 64000},
        localItems: <String, VirtualMediaItem>{},
        librarySizes: <String, Set<int>>{'img_1.heic': <int>{8}},
      );
      expect(run1.result.downloaded, 1,
          reason: 'Andere Größe → anderes Foto → Download');
    });

    test('Bereits abgeglichener Pfad wird nicht erneut geladen', () async {
      final run1 = await run(
        remote: <String, int>{'Photos/Urlaub/IMG_2.heic': 8},
        localItems: <String, VirtualMediaItem>{},
        previouslySyncedRels: <String>{'Photos/Urlaub/IMG_2.heic'},
      );
      expect(run1.rclone.listedPaths, isNotEmpty,
          reason: 'Remote-Scan muss stattgefunden haben');
      expect(run1.result.downloaded, 0,
          reason: 'Pfad war im letzten Lauf bereits abgeglichen');
    });

    test('Echt neues Cloud-Medium wird weiterhin geladen', () async {
      final run1 = await run(
        remote: <String, int>{'Photos/Urlaub/IMG_3.heic': 8},
        localItems: <String, VirtualMediaItem>{},
        librarySizes: <String, Set<int>>{'irgendwas_anderes.heic': <int>{8}},
      );
      expect(run1.result.downloaded, 1,
          reason: 'Unbekanntes Medium muss ankommen');
    });
  });
}

import 'dart:io';

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
  final List<String> uploaded = <String>[];
  final List<String> downloaded = <String>[];

  @override
  Future<List<RcloneFileInfo>> listFiles(String remoteName, String path) async {
    final String prefix = path.isEmpty ? '' : '$path/';
    return <RcloneFileInfo>[
      for (final MapEntry<String, int> e in remote.entries)
        if (e.key.startsWith(prefix) && !e.key.substring(prefix.length).contains('/'))
          RcloneFileInfo(
            name: e.key.substring(prefix.length),
            size: e.value,
            modTime: DateTime(2024, 1, 1).toIso8601String(),
            isDir: false,
          ),
    ];
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

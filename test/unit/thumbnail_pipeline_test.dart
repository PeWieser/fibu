import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:fibu/core/services/mock_rclone_service.dart';
import 'package:fibu/core/services/thumbnail_pipeline.dart';
import 'package:fibu/core/services/thumbnail_service.dart';

/// Phase 5b: Vorschaubilder erzeugen und ablegen.
///
/// Die Erzeugung selbst ist eingespritzt (`createFor`) — geprüft wird die
/// Pipeline: Ablage, Zählung, Fortschritt, Abbruch und dass ein Fehler
/// niemals den Lauf abbricht. Genau das ist die Zusage, auf die sich der
/// Sync-Hook verlässt.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late MockRcloneService rclone;
  late ThumbnailCache cache;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fibu_pipeline_test_');
    rclone = MockRcloneService();
    cache = ThumbnailCache(dir, maxBytes: 1024 * 1024);
  });

  tearDown(() async {
    rclone.dispose();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Uint8List bytes() => Uint8List.fromList([1, 2, 3, 4]);

  test('erzeugt, legt im Cache ab und zählt', () async {
    final uploaded = await ThumbnailPipeline.run(
      rclone: rclone,
      remoteName: 'cloud',
      rels: const ['Photos/A.jpg', 'Photos/B.jpg'],
      cache: cache,
      createFor: (rel) async => bytes(),
    );

    expect(uploaded, 2);
    expect(await cache.read('Photos/A.jpg'), isNotNull);
    expect(await cache.read('Photos/B.jpg'), isNotNull);
  });

  test('null heißt: keine Vorschau, aber kein Fehler', () async {
    final uploaded = await ThumbnailPipeline.run(
      rclone: rclone,
      remoteName: 'cloud',
      rels: const ['Photos/A.jpg', 'Photos/B.jpg'],
      cache: cache,
      createFor: (rel) async => rel == 'Photos/A.jpg' ? bytes() : null,
    );

    expect(uploaded, 1);
    expect(await cache.read('Photos/A.jpg'), isNotNull);
    expect(await cache.read('Photos/B.jpg'), isNull,
        reason: 'HEIC auf Windows hat keine Vorschau — und das ist okay');
  });

  test('ein Fehler bricht den Lauf nicht ab', () async {
    final uploaded = await ThumbnailPipeline.run(
      rclone: rclone,
      remoteName: 'cloud',
      rels: const ['Photos/A.jpg', 'Photos/B.jpg', 'Photos/C.jpg'],
      cache: cache,
      createFor: (rel) async {
        if (rel == 'Photos/B.jpg') throw StateError('Dekoder abgestürzt');
        return bytes();
      },
    );

    expect(uploaded, 2, reason: 'A und C laufen weiter, B wird übersprungen');
    expect(await cache.read('Photos/C.jpg'), isNotNull);
  });

  test('Abbruch stoppt, ohne den Rest zu verarbeiten', () async {
    var processed = 0;
    final uploaded = await ThumbnailPipeline.run(
      rclone: rclone,
      remoteName: 'cloud',
      rels: const ['a.jpg', 'b.jpg', 'c.jpg', 'd.jpg'],
      cache: cache,
      createFor: (rel) async {
        processed++;
        return bytes();
      },
      isCancelled: () => processed >= 2,
    );

    expect(processed, 2);
    expect(uploaded, 2);
  });

  test('Fortschritt wird für jede Aufnahme gemeldet', () async {
    final calls = <String>[];
    await ThumbnailPipeline.run(
      rclone: rclone,
      remoteName: 'cloud',
      rels: const ['a.jpg', 'b.jpg'],
      cache: cache,
      createFor: (rel) async => bytes(),
      onProgress: (done, total) => calls.add('$done/$total'),
    );

    expect(calls, ['1/2', '2/2']);
  });

  test('Bestand auflisten wirft nicht, wenn der Ordner fehlt', () async {
    final names = await ThumbnailPipeline.listCloudThumbs(rclone, 'cloud');
    expect(names, isA<Set<String>>());
  });

  test('Namen sind stabil zwischen Pipeline und Dienst', () async {
    await ThumbnailPipeline.run(
      rclone: rclone,
      remoteName: 'cloud',
      rels: const ['Photos/Urlaub/IMG_0001.HEIC'],
      cache: cache,
      createFor: (rel) async => bytes(),
    );

    final expected =
        await ThumbnailService.fileNameFor('Photos/Urlaub/IMG_0001.HEIC');
    final file = File('${dir.path}/$expected');
    expect(await file.exists(), isTrue,
        reason: 'Pipeline und Explorer müssen denselben Namen bilden');
  });
}

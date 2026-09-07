import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fibu/core/services/thumbnail_service.dart';

/// Phase 5a: Namen, Auflösung, Cache, Warteschlange.
///
/// Reine Logik und ein echtes temporäres Verzeichnis — kein Gerät, kein
/// rclone, kein Widget. Alles, was hier falsch wäre, würde später als
/// „falsches Vorschaubild" oder „doppelter Download" im Explorer auftauchen
/// und wäre dort kaum zu finden.
void main() {
  group('Name des Vorschaubilds', () {
    test('ist deterministisch', () async {
      final a = await ThumbnailService.fileNameFor('Photos/Urlaub/IMG_0001.HEIC');
      final b = await ThumbnailService.fileNameFor('Photos/Urlaub/IMG_0001.HEIC');
      expect(a, b);
    });

    test('ist 32 Hex-Zeichen plus Endung — pfadsicher', () async {
      final name =
          await ThumbnailService.fileNameFor('Photos/Sonder zeichen/äöü (1).JPG');
      expect(name, hasLength(36));
      expect(name, endsWith('.jpg'));
      expect(RegExp(r'^[0-9a-f]{32}\.jpg$').hasMatch(name), isTrue,
          reason: 'Keine Albumnamen, keine Sonderzeichen im Dateinamen');
    });

    test('normiert Trenner und führende Slashes', () async {
      final plain = await ThumbnailService.fileNameFor('Photos/A.jpg');
      final leading = await ThumbnailService.fileNameFor('/Photos/A.jpg');
      final windows = await ThumbnailService.fileNameFor('Photos\\A.jpg');
      expect(plain, leading);
      expect(plain, windows,
          reason: 'Windows-Pfade und Cloud-Pfade sind dieselbe Aufnahme');
    });

    test('verschiedene Aufnahmen bekommen verschiedene Namen', () async {
      final a = await ThumbnailService.fileNameFor('Photos/A.jpg');
      final b = await ThumbnailService.fileNameFor('Photos/B.jpg');
      expect(a, isNot(b));
    });

    test('liegt unter .fibu/thumbs/', () async {
      final path = await ThumbnailService.cloudPath('Photos/A.jpg');
      expect(path, startsWith('${ThumbnailService.cloudFolder}/'));
      expect(ThumbnailService.cloudFolder, '.fibu/thumbs');
    });
  });

  group('Auflösung: lokal vor Cloud', () {
    test('eine lokale Aufnahme gewinnt immer', () {
      expect(
        ThumbnailService.resolveSource(
            existsLocally: true, hasCloudThumb: true),
        ThumbSource.local,
        reason: 'Was auf dem Gerät liegt, wird nicht aus der Cloud geholt',
      );
      expect(
        ThumbnailService.resolveSource(
            existsLocally: true, hasCloudThumb: false),
        ThumbSource.local,
      );
    });

    test('ohne lokale Aufnahme kommt die Cloud', () {
      expect(
        ThumbnailService.resolveSource(
            existsLocally: false, hasCloudThumb: true),
        ThumbSource.cloud,
      );
    });

    test('ohne beide bleibt die Dateikachel', () {
      expect(
        ThumbnailService.resolveSource(
            existsLocally: false, hasCloudThumb: false),
        ThumbSource.none,
      );
    });
  });

  group('Nachzieh-Liste', () {
    Future<Set<String>> namesOf(List<String> rels) async =>
        {for (final r in rels) await ThumbnailService.fileNameFor(r)};

    test('was schon in der Cloud liegt, fehlt nicht', () async {
      final list = await ThumbnailService.backfillList(
        rels: const ['Photos/A.jpg', 'Photos/B.jpg'],
        cloudFileNames: await namesOf(const ['Photos/A.jpg']),
        existsLocally: (_) => false,
      );
      expect(list.map((e) => e.rel), ['Photos/B.jpg']);
    });

    test('lokale Aufnahmen kommen vor den Cloud-only-Aufnahmen', () async {
      final list = await ThumbnailService.backfillList(
        rels: const [
          'Photos/nur-cloud-1.jpg',
          'Photos/lokal.jpg',
          'Photos/nur-cloud-2.jpg',
        ],
        cloudFileNames: const {},
        existsLocally: (rel) => rel == 'Photos/lokal.jpg',
      );
      expect(list.map((e) => e.rel).toList(), [
        'Photos/lokal.jpg',
        'Photos/nur-cloud-1.jpg',
        'Photos/nur-cloud-2.jpg',
      ]);
      expect(list.first.fromLocalFile, isTrue,
          reason: 'Der billige Weg zuerst: aus der lokalen Datei erzeugen');
      expect(list[1].fromLocalFile, isFalse);
    });

    test('ist leer, wenn alles schon da ist', () async {
      const rels = ['Photos/A.jpg', 'Photos/B.jpg'];
      final list = await ThumbnailService.backfillList(
        rels: rels,
        cloudFileNames: await namesOf(rels),
        existsLocally: (_) => true,
      );
      expect(list, isEmpty);
    });

    test('verwaiste Vorschaubilder werden erkannt', () async {
      final orphans = await ThumbnailService.orphanCloudThumbs(
        rels: const ['Photos/A.jpg'],
        cloudFileNames: await namesOf(
            const ['Photos/A.jpg', 'Photos/geloescht.jpg']),
      );
      expect(orphans, [await ThumbnailService.fileNameFor('Photos/geloescht.jpg')]);
    });
  });

  group('Cache', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('fibu_thumbs_test_');
    });
    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('schreibt und liest', () async {
      final cache = ThumbnailCache(dir);
      expect(await cache.read('Photos/A.jpg'), isNull);

      await cache.write('Photos/A.jpg', const [1, 2, 3, 4]);
      expect(await cache.read('Photos/A.jpg'), const [1, 2, 3, 4]);
      expect(await cache.totalBytes(), 4);
    });

    test('derselbe Pfad landet in derselben Datei', () async {
      final cache = ThumbnailCache(dir);
      await cache.write('Photos/A.jpg', const [1, 2, 3]);
      await cache.write('/Photos/A.jpg', const [9, 9]);
      expect(await cache.totalBytes(), 2,
          reason: 'Normierte Pfade sind dieselbe Aufnahme');
    });

    test('unter der Grenze wird nichts gelöscht', () async {
      final cache = ThumbnailCache(dir, maxBytes: 1000);
      await cache.write('Photos/A.jpg', List.filled(100, 7));
      expect(await cache.prune(), 0);
      expect(await cache.read('Photos/A.jpg'), isNotNull);
    });

    test('über der Grenze fliegt das älteste Drittel raus', () async {
      final cache = ThumbnailCache(dir, maxBytes: 100);
      final base = DateTime.utc(2026, 1, 1);
      for (var i = 0; i < 9; i++) {
        final rel = 'Photos/IMG_000$i.jpg';
        await cache.write(rel, List.filled(20, i));
        // Älteste Änderung zuerst: Die ersten drei müssen gehen.
        await (await cache.fileFor(rel))
            .setLastModified(base.add(Duration(minutes: i)));
      }
      expect(await cache.totalBytes(), 180);

      final removed = await cache.prune();
      expect(removed, greaterThanOrEqualTo(3),
          reason: 'Mindestens ein Drittel, eher mehr: ein Durchlauf reicht '
              'von 180 auf 100 Bytes nicht');
      expect(await cache.read('Photos/IMG_0000.jpg'), isNull,
          reason: 'Die älteste Aufnahme geht zuerst');
      expect(await cache.read('Photos/IMG_0001.jpg'), isNull);
      expect(await cache.read('Photos/IMG_0008.jpg'), isNotNull,
          reason: 'Die neueste Aufnahme bleibt');
      expect(await cache.totalBytes(), lessThanOrEqualTo(100));
    });
  });

  group('Warteschlange', () {
    test('läuft höchstens vier gleichzeitig', () async {
      final queue = ThumbnailQueue(maxConcurrent: 4);
      var running = 0;
      var peak = 0;
      final futures = <Future<int>>[];
      for (var i = 0; i < 12; i++) {
        futures.add(queue.run('k$i', () async {
          running++;
          if (running > peak) peak = running;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          running--;
          return i;
        }));
      }
      expect(await Future.wait(futures), List.generate(12, (i) => i));
      expect(peak, lessThanOrEqualTo(4));
      expect(peak, greaterThan(1),
          reason: 'Die Warteschlange soll parallel arbeiten');
    });

    test('derselbe Schlüssel lädt nicht zweimal', () async {
      final queue = ThumbnailQueue();
      var calls = 0;
      Future<String> task() async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return 'fertig';
      }

      final first = queue.run('dieselbe', task);
      final second = queue.run('dieselbe', task);
      expect(identical(first, second), isTrue,
          reason: 'Schnelles Scrollen darf keinen Doppel-Download auslösen');
      expect(await first, 'fertig');
      expect(await second, 'fertig');
      expect(calls, 1);
    });

    test('nach einem Fehler ist der Schlüssel wieder frei', () async {
      final queue = ThumbnailQueue(maxConcurrent: 1);
      await expectLater(
        queue.run<void>('kaputt', () async => throw StateError('Netz weg')),
        throwsStateError,
      );
      expect(await queue.run<int>('danach', () async => 42), 42,
          reason: 'Ein Fehler darf die Warteschlange nicht blockieren');
    });
  });
}

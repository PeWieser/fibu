import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:fibu/core/services/thumbnail_creator.dart';
import 'package:fibu/core/services/thumbnail_service.dart';

/// Phase 5b: Vorschaubilder erzeugen.
///
/// Geprüft wird, was ohne Gerät prüfbar ist — Dekodieren, Verkleinern,
/// Kodieren, und dass nichts wirft. Die Quelle `photo_manager` (iOS/Android)
/// braucht ein Gerät und ist deshalb nicht dabei.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Eine einfarbige Aufnahme als PNG — der Test braucht keine Beispieldatei.
  Uint8List sourceImage({int width = 640, int height = 480}) {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(200, 30, 30));
    return img.encodePng(image);
  }

  group('Aus Bytes', () {
    test('verkleinert auf die Kantenlänge und erhält das Verhältnis', () async {
      final thumb = await ThumbnailCreator.fromBytes(sourceImage());
      expect(thumb, isNotNull);

      final decoded = img.decodeImage(thumb!);
      expect(decoded, isNotNull);
      expect(decoded!.width, ThumbnailService.edge);
      expect(decoded.height, 192, reason: '640×480 → 256×192');
    });

    test('kodiert JPEG und wird kleiner als die Aufnahme', () async {
      final png = sourceImage();
      final thumb = await ThumbnailCreator.fromBytes(png);
      expect(thumb, isNotNull);
      expect(thumb!.lengthInBytes, lessThan(png.lengthInBytes));
      // JPEG-Magie: FF D8
      expect(thumb[0], 0xFF);
      expect(thumb[1], 0xD8);
    });

    test('kleinere Bilder werden nicht hochskaliert', () async {
      final thumb =
          await ThumbnailCreator.fromBytes(sourceImage(width: 100, height: 80));
      expect(thumb, isNotNull);
      final decoded = img.decodeImage(thumb!);
      expect(decoded!.width, 100);
      expect(decoded.height, 80);
    });

    test('Müll liefert null statt zu werfen', () async {
      expect(
        await ThumbnailCreator.fromBytes(Uint8List.fromList([1, 2, 3, 4, 5])),
        isNull,
        reason: 'Ein Vorschaubild ist niemals ein Grund für einen Fehler',
      );
      expect(await ThumbnailCreator.fromBytes(Uint8List(0)), isNull);
    });
  });

  group('Aus Datei', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('fibu_creator_test_');
    });
    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('liest eine vorhandene Datei', () async {
      final file = File('${dir.path}/aufnahme.jpg');
      await file.writeAsBytes(sourceImage(width: 800, height: 600));

      final thumb = await ThumbnailCreator.fromFile(file);
      expect(thumb, isNotNull);
      expect(img.decodeImage(thumb!)!.width, ThumbnailService.edge);
    });

    test('eine fehlende Datei liefert null', () async {
      final missing = File('${dir.path}/gibt-es-nicht.jpg');
      expect(await ThumbnailCreator.fromFile(missing), isNull);
    });
  });
}

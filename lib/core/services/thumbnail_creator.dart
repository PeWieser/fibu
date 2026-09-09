import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:photo_manager/photo_manager.dart';

import 'thumbnail_service.dart';

/// Erzeugt Vorschaubilder: [ThumbnailService.edge] px lange Kante, JPEG in
/// [ThumbnailService.quality].
///
/// **Drei Quellen, eine Regel** (siehe `docs/PHASE5_FOTOS_NIVEAU.md` §2.1):
/// Was lokal liegt, wird lokal genommen — [fromAsset] für Aufnahmen aus der
/// Mediathek, [fromFile] für Dateien auf der Platte. Aus der Cloud kommt nur,
/// was es lokal nicht gibt.
///
/// **Niemals ein Grund für einen Fehler.** Jede Methode liefert `null` statt
/// zu werfen: Ein fehlendes Vorschaubild bedeutet eine Dateikachel, nicht
/// einen abgebrochenen Sync und keinen Dialog.
class ThumbnailCreator {
  const ThumbnailCreator._();

  /// Aus einer Aufnahme der Mediathek (iOS/Android).
  ///
  /// Läuft nativ über `photo_manager` und versteht damit auch HEIC — der
  /// Decoder von `dart:ui` und das `image`-Paket können das nicht.
  static Future<Uint8List?> fromAsset(String assetId) async {
    try {
      final asset = await AssetEntity.fromId(assetId);
      if (asset == null) return null;
      return await asset.thumbnailDataWithSize(
        const ThumbnailSize(ThumbnailService.edge, ThumbnailService.edge),
        quality: ThumbnailService.quality,
      );
    } catch (_) {
      return null;
    }
  }

  /// Aus einer lokalen Datei — der Weg auf Windows und beim Nachziehen.
  static Future<Uint8List?> fromFile(File file) async {
    try {
      if (!await file.exists()) return null;
      // `await` statt nacktem return: Ohne ihn würde ein Fehler aus
      // fromBytes am try/catch vorbeilaufen (unawaited_return_in_try_block).
      return await fromBytes(await file.readAsBytes());
    } catch (_) {
      return null;
    }
  }

  /// Aus Bytes.
  ///
  /// Dekodieren und Kodieren laufen in einem eigenen Isolat: Eine
  /// 12-Megapixel-Aufnahme zu verkleinern kostet sonst 100–300 ms auf dem
  /// UI-Thread, und beim Scrollen durch ein Raster passiert das dauernd.
  static Future<Uint8List?> fromBytes(Uint8List bytes) async {
    if (bytes.isEmpty) return null;
    try {
      return await compute(decodeAndEncode, bytes);
    } catch (_) {
      return null;
    }
  }

  /// Verkleinert auf die Kantenlänge und kodiert als JPEG.
  ///
  /// Top-Level statt privater Methode, damit [compute] es in ein Isolat
  /// schicken kann.
  static Uint8List? decodeAndEncode(Uint8List bytes) {
    try {
      final source = img.decodeImage(bytes);
      if (source == null) return null;
      return encode(source);
    } catch (_) {
      return null;
    }
  }

  /// Verkleinert seitenrichtig und kodiert JPEG. Bilder, die schon kleiner
  /// sind als die Kantenlänge, werden nicht hochskaliert.
  static Uint8List? encode(img.Image source) {
    try {
      final longest =
          source.width > source.height ? source.width : source.height;
      if (longest <= 0) return null;

      final img.Image resized;
      if (longest > ThumbnailService.edge) {
        final scale = ThumbnailService.edge / longest;
        resized = img.copyResize(
          source,
          width: (source.width * scale).round().clamp(1, ThumbnailService.edge),
          height:
              (source.height * scale).round().clamp(1, ThumbnailService.edge),
        );
      } else {
        resized = source;
      }
      return img.encodeJpg(resized, quality: ThumbnailService.quality);
    } catch (_) {
      return null;
    }
  }
}

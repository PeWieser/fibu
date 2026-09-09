import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/app_log_service.dart';
import '../../../../core/services/rclone_provider.dart';
import '../../../../core/services/thumbnail_pipeline.dart';
import '../../../../core/services/thumbnail_service.dart';
import '../../../../core/utils/app_paths.dart';

/// Vorschaubild einer gesicherten Aufnahme — **lokal vor Cloud**.
///
/// Reihenfolge (`docs/PHASE5_FOTOS_NIVEAU.md` §2.1):
///  1. liegt die Aufnahme auf dem Gerät → Vorschaubild daraus, kein Netz
///  2. Cache
///  3. `.fibu/thumbs/` in der Cloud
///  4. [fallback] — die Dateikachel
///
/// Lädt höchstens [ThumbnailQueue.maxConcurrent] gleichzeitig und bricht ab,
/// wenn die Kachel nicht mehr im Baum ist.
class ThumbImage extends ConsumerStatefulWidget {
  const ThumbImage({
    super.key,
    required this.remote,
    required this.cloudPath,
    required this.rel,
    required this.assetIds,
    required this.fallback,
  });

  final String remote;

  /// Voller Pfad in der Cloud — für die Vollbild-Ansicht und als Schlüssel.
  final String cloudPath;

  /// Spiegel-Pfad (`Photos/<Album>/<Datei>`) — daraus wird der Name des
  /// Vorschaubilds, und er ist der Schlüssel in `mirror_state.json`.
  final String rel;

  /// rel → Asset-ID, einmal pro Bildschirm geladen.
  final Map<String, String> assetIds;

  final Widget fallback;

  @override
  ConsumerState<ThumbImage> createState() => _ThumbImageState();
}

class _ThumbImageState extends ConsumerState<ThumbImage> {
  /// Global geteilt: Die Begrenzung gilt für den ganzen Bildschirm, nicht
  /// pro Kachel.
  static final ThumbnailQueue _queue = ThumbnailQueue();

  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      final support = await appSupportRoot();
      final cache = ThumbnailCache(Directory('${support.path}/thumb_cache'));

      final bytes = await _queue.run<Uint8List?>(widget.cloudPath, () async {
        // 1) Lokale Aufnahme — kein Netz, funktioniert offline.
        final assetId = widget.assetIds[widget.rel];
        if (assetId != null && assetId.isNotEmpty) {
          final local = await LocalMediaResolver.create(assetId: assetId);
          if (local != null) {
            try {
              await cache.write(widget.rel, local);
            } catch (_) {}
            return local;
          }
        }

        // 2) Cache
        final cached = await cache.read(widget.rel);
        if (cached != null) return cached;

        // 3) Cloud
        final tmp = File('${support.path}/thumb_download_${widget.rel.hashCode}.jpg');
        try {
          await ref.read(rcloneServiceProvider).downloadFile(
              widget.remote, await ThumbnailService.cloudPath(widget.rel), tmp.path);
          final downloaded = await cache.read(widget.rel);
          if (downloaded != null) return downloaded;
          final bytes = await tmp.readAsBytes();
          try {
            await cache.write(widget.rel, bytes);
          } catch (_) {}
          return bytes;
        } finally {
          try {
            if (await tmp.exists()) await tmp.delete();
          } catch (_) {}
        }
      });

      if (!mounted || bytes == null) return;
      setState(() => _bytes = bytes);
    } catch (e) {
      AppLog.warn('thumbs', 'Vorschaubild für „${widget.rel}" nicht geladen: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) return widget.fallback;
    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      // Kein Semantik-Label: Die Kachel ist als Ganzes beschriftet.
      excludeFromSemantics: true,
      errorBuilder: (_, __, ___) => widget.fallback,
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/services/app_log_service.dart';
import '../../../core/services/file_viewer_service.dart';
import '../../../core/services/rclone_provider.dart';
import '../../../core/utils/app_paths.dart';
import '../../../core/utils/format.dart';
import '../../../theme/theme.dart';

/// Eine Aufnahme für die Vollbild-Ansicht.
class ViewerPhoto {
  final String name;
  final String cloudPath;
  final String rel;
  final int size;
  final DateTime? modified;

  const ViewerPhoto({
    required this.name,
    required this.cloudPath,
    required this.rel,
    required this.size,
    this.modified,
  });
}

/// Vollbild-Ansicht einer gesicherten Aufnahme.
///
/// **Lokal vor Cloud** (`docs/PHASE5_FOTOS_NIVEAU.md` §2.1): Liegt die
/// Aufnahme noch auf dem Gerät, wird sie direkt angezeigt — kein Download,
/// funktioniert offline. Nur was es allein in der Cloud gibt, wird geholt.
///
/// Blättern per Wischen, auf Windows zusätzlich mit den Pfeiltasten; Esc
/// schließt. Zoomen mit zwei Fingern oder Doppelklick.
class CloudPhotoViewer extends ConsumerStatefulWidget {
  const CloudPhotoViewer({
    super.key,
    required this.remote,
    required this.photos,
    required this.initialIndex,
    required this.assetIds,
  });

  final String remote;
  final List<ViewerPhoto> photos;
  final int initialIndex;

  /// rel → Asset-ID bzw. absoluter Pfad (Windows).
  final Map<String, String> assetIds;

  @override
  ConsumerState<CloudPhotoViewer> createState() => _CloudPhotoViewerState();
}

class _CloudPhotoViewerState extends ConsumerState<CloudPhotoViewer> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex.clamp(0, widget.photos.length - 1));

  late int _index = widget.initialIndex.clamp(0, widget.photos.length - 1);

  /// cloudPath → lokale Datei oder Fehlergrund.
  final Map<String, File?> _loaded = {};
  final Map<String, bool> _loading = {};
  final Map<String, String> _failed = {};

  @override
  void initState() {
    super.initState();
    _load(widget.photos[_index]);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index + 1 >= widget.photos.length) return;
    _controller.nextPage(
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  void _previous() {
    if (_index == 0) return;
    _controller.previousPage(
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  Future<void> _load(ViewerPhoto photo) async {
    if (_loaded.containsKey(photo.cloudPath) ||
        _failed.containsKey(photo.cloudPath) ||
        (_loading[photo.cloudPath] ?? false)) {
      return;
    }
    setState(() => _loading[photo.cloudPath] = true);
    try {
      final file = await _localOriginal(photo.rel);
      if (file != null) {
        if (mounted) setState(() => _loaded[photo.cloudPath] = file);
        return;
      }
      final support = await appSupportRoot();
      final dir = Directory('${support.path}/viewer');
      if (!await dir.exists()) await dir.create(recursive: true);
      final target = File('${dir.path}/${photo.cloudPath.hashCode}_${photo.name}');
      await ref.read(rcloneServiceProvider).downloadFile(
          widget.remote, photo.cloudPath, target.path);
      if (mounted) setState(() => _loaded[photo.cloudPath] = target);
    } catch (e) {
      AppLog.warn('viewer', '„${photo.name}" nicht geladen: $e');
      if (mounted) {
        setState(() => _failed[photo.cloudPath] = '$e');
      }
    } finally {
      if (mounted) setState(() => _loading[photo.cloudPath] = false);
    }
  }

  /// Lokale Originaldatei, wenn es sie gibt.
  ///
  /// Auf Windows ist die `assetId` der absolute Pfad der Quelldatei, auf
  /// iOS/Android eine `photo_manager`-ID.
  Future<File?> _localOriginal(String rel) async {
    final id = widget.assetIds[rel];
    if (id == null || id.isEmpty) return null;
    try {
      final asFile = File(id);
      if (await asFile.exists()) return asFile;
    } catch (_) {}
    try {
      final asset = await AssetEntity.fromId(id);
      return await asset?.file;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openInDefaultApp(ViewerPhoto photo) async {
    await ref.read(fileViewerServiceProvider).openInDefaultApp(
          remoteName: widget.remote,
          remotePath: photo.cloudPath,
          fileName: photo.name,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final strings = ref.watch(stringsProvider);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.arrowRight): _next,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _previous,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        },
      },
      child: Focus(
        autofocus: true,
        child: material.Scaffold(
          backgroundColor: const Color(0xFF101010),
          appBar: material.AppBar(
            backgroundColor: const Color(0xFF101010),
            foregroundColor: const Color(0xFFEDEDED),
            title: Text(
              widget.photos.isEmpty ? '' : widget.photos[_index].name,
              style: const TextStyle(fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              material.TextButton(
                onPressed: widget.photos.isEmpty
                    ? null
                    : () => _openInDefaultApp(widget.photos[_index]),
                child: Text(
                  strings.openInDefaultApp,
                  style: const TextStyle(color: Color(0xFFEDEDED), fontSize: 13),
                ),
              ),
            ],
          ),
          body: widget.photos.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: widget.photos.length,
                        onPageChanged: (i) {
                          setState(() => _index = i);
                          _load(widget.photos[i]);
                          // Nachbarn vorladen, damit Blättern nicht wartet.
                          if (i + 1 < widget.photos.length) {
                            _load(widget.photos[i + 1]);
                          }
                        },
                        itemBuilder: (context, i) =>
                            _page(widget.photos[i], theme, strings),
                      ),
                    ),
                    _caption(theme, strings),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _page(ViewerPhoto photo, AppThemeData theme, AppStrings strings) {
    final file = _loaded[photo.cloudPath];
    final failed = _failed[photo.cloudPath];

    if (file == null) {
      return Center(
        child: failed != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      strings.cannotDisplayFormat,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFEDEDED)),
                    ),
                    const SizedBox(height: 16),
                    material.FilledButton(
                      onPressed: () => _openInDefaultApp(photo),
                      child: Text(strings.openInDefaultApp),
                    ),
                  ],
                ),
              )
            : const material.CircularProgressIndicator(color: Color(0xFFEDEDED)),
      );
    }

    return InteractiveViewer(
      maxScale: 5,
      child: Center(
        child: Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  strings.cannotDisplayFormat,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFEDEDED)),
                ),
                const SizedBox(height: 16),
                material.FilledButton(
                  onPressed: () => _openInDefaultApp(photo),
                  child: Text(strings.openInDefaultApp),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _caption(AppThemeData theme, AppStrings strings) {
    if (widget.photos.isEmpty) return const SizedBox.shrink();
    final photo = widget.photos[_index];
    final parts = <String>[
      if (photo.modified != null) strings.formatDateTime(photo.modified!),
      formatBytes(photo.size),
      '${_index + 1} / ${widget.photos.length}',
    ];
    return Container(
      width: double.infinity,
      color: const Color(0xFF101010),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Text(
        parts.join('  ·  '),
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 12),
      ),
    );
  }
}

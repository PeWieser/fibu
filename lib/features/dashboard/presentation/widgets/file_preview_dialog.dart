import 'package:flutter/foundation.dart';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/services/file_viewer_service.dart';
import '../../../../core/utils/ios_haptics.dart';
import '../../../../theme/theme.dart';

import 'file_metadata_helper.dart';

/// Apple Quick Look inspired modal preview dialog for cloud files.
class FilePreviewDialog extends ConsumerStatefulWidget {
  final String fileName;
  final String remoteName;
  final String remotePath;
  final int fileSize;

  const FilePreviewDialog({
    super.key,
    required this.fileName,
    required this.remoteName,
    required this.remotePath,
    required this.fileSize,
  });

  @override
  ConsumerState<FilePreviewDialog> createState() => _FilePreviewDialogState();
}

class _FilePreviewDialogState extends ConsumerState<FilePreviewDialog> {
  final TransformationController _transformController = TransformationController();
  double _zoomScale = 1.0;
  String? _previewText;
  bool _isLoadingContent = false;
  bool _copied = false;

  // Echte (heruntergeladene) Datei für die Bildvorschau.
  File? _localFile;
  bool _isImageLoading = false;
  String? _imageError;

  @override
  void initState() {
    super.initState();
    _loadContentIfNeeded();
  }

  Future<void> _loadContentIfNeeded() async {
    final cat = FileMetadataHelper.getCategory(widget.fileName);
    if (cat == FileCategory.textCode) {
      setState(() => _isLoadingContent = true);
      final text = await ref.read(fileViewerServiceProvider).getPreviewText(
        remoteName: widget.remoteName,
        fileName: widget.fileName,
        remotePath: widget.remotePath,
      );
      if (mounted) {
        setState(() {
          _previewText = text;
          _isLoadingContent = false;
        });
      }
    } else if (cat == FileCategory.image) {
      // Die echte Bilddatei aus der Cloud laden (via rclone downloadToCache)
      // statt erfundene Metadaten anzuzeigen.
      setState(() => _isImageLoading = true);
      try {
        final file = await ref.read(fileViewerServiceProvider).getLocalFile(
          remoteName: widget.remoteName,
          remotePath: widget.remotePath,
        );
        if (mounted) {
          setState(() {
            _localFile = file;
            _imageError = file == null ? _errorLoadingFile() : null;
            _isImageLoading = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _imageError = _errorLoadingFile();
            _isImageLoading = false;
          });
        }
      }
    }
  }

  String _errorLoadingFile() => 'Datei konnte nicht geladen werden.';

  void _zoomIn() {
    setState(() {
      _zoomScale = (_zoomScale + 0.25).clamp(0.5, 4.0);
      _transformController.value = Matrix4.diagonal3Values(_zoomScale, _zoomScale, 1.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomScale = (_zoomScale - 0.25).clamp(0.5, 4.0);
      _transformController.value = Matrix4.diagonal3Values(_zoomScale, _zoomScale, 1.0);
    });
  }

  void _resetZoom() {
    setState(() {
      _zoomScale = 1.0;
      _transformController.value = Matrix4.identity();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final strings = context.strings;
    final cat = FileMetadataHelper.getCategory(widget.fileName);
    final ext = FileMetadataHelper.getExtension(widget.fileName).toUpperCase();

    // iOS: nativ, vollflächig und responsiv (SafeArea + scrollbar).
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _buildIOS(context, theme, strings, cat, ext);
    }

    // Desktop (Windows) / Android: bestehende Dialog-Box.
    return Center(
      child: material.Material(
        color: material.Colors.transparent,
        child: Container(
          width: 720,
          height: 600,
          margin: EdgeInsets.all(theme.lg),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(theme.radiusLg),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 32,
                offset: Offset(0, 12),
              ),
            ],
            border: Border.all(
              color: theme.textSecondary.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Toolbar
              _buildHeader(theme, strings, ext),
              const material.Divider(height: 1),

              // Preview Body
              Expanded(
                child: _buildBody(theme, strings, cat),
              ),

              const material.Divider(height: 1),
              // Footer Action Bar
              _buildFooter(theme, strings),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // IOS: native, full-screen, responsive Quick-Look-style preview
  // =========================================================================
  Widget _buildIOS(
    BuildContext context,
    AppThemeData theme,
    AppStrings strings,
    FileCategory cat,
    String ext,
  ) {
    return cupertino.CupertinoPageScaffold(
      backgroundColor: theme.canvas,
      navigationBar: cupertino.CupertinoNavigationBar(
        middle: Text(widget.fileName, overflow: TextOverflow.ellipsis),
        leading: SizedBox(
          width: 60,
          height: 44,
          child: cupertino.CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pop(context),
            child: const Icon(cupertino.CupertinoIcons.xmark),
          ),
        ),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: theme.sm, vertical: theme.xs / 2),
          decoration: BoxDecoration(
            color: theme.accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(theme.radiusSm),
          ),
          child: Text(
            ext.isEmpty ? 'FILE' : ext,
            style: TextStyle(color: theme.accent, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Body (Bild / Text / generische Karte)
            SliverToBoxAdapter(child: _buildIOSBody(context, theme, strings, cat)),
            // Footer-Aktionen
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(theme.lg, theme.lg, theme.lg, theme.xl),
                child: _buildIOSActions(theme, strings),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIOSBody(
    BuildContext context,
    AppThemeData theme,
    AppStrings strings,
    FileCategory cat,
  ) {
    switch (cat) {
      case FileCategory.image:
        return _buildIOSImagePreview(theme, strings);
      case FileCategory.textCode:
        return _buildIOSTextPreview(theme, strings);
      case FileCategory.audio:
      case FileCategory.video:
      case FileCategory.document:
      case FileCategory.archive:
      case FileCategory.binary:
        return _buildIOSGenericPreview(theme, strings, cat);
    }
  }

  Widget _buildIOSImagePreview(AppThemeData theme, AppStrings strings) {
    return Padding(
      padding: EdgeInsets.all(theme.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bildfläche (responsiv, eigenständig scrollbar nicht nötig da CustomScrollView)
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(theme.radiusLg),
              child: Container(
                color: theme.surface,
                child: _isImageLoading
                    ? const Center(child: cupertino.CupertinoActivityIndicator())
                    : (_imageError != null || _localFile == null)
                        ? _buildIOSImageMessage(theme, strings, _imageError ?? _errorLoadingFile())
                        : InteractiveViewer(
                            transformationController: _transformController,
                            minScale: 0.5,
                            maxScale: 4.0,
                            child: Center(
                              child: Image.file(
                                _localFile!,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    _buildIOSImageMessage(theme, strings, 'Bild konnte nicht angezeigt werden.'),
                              ),
                            ),
                          ),
              ),
            ),
          ),
          SizedBox(height: theme.md),
          // Zoom-Steuerung
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _iosZoomButton(theme, strings.zoomOut, cupertino.CupertinoIcons.minus, _zoomOut),
              SizedBox(width: theme.sm),
              Text(
                '${(_zoomScale * 100).toInt()}%',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.textPrimary),
              ),
              SizedBox(width: theme.sm),
              _iosZoomButton(theme, strings.zoomIn, cupertino.CupertinoIcons.plus, _zoomIn),
              SizedBox(width: theme.sm),
              _iosZoomButton(theme, strings.resetZoom, cupertino.CupertinoIcons.refresh, _resetZoom),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iosZoomButton(AppThemeData theme, String label, IconData icon, VoidCallback onPressed) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: cupertino.CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            IosHaptics.light();
            onPressed();
          },
          child: Icon(icon, size: 20, color: theme.accent, semanticLabel: label),
        ),
      ),
    );
  }

  Widget _buildIOSImageMessage(AppThemeData theme, AppStrings strings, String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(theme.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(cupertino.CupertinoIcons.photo, size: 48, color: theme.textSecondary.withValues(alpha: 0.6)),
            SizedBox(height: theme.md),
            Text(
              widget.fileName,
              style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: theme.xs),
            Text(
              message,
              style: TextStyle(color: theme.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: theme.lg),
            _iosPrimaryButton(
              theme: theme,
              label: strings.openInDefaultApp,
              icon: cupertino.CupertinoIcons.arrow_up_right_square,
              onPressed: () => _openInDefaultApp(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIOSTextPreview(AppThemeData theme, AppStrings strings) {
    if (_isLoadingContent) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: cupertino.CupertinoActivityIndicator()),
      );
    }
    final content = _previewText ?? '';
    final lines = content.split('\n');
    return Container(
      margin: EdgeInsets.all(theme.lg),
      padding: EdgeInsets.all(theme.md),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(theme.radiusLg),
        border: Border.all(color: cupertino.CupertinoColors.separator, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${lines.length} ${strings.linesLabel} • ${content.length} ${strings.charactersLabel}',
                  style: TextStyle(fontSize: 12, color: theme.textSecondary),
                ),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  child: cupertino.CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () async {
                      await ref.read(fileViewerServiceProvider).copyToClipboard(content);
                      if (mounted) {
                        setState(() => _copied = true);
                        Future.delayed(const Duration(seconds: 2), () {
                          if (mounted) setState(() => _copied = false);
                        });
                      }
                    },
                    child: Icon(
                      _copied ? cupertino.CupertinoIcons.check_mark : cupertino.CupertinoIcons.doc_on_doc,
                      size: 20,
                      color: _copied ? theme.success : theme.textSecondary,
                      semanticLabel: strings.copy,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: theme.xs),
          Container(height: 1, color: cupertino.CupertinoColors.separator),
          SizedBox(height: theme.xs),
          // Monospace-Ansicht (scrollbar im äußeren CustomScrollView)
          material.SelectableText(
            content,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: theme.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIOSGenericPreview(AppThemeData theme, AppStrings strings, FileCategory cat) {
    return Container(
      margin: EdgeInsets.all(theme.lg),
      padding: EdgeInsets.all(theme.xl),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(theme.radiusLg),
        border: Border.all(color: cupertino.CupertinoColors.separator, width: 0.5),
      ),
      child: Column(
        children: [
          Icon(_getIOSCategoryIcon(widget.fileName), size: 56, color: theme.accent),
          SizedBox(height: theme.md),
          Text(
            widget.fileName,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimary),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: theme.xs),
          Text(
            FileMetadataHelper.getFormatLabel(widget.fileName),
            style: TextStyle(color: theme.accent, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          SizedBox(height: theme.sm),
          Text(
            '${FileMetadataHelper.getMimeType(widget.fileName)} • ${FileMetadataHelper.formatExactBytes(widget.fileSize)}',
            style: TextStyle(color: theme.textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildIOSActions(AppThemeData theme, AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _iosPrimaryButton(
          theme: theme,
          label: strings.openInDefaultApp,
          icon: cupertino.CupertinoIcons.arrow_up_right_square,
          onPressed: () => _openInDefaultApp(),
        ),
        SizedBox(height: theme.sm),
        cupertino.CupertinoButton(
          padding: EdgeInsets.symmetric(vertical: theme.md),
          color: theme.surface,
          borderRadius: BorderRadius.circular(theme.radiusSm),
          onPressed: () async {
            IosHaptics.light();
            await ref.read(fileViewerServiceProvider).copyToClipboard('/${widget.remotePath}');
            if (mounted) {
              setState(() => _copied = true);
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) setState(() => _copied = false);
              });
            }
          },
          child: Text(
            _copied ? strings.pathCopied : strings.copyPath,
            style: TextStyle(
              color: _copied ? theme.success : theme.accent,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }

  Widget _iosPrimaryButton({
    required AppThemeData theme,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: cupertino.CupertinoButton(
        color: theme.accent,
        padding: const EdgeInsets.symmetric(vertical: 12),
        borderRadius: BorderRadius.circular(theme.radiusSm),
        onPressed: () {
          IosHaptics.medium();
          onPressed();
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: cupertino.CupertinoColors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: cupertino.CupertinoColors.white, fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openInDefaultApp() async {
    if (!mounted) return;
    Navigator.pop(context);
    await ref.read(fileViewerServiceProvider).openInDefaultApp(
      remoteName: widget.remoteName,
      remotePath: widget.remotePath,
      fileName: widget.fileName,
    );
  }

  IconData _getIOSCategoryIcon(String fileName) {
    final cat = FileMetadataHelper.getCategory(fileName);
    switch (cat) {
      case FileCategory.image:
        return cupertino.CupertinoIcons.photo;
      case FileCategory.video:
        return cupertino.CupertinoIcons.video_camera;
      case FileCategory.audio:
        return cupertino.CupertinoIcons.music_note;
      case FileCategory.textCode:
        return cupertino.CupertinoIcons.doc_text;
      case FileCategory.document:
        return cupertino.CupertinoIcons.doc;
      case FileCategory.archive:
        return cupertino.CupertinoIcons.archivebox;
      case FileCategory.binary:
        return cupertino.CupertinoIcons.doc;
    }
  }

  Widget _buildHeader(AppThemeData theme, AppStrings strings, String ext) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: theme.lg, vertical: theme.md),
      child: Row(
        children: [
          Icon(
            _getCategoryIcon(widget.fileName),
            size: 24,
            color: theme.accent,
            semanticLabel: widget.fileName,
          ),
          SizedBox(width: theme.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.fileName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: theme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${widget.remoteName}: /${widget.remotePath}',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: theme.sm, vertical: theme.xs),
            decoration: BoxDecoration(
              color: theme.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(theme.radiusSm),
            ),
            child: Text(
              ext.isEmpty ? 'FILE' : ext,
              style: TextStyle(
                color: theme.accent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: theme.md),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              child: fluent.IconButton(
                icon: Icon(fluent.FluentIcons.chrome_close, size: 14, color: theme.textSecondary, semanticLabel: strings.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppThemeData theme, AppStrings strings, FileCategory cat) {
    switch (cat) {
      case FileCategory.image:
        return _buildImagePreview(theme, strings);
      case FileCategory.textCode:
        return _buildTextPreview(theme, strings);
      case FileCategory.audio:
      case FileCategory.video:
      case FileCategory.document:
      case FileCategory.archive:
      case FileCategory.binary:
        // Audio/Video/Dokumente/Archive/Binärdaten öffnen die echte Datei
        // (Download + System-Viewer/Quick Look) statt Fake-Metadaten zu zeigen.
        return _buildGenericCardPreview(theme, strings, cat);
    }
  }

  Widget _buildImagePreview(AppThemeData theme, AppStrings strings) {
    return Stack(
      children: [
        Center(
          child: _isImageLoading
              ? const Center(child: fluent.ProgressRing(strokeWidth: 2))
              : (_imageError != null || _localFile == null)
                  ? _buildImageMessage(theme, strings, _imageError ?? _errorLoadingFile())
                  : InteractiveViewer(
                      transformationController: _transformController,
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Container(
                        padding: EdgeInsets.all(theme.lg),
                        alignment: Alignment.center,
                        child: Image.file(
                          _localFile!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              _buildImageMessage(theme, strings, 'Bild konnte nicht angezeigt werden.'),
                        ),
                      ),
                    ),
        ),
        // Zoom controls overlay
        Positioned(
          bottom: theme.md,
          right: theme.md,
          child: Container(
            padding: EdgeInsets.all(theme.xs),
            decoration: BoxDecoration(
              color: theme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(theme.radiusSm),
              border: Border.all(color: theme.textSecondary.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                fluent.Tooltip(
                  message: strings.zoomOut,
                  child: fluent.IconButton(
                    icon: Icon(material.Icons.zoom_out, size: 16, color: theme.textPrimary, semanticLabel: strings.zoomOut),
                    onPressed: _zoomOut,
                  ),
                ),
                SizedBox(width: theme.xs),
                Text('${(_zoomScale * 100).toInt()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                SizedBox(width: theme.xs),
                fluent.Tooltip(
                  message: strings.zoomIn,
                  child: fluent.IconButton(
                    icon: Icon(material.Icons.zoom_in, size: 16, color: theme.textPrimary, semanticLabel: strings.zoomIn),
                    onPressed: _zoomIn,
                  ),
                ),
                SizedBox(width: theme.xs),
                fluent.Tooltip(
                  message: strings.resetZoom,
                  child: fluent.IconButton(
                    icon: Icon(fluent.FluentIcons.refresh, size: 14, color: theme.textPrimary, semanticLabel: strings.resetZoom),
                    onPressed: _resetZoom,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageMessage(AppThemeData theme, AppStrings strings, String message) {
    return Container(
      padding: EdgeInsets.all(theme.lg),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            fluent.FluentIcons.photo_collection,
            size: 64,
            color: theme.textSecondary.withValues(alpha: 0.6),
            semanticLabel: 'Bild',
          ),
          SizedBox(height: theme.md),
          Text(
            widget.fileName,
            style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: theme.xs),
          Text(
            message,
            style: TextStyle(color: theme.textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: theme.xl),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 200, minHeight: 44),
              child: fluent.FilledButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await ref.read(fileViewerServiceProvider).openInDefaultApp(
                    remoteName: widget.remoteName,
                    remotePath: widget.remotePath,
                    fileName: widget.fileName,
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      fluent.FluentIcons.open_in_new_window,
                      size: 16,
                      color: Color(0xFFFFFFFF),
                      semanticLabel: 'Open',
                    ),
                    const SizedBox(width: 8),
                    Text(
                      strings.openInDefaultApp,
                      style: const TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextPreview(AppThemeData theme, AppStrings strings) {
    if (_isLoadingContent) {
      return const Center(child: fluent.ProgressRing(strokeWidth: 2));
    }

    final content = _previewText ?? '';
    final lines = content.split('\n');

    return Container(
      color: theme.canvas,
      child: Column(
        children: [
          // Editor info header
          Container(
            padding: EdgeInsets.symmetric(horizontal: theme.md, vertical: theme.xs),
            color: theme.surface,
            child: Row(
              children: [
                Text(
                  '${lines.length} ${strings.linesLabel} • ${content.length} ${strings.charactersLabel} • UTF-8',
                  style: TextStyle(fontSize: 12, color: theme.textSecondary),
                ),
                const Spacer(),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: fluent.IconButton(
                    icon: Icon(
                      _copied ? fluent.FluentIcons.check_mark : fluent.FluentIcons.copy,
                      size: 14,
                      color: _copied ? theme.success : theme.textSecondary,
                      semanticLabel: strings.copy,
                    ),
                    onPressed: () async {
                      await ref.read(fileViewerServiceProvider).copyToClipboard(content);
                      setState(() => _copied = true);
                      Future.delayed(const Duration(seconds: 2), () {
                        if (mounted) setState(() => _copied = false);
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          const material.Divider(height: 1),
          // Scrollable code view
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(theme.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Line numbers
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(
                      lines.length,
                      (index) => Text(
                        '${index + 1} ',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: theme.textSecondary.withValues(alpha: 0.4),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: theme.sm),
                  Container(width: 1, height: lines.length * 16.8, color: theme.textSecondary.withValues(alpha: 0.15)),
                  SizedBox(width: theme.sm),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: lines.map((line) => Text(
                        line.isEmpty ? ' ' : line,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: theme.textPrimary,
                          height: 1.4,
                        ),
                      )).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenericCardPreview(AppThemeData theme, AppStrings strings, FileCategory cat) {
    return Center(
      child: Container(
        width: 480,
        padding: EdgeInsets.all(theme.xl),
        decoration: BoxDecoration(
          color: theme.canvas,
          borderRadius: BorderRadius.circular(theme.radiusLg),
          border: Border.all(color: theme.textSecondary.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getCategoryIcon(widget.fileName), size: 64, color: theme.accent, semanticLabel: widget.fileName),
            SizedBox(height: theme.md),
            Text(
              widget.fileName,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimary),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: theme.xs),
            Text(
              FileMetadataHelper.getFormatLabel(widget.fileName),
              style: TextStyle(color: theme.accent, fontWeight: FontWeight.w600, fontSize: 13),
            ),
            SizedBox(height: theme.sm),
            Text(
              '${FileMetadataHelper.getMimeType(widget.fileName)} • ${FileMetadataHelper.formatExactBytes(widget.fileSize)}',
              style: TextStyle(color: theme.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: theme.xl),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 200, minHeight: 44),
                child: fluent.FilledButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await ref.read(fileViewerServiceProvider).openInDefaultApp(
                      remoteName: widget.remoteName,
                      remotePath: widget.remotePath,
                      fileName: widget.fileName,
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(fluent.FluentIcons.open_in_new_window, size: 16, color: Color(0xFFFFFFFF), semanticLabel: 'Open'),
                      SizedBox(width: theme.sm),
                      Text(
                        strings.openInDefaultApp,
                        style: const TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(AppThemeData theme, AppStrings strings) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.lg, vertical: theme.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: fluent.Button(
                onPressed: () async {
                  await ref.read(fileViewerServiceProvider).copyToClipboard('/${widget.remotePath}');
                  if (mounted) {
                    setState(() => _copied = true);
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted) setState(() => _copied = false);
                    });
                  }
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _copied ? fluent.FluentIcons.check_mark : fluent.FluentIcons.copy,
                      size: 14,
                      color: _copied ? theme.success : theme.textPrimary,
                      semanticLabel: strings.copyPath,
                    ),
                    SizedBox(width: theme.xs),
                    Text(
                      _copied ? strings.pathCopied : strings.copyPath,
                      style: TextStyle(color: _copied ? theme.success : theme.textPrimary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: fluent.FilledButton(
                    onPressed: () async {
                      await ref.read(fileViewerServiceProvider).openInDefaultApp(
                        remoteName: widget.remoteName,
                        remotePath: widget.remotePath,
                        fileName: widget.fileName,
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(fluent.FluentIcons.open_in_new_window, size: 14, color: Color(0xFFFFFFFF), semanticLabel: 'Open'),
                        SizedBox(width: theme.xs),
                        Text(
                          strings.openInDefaultApp,
                          style: const TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: theme.md),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44, minWidth: 80),
                  child: fluent.Button(
                    onPressed: () => Navigator.pop(context),
                    child: Text(strings.close, style: TextStyle(color: theme.textPrimary, fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String fileName) {
    final cat = FileMetadataHelper.getCategory(fileName);
    switch (cat) {
      case FileCategory.image:
        return fluent.FluentIcons.photo_collection;
      case FileCategory.video:
        return fluent.FluentIcons.video;
      case FileCategory.audio:
        return fluent.FluentIcons.music_in_collection;
      case FileCategory.textCode:
        return fluent.FluentIcons.code;
      case FileCategory.document:
        return fluent.FluentIcons.document;
      case FileCategory.archive:
        return fluent.FluentIcons.archive;
      case FileCategory.binary:
        return fluent.FluentIcons.page;
    }
  }
}

import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' as material;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/services/file_viewer_service.dart';
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
  bool _isPlayingAudio = false;
  String? _previewText;
  bool _isLoadingContent = false;
  bool _copied = false;

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
    }
  }

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
        return _buildAudioPreview(theme, strings);
      case FileCategory.video:
      case FileCategory.document:
      case FileCategory.archive:
      case FileCategory.binary:
        return _buildGenericCardPreview(theme, strings, cat);
    }
  }

  Widget _buildImagePreview(AppThemeData theme, AppStrings strings) {
    return Stack(
      children: [
        Center(
          child: InteractiveViewer(
            transformationController: _transformController,
            minScale: 0.5,
            maxScale: 4.0,
            child: Container(
              padding: EdgeInsets.all(theme.lg),
              alignment: Alignment.center,
              child: Container(
                width: 480,
                height: 320,
                decoration: BoxDecoration(
                  color: theme.canvas,
                  borderRadius: BorderRadius.circular(theme.radiusSm),
                  border: Border.all(color: theme.textSecondary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(fluent.FluentIcons.photo_collection, size: 72, color: theme.accent.withValues(alpha: 0.7), semanticLabel: 'Photo'),
                    SizedBox(height: theme.md),
                    Text(
                      widget.fileName,
                      style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary, fontSize: 14),
                    ),
                    SizedBox(height: theme.xs),
                    Text(
                      '4032 × 3024 Pixel • 12.2 MP • sRGB 24-Bit',
                      style: TextStyle(color: theme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
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

  Widget _buildAudioPreview(AppThemeData theme, AppStrings strings) {
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
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(fluent.FluentIcons.music_in_collection, size: 36, color: theme.accent, semanticLabel: 'Audio'),
            ),
            SizedBox(height: theme.lg),
            Text(
              widget.fileName,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimary),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: theme.xs),
            Text(
              'FLAC Lossless • 48.0 kHz • 2 Kanäle • 03:42 Min.',
              style: TextStyle(fontSize: 12, color: theme.textSecondary),
            ),
            SizedBox(height: theme.xl),
            // Simulated waveform / progress bar
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: theme.textSecondary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Row(
                children: [
                  Container(
                    width: _isPlayingAudio ? 240 : 80,
                    decoration: BoxDecoration(
                      color: theme.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: theme.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_isPlayingAudio ? '01:24' : '00:00', style: TextStyle(fontSize: 11, color: theme.textSecondary)),
                Text('03:42', style: TextStyle(fontSize: 11, color: theme.textSecondary)),
              ],
            ),
            SizedBox(height: theme.lg),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 120, minHeight: 44),
                child: fluent.FilledButton(
                  onPressed: () => setState(() => _isPlayingAudio = !_isPlayingAudio),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isPlayingAudio ? fluent.FluentIcons.pause : fluent.FluentIcons.play,
                        size: 16,
                        color: const Color(0xFFFFFFFF),
                        semanticLabel: _isPlayingAudio ? strings.pauseAudio : strings.playAudio,
                      ),
                      SizedBox(width: theme.sm),
                      Text(
                        _isPlayingAudio ? strings.pauseAudio : strings.playAudio,
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

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/rclone_service.dart';
import '../../../core/services/rclone_provider.dart';
import '../../../core/services/file_viewer_service.dart';
import '../../../core/localization/app_strings.dart';
import '../../../theme/theme.dart';
import '../../tasks/presentation/tasks_controller.dart';
import '../../settings/presentation/cloud_drives_screen.dart';
import 'widgets/file_metadata_helper.dart';
import 'widgets/file_preview_dialog.dart';

/// Screen displaying remote files and folders dynamically, supporting interactive
/// breadcrumb navigation, file inspection actions, exclusion rules, and multi-drive browsing.
class CloudExplorerScreen extends ConsumerStatefulWidget {
  const CloudExplorerScreen({super.key});

  @override
  ConsumerState<CloudExplorerScreen> createState() => _CloudExplorerScreenState();
}

class _CloudExplorerScreenState extends ConsumerState<CloudExplorerScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedRemote;
  String _currentPath = '';
  final List<String> _navigationHistory = [];
  bool _isLoading = false;
  bool _isRefreshing = false;
  List<RcloneFileInfo> _files = [];
  String? _errorMessage;
  String? _bannerMessage;
  bool _isBannerError = false;
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    // Safely load the first remote after widget builds
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final remotes = await ref.read(remotesProvider.future);
      if (remotes.isNotEmpty && mounted) {
        setState(() {
          _selectedRemote = remotes.first;
        });
        _loadFiles();
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _showNotification(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _bannerMessage = message;
      _isBannerError = isError;
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _bannerMessage == message) {
        setState(() {
          _bannerMessage = null;
        });
      }
    });
  }

  Future<void> _loadFiles() async {
    final remote = _selectedRemote;
    if (remote == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final files = await ref.read(rcloneServiceProvider).listFiles(remote, _currentPath);
      if (mounted) {
        setState(() {
          _files = files;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
          _files = [];
        });
      }
    }
  }

  Future<void> _handleRefresh({bool showSuccessBanner = true}) async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
    });
    _rotationController.repeat();

    try {
      await _loadFiles();
      if (mounted && showSuccessBanner && _errorMessage == null) {
        _showNotification(context.strings.filesRefreshed, isError: false);
      }
    } finally {
      if (mounted) {
        _rotationController.stop();
        _rotationController.reset();
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  void _navigateToFolder(String folderName) {
    setState(() {
      _navigationHistory.add(_currentPath);
      _currentPath = _currentPath.isEmpty ? folderName : '$_currentPath/$folderName';
    });
    _loadFiles();
  }

  void _navigateToBreadcrumb(int segmentIndex) {
    if (segmentIndex == -1) {
      if (_currentPath.isEmpty) return;
      setState(() {
        _navigationHistory.add(_currentPath);
        _currentPath = '';
      });
      _loadFiles();
      return;
    }

    final segments = _currentPath.split('/').where((s) => s.isNotEmpty).toList();
    if (segmentIndex < segments.length - 1) {
      final newPath = segments.take(segmentIndex + 1).join('/');
      setState(() {
        _navigationHistory.add(_currentPath);
        _currentPath = newPath;
      });
      _loadFiles();
    }
  }

  void _navigateBack() {
    if (_navigationHistory.isNotEmpty) {
      setState(() {
        _currentPath = _navigationHistory.removeLast();
      });
      _loadFiles();
    } else if (_currentPath.isNotEmpty) {
      final segments = _currentPath.split('/').where((s) => s.isNotEmpty).toList();
      if (segments.length <= 1) {
        setState(() {
          _currentPath = '';
        });
      } else {
        segments.removeLast();
        setState(() {
          _currentPath = segments.join('/');
        });
      }
      _loadFiles();
    }
  }

  void _changeRemote(String? remoteName) {
    if (remoteName != null && remoteName != _selectedRemote) {
      setState(() {
        _selectedRemote = remoteName;
        _currentPath = '';
        _navigationHistory.clear();
        _bannerMessage = null;
      });
      _loadFiles();
    }
  }

  void _navigateToCloudDrives(BuildContext context) {
    final platform = defaultTargetPlatform;
    final route = platform == TargetPlatform.windows
        ? fluent.FluentPageRoute(builder: (_) => const CloudDrivesScreen())
        : (platform == TargetPlatform.iOS
            ? cupertino.CupertinoPageRoute(builder: (_) => const CloudDrivesScreen())
            : material.MaterialPageRoute(builder: (_) => const CloudDrivesScreen()));
    Navigator.of(context).push(route);
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  String _formatDate(String isoString) {
    if (isoString.isEmpty) return '-';
    try {
      final parsed = DateTime.parse(isoString).toLocal();
      final year = parsed.year.toString();
      final month = parsed.month.toString().padLeft(2, '0');
      final day = parsed.day.toString().padLeft(2, '0');
      final hour = parsed.hour.toString().padLeft(2, '0');
      final minute = parsed.minute.toString().padLeft(2, '0');
      return '$year-$month-$day $hour:$minute';
    } catch (_) {
      return isoString.length > 10 ? isoString.substring(0, 10) : isoString;
    }
  }

  void _simulateDownload(RcloneFileInfo file, AppStrings strings) {
    _showNotification('${file.name}: ${strings.downloadFile} ${strings.success.toLowerCase()}.', isError: false);
  }

  Future<void> _executeDeleteAndExclude(String fileName, String fullFilePath, AppStrings strings) async {
    final remote = _selectedRemote;
    if (remote == null) return;

    setState(() {
      _isLoading = true;
      _bannerMessage = null;
    });

    try {
      // 1. Delete file via rclone
      await ref.read(rcloneServiceProvider).deleteFile(remote, fullFilePath);

      // 2. Add exclude rule to prevent re-upload on next sync
      ref.read(tasksListProvider.notifier).addExcludeRule(remote, fullFilePath);

      if (mounted) {
        _showNotification('$fileName: ${strings.delete.toLowerCase()}. ${strings.excludeRuleCreated}', isError: false);
      }

      // 3. Reload files
      await _loadFiles();
    } catch (e) {
      if (mounted) {
        _showNotification('${strings.error}: $e', isError: true);
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- Rule 6 Confirmation Dialog ---
  void _confirmDeleteFile(BuildContext context, RcloneFileInfo file, TargetPlatform platform) {
    final strings = context.strings;
    final theme = context.theme;
    final title = strings.deleteFileConfirmTitle;
    final message = '${strings.deleteFilePrompt(file.name)}\n\n${strings.deleteFileRule6Notice(file.name)}';
    final fullFilePath = _currentPath.isEmpty ? file.name : '$_currentPath/${file.name}';

    if (platform == TargetPlatform.windows) {
      fluent.showDialog(
        context: context,
        builder: (dialogCtx) => fluent.ContentDialog(
          constraints: const BoxConstraints(maxWidth: 480, minWidth: 380),
          title: fluent.Text(title),
          content: Text(message, style: TextStyle(color: theme.textPrimary, height: 1.4)),
          actions: [
            Wrap(
              spacing: theme.sm,
              runSpacing: theme.xs,
              alignment: WrapAlignment.end,
              children: [
                fluent.Tooltip(
                  message: strings.delete,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 80, minHeight: 44),
                      child: fluent.FilledButton(
                        style: fluent.ButtonStyle(
                          backgroundColor: WidgetStateProperty.resolveWith((_) => theme.error),
                        ),
                        onPressed: () async {
                          Navigator.pop(dialogCtx);
                          await _executeDeleteAndExclude(file.name, fullFilePath, strings);
                        },
                        child: Text(strings.delete),
                      ),
                    ),
                  ),
                ),
                fluent.Tooltip(
                  message: strings.cancel,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 80, minHeight: 44),
                      child: fluent.Button(
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: Text(strings.cancel),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else if (platform == TargetPlatform.iOS) {
      cupertino.showCupertinoDialog(
        context: context,
        builder: (dialogCtx) => cupertino.CupertinoAlertDialog(
          title: Text(title),
          content: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(message),
          ),
          actions: [
            cupertino.CupertinoDialogAction(
              child: Text(strings.cancel),
              onPressed: () => Navigator.pop(dialogCtx),
            ),
            cupertino.CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.pop(dialogCtx);
                await _executeDeleteAndExclude(file.name, fullFilePath, strings);
              },
              child: Text(strings.delete),
            ),
          ],
        ),
      );
    } else {
      material.showDialog(
        context: context,
        builder: (dialogCtx) => material.AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            material.TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(strings.cancel),
            ),
            material.FilledButton(
              style: material.FilledButton.styleFrom(
                backgroundColor: theme.error,
              ),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                await _executeDeleteAndExclude(file.name, fullFilePath, strings);
              },
              child: Text(strings.delete),
            ),
          ],
        ),
      );
    }
  }

  // --- Details / Actions Modals ---
  void _showWindowsFileDetails(BuildContext context, RcloneFileInfo file, AppThemeData theme, AppStrings strings) {
    final fullFilePath = _currentPath.isEmpty ? file.name : '$_currentPath/${file.name}';
    final specificMetadata = FileMetadataHelper.getSpecificMetadata(fileName: file.name, fileSize: file.size);
    final mimeType = FileMetadataHelper.getMimeType(file.name);
    final exactBytes = FileMetadataHelper.formatExactBytes(file.size);
    final formatLabel = FileMetadataHelper.getFormatLabel(file.name);

    fluent.showDialog(
      context: context,
      builder: (dialogCtx) => fluent.ContentDialog(
        constraints: const BoxConstraints(maxWidth: 620, minWidth: 480),
        title: Row(
          children: [
            Icon(fluent.FluentIcons.info, size: 18, color: theme.accent),
            SizedBox(width: theme.sm),
            Text(strings.fileDetailsTitle),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with large icon and title
                Container(
                  padding: EdgeInsets.all(theme.md),
                  decoration: BoxDecoration(
                    color: theme.canvas,
                    borderRadius: BorderRadius.circular(theme.radiusSm),
                    border: Border.all(color: theme.textSecondary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(fluent.FluentIcons.document, size: 40, color: theme.accent, semanticLabel: strings.fileName),
                      SizedBox(width: theme.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.name,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: theme.xs),
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: theme.sm, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.accent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(theme.radiusSm),
                                  ),
                                  child: Text(
                                    formatLabel,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.accent),
                                  ),
                                ),
                                SizedBox(width: theme.sm),
                                Text(
                                  _formatBytes(file.size),
                                  style: TextStyle(fontSize: 12, color: theme.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: theme.lg),

                // Sektion 1: Allgemeine Informationen
                Text(
                  strings.metadataSectionGeneral,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.accent),
                ),
                SizedBox(height: theme.xs),
                Container(
                  padding: EdgeInsets.all(theme.md),
                  decoration: BoxDecoration(
                    color: theme.canvas,
                    borderRadius: BorderRadius.circular(theme.radiusSm),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow(strings.filePath, '/$fullFilePath', theme),
                      SizedBox(height: theme.xs),
                      _buildDetailRow(strings.cloudRemote, _selectedRemote ?? '-', theme),
                      SizedBox(height: theme.xs),
                      _buildDetailRow(strings.metadataMimeType, mimeType, theme),
                      SizedBox(height: theme.xs),
                      _buildDetailRow(strings.metadataExactBytes, exactBytes, theme),
                      SizedBox(height: theme.xs),
                      _buildDetailRow(strings.fileModTime, _formatDate(file.modTime), theme),
                    ],
                  ),
                ),
                SizedBox(height: theme.lg),

                // Sektion 2: Spezifische Metadaten
                if (specificMetadata.isNotEmpty) ...[
                  Text(
                    strings.metadataSectionDetails,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.accent),
                  ),
                  SizedBox(height: theme.xs),
                  Container(
                    padding: EdgeInsets.all(theme.md),
                    decoration: BoxDecoration(
                      color: theme.canvas,
                      borderRadius: BorderRadius.circular(theme.radiusSm),
                    ),
                    child: Column(
                      children: specificMetadata.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: _buildDetailRow('${entry.key}:', entry.value, theme),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          Wrap(
            spacing: theme.sm,
            runSpacing: theme.xs,
            alignment: WrapAlignment.end,
            children: [
              // Vorschau (Quick Look)
              fluent.Tooltip(
                message: strings.previewFile,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: fluent.FilledButton(
                      onPressed: () {
                        Navigator.pop(dialogCtx);
                        material.showDialog(
                          context: context,
                          builder: (_) => FilePreviewDialog(
                            fileName: file.name,
                            remoteName: _selectedRemote ?? '',
                            remotePath: fullFilePath,
                            fileSize: file.size,
                          ),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(fluent.FluentIcons.view, size: 16, color: Color(0xFFFFFFFF), semanticLabel: 'Preview'),
                          SizedBox(width: theme.sm),
                          Text(
                            strings.previewFile,
                            style: const TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // In Standard-App öffnen
              fluent.Tooltip(
                message: strings.openInDefaultApp,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: fluent.Button(
                      onPressed: () async {
                        Navigator.pop(dialogCtx);
                        _showNotification(strings.openingFile, isError: false);
                        await ref.read(fileViewerServiceProvider).openInDefaultApp(
                          remoteName: _selectedRemote ?? '',
                          remotePath: fullFilePath,
                          fileName: file.name,
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(fluent.FluentIcons.open_in_new_window, size: 16, color: theme.textPrimary, semanticLabel: strings.openInDefaultApp),
                          SizedBox(width: theme.sm),
                          Text(strings.openInDefaultApp, style: TextStyle(color: theme.textPrimary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Herunterladen
              fluent.Tooltip(
                message: strings.downloadFile,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: fluent.Button(
                      onPressed: () {
                        Navigator.pop(dialogCtx);
                        _simulateDownload(file, strings);
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(fluent.FluentIcons.download, size: 16, color: theme.textPrimary, semanticLabel: strings.downloadFile),
                          SizedBox(width: theme.sm),
                          Text(strings.downloadFile, style: TextStyle(color: theme.textPrimary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Pfad kopieren
              fluent.Tooltip(
                message: strings.copyPath,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: fluent.Button(
                      onPressed: () async {
                        await ref.read(fileViewerServiceProvider).copyToClipboard('/$fullFilePath');
                        _showNotification(strings.pathCopied, isError: false);
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(fluent.FluentIcons.copy, size: 16, color: theme.textPrimary, semanticLabel: strings.copyPath),
                          SizedBox(width: theme.sm),
                          Text(strings.copyPath, style: TextStyle(color: theme.textPrimary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Löschen
              fluent.Tooltip(
                message: strings.deleteFile,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: fluent.Button(
                      style: fluent.ButtonStyle(
                        foregroundColor: WidgetStateProperty.resolveWith((_) => theme.error),
                      ),
                      onPressed: () {
                        Navigator.pop(dialogCtx);
                        _confirmDeleteFile(context, file, TargetPlatform.windows);
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(fluent.FluentIcons.delete, size: 16, color: theme.error, semanticLabel: strings.deleteFile),
                          SizedBox(width: theme.sm),
                          Text(strings.deleteFile),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Schließen
              fluent.Tooltip(
                message: strings.close,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: fluent.Button(
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: Text(strings.close, style: TextStyle(color: theme.textPrimary)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showIOSFileDetails(BuildContext context, RcloneFileInfo file, AppThemeData theme, AppStrings strings) {
    final fullFilePath = _currentPath.isEmpty ? file.name : '$_currentPath/${file.name}';
    final exactBytes = FileMetadataHelper.formatExactBytes(file.size);
    final mimeType = FileMetadataHelper.getMimeType(file.name);

    cupertino.showCupertinoModalPopup<void>(
      context: context,
      builder: (modalCtx) => cupertino.CupertinoActionSheet(
        title: Text(strings.fileDetailsTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        message: Column(
          children: [
            Text(file.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 6),
            Text('${strings.fileSize} ${_formatBytes(file.size)} ($exactBytes)'),
            const SizedBox(height: 4),
            Text('MIME: $mimeType | /$fullFilePath', style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          cupertino.CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(modalCtx);
              material.showDialog(
                context: context,
                builder: (_) => FilePreviewDialog(
                  fileName: file.name,
                  remoteName: _selectedRemote ?? '',
                  remotePath: fullFilePath,
                  fileSize: file.size,
                ),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(cupertino.CupertinoIcons.eye, size: 20, color: theme.accent, semanticLabel: strings.previewFile),
                SizedBox(width: theme.sm),
                Text(strings.previewFile, style: TextStyle(color: theme.accent)),
              ],
            ),
          ),
          cupertino.CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(modalCtx);
              await ref.read(fileViewerServiceProvider).openInDefaultApp(
                remoteName: _selectedRemote ?? '',
                remotePath: fullFilePath,
                fileName: file.name,
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(cupertino.CupertinoIcons.arrow_up_right_square, size: 20, color: theme.accent, semanticLabel: strings.openInDefaultApp),
                SizedBox(width: theme.sm),
                Text(strings.openInDefaultApp, style: TextStyle(color: theme.accent)),
              ],
            ),
          ),
          cupertino.CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(modalCtx);
              _simulateDownload(file, strings);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(cupertino.CupertinoIcons.cloud_download, size: 20, color: theme.accent, semanticLabel: strings.downloadFile),
                SizedBox(width: theme.sm),
                Text(strings.downloadFile, style: TextStyle(color: theme.accent)),
              ],
            ),
          ),
          cupertino.CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(modalCtx);
              _confirmDeleteFile(context, file, TargetPlatform.iOS);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(cupertino.CupertinoIcons.trash, size: 20, color: theme.error, semanticLabel: strings.deleteFile),
                SizedBox(width: theme.sm),
                Text(strings.deleteFile),
              ],
            ),
          ),
        ],
        cancelButton: cupertino.CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(modalCtx),
          child: Text(strings.close),
        ),
      ),
    );
  }

  void _showAndroidFileDetails(BuildContext context, RcloneFileInfo file, AppThemeData theme, AppStrings strings) {
    final fullFilePath = _currentPath.isEmpty ? file.name : '$_currentPath/${file.name}';
    final exactBytes = FileMetadataHelper.formatExactBytes(file.size);
    final mimeType = FileMetadataHelper.getMimeType(file.name);

    material.showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.surface,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(theme.radiusLg)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(theme.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(material.Icons.description, size: 32, color: theme.accent, semanticLabel: strings.fileName),
                  SizedBox(width: theme.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(file.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                        Text('/$fullFilePath', style: TextStyle(fontSize: 12, color: theme.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: theme.md),
              _buildDetailRow(strings.metadataMimeType, mimeType, theme),
              SizedBox(height: theme.xs),
              _buildDetailRow(strings.fileSize, '${_formatBytes(file.size)} ($exactBytes)', theme),
              SizedBox(height: theme.xs),
              _buildDetailRow(strings.fileModTime, _formatDate(file.modTime), theme),
              SizedBox(height: theme.lg),
              Wrap(
                spacing: theme.md,
                runSpacing: theme.sm,
                alignment: WrapAlignment.end,
                children: [
                  material.Tooltip(
                    message: strings.previewFile,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: material.FilledButton.icon(
                          style: material.FilledButton.styleFrom(
                            backgroundColor: theme.accent,
                            foregroundColor: material.Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(theme.radiusSm)),
                          ),
                          onPressed: () {
                            Navigator.pop(sheetCtx);
                            material.showDialog(
                              context: context,
                              builder: (_) => FilePreviewDialog(
                                fileName: file.name,
                                remoteName: _selectedRemote ?? '',
                                remotePath: fullFilePath,
                                fileSize: file.size,
                              ),
                            );
                          },
                          icon: const Icon(material.Icons.visibility, color: material.Colors.white, semanticLabel: 'Preview'),
                          label: Text(strings.previewFile, style: const TextStyle(color: material.Colors.white, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ),
                  material.Tooltip(
                    message: strings.deleteFile,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: material.OutlinedButton.icon(
                          style: material.OutlinedButton.styleFrom(
                            foregroundColor: theme.error,
                            side: BorderSide(color: theme.error),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(theme.radiusSm)),
                          ),
                          onPressed: () {
                            Navigator.pop(sheetCtx);
                            _confirmDeleteFile(context, file, TargetPlatform.android);
                          },
                          icon: Icon(material.Icons.delete_outline, color: theme.error, semanticLabel: strings.deleteFile),
                          label: Text(strings.deleteFile),
                        ),
                      ),
                    ),
                  ),
                  material.Tooltip(
                    message: strings.downloadFile,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: material.FilledButton.icon(
                          style: material.FilledButton.styleFrom(
                            backgroundColor: theme.accent,
                            foregroundColor: material.Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(theme.radiusSm)),
                          ),
                          onPressed: () {
                            Navigator.pop(sheetCtx);
                            _simulateDownload(file, strings);
                          },
                          icon: const Icon(material.Icons.download, color: material.Colors.white, semanticLabel: 'Download'),
                          label: Text(strings.downloadFile, style: const TextStyle(color: material.Colors.white, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFileDetails(
    BuildContext context,
    RcloneFileInfo file,
    TargetPlatform platform,
    AppThemeData theme,
    AppStrings strings,
  ) {
    if (platform == TargetPlatform.windows) {
      _showWindowsFileDetails(context, file, theme, strings);
    } else if (platform == TargetPlatform.iOS) {
      _showIOSFileDetails(context, file, theme, strings);
    } else {
      _showAndroidFileDetails(context, file, theme, strings);
    }
  }

  Widget _buildDetailRow(String label, String value, AppThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(color: theme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final platform = defaultTargetPlatform;
    final theme = context.theme;
    final strings = context.strings;
    final remotesAsync = ref.watch(remotesProvider);

    return remotesAsync.when(
      data: (remotes) {
        if (remotes.isEmpty) {
          return _buildNoRemotesState(theme, platform, strings);
        }

        if (platform == TargetPlatform.windows) {
          return _buildWindows(context, remotes, theme, strings);
        } else if (platform == TargetPlatform.iOS) {
          return _buildIOS(context, remotes, theme, strings);
        } else {
          return _buildAndroid(context, remotes, theme, strings);
        }
      },
      loading: () => _buildLoadingOverlay(platform),
      error: (err, _) => _buildErrorScreen(err.toString(), platform, theme, strings),
    );
  }

  // --- Windows (Fluent Design) ---
  Widget _buildWindows(BuildContext context, List<String> remotes, AppThemeData theme, AppStrings strings) {
    return fluent.ScaffoldPage(
      header: fluent.PageHeader(
        title: fluent.Text(strings.cloudExplorerTitle),
        leading: fluent.Tooltip(
          message: strings.back,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              child: fluent.IconButton(
                icon: Icon(fluent.FluentIcons.back, semanticLabel: strings.back),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
      ),
      content: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '${strings.remoteDriveSelectorLabel}: ',
                  style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                SizedBox(width: theme.sm),
                fluent.Tooltip(
                  message: strings.remoteDriveSelectorLabel,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44, minWidth: 160),
                    child: fluent.ComboBox<String>(
                      value: _selectedRemote,
                      items: remotes.map((r) => fluent.ComboBoxItem(
                        value: r,
                        child: Text(r, style: TextStyle(color: theme.textPrimary)),
                      )).toList(),
                      onChanged: _changeRemote,
                    ),
                  ),
                ),
                const Spacer(),
                fluent.Tooltip(
                  message: strings.refresh,
                  child: MouseRegion(
                    cursor: _isLoading || _isRefreshing ? SystemMouseCursors.basic : SystemMouseCursors.click,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      child: fluent.IconButton(
                        icon: _isRefreshing
                            ? RotationTransition(
                                turns: _rotationController,
                                child: Icon(fluent.FluentIcons.refresh, size: 18, color: theme.accent, semanticLabel: strings.refresh),
                              )
                            : Icon(fluent.FluentIcons.refresh, size: 18, color: theme.textPrimary, semanticLabel: strings.refresh),
                        onPressed: _isLoading || _isRefreshing ? null : () => _handleRefresh(showSuccessBanner: true),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: theme.md),
            _buildBreadcrumbBar(theme, TargetPlatform.windows, strings),
            SizedBox(height: theme.xs),
            if (_isLoading || _isRefreshing)
              const fluent.ProgressBar(value: null)
            else
              const SizedBox(height: 4),
            if (_bannerMessage != null) ...[
              SizedBox(height: theme.sm),
              fluent.InfoBar(
                title: Text(_isBannerError ? strings.error : strings.success),
                content: Text(_bannerMessage!),
                severity: _isBannerError ? fluent.InfoBarSeverity.error : fluent.InfoBarSeverity.success,
                onClose: () => setState(() => _bannerMessage = null),
              ),
            ],
            SizedBox(height: theme.sm),
            Expanded(
              child: _buildExplorerBody(theme, TargetPlatform.windows, strings),
            ),
          ],
        ),
      ),
    );
  }

  // --- iOS (Cupertino Design) ---
  Widget _buildIOS(BuildContext context, List<String> remotes, AppThemeData theme, AppStrings strings) {
    return cupertino.CupertinoPageScaffold(
      navigationBar: cupertino.CupertinoNavigationBar(
        middle: Text(strings.cloudExplorerTitle),
        previousPageTitle: strings.back,
        trailing: material.Tooltip(
          message: strings.refresh,
          child: MouseRegion(
            cursor: _isLoading || _isRefreshing ? SystemMouseCursors.basic : SystemMouseCursors.click,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              child: cupertino.CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _isLoading || _isRefreshing ? null : () => _handleRefresh(showSuccessBanner: true),
                child: _isRefreshing
                    ? RotationTransition(
                        turns: _rotationController,
                        child: Icon(cupertino.CupertinoIcons.refresh, color: theme.accent, semanticLabel: strings.refresh),
                      )
                    : Icon(cupertino.CupertinoIcons.refresh, semanticLabel: strings.refresh),
              ),
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(theme.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (remotes.length <= 3)
                cupertino.CupertinoSlidingSegmentedControl<String>(
                  groupValue: _selectedRemote,
                  children: {
                    for (final r in remotes)
                      r: Padding(
                        padding: EdgeInsets.symmetric(vertical: theme.xs, horizontal: theme.sm),
                        child: Text(r, style: TextStyle(fontSize: 13, color: theme.textPrimary)),
                      ),
                  },
                  onValueChanged: _changeRemote,
                )
              else
                material.Tooltip(
                  message: strings.remoteDriveSelectorLabel,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: cupertino.CupertinoButton(
                        padding: EdgeInsets.symmetric(horizontal: theme.md, vertical: theme.sm),
                        color: theme.textSecondary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(theme.radiusSm),
                        onPressed: () {
                          cupertino.showCupertinoModalPopup<void>(
                            context: context,
                            builder: (actionCtx) => cupertino.CupertinoActionSheet(
                              title: Text(strings.remoteDriveSelectorLabel),
                              actions: remotes.map((r) => cupertino.CupertinoActionSheetAction(
                                onPressed: () {
                                  Navigator.pop(actionCtx);
                                  _changeRemote(r);
                                },
                                child: Text(
                                  r,
                                  style: TextStyle(
                                    fontWeight: r == _selectedRemote ? FontWeight.bold : FontWeight.normal,
                                    color: r == _selectedRemote ? theme.accent : theme.textPrimary,
                                  ),
                                ),
                              )).toList(),
                              cancelButton: cupertino.CupertinoActionSheetAction(
                                onPressed: () => Navigator.pop(actionCtx),
                                child: Text(strings.cancel),
                              ),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_selectedRemote ?? '', style: TextStyle(color: theme.textPrimary, fontSize: 14)),
                            Icon(cupertino.CupertinoIcons.chevron_down, size: 16, color: theme.textSecondary, semanticLabel: strings.remoteDriveSelectorLabel),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              SizedBox(height: theme.md),
              _buildBreadcrumbBar(theme, TargetPlatform.iOS, strings),
              SizedBox(height: theme.xs),
              if (_isLoading || _isRefreshing)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 2.0),
                  child: Center(child: cupertino.CupertinoActivityIndicator()),
                )
              else
                const SizedBox(height: 4),
              if (_bannerMessage != null) ...[
                SizedBox(height: theme.sm),
                _buildFeedbackBanner(theme, TargetPlatform.iOS, strings),
              ],
              SizedBox(height: theme.sm),
              Expanded(
                child: _buildExplorerBody(theme, TargetPlatform.iOS, strings),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Android (Material 3 Design) ---
  Widget _buildAndroid(BuildContext context, List<String> remotes, AppThemeData theme, AppStrings strings) {
    return material.Scaffold(
      appBar: material.AppBar(
        title: Text(strings.cloudExplorerTitle),
        actions: [
          material.Tooltip(
            message: strings.refresh,
            child: MouseRegion(
              cursor: _isLoading || _isRefreshing ? SystemMouseCursors.basic : SystemMouseCursors.click,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: material.IconButton(
                  icon: _isRefreshing
                      ? RotationTransition(
                          turns: _rotationController,
                          child: Icon(material.Icons.refresh, color: theme.accent, semanticLabel: strings.refresh),
                        )
                      : Icon(material.Icons.refresh, semanticLabel: strings.refresh),
                  onPressed: _isLoading || _isRefreshing ? null : () => _handleRefresh(showSuccessBanner: true),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(theme.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: material.Tooltip(
                    message: strings.remoteDriveSelectorLabel,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: material.DropdownButtonFormField<String>(
                        initialValue: _selectedRemote,
                        decoration: material.InputDecoration(
                          labelText: strings.remoteDriveSelectorLabel,
                          contentPadding: EdgeInsets.symmetric(horizontal: theme.md, vertical: theme.xs),
                          border: material.OutlineInputBorder(
                            borderRadius: BorderRadius.circular(theme.radiusSm),
                          ),
                        ),
                        items: remotes.map((r) => material.DropdownMenuItem(
                          value: r,
                          child: Text(r, style: TextStyle(color: theme.textPrimary)),
                        )).toList(),
                        onChanged: _changeRemote,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: theme.md),
            _buildBreadcrumbBar(theme, TargetPlatform.android, strings),
            SizedBox(height: theme.xs),
            if (_isLoading || _isRefreshing)
              material.LinearProgressIndicator(
                color: theme.accent,
                backgroundColor: theme.textSecondary.withValues(alpha: 0.1),
              )
            else
              const SizedBox(height: 4),
            if (_bannerMessage != null) ...[
              SizedBox(height: theme.sm),
              _buildFeedbackBanner(theme, TargetPlatform.android, strings),
            ],
            SizedBox(height: theme.sm),
            Expanded(
              child: _buildExplorerBody(theme, TargetPlatform.android, strings),
            ),
          ],
        ),
      ),
    );
  }

  // --- Interactive Breadcrumbs Bar ---
  Widget _buildBreadcrumbBar(AppThemeData theme, TargetPlatform platform, AppStrings strings) {
    final segments = _currentPath.split('/').where((s) => s.isNotEmpty).toList();

    final backIcon = platform == TargetPlatform.windows
        ? fluent.FluentIcons.back
        : (platform == TargetPlatform.iOS ? cupertino.CupertinoIcons.back : material.Icons.arrow_back);

    final separatorIcon = platform == TargetPlatform.windows
        ? fluent.FluentIcons.chevron_right_small
        : (platform == TargetPlatform.iOS ? cupertino.CupertinoIcons.chevron_right : material.Icons.chevron_right);

    final canGoBack = _navigationHistory.isNotEmpty || _currentPath.isNotEmpty;

    final backButton = MouseRegion(
      cursor: canGoBack ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: platform == TargetPlatform.windows
            ? fluent.IconButton(
                icon: Icon(
                  backIcon,
                  color: canGoBack ? theme.accent : theme.textSecondary.withValues(alpha: 0.4),
                  size: 18,
                  semanticLabel: strings.back,
                ),
                onPressed: canGoBack ? _navigateBack : null,
              )
            : (platform == TargetPlatform.iOS
                ? cupertino.CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: canGoBack ? _navigateBack : null,
                    child: Icon(
                      backIcon,
                      color: canGoBack ? theme.accent : theme.textSecondary.withValues(alpha: 0.4),
                      size: 20,
                      semanticLabel: strings.back,
                    ),
                  )
                : material.IconButton(
                    icon: Icon(
                      backIcon,
                      color: canGoBack ? theme.accent : theme.textSecondary.withValues(alpha: 0.4),
                      size: 20,
                      semanticLabel: strings.back,
                    ),
                    onPressed: canGoBack ? _navigateBack : null,
                  )),
      ),
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: theme.sm, vertical: theme.xs),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(theme.radiusSm),
        border: Border.all(
          color: theme.textSecondary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          // Back button with Tooltip
          platform == TargetPlatform.windows
              ? fluent.Tooltip(message: strings.back, child: backButton)
              : material.Tooltip(message: strings.back, child: backButton),
          SizedBox(width: theme.xs),
          // Scrollable breadcrumb chips
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSegmentChip(
                    label: '/',
                    icon: platform == TargetPlatform.windows
                        ? fluent.FluentIcons.cloud
                        : (platform == TargetPlatform.iOS ? cupertino.CupertinoIcons.cloud : material.Icons.cloud_outlined),
                    isCurrent: segments.isEmpty,
                    theme: theme,
                    platform: platform,
                    onTap: () => _navigateToBreadcrumb(-1),
                    semanticLabel: 'Root /',
                    tooltipMessage: strings.isGerman ? 'Hauptverzeichnis (/)' : 'Root folder (/)',
                  ),
                  for (int i = 0; i < segments.length; i++) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: theme.xs),
                      child: Icon(
                        separatorIcon,
                        size: 14,
                        color: theme.textSecondary.withValues(alpha: 0.5),
                        semanticLabel: '/',
                      ),
                    ),
                    _buildSegmentChip(
                      label: segments[i],
                      isCurrent: i == segments.length - 1,
                      theme: theme,
                      platform: platform,
                      onTap: () => _navigateToBreadcrumb(i),
                      semanticLabel: segments[i],
                      tooltipMessage: '${strings.isGerman ? 'Ordner' : 'Folder'}: ${segments[i]}',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentChip({
    required String label,
    IconData? icon,
    required bool isCurrent,
    required AppThemeData theme,
    required TargetPlatform platform,
    required VoidCallback onTap,
    required String semanticLabel,
    required String tooltipMessage,
  }) {
    final chipContent = MouseRegion(
      cursor: isCurrent ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: isCurrent ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: theme.sm, vertical: theme.xs),
            decoration: BoxDecoration(
              color: isCurrent
                  ? theme.accent.withValues(alpha: 0.12)
                  : theme.textSecondary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(theme.radiusSm),
              border: isCurrent
                  ? Border.all(color: theme.accent.withValues(alpha: 0.3))
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 16,
                    color: isCurrent ? theme.accent : theme.textSecondary,
                    semanticLabel: semanticLabel,
                  ),
                  SizedBox(width: theme.xs),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                    color: isCurrent ? theme.accent : theme.textPrimary,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (platform == TargetPlatform.windows) {
      return fluent.Tooltip(
        message: tooltipMessage,
        child: chipContent,
      );
    } else {
      return material.Tooltip(
        message: tooltipMessage,
        child: chipContent,
      );
    }
  }

  Widget _buildFeedbackBanner(AppThemeData theme, TargetPlatform platform, AppStrings strings) {
    return Container(
      padding: EdgeInsets.all(theme.md),
      decoration: BoxDecoration(
        color: _isBannerError ? theme.error.withValues(alpha: 0.12) : theme.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(theme.radiusSm),
        border: Border.all(
          color: _isBannerError ? theme.error.withValues(alpha: 0.4) : theme.success.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isBannerError
                ? (platform == TargetPlatform.iOS ? cupertino.CupertinoIcons.exclamationmark_circle : material.Icons.error_outline)
                : (platform == TargetPlatform.iOS ? cupertino.CupertinoIcons.checkmark_circle : material.Icons.check_circle_outline),
            color: _isBannerError ? theme.error : theme.success,
            size: 20,
            semanticLabel: _isBannerError ? strings.error : strings.success,
          ),
          SizedBox(width: theme.sm),
          Expanded(
            child: Text(
              _bannerMessage!,
              style: TextStyle(
                color: _isBannerError ? theme.error : theme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => setState(() => _bannerMessage = null),
              child: Icon(
                platform == TargetPlatform.iOS ? cupertino.CupertinoIcons.xmark : material.Icons.close,
                size: 18,
                color: theme.textSecondary,
                semanticLabel: strings.close,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Core Files List Builder ---
  Widget _buildExplorerBody(AppThemeData theme, TargetPlatform platform, AppStrings strings) {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              platform == TargetPlatform.windows
                  ? fluent.FluentIcons.error
                  : (platform == TargetPlatform.iOS ? cupertino.CupertinoIcons.exclamationmark_triangle : material.Icons.error_outline),
              size: 40,
              color: theme.error,
              semanticLabel: strings.error,
            ),
            SizedBox(height: theme.sm),
            Text(
              '${strings.error}:\n$_errorMessage',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.error, fontSize: 13),
            ),
            SizedBox(height: theme.md),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44, minWidth: 100),
                child: platform == TargetPlatform.windows
                    ? fluent.Button(
                        onPressed: () => _handleRefresh(showSuccessBanner: false),
                        child: Text(strings.retry),
                      )
                    : (platform == TargetPlatform.iOS
                        ? cupertino.CupertinoButton(
                            padding: EdgeInsets.symmetric(horizontal: theme.md),
                            onPressed: () => _handleRefresh(showSuccessBanner: false),
                            child: Text(strings.retry),
                          )
                        : material.OutlinedButton(
                            onPressed: () => _handleRefresh(showSuccessBanner: false),
                            child: Text(strings.retry),
                          )),
              ),
            ),
          ],
        ),
      );
    }

    if (_files.isEmpty && !_isLoading && !_isRefreshing) {
      return _buildEmptyFolderState(theme, platform, strings);
    }

    if (_files.isEmpty && (_isLoading || _isRefreshing)) {
      return Center(
        child: platform == TargetPlatform.windows
            ? const fluent.ProgressRing()
            : (platform == TargetPlatform.iOS ? const cupertino.CupertinoActivityIndicator() : const material.CircularProgressIndicator()),
      );
    }

    return ListView.separated(
      itemCount: _files.length,
      separatorBuilder: (_, __) => platform == TargetPlatform.windows
          ? const fluent.Divider()
          : (platform == TargetPlatform.iOS
              ? Container(height: 1, color: theme.textSecondary.withValues(alpha: 0.1))
              : const material.Divider(height: 1)),
      itemBuilder: (context, index) {
        final file = _files[index];
        final folderIcon = platform == TargetPlatform.windows
            ? fluent.FluentIcons.folder_horizontal
            : (platform == TargetPlatform.iOS ? cupertino.CupertinoIcons.folder_fill : material.Icons.folder);
        final fileIcon = platform == TargetPlatform.windows
            ? fluent.FluentIcons.document
            : (platform == TargetPlatform.iOS ? cupertino.CupertinoIcons.doc : material.Icons.description);
        final chevronIcon = platform == TargetPlatform.windows
            ? fluent.FluentIcons.chevron_right
            : (platform == TargetPlatform.iOS ? cupertino.CupertinoIcons.chevron_forward : material.Icons.chevron_right);
        final infoIcon = platform == TargetPlatform.windows
            ? fluent.FluentIcons.info
            : (platform == TargetPlatform.iOS ? cupertino.CupertinoIcons.info_circle : material.Icons.info_outline);

        if (file.isDir) {
          final folderItem = MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _navigateToFolder(file.name),
              behavior: HitTestBehavior.opaque,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(theme.xs, theme.sm, theme.lg, theme.sm),
                  child: Row(
                    children: [
                      Icon(folderIcon, color: theme.accent, size: 24, semanticLabel: '${strings.isGerman ? 'Ordner' : 'Folder'} ${file.name}'),
                      SizedBox(width: theme.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.name,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: theme.xs / 2),
                            Text(
                              strings.isGerman ? 'Ordner' : 'Folder',
                              style: TextStyle(color: theme.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        chevronIcon,
                        color: theme.textSecondary,
                        size: 16,
                        semanticLabel: strings.next,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

          if (platform == TargetPlatform.windows) {
            return fluent.Tooltip(
              message: '${strings.isGerman ? 'Ordner öffnen' : 'Open folder'}: ${file.name}',
              child: folderItem,
            );
          } else {
            return material.Tooltip(
              message: '${strings.isGerman ? 'Ordner öffnen' : 'Open folder'}: ${file.name}',
              child: folderItem,
            );
          }
        } else {
          final fileItem = MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _showFileDetails(context, file, platform, theme, strings),
              behavior: HitTestBehavior.opaque,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(theme.xs, theme.sm, theme.lg, theme.sm),
                  child: Row(
                    children: [
                      Icon(fileIcon, color: theme.textSecondary, size: 24, semanticLabel: '${strings.isGerman ? 'Datei' : 'File'} ${file.name}'),
                      SizedBox(width: theme.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.name,
                              style: TextStyle(fontSize: 14, color: theme.textPrimary, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: theme.xs / 2),
                            Text(
                              '${strings.fileSize} ${_formatBytes(file.size)} | ${_formatDate(file.modTime)}',
                              style: TextStyle(color: theme.textSecondary, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        infoIcon,
                        color: theme.textSecondary.withValues(alpha: 0.7),
                        size: 18,
                        semanticLabel: strings.fileDetailsTitle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

          if (platform == TargetPlatform.windows) {
            return fluent.Tooltip(
              message: '${strings.fileDetailsTitle}: ${file.name}',
              child: fileItem,
            );
          } else {
            return material.Tooltip(
              message: '${strings.fileDetailsTitle}: ${file.name}',
              child: fileItem,
            );
          }
        }
      },
    );
  }

  // --- Edge State Screen Helpers ---
  Widget _buildEmptyFolderState(AppThemeData theme, TargetPlatform platform, AppStrings strings) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(theme.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              platform == TargetPlatform.windows
                  ? fluent.FluentIcons.folder_horizontal
                  : (platform == TargetPlatform.iOS ? cupertino.CupertinoIcons.folder : material.Icons.folder_open),
              size: 48,
              color: theme.textSecondary.withValues(alpha: 0.5),
              semanticLabel: strings.emptyFolder,
            ),
            SizedBox(height: theme.md),
            Text(
              strings.emptyFolder,
              style: TextStyle(
                color: theme.textSecondary,
                fontStyle: FontStyle.italic,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoRemotesState(AppThemeData theme, TargetPlatform platform, AppStrings strings) {
    final widgetBody = Center(
      child: Padding(
        padding: EdgeInsets.all(theme.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              platform == TargetPlatform.windows
                  ? fluent.FluentIcons.cloud
                  : (platform == TargetPlatform.iOS ? cupertino.CupertinoIcons.cloud_fill : material.Icons.cloud_off),
              size: 64,
              color: theme.textSecondary.withValues(alpha: 0.6),
              semanticLabel: strings.noRemotesInExplorer,
            ),
            SizedBox(height: theme.lg),
            Text(
              strings.noRemotesInExplorer,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: theme.textPrimary),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: theme.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(
                strings.noDrivesDescription,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.textSecondary, fontSize: 14),
              ),
            ),
            SizedBox(height: theme.xl),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44, minWidth: 180),
                child: platform == TargetPlatform.windows
                    ? fluent.FilledButton(
                        onPressed: () => _navigateToCloudDrives(context),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(fluent.FluentIcons.add, size: 16, semanticLabel: strings.addRemoteCTA),
                            SizedBox(width: theme.sm),
                            Text(strings.addRemoteCTA),
                          ],
                        ),
                      )
                    : (platform == TargetPlatform.iOS
                        ? cupertino.CupertinoButton.filled(
                            padding: EdgeInsets.symmetric(horizontal: theme.xl, vertical: theme.md),
                            onPressed: () => _navigateToCloudDrives(context),
                            child: Text(strings.addRemoteCTA),
                          )
                        : material.FilledButton.icon(
                            style: material.FilledButton.styleFrom(
                              backgroundColor: theme.accent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(theme.radiusSm)),
                            ),
                            onPressed: () => _navigateToCloudDrives(context),
                            icon: Icon(material.Icons.add, semanticLabel: strings.addRemoteCTA),
                            label: Text(strings.addRemoteCTA),
                          )),
              ),
            ),
          ],
        ),
      ),
    );

    if (platform == TargetPlatform.windows) {
      return fluent.ScaffoldPage(
        header: fluent.PageHeader(
          title: fluent.Text(strings.cloudExplorerTitle),
          leading: fluent.Tooltip(
            message: strings.back,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: fluent.IconButton(
                  icon: Icon(fluent.FluentIcons.back, semanticLabel: strings.back),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ),
        content: widgetBody,
      );
    } else if (platform == TargetPlatform.iOS) {
      return cupertino.CupertinoPageScaffold(
        navigationBar: cupertino.CupertinoNavigationBar(
          middle: Text(strings.cloudExplorerTitle),
          previousPageTitle: strings.back,
        ),
        child: SafeArea(child: widgetBody),
      );
    } else {
      return material.Scaffold(
        appBar: material.AppBar(title: Text(strings.cloudExplorerTitle)),
        body: widgetBody,
      );
    }
  }

  Widget _buildLoadingOverlay(TargetPlatform platform) {
    return Center(
      child: platform == TargetPlatform.windows
          ? const fluent.ProgressRing()
          : (platform == TargetPlatform.iOS ? const cupertino.CupertinoActivityIndicator() : const material.CircularProgressIndicator()),
    );
  }

  Widget _buildErrorScreen(String error, TargetPlatform platform, AppThemeData theme, AppStrings strings) {
    final widgetBody = Center(
      child: Padding(
        padding: EdgeInsets.all(theme.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              platform == TargetPlatform.windows
                  ? fluent.FluentIcons.error
                  : (platform == TargetPlatform.iOS ? cupertino.CupertinoIcons.exclamationmark_triangle : material.Icons.error_outline),
              size: 48,
              color: theme.error,
              semanticLabel: strings.error,
            ),
            SizedBox(height: theme.md),
            Text(
              '${strings.error}: $error',
              style: TextStyle(color: theme.error, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    if (platform == TargetPlatform.windows) {
      return fluent.ScaffoldPage(
        header: fluent.PageHeader(
          title: fluent.Text(strings.cloudExplorerTitle),
          leading: fluent.Tooltip(
            message: strings.back,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: fluent.IconButton(
                  icon: Icon(fluent.FluentIcons.back, semanticLabel: strings.back),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ),
        content: widgetBody,
      );
    } else if (platform == TargetPlatform.iOS) {
      return cupertino.CupertinoPageScaffold(
        navigationBar: cupertino.CupertinoNavigationBar(
          middle: Text(strings.cloudExplorerTitle),
          previousPageTitle: strings.back,
        ),
        child: SafeArea(child: widgetBody),
      );
    } else {
      return material.Scaffold(
        appBar: material.AppBar(title: Text(strings.cloudExplorerTitle)),
        body: widgetBody,
      );
    }
  }
}

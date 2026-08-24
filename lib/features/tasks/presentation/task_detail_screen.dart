import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/theme.dart';
import '../../../theme/ios_theme.dart';
import '../../../core/localization/app_strings.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../core/services/rclone_service.dart';
import '../../../core/services/rclone_provider.dart';
import '../../../core/services/remote_registry_service.dart';
import '../../dashboard/presentation/dashboard_controller.dart';
import 'tasks_controller.dart';
import 'tasks_screen.dart';

/// Platform-adaptive Task Detail screen structured according to Apple Settings HIG.
/// Displays complete configuration of a single backup task in organized, clean groups.
class TaskDetailScreen extends ConsumerStatefulWidget {
  final String taskId;

  const TaskDetailScreen({
    super.key,
    required this.taskId,
  });

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  bool _isSyncing = false;
  String? _syncMessage;

  // Inline-Bearbeitung (kein Wizard-Sprung mehr): Name, Album-Auswahl
  // (nur nicht-leere Alben, mit Zähler) sowie Sync-Modus.
  bool _isEditing = false;
  final TextEditingController _nameCtrl = TextEditingController();
  final Set<String> _editAlbumSelection = {};
  List<_EditAlbumOption> _editAlbumOptions = [];
  bool _editAlbumsLoading = false;
  SyncMode _editSyncMode = SyncMode.incremental;
  bool _editIsMediaSource = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // Aktuelle Aufgabenquelle in die Auswahl überführen.
  void _initEditSource(BackupTask task) {
    final src = task.sourcePath;
    _editIsMediaSource = !_isFilesSource(src);
    _editSyncMode = task.syncMode;
    _editAlbumSelection
      ..clear()
      ..addAll(task.selectedAlbums);
  }

  /// Dateien-Quellen (`files:`/`folders:`) sind im Inline-Edit bewusst
  /// nicht umschaltbar — Medien-Quellen bekommen die Albumliste.
  static bool _isFilesSource(String src) {
    final lower = src.toLowerCase();
    return lower.startsWith('files:') ||
        lower.startsWith('folders:') ||
        lower.startsWith('folders');
  }

  Future<void> _loadEditAlbums() async {
    setState(() => _editAlbumsLoading = true);
    try {
      final ps = await PhotoManager.requestPermissionExtend();
      if (ps.isAuth || ps.hasAccess) {
        final paths = await PhotoManager.getAssetPathList(
            type: RequestType.common, hasAll: true);
        final options = <_EditAlbumOption>[];
        for (final p in paths) {
          int? count;
          try {
            count = await p.assetCountAsync;
          } catch (_) {}
          // AUCH HIER: Alben ohne Inhalt gar nicht erst zeigen.
          if (count == 0) continue;
          options.add(_EditAlbumOption(p, count));
        }
        if (!mounted) return;
        setState(() {
          _editAlbumOptions = options;
          _editAlbumsLoading = false;
        });
      } else {
        if (mounted) setState(() => _editAlbumsLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _editAlbumsLoading = false);
    }
  }

  void _startInlineEdit(BackupTask task) {
    setState(() {
      _isEditing = true;
      _nameCtrl.text = task.name;
    });
    _initEditSource(task);
    if (_editIsMediaSource) {
      _loadEditAlbums();
    }
  }

  Future<void> _finishInlineEdit(BackupTask task) async {
    final newName = _nameCtrl.text.trim();
    String newSource = task.sourcePath;
    List<String> newAlbums = task.selectedAlbums;
    if (_editIsMediaSource) {
      // Gleiche Kodierung wie der Task-Wizard: „all:A|B“ bzw. „all“.
      if (_editAlbumSelection.isEmpty) {
        newSource = 'all';
        newAlbums = const [];
      } else {
        final ordered = _editAlbumOptions
            .map((o) => o.name)
            .where((n) => _editAlbumSelection.contains(n))
            .toList();
        // Falls ein gewähltes Album aktuell nicht (mehr) geladen werden kann,
        // bleibt es trotzdem in der Auswahl (kein stiller Datenverlust).
        for (final sel in _editAlbumSelection) {
          if (!ordered.contains(sel)) ordered.add(sel);
        }
        newSource = 'all:${ordered.join('|')}';
        newAlbums = ordered;
      }
    }
    final switchedToMirror =
        _editSyncMode == SyncMode.mirror && task.syncMode != SyncMode.mirror;
    final updated = task.copyWith(
      name: newName.isNotEmpty ? newName : task.name,
      sourcePath: newSource,
      selectedAlbums: newAlbums,
      syncMode: _editSyncMode,
    );
    ref.read(tasksListProvider.notifier).updateTask(task.id, updated);
    // Wechsel Inkrementell → Spiegelung: bestehende Cloud-Dateien beim
    // ersten Spiegel-Lauf adoptieren (kein Massen-Download in die Mediathek).
    if (switchedToMirror) {
      try {
        await ref.read(rcloneServiceProvider).markMirrorAdoption();
      } catch (_) {}
    }
    if (mounted) setState(() => _isEditing = false);
  }

  /// Anzeigename je Remote-ID auflösen (Registry); fehlende markieren.
  String _remoteLabelFor(String id) {
    final entry = ref.watch(remoteEntryProvider(id));
    if (entry != null) return entry.name;
    return '$id (${context.strings.remoteMissingBadge})';
  }

  String _joinRemoteNames(BackupTask task) =>
      task.targetRemotes.map(_remoteLabelFor).join(', ');

  Future<void> _handleSyncNow(BackupTask task) async {
    final strings = context.strings;
    setState(() {
      _isSyncing = true;
      _syncMessage = null;
    });

    try {
      // Nur diesen einzelnen Task synchronisieren (nicht die ganze Queue).
      await ref.read(activeJobProvider.notifier).triggerSyncTask(task.id);
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _syncMessage = strings.syncTriggeredSuccess;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _syncMessage = '${strings.error}: $e';
        });
      }
    }
  }

  /// Live-Fortschritt des aktuell laufenden Syncs – Apple-konform:
  /// Fortschrittsbalken, Prozentzahl, „x von y Dateien“ und aktuelle Datei.
  /// Zeigt nichts an, wenn gerade kein Sync läuft.
  Widget _buildLiveSyncProgress(
      BuildContext context, AppThemeData theme, AppStrings strings) {
    final job = ref.watch(activeJobProvider);
    final isSyncing = job.status == RcloneJobStatus.syncing ||
        job.status == RcloneJobStatus.pending;
    if (!isSyncing) return const SizedBox.shrink();

    final platform = defaultTargetPlatform;
    final pct = (job.percentage.clamp(0.0, 100.0) / 100).toDouble();

    final Widget bar;
    if (platform == TargetPlatform.windows) {
      bar = fluent.ProgressBar(value: job.percentage, activeColor: theme.accent);
    } else if (platform == TargetPlatform.iOS) {
      bar = ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          height: 6,
          child: Stack(
            children: [
              Container(color: cupertino.CupertinoColors.systemGrey5),
              FractionallySizedBox(
                widthFactor: pct,
                child: Container(color: theme.accent),
              ),
            ],
          ),
        ),
      );
    } else {
      bar = material.LinearProgressIndicator(value: pct, valueColor: material.AlwaysStoppedAnimation(theme.accent));
    }

    return Padding(
      padding: EdgeInsets.only(bottom: theme.md),
      child: Container(
        padding: EdgeInsets.all(theme.md),
        decoration: BoxDecoration(
          color: theme.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(theme.radiusSm),
          border: Border.all(color: theme.accent.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              job.currentFile.isEmpty ? strings.preparing : job.currentFile,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.textPrimary, fontSize: 13),
            ),
            SizedBox(height: theme.sm),
            bar,
            SizedBox(height: theme.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (job.itemsTotal > 0)
                  Text(
                    strings.syncItemsProgress(job.itemsDone, job.itemsTotal),
                    style: TextStyle(color: theme.textSecondary, fontSize: 12),
                  )
                else
                  const SizedBox.shrink(),
                Text(
                  '${job.percentage.toStringAsFixed(1)}%',
                  style: TextStyle(color: theme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// GitHub-Style Doppelbestätigung: Der Zielordner-Pfad muss EXAKT erneut
  /// eingegeben werden, bevor der Remote-Ordner rekursiv gelöscht wird.
  Future<void> _confirmAndPurgeRemoteFolder(BuildContext context, BackupTask task) async {
    final strings = context.strings;
    final theme = context.theme;
    final folder = task.targetFolderName.trim().replaceAll(RegExp(r'^/+|/+\$'), '');
    if (folder.isEmpty) return;
    if (task.targetRemotes.isEmpty) return;
    final remote = task.targetRemotes.first;
    final platform = defaultTargetPlatform;
    final typed = TextEditingController();
    var confirmed = false;

    Future<void> doPurge() async {
      Navigator.of(context).pop();
      try {
        await ref.read(rcloneServiceProvider).purgeRemoteDirectory(
              remoteName: remote,
              remotePath: folder,
            );
        ref.invalidate(remotesProvider);
        ref.invalidate(primaryQuotaProvider);
        if (mounted) setState(() => _syncMessage = strings.remoteFolderDeleted);
      } catch (e) {
        if (mounted) {
          setState(() => _syncMessage =
              '${strings.remoteFolderDeleteError} ${e.toString().replaceAll('Exception: ', '').trim()}');
        }
      }
    }

    if (platform == TargetPlatform.windows) {
      confirmed = false;
      await fluent.showDialog<void>(
        context: context,
        builder: (dialogCtx) => StatefulBuilder(
          builder: (ctx, setInner) => fluent.ContentDialog(
            title: fluent.Text(strings.deleteRemoteFolderLabel),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings.deleteRemoteFolderPrompt(folder)),
                const SizedBox(height: 12),
                fluent.TextBox(
                  controller: typed,
                  placeholder: folder,
                  onChanged: (_) => setInner(() {}),
                ),
              ],
            ),
            actions: [
              fluent.FilledButton(
                onPressed: typed.text.trim() == folder
                    ? () {
                        confirmed = true;
                        Navigator.pop(dialogCtx);
                      }
                    : null,
                child: Text(strings.delete, style: const TextStyle(color: Color(0xFFFFFFFF))),
              ),
              fluent.Button(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(strings.cancel),
              ),
            ],
          ),
        ),
      );
    } else if (platform == TargetPlatform.iOS) {
      await cupertino.showCupertinoDialog<void>(
        context: context,
        builder: (dialogCtx) => StatefulBuilder(
          builder: (ctx, setInner) => cupertino.CupertinoAlertDialog(
            title: Text(strings.deleteRemoteFolderLabel),
            content: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(strings.deleteRemoteFolderPrompt(folder), style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 10),
                  cupertino.CupertinoTextField(
                    controller: typed,
                    placeholder: folder,
                    onChanged: (_) => setInner(() {}),
                  ),
                ],
              ),
            ),
            actions: [
              cupertino.CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(strings.cancel),
              ),
              cupertino.CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: typed.text.trim() == folder
                    ? () {
                        confirmed = true;
                        Navigator.pop(dialogCtx);
                      }
                    : null,
                child: Text(strings.delete),
              ),
            ],
          ),
        ),
      );
    } else {
      await material.showDialog<void>(
        context: context,
        builder: (dialogCtx) => StatefulBuilder(
          builder: (ctx, setInner) => material.AlertDialog(
            title: Text(strings.deleteRemoteFolderLabel),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings.deleteRemoteFolderPrompt(folder), style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 10),
                material.TextField(
                  controller: typed,
                  decoration: material.InputDecoration(hintText: folder),
                  onChanged: (_) => setInner(() {}),
                ),
              ],
            ),
            actions: [
              material.TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(strings.cancel),
              ),
              material.FilledButton(
                style: material.FilledButton.styleFrom(backgroundColor: theme.error),
                onPressed: typed.text.trim() == folder
                    ? () {
                        confirmed = true;
                        Navigator.pop(dialogCtx);
                      }
                    : null,
                child: Text(strings.delete),
              ),
            ],
          ),
        ),
      );
    }

    typed.dispose();
    if (confirmed) await doPurge();
  }

  void _confirmDeleteTask(BuildContext context, BackupTask task, TargetPlatform platform) {
    final strings = context.strings;
    final title = strings.deleteTaskConfirmTitle;
    final message = '${strings.deleteTaskPrompt(task.name)}\n\n${strings.deleteTaskRule6Notice}';

    if (platform == TargetPlatform.windows) {
      fluent.showDialog(
        context: context,
        builder: (dialogCtx) => fluent.ContentDialog(
          title: fluent.Text(title),
          content: Text(message),
          actions: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 80, minHeight: 44),
                child: fluent.FilledButton(
                  onPressed: () {
                    ref.read(tasksListProvider.notifier).removeTask(task.id);
                    Navigator.pop(dialogCtx);
                    Navigator.pop(context);
                  },
                  child: Text(
                    strings.delete,
                    style: const TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 80, minHeight: 44),
                child: fluent.Button(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(strings.cancel),
                ),
              ),
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
              onPressed: () {
                ref.read(tasksListProvider.notifier).removeTask(task.id);
                Navigator.pop(dialogCtx);
                Navigator.pop(context);
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
              style: material.FilledButton.styleFrom(backgroundColor: context.theme.error),
              onPressed: () {
                ref.read(tasksListProvider.notifier).removeTask(task.id);
                Navigator.pop(dialogCtx);
                Navigator.pop(context);
              },
              child: Text(strings.delete),
            ),
          ],
        ),
      );
    }
  }

  void _openEditTask(BuildContext context, BackupTask task, TargetPlatform platform) {
    showAddEditTaskDialog(context, ref, task, platform);
  }

  String _formatSourcePath(AppStrings strings, String path) {
    if (path == 'all' || path == 'Alles') return strings.allMedia;
    if (path == 'photos' || path == 'Alle Fotos') return strings.allPhotos;
    if (path == 'videos' || path == 'Alle Videos') return strings.allVideos;
    if (path.startsWith('files:')) return strings.sourceTabFiles;
    if (path.startsWith('all:')) return '${strings.sourceTabPhotosVideos} (${path.split(':')[1].split('|').length} Alben)';
    if (path.startsWith('photos:')) return '${strings.allPhotos} (${path.split(':')[1].split('|').length})';
    if (path.startsWith('videos:')) return '${strings.allVideos} (${path.split(':')[1].split('|').length})';
    return path;
  }

  String _formatTargetFolder(AppStrings strings, BackupTask task) {
    if (task.targetFolderMode == TargetFolderMode.root) {
      return '/ (Root)';
    }
    final folder = task.targetFolderName.trim();
    if (folder.isEmpty || folder == '/') return '/ (Root)';
    return folder.startsWith('/') ? folder : '/$folder';
  }

  String _formatSyncMode(AppStrings strings, SyncMode mode) {
    if (mode == SyncMode.mirror) {
      return strings.syncModeMirror;
    }
    return strings.syncModeIncremental;
  }

  String _formatSyncModeDescription(AppStrings strings, SyncMode mode) {
    if (mode == SyncMode.mirror) {
      return strings.syncModeMirrorDescription;
    }
    return strings.syncModeIncrementalDescription;
  }

  String _formatYesNo(AppStrings strings, bool value) {
    return value ? (strings.isGerman ? 'Ja' : 'Yes') : (strings.isGerman ? 'Nein' : 'No');
  }

  @override
  Widget build(BuildContext context) {
    // Theme live verfolgen, damit Dark-/Light-/Palettenwechsel sofort greift.
    ref.watch(appThemeProvider);
    final tasks = ref.watch(tasksListProvider);
    final taskIndex = tasks.indexWhere((t) => t.id == widget.taskId);

    if (taskIndex == -1) {
      return const SizedBox.shrink();
    }

    final task = tasks[taskIndex];
    final platform = defaultTargetPlatform;

    if (platform == TargetPlatform.windows) {
      return _buildWindows(context, task);
    } else if (platform == TargetPlatform.iOS) {
      return _buildIOS(context, task);
    } else {
      return _buildAndroid(context, task);
    }
  }

  // =========================================================================
  // WINDOWS (Fluent UI)
  // =========================================================================
  Widget _buildWindows(BuildContext context, BackupTask task) {
    final theme = context.theme;
    final strings = context.strings;

    return fluent.ScaffoldPage.scrollable(
      header: fluent.PageHeader(
        title: fluent.Text(task.name),
        leading: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: fluent.IconButton(
              icon: const Icon(fluent.FluentIcons.back, semanticLabel: 'Back'),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        commandBar: fluent.CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            fluent.CommandBarButton(
              icon: Icon(fluent.FluentIcons.edit, semanticLabel: strings.editTask),
              label: Text(strings.editTask),
              onPressed: () => _openEditTask(context, task, TargetPlatform.windows),
            ),
          ],
        ),
      ),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLiveSyncProgress(context, theme, strings),
              if (_syncMessage != null) ...[
                fluent.InfoBar(
                  title: Text(_syncMessage!),
                  severity: fluent.InfoBarSeverity.info,
                  onClose: () => setState(() => _syncMessage = null),
                ),
                SizedBox(height: theme.md),
              ],
              
              // 1. Status Section
              fluent.Text(strings.generalSection, style: fluent.FluentTheme.of(context).typography.subtitle),
              SizedBox(height: theme.md),
              fluent.Card(
                child: Row(
                  children: [
                    Text(task.isActive ? strings.statusActive : strings.statusInactive, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    fluent.ToggleSwitch(
                      checked: task.isActive,
                      onChanged: (_) => ref.read(tasksListProvider.notifier).toggleTaskActive(task.id),
                    ),
                  ],
                ),
              ),
              SizedBox(height: theme.xl),

              // 2. Source & Target Section
              fluent.Text(strings.sourceAndTargetSection, style: fluent.FluentTheme.of(context).typography.subtitle),
              SizedBox(height: theme.md),
              fluent.Card(
                child: Column(
                  children: [
                    _buildWindowsInfoRow(strings.sourcePrefix, _formatSourcePath(strings, task.sourcePath), theme),
                    const SizedBox(height: 8),
                    const fluent.Divider(),
                    const SizedBox(height: 8),
                    _buildWindowsInfoRow(strings.destinationPrefix, _joinRemoteNames(task), theme),
                    const SizedBox(height: 8),
                    const fluent.Divider(),
                    const SizedBox(height: 8),
                    _buildWindowsInfoRow(strings.targetFolderLabel, _formatTargetFolder(strings, task), theme),
                    if (task.targetRemotes.length > 1) ...[
                      const SizedBox(height: 8),
                      const fluent.Divider(),
                      const SizedBox(height: 8),
                      _buildWindowsInfoRow(
                        strings.distributionLabel,
                        task.distributionStrategy == DistributionStrategy.mirrorAll
                            ? strings.distributionMirrorAll
                            : strings.distributionBalance,
                        theme,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: theme.xl),

              // 3. Sync Settings Section
              fluent.Text(strings.syncSettingsSection, style: fluent.FluentTheme.of(context).typography.subtitle),
              SizedBox(height: theme.md),
              fluent.Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWindowsInfoRow(strings.syncModeLabel, _formatSyncMode(strings, task.syncMode), theme),
                    SizedBox(height: theme.xs),
                    Text(
                      _formatSyncModeDescription(strings, task.syncMode),
                      style: TextStyle(fontSize: 12, color: theme.textSecondary),
                    ),
                  ],
                ),
              ),
              SizedBox(height: theme.xl),

              // 4. Schedule & Network Section
              fluent.Text(strings.scheduleAndNetworkSection, style: fluent.FluentTheme.of(context).typography.subtitle),
              SizedBox(height: theme.md),
              fluent.Card(
                child: Column(
                  children: [
                    _buildWindowsInfoRow(
                      strings.scheduleLabel,
                      strings.scheduleDescriptionFor(task.scheduleDay, task.scheduleTime),
                      theme,
                    ),
                    const SizedBox(height: 8),
                    const fluent.Divider(),
                    const SizedBox(height: 8),
                    _buildWindowsInfoRow(
                      strings.excludedFilesLabel,
                      task.excludedFiles.isNotEmpty ? task.excludedFiles.join(', ') : strings.noExcludedFiles,
                      theme,
                    ),
                  ],
                ),
              ),
              SizedBox(height: theme.xl),

              // 5. Action Buttons
              Row(
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 160, minHeight: 44),
                      child: fluent.FilledButton(
                        onPressed: _isSyncing ? null : () => _handleSyncNow(task),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isSyncing)
                              const SizedBox(width: 16, height: 16, child: fluent.ProgressRing())
                            else
                              const Icon(fluent.FluentIcons.sync, size: 16, color: Color(0xFFFFFFFF)),
                            SizedBox(width: theme.sm),
                            Text(
                              strings.syncTaskNow,
                              style: const TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
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
                      constraints: const BoxConstraints(minWidth: 140, minHeight: 44),
                      child: fluent.Button(
                        onPressed: () => _confirmDeleteTask(context, task, TargetPlatform.windows),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(fluent.FluentIcons.delete, size: 16, color: theme.error),
                            SizedBox(width: theme.sm),
                            Text(
                              strings.deleteTask,
                              style: TextStyle(color: theme.error, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: theme.sm),
              Row(
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 220, minHeight: 44),
                      child: fluent.Button(
                        onPressed: () => _confirmAndPurgeRemoteFolder(context, task),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(fluent.FluentIcons.delete, size: 16, color: theme.error),
                            SizedBox(width: theme.sm),
                            Text(
                              strings.deleteRemoteFolderLabel,
                              style: TextStyle(color: theme.error, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: theme.xl),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // IOS (Cupertino UI in Apple Minimalist Style)
  // =========================================================================
  Widget _buildIOS(BuildContext context, BackupTask task) {
    final theme = context.theme;
    final strings = context.strings;

    return cupertino.CupertinoPageScaffold(
      navigationBar: cupertino.CupertinoNavigationBar(
        // Nav-Titel sind laut HIG einzeilig; lange Namen kürzen wir sauber
        // mit Ellipse, statt sie unkontrolliert abzuschneiden.
        middle: Text(
          _isEditing ? _nameCtrl.text : task.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: cupertino.CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          onPressed: () {
            if (_isEditing) {
              _finishInlineEdit(task);
            } else {
              _startInlineEdit(task);
            }
          },
          child: Text(
            _isEditing ? strings.doneEditing : strings.editTaskInline,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(0, 0, 0, theme.lg),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(theme.lg, 0, theme.lg, 0),
                child: _buildLiveSyncProgress(context, theme, strings),
              ),
              if (_syncMessage != null)
                Padding(
                  padding: EdgeInsets.all(theme.md),
                  child: Container(
                    padding: EdgeInsets.all(theme.md),
                    decoration: BoxDecoration(
                      color: theme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(theme.radiusSm),
                    ),
                    child: Row(
                      children: [
                        Icon(cupertino.CupertinoIcons.info, color: theme.accent, size: 20),
                        SizedBox(width: theme.sm),
                        Expanded(child: Text(_syncMessage!, style: TextStyle(color: theme.accent, fontSize: 13))),
                      ],
                    ),
                  ),
                ),

              // 1. Status Section
              cupertino.CupertinoListSection.insetGrouped(
                header: IosTheme.sectionHeader(strings.generalSection, theme),
                children: [
                  if (_isEditing)
                    cupertino.CupertinoListTile(
                      leading: Icon(cupertino.CupertinoIcons.text_cursor, color: theme.accent, size: 22),
                      title: Text(strings.taskNameLabel, style: const TextStyle(fontSize: 16)),
                      trailing: SizedBox(
                        width: 170,
                        child: cupertino.CupertinoTextField(
                          controller: _nameCtrl,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ),
                  cupertino.CupertinoListTile(
                    leading: Icon(
                      task.isActive ? cupertino.CupertinoIcons.checkmark_alt_circle_fill : cupertino.CupertinoIcons.pause_circle_fill,
                      color: task.isActive ? theme.accent : theme.textSecondary,
                      size: 22,
                    ),
                    title: Text(strings.statusActive, style: const TextStyle(fontSize: 16)),
                    trailing: cupertino.CupertinoSwitch(
                      value: task.isActive,
                      onChanged: (_) => ref.read(tasksListProvider.notifier).toggleTaskActive(task.id),
                    ),
                  ),
                ],
              ),

              // 2. Source & Target Section
              cupertino.CupertinoListSection.insetGrouped(
                header: IosTheme.sectionHeader(strings.sourceAndTargetSection, theme),
                children: [
                  cupertino.CupertinoListTile(
                    leading: Icon(cupertino.CupertinoIcons.folder, color: theme.accent, size: 22),
                    title: Text(strings.sourcePrefix, style: const TextStyle(fontSize: 16)),
                    trailing: Text(
                      _formatSourcePath(strings, task.sourcePath),
                      style: TextStyle(color: theme.textSecondary, fontSize: 15),
                    ),
                  ),
                  cupertino.CupertinoListTile(
                    leading: Icon(cupertino.CupertinoIcons.cloud, color: theme.accent, size: 22),
                    title: Text(strings.destinationPrefix, style: const TextStyle(fontSize: 16)),
                    trailing: Text(
                      _joinRemoteNames(task),
                      style: TextStyle(color: theme.textSecondary, fontSize: 15),
                    ),
                  ),
                  cupertino.CupertinoListTile(
                    leading: Icon(cupertino.CupertinoIcons.folder_badge_plus, color: theme.accent, size: 22),
                    title: Text(strings.targetFolderLabel, style: const TextStyle(fontSize: 16)),
                    trailing: Text(
                      _formatTargetFolder(strings, task),
                      style: TextStyle(color: theme.textSecondary, fontSize: 14),
                    ),
                  ),
                  if (task.targetRemotes.length > 1)
                    cupertino.CupertinoListTile(
                      title: Text(strings.distributionLabel, style: const TextStyle(fontSize: 16)),
                      trailing: Text(
                        task.distributionStrategy == DistributionStrategy.mirrorAll
                            ? strings.distributionMirrorAll
                            : strings.distributionBalance,
                        style: TextStyle(color: theme.textSecondary, fontSize: 14),
                      ),
                    ),
                ],
              ),

              // 2b. Album-Auswahl — nur im Bearbeiten-Modus, nur für
              // Medien-Quellen: ausschließlich die Albenliste (mit Zähler,
              // leere Alben ausgeblendet, vorhandene Auswahl vorgehakt).
              if (_isEditing && _editIsMediaSource)
                cupertino.CupertinoListSection.insetGrouped(
                  header: IosTheme.sectionHeader(strings.albumsSectionTitle, theme),
                  footer: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(strings.albumsEditNote),
                  ),
                  children: [
                    if (_editAlbumsLoading)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: cupertino.CupertinoActivityIndicator()),
                      )
                    else if (_editAlbumOptions.isEmpty)
                      Padding(
                        padding: EdgeInsets.all(theme.md),
                        child: Text(
                          strings.noAlbumsFound,
                          style: TextStyle(color: theme.textSecondary, fontSize: 13),
                        ),
                      )
                    else
                      ...() {
                        // Gewählte, gerade nicht ladbare Alben (z. B. gelöscht)
                        // sichtbar halten, damit sie nicht still verschwinden.
                        final known = _editAlbumOptions.map((o) => o.name).toSet();
                        final stale = _editAlbumSelection
                            .where((n) => !known.contains(n))
                            .toList();
                        final rows = <Widget>[
                          for (final o in _editAlbumOptions)
                            (() {
                              final checked = _editAlbumSelection.contains(o.name);
                              return cupertino.CupertinoListTile(
                                title: Text(o.name, style: const TextStyle(fontSize: 14)),
                                subtitle: o.count != null
                                    ? Text('${o.count}',
                                        style: TextStyle(color: theme.textSecondary, fontSize: 12))
                                    : null,
                                trailing: checked
                                    ? Icon(cupertino.CupertinoIcons.check_mark_circled_solid,
                                        color: theme.accent, size: 22)
                                    : Icon(cupertino.CupertinoIcons.circle,
                                        color: theme.textSecondary, size: 22),
                                onTap: () {
                                  setState(() {
                                    if (checked) {
                                      _editAlbumSelection.remove(o.name);
                                    } else {
                                      _editAlbumSelection.add(o.name);
                                    }
                                  });
                                },
                              );
                            })(),
                          for (final name in stale)
                            cupertino.CupertinoListTile(
                              title: Text(
                                '$name (${strings.remoteMissingBadge})',
                                style: TextStyle(fontSize: 14, color: theme.textSecondary),
                              ),
                              trailing: Icon(cupertino.CupertinoIcons.check_mark_circled_solid,
                                  color: theme.accent, size: 22),
                              onTap: () {
                                setState(() => _editAlbumSelection.remove(name));
                              },
                            ),
                        ];
                        return rows;
                      }(),
                  ],
                ),

              // 3. Sync Mode Section — im Bearbeiten-Modus umschaltbar
              // (Inkrementell ↔ Spiegelung). Beim Wechsel AUF Spiegelung
              // werden bestehende Cloud-Dateien beim ersten Lauf adoptiert.
              cupertino.CupertinoListSection.insetGrouped(
                header: IosTheme.sectionHeader(strings.syncSettingsSection, theme),
                footer: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    () {
                      if (!_isEditing) {
                        return _formatSyncModeDescription(strings, task.syncMode);
                      }
                      final shown = _editSyncMode == SyncMode.mirror
                          ? strings.syncModeMirrorDescription
                          : strings.syncModeIncrementalDescription;
                      final switchedToMirror = _editSyncMode == SyncMode.mirror &&
                          task.syncMode != SyncMode.mirror;
                      return switchedToMirror
                          ? '$shown\n\n${strings.mirrorDeletionWarningEdit}\n${strings.mirrorAdoptionHint}\n\n${strings.syncModeChangedNote}'
                          : '$shown\n\n${strings.syncModeChangedNote}';
                    }(),
                  ),
                ),
                children: [
                  cupertino.CupertinoListTile(
                    leading: Icon(
                      (_isEditing ? _editSyncMode : task.syncMode) == SyncMode.mirror
                          ? cupertino.CupertinoIcons.arrow_2_squarepath
                          : cupertino.CupertinoIcons.arrow_up_circle,
                      color: theme.accent,
                      size: 22,
                    ),
                    title: Text(strings.syncModeLabel, style: const TextStyle(fontSize: 16)),
                    trailing: _isEditing
                        ? cupertino.CupertinoSlidingSegmentedControl<SyncMode>(
                            groupValue: _editSyncMode,
                            children: {
                              SyncMode.incremental: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(strings.syncModeBadgeIncremental,
                                    style: const TextStyle(fontSize: 13)),
                              ),
                              SyncMode.mirror: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(strings.syncModeBadgeMirror,
                                    style: const TextStyle(fontSize: 13)),
                              ),
                            },
                            onValueChanged: (v) {
                              if (v == null) return;
                              setState(() => _editSyncMode = v);
                            },
                          )
                        : Text(
                            _formatSyncMode(strings, task.syncMode),
                            style: TextStyle(color: theme.textSecondary, fontSize: 15),
                          ),
                  ),
                ],
              ),

              // 4. Schedule & Network Section
              cupertino.CupertinoListSection.insetGrouped(
                header: IosTheme.sectionHeader(strings.scheduleAndNetworkSection, theme),
                children: [
                  cupertino.CupertinoListTile(
                    leading: Icon(cupertino.CupertinoIcons.clock, color: theme.accent, size: 22),
                    title: Text(strings.scheduleLabel, style: const TextStyle(fontSize: 16)),
                    trailing: Text(
                      strings.scheduleDescriptionFor(task.scheduleDay, task.scheduleTime),
                      style: TextStyle(color: theme.textSecondary, fontSize: 15),
                    ),
                  ),
                  cupertino.CupertinoListTile(
                    leading: Icon(cupertino.CupertinoIcons.slider_horizontal_3, color: theme.accent, size: 22),
                    title: Text(strings.excludedFilesLabel, style: const TextStyle(fontSize: 16)),
                    trailing: Text(
                      task.excludedFiles.isNotEmpty ? task.excludedFiles.join(', ') : strings.noExcludedFiles,
                      style: TextStyle(color: theme.textSecondary, fontSize: 14),
                    ),
                  ),
                ],
              ),

              // 5a. Sync Section (sync ist bewusst NICHT im Löschbereich)
              cupertino.CupertinoListSection.insetGrouped(
                header: IosTheme.sectionHeader(strings.syncSection, theme),
                children: [
                  cupertino.CupertinoListTile(
                    leading: _isSyncing
                        ? const cupertino.CupertinoActivityIndicator()
                        : Icon(cupertino.CupertinoIcons.arrow_2_circlepath, color: theme.accent, size: 22),
                    title: Text(
                      strings.syncTaskNow,
                      style: TextStyle(color: theme.accent, fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    onTap: _isSyncing ? null : () => _handleSyncNow(task),
                  ),
                ],
              ),

              // 5b. Danger Zone (Lösch-Aktionen existieren nur im Bearbeiten-Modus)
              if (_isEditing)
              cupertino.CupertinoListSection.insetGrouped(
                header: IosTheme.sectionHeader(strings.dangerZone, theme),
                children: [
                  cupertino.CupertinoListTile(
                    leading: Icon(cupertino.CupertinoIcons.trash, color: theme.error, size: 22),
                    title: Text(
                      strings.deleteTask,
                      style: TextStyle(color: theme.error, fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    onTap: () => _confirmDeleteTask(context, task, TargetPlatform.iOS),
                  ),
                  cupertino.CupertinoListTile(
                    leading: Icon(cupertino.CupertinoIcons.cloud_bolt_fill, color: theme.error, size: 22),
                    title: Text(
                      strings.deleteRemoteFolderLabel,
                      style: TextStyle(color: theme.error, fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    onTap: () => _confirmAndPurgeRemoteFolder(context, task),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // ANDROID (Material 3 UI)
  // =========================================================================
  Widget _buildAndroid(BuildContext context, BackupTask task) {
    final theme = context.theme;
    final strings = context.strings;

    return material.Scaffold(
      appBar: material.AppBar(
        title: Text(task.name),
        actions: [
          material.IconButton(
            icon: const Icon(material.Icons.edit_outlined),
            onPressed: () => _openEditTask(context, task, TargetPlatform.android),
            tooltip: strings.editTask,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(theme.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildLiveSyncProgress(context, theme, strings),
            if (_syncMessage != null) ...[
              material.MaterialBanner(
                content: Text(_syncMessage!),
                backgroundColor: theme.accent.withValues(alpha: 0.15),
                leading: Icon(material.Icons.info_outline, color: theme.accent),
                actions: [
                  material.TextButton(
                    onPressed: () => setState(() => _syncMessage = null),
                    child: Text(strings.close),
                  ),
                ],
              ),
              SizedBox(height: theme.md),
            ],

            // 1. Status Section
            Text(strings.generalSection, style: material.Theme.of(context).textTheme.titleSmall),
            SizedBox(height: theme.md),
            material.Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(theme.radiusLg),
                side: BorderSide(color: material.Theme.of(context).colorScheme.outlineVariant),
              ),
              child: material.SwitchListTile(
                title: Text(strings.statusActive, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(task.isActive ? strings.statusActive : strings.statusInactive),
                value: task.isActive,
                onChanged: (_) => ref.read(tasksListProvider.notifier).toggleTaskActive(task.id),
              ),
            ),
            SizedBox(height: theme.lg),

            // 2. Source & Target Section
            Text(strings.sourceAndTargetSection, style: material.Theme.of(context).textTheme.titleSmall),
            SizedBox(height: theme.md),
            material.Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(theme.radiusLg),
                side: BorderSide(color: material.Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  material.ListTile(
                    leading: Icon(material.Icons.folder_outlined, color: theme.accent),
                    title: Text(strings.sourcePrefix),
                    trailing: Text(_formatSourcePath(strings, task.sourcePath)),
                  ),
                  const material.Divider(height: 1),
                  material.ListTile(
                    leading: Icon(material.Icons.cloud_outlined, color: theme.accent),
                    title: Text(strings.destinationPrefix),
                    trailing: Text(_joinRemoteNames(task), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const material.Divider(height: 1),
                  material.ListTile(
                    leading: Icon(material.Icons.drive_file_move_outlined, color: theme.accent),
                    title: Text(strings.targetFolderLabel),
                    trailing: Text(_formatTargetFolder(strings, task)),
                  ),
                  if (task.targetRemotes.length > 1) ...[
                    const material.Divider(height: 1),
                    material.ListTile(
                      title: Text(strings.distributionLabel),
                      trailing: Text(
                        task.distributionStrategy == DistributionStrategy.mirrorAll
                            ? strings.distributionMirrorAll
                            : strings.distributionBalance,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: theme.lg),

            // 3. Sync Mode Section
            Text(strings.syncSettingsSection, style: material.Theme.of(context).textTheme.titleSmall),
            SizedBox(height: theme.md),
            material.Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(theme.radiusLg),
                side: BorderSide(color: material.Theme.of(context).colorScheme.outlineVariant),
              ),
              child: material.ListTile(
                leading: Icon(
                  task.syncMode == SyncMode.mirror ? material.Icons.sync : material.Icons.arrow_upward,
                  color: theme.accent,
                ),
                title: Text(strings.syncModeLabel),
                subtitle: Text(_formatSyncModeDescription(strings, task.syncMode)),
                trailing: Text(_formatSyncMode(strings, task.syncMode), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(height: theme.lg),

            // 4. Schedule & Network Section
            Text(strings.scheduleAndNetworkSection, style: material.Theme.of(context).textTheme.titleSmall),
            SizedBox(height: theme.md),
            material.Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(theme.radiusLg),
                side: BorderSide(color: material.Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  material.ListTile(
                    leading: Icon(material.Icons.schedule, color: theme.accent),
                    title: Text(strings.scheduleLabel),
                    trailing: Text(strings.scheduleDescriptionFor(task.scheduleDay, task.scheduleTime)),
                  ),
                  const material.Divider(height: 1),
                  material.ListTile(
                    leading: Icon(material.Icons.filter_alt_outlined, color: theme.accent),
                    title: Text(strings.excludedFilesLabel),
                    trailing: Text(
                      task.excludedFiles.isNotEmpty ? task.excludedFiles.join(', ') : strings.noExcludedFiles,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: theme.xl),

            // 5. Action Buttons
            Row(
              children: [
                Expanded(
                  child: material.FilledButton.icon(
                    icon: _isSyncing
                        ? const SizedBox(width: 18, height: 18, child: material.CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFFFFF)))
                        : const Icon(material.Icons.sync),
                    label: Text(strings.syncTaskNow),
                    onPressed: _isSyncing ? null : () => _handleSyncNow(task),
                  ),
                ),
              ],
            ),
            SizedBox(height: theme.sm),
            Row(
              children: [
                Expanded(
                  child: material.OutlinedButton.icon(
                    icon: Icon(material.Icons.delete_outline, color: theme.error),
                    label: Text(strings.deleteTask, style: TextStyle(color: theme.error)),
                    onPressed: () => _confirmDeleteTask(context, task, TargetPlatform.android),
                  ),
                ),
              ],
            ),
            SizedBox(height: theme.sm),
            Row(
              children: [
                Expanded(
                  child: material.OutlinedButton.icon(
                    icon: Icon(material.Icons.cloud_off, color: theme.error),
                    label: Text(
                      strings.deleteRemoteFolderLabel,
                      style: TextStyle(color: theme.error),
                    ),
                    onPressed: () => _confirmAndPurgeRemoteFolder(context, task),
                  ),
                ),
              ],
            ),
            SizedBox(height: theme.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildWindowsInfoRow(String label, String value, AppThemeData theme) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(value, style: TextStyle(color: theme.textSecondary)),
      ],
    );
  }
}

/// Album-Zeile im Inline-Edit: Name + optionaler Medienzähler
/// (leere Alben werden bereits beim Laden herausgefiltert).
class _EditAlbumOption {
  _EditAlbumOption(this.entity, this.count);

  final AssetPathEntity entity;
  final int? count;

  String get name => entity.name;
}

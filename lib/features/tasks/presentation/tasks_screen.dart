import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../theme/theme.dart';
import '../../../core/services/rclone_provider.dart';
import '../../../core/localization/app_strings.dart';
import 'tasks_controller.dart';

/// Platform-adaptive Tasks and Backup Jobs screen.
/// Renders layout dynamically based on current platform:
/// - Windows (Fluent Design)
/// - iOS (Cupertino with modal CupertinoPageScaffold sheet)
/// - Android (Material 3)
/// Allows viewing, adding, editing, and deleting backup tasks with multi-remote targets,
/// distribution strategy, target folder mode, and Rule 6 compliance.
class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platform = defaultTargetPlatform;

    if (platform == TargetPlatform.windows) {
      return _buildWindows(context, ref);
    } else if (platform == TargetPlatform.iOS) {
      return _buildIOS(context, ref);
    } else {
      return _buildAndroid(context, ref);
    }
  }

  // =========================================================================
  // WINDOWS (Fluent UI)
  // =========================================================================
  Widget _buildWindows(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final strings = ref.watch(stringsProvider);
    final tasks = ref.watch(tasksListProvider);

    return fluent.ScaffoldPage(
      header: fluent.PageHeader(
        title: fluent.Text(
          strings.tasksTitle,
          style: fluent.FluentTheme.of(context).typography.title,
        ),
        commandBar: fluent.CommandBar(
          primaryItems: [
            fluent.CommandBarButton(
              icon: Icon(fluent.FluentIcons.add, semanticLabel: strings.addTask),
              label: Text(strings.addTask),
              onPressed: () => _showAddEditTaskDialog(context, ref, null, TargetPlatform.windows),
            ),
          ],
        ),
      ),
      content: tasks.isEmpty
          ? _buildEmptyState(context, ref, TargetPlatform.windows, theme, strings)
          : ListView.separated(
              padding: EdgeInsets.all(theme.lg),
              itemCount: tasks.length,
              separatorBuilder: (_, __) => SizedBox(height: theme.md),
              itemBuilder: (context, index) {
                final task = tasks[index];
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: fluent.Card(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: theme.xs),
                          child: Icon(
                            fluent.FluentIcons.task_manager,
                            size: 28,
                            color: theme.accent,
                            semanticLabel: strings.tasksTitle,
                          ),
                        ),
                        SizedBox(width: theme.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              SizedBox(height: theme.xs),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${strings.sourcePrefix} ',
                                      style: TextStyle(
                                        color: theme.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextSpan(
                                      text: _formatSourcePath(strings, task.sourcePath),
                                      style: TextStyle(color: theme.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: theme.xs / 2),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: theme.xs,
                                runSpacing: theme.xs / 2,
                                children: [
                                  Text(
                                    '${strings.destinationPrefix} ',
                                    style: TextStyle(
                                      color: theme.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  _buildRemoteChips(context, theme, task.targetRemotes),
                                  Text(
                                    '(${_formatTargetFolder(strings, task)})',
                                    style: TextStyle(color: theme.textSecondary, fontSize: 11),
                                  ),
                                ],
                              ),
                              SizedBox(height: theme.sm),
                              Wrap(
                                spacing: theme.sm,
                                runSpacing: theme.xs,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _buildSyncModeBadge(context, theme, strings, task.syncMode),
                                  if (task.targetRemotes.length > 1)
                                    _buildDistributionBadge(context, theme, strings, task.distributionStrategy),
                                  _buildScheduleBadge(context, theme, strings, task),
                                  if (task.excludedFiles.isNotEmpty)
                                    _buildExcludedFilesBadge(context, theme, strings, task.excludedFiles),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: theme.md),
                        SizedBox(
                          height: 44,
                          child: fluent.ToggleSwitch(
                            checked: task.isActive,
                            content: Text(task.isActive ? strings.active : strings.paused),
                            onChanged: (_) {
                              ref.read(tasksListProvider.notifier).toggleTaskActive(task.id);
                            },
                          ),
                        ),
                        SizedBox(width: theme.lg),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: fluent.IconButton(
                              icon: Icon(fluent.FluentIcons.edit, semanticLabel: strings.editTask),
                              onPressed: () => _showAddEditTaskDialog(context, ref, task, TargetPlatform.windows),
                            ),
                          ),
                        ),
                        SizedBox(width: theme.xs),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: fluent.IconButton(
                              icon: Icon(
                                fluent.FluentIcons.delete,
                                color: theme.error,
                                semanticLabel: strings.deleteTask,
                              ),
                              onPressed: () => _confirmDeleteTask(context, ref, task, TargetPlatform.windows),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  // =========================================================================
  // IOS (Cupertino UI)
  // =========================================================================
  Widget _buildIOS(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final strings = ref.watch(stringsProvider);
    final tasks = ref.watch(tasksListProvider);

    return cupertino.CupertinoPageScaffold(
      navigationBar: cupertino.CupertinoNavigationBar(
        middle: Text(strings.tasksTitle),
        trailing: SizedBox(
          width: 44,
          height: 44,
          child: cupertino.CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _showAddEditTaskDialog(context, ref, null, TargetPlatform.iOS),
            child: Icon(cupertino.CupertinoIcons.add, semanticLabel: strings.addTask),
          ),
        ),
      ),
      child: SafeArea(
        child: tasks.isEmpty
            ? _buildEmptyState(context, ref, TargetPlatform.iOS, theme, strings)
            : SingleChildScrollView(
                child: cupertino.CupertinoListSection.insetGrouped(
                  header: Text(strings.backupJobsHeader),
                  children: tasks.map((task) {
                    return cupertino.CupertinoListTile.notched(
                      title: Text(task.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: theme.xs / 2),
                          Text(
                            '${strings.sourcePrefix} ${_formatSourcePath(strings, task.sourcePath)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: theme.xs / 2),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: theme.xs,
                            runSpacing: theme.xs / 2,
                            children: [
                              Text(
                                '${strings.destinationPrefix} ',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              _buildRemoteChips(context, theme, task.targetRemotes),
                              Text(
                                '(${_formatTargetFolder(strings, task)})',
                                style: TextStyle(color: theme.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                          SizedBox(height: theme.xs),
                          Wrap(
                            spacing: theme.sm,
                            runSpacing: theme.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _buildSyncModeBadge(context, theme, strings, task.syncMode),
                              if (task.targetRemotes.length > 1)
                                _buildDistributionBadge(context, theme, strings, task.distributionStrategy),
                              _buildScheduleBadge(context, theme, strings, task),
                              if (task.excludedFiles.isNotEmpty)
                                _buildExcludedFilesBadge(context, theme, strings, task.excludedFiles),
                            ],
                          ),
                        ],
                      ),
                      leading: Icon(
                        cupertino.CupertinoIcons.list_bullet_indent,
                        color: theme.accent,
                        semanticLabel: strings.tasksTitle,
                      ),
                      additionalInfo: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(
                              child: cupertino.CupertinoSwitch(
                                value: task.isActive,
                                onChanged: (_) {
                                  ref.read(tasksListProvider.notifier).toggleTaskActive(task.id);
                                },
                              ),
                            ),
                          ),
                          SizedBox(width: theme.xs),
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: cupertino.CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => _showAddEditTaskDialog(context, ref, task, TargetPlatform.iOS),
                              child: Icon(
                                cupertino.CupertinoIcons.pencil_circle,
                                color: theme.accent,
                                semanticLabel: strings.editTask,
                              ),
                            ),
                          ),
                          SizedBox(width: theme.xs),
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: cupertino.CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => _confirmDeleteTask(context, ref, task, TargetPlatform.iOS),
                              child: Icon(
                                cupertino.CupertinoIcons.trash_circle,
                                color: theme.error,
                                semanticLabel: strings.deleteTask,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
      ),
    );
  }

  // =========================================================================
  // ANDROID (Material 3 UI)
  // =========================================================================
  Widget _buildAndroid(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final strings = ref.watch(stringsProvider);
    final tasks = ref.watch(tasksListProvider);

    return material.Scaffold(
      appBar: material.AppBar(
        title: Text(strings.tasksTitle),
      ),
      body: tasks.isEmpty
          ? _buildEmptyState(context, ref, TargetPlatform.android, theme, strings)
          : ListView.separated(
              padding: EdgeInsets.all(theme.lg),
              itemCount: tasks.length,
              separatorBuilder: (_, __) => SizedBox(height: theme.sm),
              itemBuilder: (context, index) {
                final task = tasks[index];
                return material.Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(theme.radiusLg),
                    side: BorderSide(color: material.Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: material.ListTile(
                    leading: Icon(
                      material.Icons.backup_outlined,
                      color: theme.accent,
                      semanticLabel: strings.tasksTitle,
                    ),
                    title: Text(task.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: theme.xs),
                        Text('${strings.sourcePrefix} ${_formatSourcePath(strings, task.sourcePath)}'),
                        SizedBox(height: theme.xs / 2),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: theme.xs,
                          runSpacing: theme.xs / 2,
                          children: [
                            Text(
                              '${strings.destinationPrefix} ',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            _buildRemoteChips(context, theme, task.targetRemotes),
                            Text(
                              '(${_formatTargetFolder(strings, task)})',
                              style: TextStyle(color: theme.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                        SizedBox(height: theme.xs),
                        Wrap(
                          spacing: theme.sm,
                          runSpacing: theme.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildSyncModeBadge(context, theme, strings, task.syncMode),
                            if (task.targetRemotes.length > 1)
                              _buildDistributionBadge(context, theme, strings, task.distributionStrategy),
                            _buildScheduleBadge(context, theme, strings, task),
                            if (task.excludedFiles.isNotEmpty)
                              _buildExcludedFilesBadge(context, theme, strings, task.excludedFiles),
                          ],
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: material.Switch(
                              value: task.isActive,
                              onChanged: (_) {
                                ref.read(tasksListProvider.notifier).toggleTaskActive(task.id);
                              },
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: material.PopupMenuButton<String>(
                            icon: Icon(
                              material.Icons.more_vert,
                              semanticLabel: strings.editTask,
                            ),
                            onSelected: (value) {
                              if (value == 'edit') {
                                _showAddEditTaskDialog(context, ref, task, TargetPlatform.android);
                              } else if (value == 'delete') {
                                _confirmDeleteTask(context, ref, task, TargetPlatform.android);
                              }
                            },
                            itemBuilder: (context) => [
                              material.PopupMenuItem(
                                value: 'edit',
                                child: Text(strings.editTask),
                              ),
                              material.PopupMenuItem(
                                value: 'delete',
                                child: Text(strings.deleteTask, style: TextStyle(color: theme.error)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: SizedBox(
        width: 56,
        height: 56,
        child: material.FloatingActionButton(
          tooltip: strings.addTask,
          backgroundColor: theme.accent,
          onPressed: () => _showAddEditTaskDialog(context, ref, null, TargetPlatform.android),
          child: const Icon(material.Icons.add, color: Color(0xFFFFFFFF), semanticLabel: 'Add Task'),
        ),
      ),
    );
  }

  // =========================================================================
  // COMMON EMPTY STATE (With CTA Button)
  // =========================================================================
  Widget _buildEmptyState(
    BuildContext context,
    WidgetRef ref,
    TargetPlatform platform,
    AppThemeData theme,
    AppStrings strings,
  ) {
    final iconData = platform == TargetPlatform.windows
        ? fluent.FluentIcons.task_manager
        : (platform == TargetPlatform.iOS ? cupertino.CupertinoIcons.list_bullet : material.Icons.list_alt);

    final Widget ctaButton;
    if (platform == TargetPlatform.windows) {
      ctaButton = SizedBox(
        height: 44,
        child: fluent.FilledButton(
          onPressed: () => _showAddEditTaskDialog(context, ref, null, TargetPlatform.windows),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(fluent.FluentIcons.add, size: 16, color: Color(0xFFFFFFFF)),
              SizedBox(width: theme.sm),
              Text(
                strings.addTask,
                style: const TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    } else if (platform == TargetPlatform.iOS) {
      ctaButton = SizedBox(
        height: 44,
        child: cupertino.CupertinoButton.filled(
          padding: EdgeInsets.symmetric(horizontal: theme.lg),
          onPressed: () => _showAddEditTaskDialog(context, ref, null, TargetPlatform.iOS),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(cupertino.CupertinoIcons.add, size: 16, color: Color(0xFFFFFFFF)),
              SizedBox(width: theme.sm),
              Text(
                strings.addTask,
                style: const TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    } else {
      ctaButton = SizedBox(
        height: 44,
        child: material.FilledButton.icon(
          onPressed: () => _showAddEditTaskDialog(context, ref, null, TargetPlatform.android),
          icon: const Icon(material.Icons.add, size: 18, color: Color(0xFFFFFFFF)),
          label: Text(
            strings.addTask,
            style: const TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: EdgeInsets.all(theme.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              iconData,
              size: 64,
              color: theme.textSecondary,
              semanticLabel: strings.noTasksConfigured,
            ),
            SizedBox(height: theme.md),
            Text(
              strings.noTasksConfigured,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: theme.sm),
            Text(
              strings.noTasksDescription,
              style: TextStyle(color: theme.textSecondary),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: theme.lg),
            ctaButton,
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // REMOTE CHIPS (Multiple Cloud Remotes Tags)
  // =========================================================================
  Widget _buildRemoteChips(
    BuildContext context,
    AppThemeData theme,
    List<String> remotes,
  ) {
    if (remotes.isEmpty) return const SizedBox.shrink();

    final IconData cloudIcon;
    if (defaultTargetPlatform == TargetPlatform.windows) {
      cloudIcon = fluent.FluentIcons.cloud;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      cloudIcon = cupertino.CupertinoIcons.cloud_fill;
    } else {
      cloudIcon = material.Icons.cloud_outlined;
    }

    return Wrap(
      spacing: theme.xs,
      runSpacing: theme.xs / 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: remotes.map((remote) {
        final cleanName = remote.split(':').first;
        return Container(
          padding: EdgeInsets.symmetric(horizontal: theme.xs, vertical: theme.xs / 3),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(theme.radiusSm),
            border: Border.all(color: theme.textSecondary.withValues(alpha: 0.25), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                cloudIcon,
                size: 11,
                color: theme.accent,
                semanticLabel: cleanName,
              ),
              SizedBox(width: theme.xs / 2),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  cleanName,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // =========================================================================
  // DISTRIBUTION STRATEGY BADGE
  // =========================================================================
  Widget _buildDistributionBadge(
    BuildContext context,
    AppThemeData theme,
    AppStrings strings,
    DistributionStrategy strategy,
  ) {
    final isMirrorAll = strategy == DistributionStrategy.mirrorAll;
    final badgeColor = theme.accent;
    final labelText = isMirrorAll ? strings.distributionBadgeMirrorAll : strings.distributionBadgeBalance;
    final tooltipText = isMirrorAll ? strings.distributionMirrorAllDesc : strings.distributionBalanceDesc;

    final IconData badgeIcon;
    if (defaultTargetPlatform == TargetPlatform.windows) {
      badgeIcon = isMirrorAll ? fluent.FluentIcons.copy : fluent.FluentIcons.split;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      badgeIcon = isMirrorAll ? cupertino.CupertinoIcons.square_on_square : cupertino.CupertinoIcons.arrow_branch;
    } else {
      badgeIcon = isMirrorAll ? material.Icons.content_copy : material.Icons.alt_route;
    }

    return material.Tooltip(
      message: tooltipText,
      waitDuration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(theme.radiusSm),
        border: Border.all(color: badgeColor.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: theme.canvas.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      textStyle: TextStyle(
        color: theme.textPrimary,
        fontSize: 11,
        fontWeight: FontWeight.normal,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: theme.sm, vertical: theme.xs / 2),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(theme.radiusSm),
          border: Border.all(color: badgeColor.withValues(alpha: 0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              badgeIcon,
              size: 11,
              color: badgeColor,
              semanticLabel: labelText,
            ),
            SizedBox(width: theme.xs),
            Text(
              labelText,
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // SYNC MODE BADGE (Incremental vs Mirror/Echo)
  // =========================================================================
  Widget _buildSyncModeBadge(
    BuildContext context,
    AppThemeData theme,
    AppStrings strings,
    SyncMode mode,
  ) {
    final isMirror = mode == SyncMode.mirror;
    final badgeColor = isMirror ? theme.warning : theme.accent;
    final labelText = isMirror ? strings.syncModeBadgeMirror : strings.syncModeBadgeIncremental;
    final tooltipText = isMirror ? strings.syncModeTooltipMirror : strings.syncModeTooltipIncremental;

    final IconData badgeIcon;
    if (defaultTargetPlatform == TargetPlatform.windows) {
      badgeIcon = isMirror ? fluent.FluentIcons.warning : fluent.FluentIcons.sync;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      badgeIcon = isMirror ? cupertino.CupertinoIcons.exclamationmark_triangle_fill : cupertino.CupertinoIcons.arrow_2_circlepath;
    } else {
      badgeIcon = isMirror ? material.Icons.warning_amber_rounded : material.Icons.sync;
    }

    return material.Tooltip(
      message: tooltipText,
      waitDuration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(theme.radiusSm),
        border: Border.all(color: badgeColor.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: theme.canvas.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      textStyle: TextStyle(
        color: theme.textPrimary,
        fontSize: 11,
        fontWeight: FontWeight.normal,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: theme.sm, vertical: theme.xs / 2),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(theme.radiusSm),
          border: Border.all(color: badgeColor.withValues(alpha: 0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              badgeIcon,
              size: 11,
              color: badgeColor,
              semanticLabel: labelText,
            ),
            SizedBox(width: theme.xs),
            Text(
              labelText,
              style: TextStyle(
                color: isMirror ? theme.warning : theme.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // SCHEDULE BADGE
  // =========================================================================
  Widget _buildScheduleBadge(
    BuildContext context,
    AppThemeData theme,
    AppStrings strings,
    BackupTask task,
  ) {
    final scheduleText = _formatScheduleDescription(strings, task);
    return material.Tooltip(
      message: strings.tooltipSchedule,
      waitDuration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(theme.radiusSm),
        border: Border.all(color: theme.textSecondary.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: theme.canvas.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      textStyle: TextStyle(
        color: theme.textPrimary,
        fontSize: 11,
        fontWeight: FontWeight.normal,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: theme.sm,
          vertical: theme.xs / 2,
        ),
        decoration: BoxDecoration(
          color: theme.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(theme.radiusSm),
        ),
        child: Text(
          scheduleText,
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // CONTEXTUAL INFO TOOLTIP (ℹ️)
  // =========================================================================
  Widget _buildInfoTooltip(
    BuildContext context,
    AppThemeData theme,
    String tooltipText,
  ) {
    final IconData infoIcon;
    if (defaultTargetPlatform == TargetPlatform.windows) {
      infoIcon = fluent.FluentIcons.info;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      infoIcon = cupertino.CupertinoIcons.info_circle;
    } else {
      infoIcon = material.Icons.info_outline;
    }

    return material.Tooltip(
      message: tooltipText,
      waitDuration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(theme.radiusSm),
        border: Border.all(color: theme.textSecondary.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: theme.canvas.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      textStyle: TextStyle(
        color: theme.textPrimary,
        fontSize: 11,
        fontWeight: FontWeight.normal,
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.help,
        child: Padding(
          padding: EdgeInsets.all(theme.xs / 2),
          child: Icon(
            infoIcon,
            size: 14,
            color: theme.textSecondary,
            semanticLabel: tooltipText,
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // EXCLUDED FILES BADGE INDICATOR
  // =========================================================================
  Widget _buildExcludedFilesBadge(
    BuildContext context,
    AppThemeData theme,
    AppStrings strings,
    List<String> excludedFiles,
  ) {
    if (excludedFiles.isEmpty) return const SizedBox.shrink();

    final count = excludedFiles.length;
    final tooltipText = '${strings.excludedFilesTooltip(count)}:\n${excludedFiles.map((f) => '• $f').join('\n')}';

    final IconData badgeIcon;
    if (defaultTargetPlatform == TargetPlatform.windows) {
      badgeIcon = fluent.FluentIcons.blocked;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      badgeIcon = cupertino.CupertinoIcons.minus_circle;
    } else {
      badgeIcon = material.Icons.filter_alt_outlined;
    }

    return material.Tooltip(
      message: tooltipText,
      waitDuration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(theme.radiusSm),
        border: Border.all(color: theme.warning.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: theme.canvas.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      textStyle: TextStyle(
        color: theme.textPrimary,
        fontSize: 11,
        fontWeight: FontWeight.normal,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: theme.sm, vertical: theme.xs / 2),
        decoration: BoxDecoration(
          color: theme.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(theme.radiusSm),
          border: Border.all(color: theme.warning.withValues(alpha: 0.35), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              badgeIcon,
              size: 11,
              color: theme.warning,
              semanticLabel: strings.excludedFilesTooltip(count),
            ),
            SizedBox(width: theme.xs),
            Text(
              strings.excludedFilesBadge(count),
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // DESTRUCTIVE ACTION CONFIRMATION DIALOG (Rule 6 Guard)
  // =========================================================================
  void _confirmDeleteTask(BuildContext context, WidgetRef ref, BackupTask task, TargetPlatform platform) {
    final strings = ref.read(stringsProvider);
    final theme = context.theme;
    final title = strings.deleteTaskConfirmTitle;
    final message = '${strings.deleteTaskPrompt(task.name)}\n\n${strings.deleteTaskRule6Notice}';

    if (platform == TargetPlatform.windows) {
      fluent.showDialog(
        context: context,
        builder: (context) => fluent.ContentDialog(
          title: fluent.Text(title),
          content: Text(message),
          actions: [
            fluent.FilledButton(
              style: fluent.ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) => theme.error),
              ),
              onPressed: () {
                ref.read(tasksListProvider.notifier).removeTask(task.id);
                Navigator.pop(context);
              },
              child: Text(
                strings.delete,
                style: const TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.bold),
              ),
            ),
            fluent.Button(
              onPressed: () => Navigator.pop(context),
              child: Text(strings.cancel),
            ),
          ],
        ),
      );
    } else if (platform == TargetPlatform.iOS) {
      cupertino.showCupertinoDialog(
        context: context,
        builder: (context) => cupertino.CupertinoAlertDialog(
          title: Text(title),
          content: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(message),
          ),
          actions: [
            cupertino.CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                ref.read(tasksListProvider.notifier).removeTask(task.id);
                Navigator.pop(context);
              },
              child: Text(strings.delete),
            ),
            cupertino.CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: Text(strings.cancel),
            ),
          ],
        ),
      );
    } else {
      material.showDialog(
        context: context,
        builder: (context) => material.AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            material.TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(strings.cancel),
            ),
            material.FilledButton(
              style: material.FilledButton.styleFrom(
                backgroundColor: theme.error,
              ),
              onPressed: () {
                ref.read(tasksListProvider.notifier).removeTask(task.id);
                Navigator.pop(context);
              },
              child: Text(
                strings.delete,
                style: const TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }
  }

  // =========================================================================
  // MAIN ADD/EDIT DIALOG DISPATCHER
  // =========================================================================
  void _showAddEditTaskDialog(
    BuildContext context,
    WidgetRef ref,
    BackupTask? existingTask,
    TargetPlatform platform,
  ) {
    if (platform == TargetPlatform.windows) {
      _showWindowsAddEditDialog(context, ref, existingTask);
    } else if (platform == TargetPlatform.iOS) {
      _showIOSAddEditModalSheet(context, ref, existingTask);
    } else {
      _showAndroidAddEditDialog(context, ref, existingTask);
    }
  }

  // =========================================================================
  // WINDOWS ADD / EDIT FORM
  // =========================================================================
  void _showWindowsAddEditDialog(BuildContext context, WidgetRef ref, BackupTask? existingTask) {
    final theme = context.theme;
    final strings = ref.read(stringsProvider);
    final remotesList = _resolveRemotesList(ref);

    final nameController = TextEditingController(text: existingTask?.name ?? '');
    final srcController = TextEditingController(text: existingTask?.sourcePath ?? '');
    final targetFolderController = TextEditingController(text: existingTask?.targetFolderName ?? 'backup/media');

    final List<String> selectedRemotes = existingTask != null && existingTask.targetRemotes.isNotEmpty
        ? List<String>.from(existingTask.targetRemotes)
        : (remotesList.isNotEmpty ? [remotesList.first] : ['GoogleDrive_Backup']);

    DistributionStrategy selectedDistribution = existingTask?.distributionStrategy ?? DistributionStrategy.mirrorAll;
    TargetFolderMode selectedTargetFolderMode = existingTask?.targetFolderMode ?? TargetFolderMode.custom;
    SyncMode selectedSyncMode = existingTask?.syncMode ?? SyncMode.incremental;

    String selectedScheduleDay = existingTask?.scheduleDay ?? 'Daily';
    String selectedHour = '02';
    String selectedMinute = '00';
    if (existingTask != null && existingTask.scheduleTime.contains(':')) {
      final parts = existingTask.scheduleTime.split(':');
      if (parts.length == 2) {
        selectedHour = parts[0];
        selectedMinute = parts[1];
      }
    }
    bool isActive = existingTask?.isActive ?? true;

    String? nameError;
    String? sourceError;
    String? remotesError;

    const scheduleDayOptions = _scheduleDayKeys;
    final hours = List.generate(24, (i) => i.toString().padLeft(2, '0'));
    final minutes = List.generate(12, (i) => (i * 5).toString().padLeft(2, '0'));

    fluent.showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          void handleSave() {
            final name = nameController.text.trim();
            final sourcePath = srcController.text.trim();

            bool hasError = false;
            String? newNameError;
            String? newSourceError;
            String? newRemotesError;

            if (name.isEmpty) {
              newNameError = strings.taskNameRequiredError;
              hasError = true;
            }
            if (sourcePath.isEmpty) {
              newSourceError = strings.sourcePathRequiredError;
              hasError = true;
            }
            if (selectedRemotes.isEmpty) {
              newRemotesError = strings.selectAtLeastOneRemote;
              hasError = true;
            }

            if (hasError) {
              setState(() {
                nameError = newNameError;
                sourceError = newSourceError;
                remotesError = newRemotesError;
              });
              return;
            }

            final String finalTime = selectedScheduleDay == 'Manual' ? '12:00' : '$selectedHour:$selectedMinute';
            final String finalSchedule = selectedScheduleDay == 'Daily'
                ? 'Daily at $finalTime'
                : (selectedScheduleDay == 'Manual' ? 'Manual' : 'Weekly on ${selectedScheduleDay}s at $finalTime');

            String finalTargetFolder = targetFolderController.text.trim();
            if (selectedTargetFolderMode == TargetFolderMode.root) {
              finalTargetFolder = '/';
            } else if (finalTargetFolder.isEmpty) {
              finalTargetFolder = selectedTargetFolderMode == TargetFolderMode.newFolder ? 'new_backup' : 'backup/media';
            }

            final task = BackupTask(
              id: existingTask?.id ?? 'task_${DateTime.now().millisecondsSinceEpoch}',
              name: name,
              sourcePath: sourcePath,
              targetRemotes: List<String>.from(selectedRemotes),
              schedule: finalSchedule,
              scheduleDay: selectedScheduleDay,
              scheduleTime: finalTime,
              isActive: isActive,
              runMissedOnStartup: true,
              excludedFiles: existingTask?.excludedFiles ?? const [],
              syncMode: selectedSyncMode,
              distributionStrategy: selectedRemotes.length > 1 ? selectedDistribution : DistributionStrategy.mirrorAll,
              targetFolderMode: selectedTargetFolderMode,
              targetFolderName: finalTargetFolder,
            );

            if (existingTask == null) {
              ref.read(tasksListProvider.notifier).addTask(task);
            } else {
              ref.read(tasksListProvider.notifier).updateTask(existingTask.id, task);
            }
            Navigator.pop(dialogContext);
          }

          return fluent.ContentDialog(
            title: fluent.Text(existingTask == null ? strings.addTask : strings.editTask),
            content: _buildWindowsFormFields(
              context: context,
              theme: theme,
              strings: strings,
              nameController: nameController,
              srcController: srcController,
              targetFolderController: targetFolderController,
              nameError: nameError,
              sourceError: sourceError,
              remotesError: remotesError,
              selectedRemotes: selectedRemotes,
              remotesList: remotesList,
              onToggleRemote: (remote, checked) {
                setState(() {
                  if (checked == true) {
                    if (!selectedRemotes.contains(remote)) selectedRemotes.add(remote);
                  } else {
                    selectedRemotes.remove(remote);
                  }
                  if (selectedRemotes.isNotEmpty) remotesError = null;
                });
              },
              selectedDistribution: selectedDistribution,
              onDistributionChanged: (val) => setState(() => selectedDistribution = val),
              selectedTargetFolderMode: selectedTargetFolderMode,
              onTargetFolderModeChanged: (val) => setState(() => selectedTargetFolderMode = val),
              selectedSyncMode: selectedSyncMode,
              onSyncModeChanged: (val) => setState(() => selectedSyncMode = val),
              selectedScheduleDay: selectedScheduleDay,
              scheduleDayOptions: scheduleDayOptions,
              onScheduleDayChanged: (val) {
                if (val != null) setState(() => selectedScheduleDay = val);
              },
              selectedHour: selectedHour,
              hours: hours,
              onHourChanged: (val) {
                if (val != null) setState(() => selectedHour = val);
              },
              selectedMinute: selectedMinute,
              minutes: minutes,
              onMinuteChanged: (val) {
                if (val != null) setState(() => selectedMinute = val);
              },
              isActive: isActive,
              onActiveChanged: (val) => setState(() => isActive = val),
              onPickSourceFolder: () async {
                final path = await FilePicker.getDirectoryPath();
                if (path != null) {
                  setState(() {
                    srcController.text = path;
                    sourceError = null;
                  });
                }
              },
              onNameChanged: () {
                if (nameError != null) setState(() => nameError = null);
              },
              onSourceChanged: () {
                if (sourceError != null) setState(() => sourceError = null);
              },
            ),
            actions: [
              fluent.FilledButton(
                onPressed: handleSave,
                child: Text(
                  strings.save,
                  style: const TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.bold),
                ),
              ),
              fluent.Button(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(strings.cancel),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWindowsFormFields({
    required BuildContext context,
    required AppThemeData theme,
    required AppStrings strings,
    required TextEditingController nameController,
    required TextEditingController srcController,
    required TextEditingController targetFolderController,
    required String? nameError,
    required String? sourceError,
    required String? remotesError,
    required List<String> selectedRemotes,
    required List<String> remotesList,
    required void Function(String remote, bool? checked) onToggleRemote,
    required DistributionStrategy selectedDistribution,
    required ValueChanged<DistributionStrategy> onDistributionChanged,
    required TargetFolderMode selectedTargetFolderMode,
    required ValueChanged<TargetFolderMode> onTargetFolderModeChanged,
    required SyncMode selectedSyncMode,
    required ValueChanged<SyncMode> onSyncModeChanged,
    required String selectedScheduleDay,
    required List<String> scheduleDayOptions,
    required ValueChanged<String?> onScheduleDayChanged,
    required String selectedHour,
    required List<String> hours,
    required ValueChanged<String?> onHourChanged,
    required String selectedMinute,
    required List<String> minutes,
    required ValueChanged<String?> onMinuteChanged,
    required bool isActive,
    required ValueChanged<bool> onActiveChanged,
    required VoidCallback onPickSourceFolder,
    required VoidCallback onNameChanged,
    required VoidCallback onSourceChanged,
  }) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(strings.taskNameLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: theme.xs),
          fluent.TextBox(
            controller: nameController,
            placeholder: strings.taskNameHint,
            decoration: nameError != null
                ? WidgetStatePropertyAll(
                    BoxDecoration(
                      color: theme.surface,
                      border: Border.all(color: theme.error, width: 1.5),
                      borderRadius: BorderRadius.circular(theme.radiusSm),
                    ),
                  )
                : null,
            onChanged: (_) => onNameChanged(),
          ),
          if (nameError != null) ...[
            SizedBox(height: theme.xs),
            Text(
              nameError,
              style: TextStyle(color: theme.error, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
          SizedBox(height: theme.md),
          Row(
            children: [
              Text(strings.sourcePathLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(width: theme.xs),
              _buildInfoTooltip(context, theme, strings.tooltipSourcePath),
            ],
          ),
          SizedBox(height: theme.xs),
          Row(
            children: [
              Expanded(
                child: fluent.TextBox(
                  controller: srcController,
                  placeholder: strings.sourcePathHint,
                  decoration: sourceError != null
                      ? WidgetStatePropertyAll(
                          BoxDecoration(
                            color: theme.surface,
                            border: Border.all(color: theme.error, width: 1.5),
                            borderRadius: BorderRadius.circular(theme.radiusSm),
                          ),
                        )
                      : null,
                  onChanged: (_) => onSourceChanged(),
                ),
              ),
              SizedBox(width: theme.sm),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: fluent.IconButton(
                    icon: Icon(fluent.FluentIcons.folder_open, semanticLabel: strings.selectFolder),
                    onPressed: onPickSourceFolder,
                  ),
                ),
              ),
            ],
          ),
          if (sourceError != null) ...[
            SizedBox(height: theme.xs),
            Text(
              sourceError,
              style: TextStyle(color: theme.error, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
          SizedBox(height: theme.md),

          // --- Destination Cloud Remotes Multi-Select ---
          Row(
            children: [
              Text(strings.destinationRemoteLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(width: theme.xs),
              _buildInfoTooltip(context, theme, strings.tooltipDestinationRemote),
            ],
          ),
          SizedBox(height: theme.xs),
          Container(
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(theme.radiusSm),
              border: Border.all(
                color: remotesError != null ? theme.error : theme.textSecondary.withValues(alpha: 0.25),
                width: remotesError != null ? 1.5 : 1,
              ),
            ),
            padding: EdgeInsets.all(theme.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: remotesList.map((remote) {
                final isChecked = selectedRemotes.contains(remote);
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: theme.xs / 2),
                  child: fluent.Checkbox(
                    checked: isChecked,
                    content: Text(remote),
                    onChanged: (val) => onToggleRemote(remote, val),
                  ),
                );
              }).toList(),
            ),
          ),
          if (remotesError != null) ...[
            SizedBox(height: theme.xs),
            Text(
              remotesError,
              style: TextStyle(color: theme.error, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],

          // --- Distribution Strategy (If > 1 remote selected) ---
          if (selectedRemotes.length > 1) ...[
            SizedBox(height: theme.md),
            Row(
              children: [
                Text(strings.distributionStrategyLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(width: theme.xs),
                _buildInfoTooltip(context, theme, strings.distributionTooltip),
              ],
            ),
            SizedBox(height: theme.xs),
            fluent.Card(
              padding: EdgeInsets.all(theme.sm),
              backgroundColor: selectedDistribution == DistributionStrategy.mirrorAll
                  ? theme.accent.withValues(alpha: 0.08)
                  : theme.surface,
              borderColor: selectedDistribution == DistributionStrategy.mirrorAll ? theme.accent : null,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onDistributionChanged(DistributionStrategy.mirrorAll),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        selectedDistribution == DistributionStrategy.mirrorAll
                            ? fluent.FluentIcons.radio_bullet
                            : fluent.FluentIcons.radio_btn_off,
                        color: selectedDistribution == DistributionStrategy.mirrorAll ? theme.accent : theme.textSecondary,
                        size: 18,
                        semanticLabel: strings.distributionMirrorAll,
                      ),
                      SizedBox(width: theme.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.distributionMirrorAll,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            SizedBox(height: theme.xs / 2),
                            Text(
                              strings.distributionMirrorAllDesc,
                              style: TextStyle(fontSize: 11, color: theme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: theme.xs),
            fluent.Card(
              padding: EdgeInsets.all(theme.sm),
              backgroundColor: selectedDistribution == DistributionStrategy.balance
                  ? theme.accent.withValues(alpha: 0.08)
                  : theme.surface,
              borderColor: selectedDistribution == DistributionStrategy.balance ? theme.accent : null,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onDistributionChanged(DistributionStrategy.balance),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        selectedDistribution == DistributionStrategy.balance
                            ? fluent.FluentIcons.radio_bullet
                            : fluent.FluentIcons.radio_btn_off,
                        color: selectedDistribution == DistributionStrategy.balance ? theme.accent : theme.textSecondary,
                        size: 18,
                        semanticLabel: strings.distributionBalance,
                      ),
                      SizedBox(width: theme.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.distributionBalance,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            SizedBox(height: theme.xs / 2),
                            Text(
                              strings.distributionBalanceDesc,
                              style: TextStyle(fontSize: 11, color: theme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          SizedBox(height: theme.md),

          // --- Cloud Target Folder Mode ---
          Row(
            children: [
              Text(strings.targetFolderModeLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(width: theme.xs),
              _buildInfoTooltip(context, theme, strings.targetFolderTooltip),
            ],
          ),
          SizedBox(height: theme.xs),
          fluent.ComboBox<TargetFolderMode>(
            value: selectedTargetFolderMode,
            items: [
              fluent.ComboBoxItem(
                value: TargetFolderMode.root,
                child: Text(strings.targetFolderRoot),
              ),
              fluent.ComboBoxItem(
                value: TargetFolderMode.custom,
                child: Text(strings.targetFolderCustom),
              ),
              fluent.ComboBoxItem(
                value: TargetFolderMode.newFolder,
                child: Text(strings.targetFolderNew),
              ),
            ],
            onChanged: (val) {
              if (val != null) onTargetFolderModeChanged(val);
            },
          ),
          if (selectedTargetFolderMode == TargetFolderMode.custom || selectedTargetFolderMode == TargetFolderMode.newFolder) ...[
            SizedBox(height: theme.xs),
            fluent.TextBox(
              controller: targetFolderController,
              placeholder: selectedTargetFolderMode == TargetFolderMode.newFolder
                  ? strings.newFolderNameHint
                  : 'backup/media',
            ),
          ],

          SizedBox(height: theme.md),

          // --- Sync Mode Selection ---
          Row(
            children: [
              Text(strings.syncModeLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(width: theme.xs),
              _buildInfoTooltip(
                context,
                theme,
                selectedSyncMode == SyncMode.incremental
                    ? strings.syncModeTooltipIncremental
                    : strings.syncModeTooltipMirror,
              ),
            ],
          ),
          SizedBox(height: theme.xs),
          fluent.Card(
            padding: EdgeInsets.all(theme.sm),
            backgroundColor: selectedSyncMode == SyncMode.incremental
                ? theme.accent.withValues(alpha: 0.08)
                : theme.surface,
            borderColor: selectedSyncMode == SyncMode.incremental ? theme.accent : null,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSyncModeChanged(SyncMode.incremental),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      selectedSyncMode == SyncMode.incremental
                          ? fluent.FluentIcons.radio_bullet
                          : fluent.FluentIcons.radio_btn_off,
                      color: selectedSyncMode == SyncMode.incremental ? theme.accent : theme.textSecondary,
                      size: 18,
                      semanticLabel: strings.syncModeIncremental,
                    ),
                    SizedBox(width: theme.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.syncModeIncremental,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          SizedBox(height: theme.xs / 2),
                          Text(
                            strings.syncModeIncrementalDescription,
                            style: TextStyle(fontSize: 11, color: theme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: theme.xs),
          fluent.Card(
            padding: EdgeInsets.all(theme.sm),
            backgroundColor: selectedSyncMode == SyncMode.mirror
                ? theme.warning.withValues(alpha: 0.1)
                : theme.surface,
            borderColor: selectedSyncMode == SyncMode.mirror ? theme.warning : null,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSyncModeChanged(SyncMode.mirror),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      selectedSyncMode == SyncMode.mirror
                          ? fluent.FluentIcons.radio_bullet
                          : fluent.FluentIcons.radio_btn_off,
                      color: selectedSyncMode == SyncMode.mirror ? theme.warning : theme.textSecondary,
                      size: 18,
                      semanticLabel: strings.syncModeMirror,
                    ),
                    SizedBox(width: theme.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                strings.syncModeMirror,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: selectedSyncMode == SyncMode.mirror ? theme.warning : null,
                                ),
                              ),
                              SizedBox(width: theme.xs),
                              Icon(
                                fluent.FluentIcons.warning,
                                size: 14,
                                color: theme.warning,
                                semanticLabel: strings.syncModeMirror,
                              ),
                            ],
                          ),
                          SizedBox(height: theme.xs / 2),
                          Text(
                            strings.syncModeMirrorDescription,
                            style: TextStyle(
                              fontSize: 11,
                              color: selectedSyncMode == SyncMode.mirror ? theme.warning : theme.textSecondary,
                              fontWeight: selectedSyncMode == SyncMode.mirror ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: theme.md),

          // --- Schedule Selection ---
          Row(
            children: [
              Text(strings.scheduleDayLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(width: theme.xs),
              _buildInfoTooltip(context, theme, strings.tooltipSchedule),
            ],
          ),
          SizedBox(height: theme.xs),
          fluent.ComboBox<String>(
            value: selectedScheduleDay,
            items: scheduleDayOptions.map((sched) {
              return fluent.ComboBoxItem(value: sched, child: Text(_getDayLabel(strings, sched)));
            }).toList(),
            onChanged: onScheduleDayChanged,
          ),
          if (selectedScheduleDay != 'Manual') ...[
            SizedBox(height: theme.sm),
            Row(
              children: [
                Text('${strings.scheduleTimeLabel}:'),
                SizedBox(width: theme.sm),
                fluent.ComboBox<String>(
                  value: selectedHour,
                  items: hours.map((h) => fluent.ComboBoxItem(value: h, child: Text(h))).toList(),
                  onChanged: onHourChanged,
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: theme.xs),
                  child: const Text(':'),
                ),
                fluent.ComboBox<String>(
                  value: selectedMinute,
                  items: minutes.map((m) => fluent.ComboBoxItem(value: m, child: Text(m))).toList(),
                  onChanged: onMinuteChanged,
                ),
              ],
            ),
          ],
          SizedBox(height: theme.lg),
          Row(
            children: [
              Text('${strings.activeSyncJob}:'),
              const Spacer(),
              fluent.ToggleSwitch(
                checked: isActive,
                onChanged: onActiveChanged,
              ),
            ],
          ),
          SizedBox(height: theme.md),
          Row(
            children: [
              Icon(fluent.FluentIcons.completed, size: 14, color: theme.success, semanticLabel: strings.catchUpNotice),
              SizedBox(width: theme.xs),
              Expanded(
                child: Text(
                  strings.catchUpNotice,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(width: theme.xs),
              _buildInfoTooltip(context, theme, strings.tooltipCatchUp),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // IOS MODAL SHEET (Prevents keyboard overflow via CupertinoPageScaffold)
  // =========================================================================
  void _showIOSAddEditModalSheet(BuildContext context, WidgetRef ref, BackupTask? existingTask) {
    final theme = context.theme;
    final strings = ref.read(stringsProvider);
    final remotesList = _resolveRemotesList(ref);

    final nameController = TextEditingController(text: existingTask?.name ?? '');
    final srcController = TextEditingController(text: existingTask?.sourcePath ?? '');
    final targetFolderController = TextEditingController(text: existingTask?.targetFolderName ?? 'backup/media');

    final List<String> selectedRemotes = existingTask != null && existingTask.targetRemotes.isNotEmpty
        ? List<String>.from(existingTask.targetRemotes)
        : (remotesList.isNotEmpty ? [remotesList.first] : ['GoogleDrive_Backup']);

    DistributionStrategy selectedDistribution = existingTask?.distributionStrategy ?? DistributionStrategy.mirrorAll;
    TargetFolderMode selectedTargetFolderMode = existingTask?.targetFolderMode ?? TargetFolderMode.custom;
    SyncMode selectedSyncMode = existingTask?.syncMode ?? SyncMode.incremental;

    String selectedScheduleDay = existingTask?.scheduleDay ?? 'Daily';
    String selectedHour = '02';
    String selectedMinute = '00';
    if (existingTask != null && existingTask.scheduleTime.contains(':')) {
      final parts = existingTask.scheduleTime.split(':');
      if (parts.length == 2) {
        selectedHour = parts[0];
        selectedMinute = parts[1];
      }
    }
    bool isActive = existingTask?.isActive ?? true;

    final mobileCategories = ['all', 'photos', 'videos', 'folders'];
    String selectedSourceCategory = 'all';
    if (existingTask != null) {
      if (existingTask.sourcePath == 'all' || existingTask.sourcePath == 'Alles') {
        selectedSourceCategory = 'all';
      } else if (existingTask.sourcePath == 'photos' || existingTask.sourcePath == 'Alle Fotos') {
        selectedSourceCategory = 'photos';
      } else if (existingTask.sourcePath == 'videos' || existingTask.sourcePath == 'Alle Videos') {
        selectedSourceCategory = 'videos';
      } else {
        selectedSourceCategory = 'folders';
      }
    }

    String? nameError;
    String? sourceError;
    String? remotesError;

    const scheduleDayOptions = ['Daily', 'Monday', 'Sunday', 'Manual'];
    final hours = List.generate(24, (i) => i.toString().padLeft(2, '0'));
    final minutes = List.generate(12, (i) => (i * 5).toString().padLeft(2, '0'));

    cupertino.showCupertinoModalPopup(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) {
          void handleSave() {
            final name = nameController.text.trim();
            String finalSourcePath = srcController.text.trim();

            bool hasError = false;
            String? newNameError;
            String? newSourceError;
            String? newRemotesError;

            if (name.isEmpty) {
              newNameError = strings.taskNameRequiredError;
              hasError = true;
            }

            if (selectedSourceCategory == 'folders') {
              if (finalSourcePath.isEmpty) {
                newSourceError = strings.sourcePathRequiredError;
                hasError = true;
              }
            } else {
              finalSourcePath = selectedSourceCategory;
            }

            if (selectedRemotes.isEmpty) {
              newRemotesError = strings.selectAtLeastOneRemote;
              hasError = true;
            }

            if (hasError) {
              setState(() {
                nameError = newNameError;
                sourceError = newSourceError;
                remotesError = newRemotesError;
              });
              return;
            }

            final String finalTime = selectedScheduleDay == 'Manual' ? '12:00' : '$selectedHour:$selectedMinute';
            final String finalSchedule = selectedScheduleDay == 'Daily'
                ? 'Daily at $finalTime'
                : (selectedScheduleDay == 'Manual' ? 'Manual' : 'Weekly on ${selectedScheduleDay}s at $finalTime');

            String finalTargetFolder = targetFolderController.text.trim();
            if (selectedTargetFolderMode == TargetFolderMode.root) {
              finalTargetFolder = '/';
            } else if (finalTargetFolder.isEmpty) {
              finalTargetFolder = selectedTargetFolderMode == TargetFolderMode.newFolder ? 'new_backup' : 'backup/media';
            }

            final task = BackupTask(
              id: existingTask?.id ?? 'task_${DateTime.now().millisecondsSinceEpoch}',
              name: name,
              sourcePath: finalSourcePath,
              targetRemotes: List<String>.from(selectedRemotes),
              schedule: finalSchedule,
              scheduleDay: selectedScheduleDay,
              scheduleTime: finalTime,
              isActive: isActive,
              runMissedOnStartup: true,
              excludedFiles: existingTask?.excludedFiles ?? const [],
              syncMode: selectedSyncMode,
              distributionStrategy: selectedRemotes.length > 1 ? selectedDistribution : DistributionStrategy.mirrorAll,
              targetFolderMode: selectedTargetFolderMode,
              targetFolderName: finalTargetFolder,
            );

            if (existingTask == null) {
              ref.read(tasksListProvider.notifier).addTask(task);
            } else {
              ref.read(tasksListProvider.notifier).updateTask(existingTask.id, task);
            }
            Navigator.pop(sheetContext);
          }

          return _buildIOSModalSheet(
            context: context,
            theme: theme,
            strings: strings,
            existingTask: existingTask,
            nameController: nameController,
            srcController: srcController,
            targetFolderController: targetFolderController,
            nameError: nameError,
            sourceError: sourceError,
            remotesError: remotesError,
            selectedSourceCategory: selectedSourceCategory,
            mobileCategories: mobileCategories,
            onSourceCategoryChanged: (val) {
              if (val != null) {
                setState(() {
                  selectedSourceCategory = val;
                  if (val != 'folders') sourceError = null;
                });
              }
            },
            selectedRemotes: selectedRemotes,
            remotesList: remotesList,
            onToggleRemote: (remote) {
              setState(() {
                if (selectedRemotes.contains(remote)) {
                  selectedRemotes.remove(remote);
                } else {
                  selectedRemotes.add(remote);
                }
                if (selectedRemotes.isNotEmpty) remotesError = null;
              });
            },
            selectedDistribution: selectedDistribution,
            onDistributionChanged: (val) => setState(() => selectedDistribution = val),
            selectedTargetFolderMode: selectedTargetFolderMode,
            onTargetFolderModeChanged: (val) => setState(() => selectedTargetFolderMode = val),
            selectedSyncMode: selectedSyncMode,
            onSyncModeChanged: (val) => setState(() => selectedSyncMode = val),
            selectedScheduleDay: selectedScheduleDay,
            scheduleDayOptions: scheduleDayOptions,
            onScheduleDayChanged: (val) {
              if (val != null) setState(() => selectedScheduleDay = val);
            },
            selectedHour: selectedHour,
            hours: hours,
            onHourChanged: (val) {
              if (val != null) setState(() => selectedHour = val);
            },
            selectedMinute: selectedMinute,
            minutes: minutes,
            onMinuteChanged: (val) {
              if (val != null) setState(() => selectedMinute = val);
            },
            isActive: isActive,
            onActiveChanged: (val) => setState(() => isActive = val),
            onNameChanged: () {
              if (nameError != null) setState(() => nameError = null);
            },
            onSourceChanged: () {
              if (sourceError != null) setState(() => sourceError = null);
            },
            onSave: handleSave,
            onCancel: () => Navigator.pop(sheetContext),
          );
        },
      ),
    );
  }

  Widget _buildIOSModalSheet({
    required BuildContext context,
    required AppThemeData theme,
    required AppStrings strings,
    required BackupTask? existingTask,
    required TextEditingController nameController,
    required TextEditingController srcController,
    required TextEditingController targetFolderController,
    required String? nameError,
    required String? sourceError,
    required String? remotesError,
    required String selectedSourceCategory,
    required List<String> mobileCategories,
    required ValueChanged<String?> onSourceCategoryChanged,
    required List<String> selectedRemotes,
    required List<String> remotesList,
    required ValueChanged<String> onToggleRemote,
    required DistributionStrategy selectedDistribution,
    required ValueChanged<DistributionStrategy> onDistributionChanged,
    required TargetFolderMode selectedTargetFolderMode,
    required ValueChanged<TargetFolderMode> onTargetFolderModeChanged,
    required SyncMode selectedSyncMode,
    required ValueChanged<SyncMode> onSyncModeChanged,
    required String selectedScheduleDay,
    required List<String> scheduleDayOptions,
    required ValueChanged<String?> onScheduleDayChanged,
    required String selectedHour,
    required List<String> hours,
    required ValueChanged<String?> onHourChanged,
    required String selectedMinute,
    required List<String> minutes,
    required ValueChanged<String?> onMinuteChanged,
    required bool isActive,
    required ValueChanged<bool> onActiveChanged,
    required VoidCallback onNameChanged,
    required VoidCallback onSourceChanged,
    required VoidCallback onSave,
    required VoidCallback onCancel,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * 0.85;

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: theme.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(theme.radiusLg)),
      ),
      child: cupertino.CupertinoPageScaffold(
        backgroundColor: theme.canvas,
        navigationBar: cupertino.CupertinoNavigationBar(
          backgroundColor: theme.surface,
          middle: Text(existingTask == null ? strings.addTask : strings.editTask),
          leading: SizedBox(
            width: 70,
            height: 44,
            child: cupertino.CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: onCancel,
              child: Text(strings.cancel),
            ),
          ),
          trailing: SizedBox(
            width: 80,
            height: 44,
            child: cupertino.CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: onSave,
              child: Text(
                strings.save,
                style: TextStyle(fontWeight: FontWeight.bold, color: theme.accent),
              ),
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(theme.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(strings.taskNameLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                SizedBox(height: theme.xs),
                cupertino.CupertinoTextField(
                  controller: nameController,
                  placeholder: strings.taskNameHint,
                  padding: EdgeInsets.all(theme.md),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    border: Border.all(
                      color: nameError != null ? theme.error : cupertino.CupertinoColors.separator,
                      width: nameError != null ? 1.5 : 0.5,
                    ),
                    borderRadius: BorderRadius.circular(theme.radiusSm),
                  ),
                  onChanged: (_) => onNameChanged(),
                ),
                if (nameError != null) ...[
                  SizedBox(height: theme.xs),
                  Text(
                    nameError,
                    style: TextStyle(color: theme.error, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],
                SizedBox(height: theme.md),
                Row(
                  children: [
                    Text(strings.sourceCategoryLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    SizedBox(width: theme.xs),
                    _buildInfoTooltip(context, theme, strings.tooltipSourcePath),
                  ],
                ),
                SizedBox(height: theme.xs),
                cupertino.CupertinoSlidingSegmentedControl<String>(
                  groupValue: selectedSourceCategory,
                  children: {
                    'all': Text(strings.allMedia, style: const TextStyle(fontSize: 11)),
                    'photos': Text(strings.allPhotos, style: const TextStyle(fontSize: 11)),
                    'videos': Text(strings.allVideos, style: const TextStyle(fontSize: 11)),
                    'folders': Text(strings.specificFoldersShort, style: const TextStyle(fontSize: 11)),
                  },
                  onValueChanged: onSourceCategoryChanged,
                ),
                if (selectedSourceCategory == 'folders') ...[
                  SizedBox(height: theme.sm),
                  cupertino.CupertinoTextField(
                    controller: srcController,
                    placeholder: strings.specificFoldersHint,
                    padding: EdgeInsets.all(theme.md),
                    decoration: BoxDecoration(
                      color: theme.surface,
                      border: Border.all(
                        color: sourceError != null ? theme.error : cupertino.CupertinoColors.separator,
                        width: sourceError != null ? 1.5 : 0.5,
                      ),
                      borderRadius: BorderRadius.circular(theme.radiusSm),
                    ),
                    onChanged: (_) => onSourceChanged(),
                  ),
                  if (sourceError != null) ...[
                    SizedBox(height: theme.xs),
                    Text(
                      sourceError,
                      style: TextStyle(color: theme.error, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ],
                SizedBox(height: theme.md),

                // --- Destination Remotes Multi-Select ---
                Row(
                  children: [
                    Text(strings.destinationRemoteLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    SizedBox(width: theme.xs),
                    _buildInfoTooltip(context, theme, strings.tooltipDestinationRemote),
                  ],
                ),
                SizedBox(height: theme.xs),
                Container(
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(theme.radiusSm),
                    border: Border.all(
                      color: remotesError != null ? theme.error : cupertino.CupertinoColors.separator,
                      width: remotesError != null ? 1.5 : 0.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < remotesList.length; i++) ...[
                        if (i > 0)
                          material.Divider(height: 1, indent: theme.md, color: theme.canvas),
                        cupertino.CupertinoListTile(
                          padding: EdgeInsets.symmetric(horizontal: theme.md, vertical: theme.xs),
                          title: Text(remotesList[i], style: const TextStyle(fontSize: 13)),
                          trailing: selectedRemotes.contains(remotesList[i])
                              ? Icon(cupertino.CupertinoIcons.checkmark_alt_circle_fill, color: theme.accent, size: 22)
                              : Icon(cupertino.CupertinoIcons.circle, color: theme.textSecondary, size: 22),
                          onTap: () => onToggleRemote(remotesList[i]),
                        ),
                      ],
                    ],
                  ),
                ),
                if (remotesError != null) ...[
                  SizedBox(height: theme.xs),
                  Text(
                    remotesError,
                    style: TextStyle(color: theme.error, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],

                // --- Distribution Strategy (If > 1 remote selected) ---
                if (selectedRemotes.length > 1) ...[
                  SizedBox(height: theme.md),
                  Row(
                    children: [
                      Text(strings.distributionStrategyLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      SizedBox(width: theme.xs),
                      _buildInfoTooltip(context, theme, strings.distributionTooltip),
                    ],
                  ),
                  SizedBox(height: theme.xs),
                  cupertino.CupertinoSlidingSegmentedControl<DistributionStrategy>(
                    groupValue: selectedDistribution,
                    children: {
                      DistributionStrategy.mirrorAll: Padding(
                        padding: EdgeInsets.symmetric(horizontal: theme.sm, vertical: theme.xs),
                        child: Text(strings.distributionBadgeMirrorAll, style: const TextStyle(fontSize: 11)),
                      ),
                      DistributionStrategy.balance: Padding(
                        padding: EdgeInsets.symmetric(horizontal: theme.sm, vertical: theme.xs),
                        child: Text(strings.distributionBadgeBalance, style: const TextStyle(fontSize: 11)),
                      ),
                    },
                    onValueChanged: (val) {
                      if (val != null) onDistributionChanged(val);
                    },
                  ),
                  SizedBox(height: theme.xs),
                  Container(
                    padding: EdgeInsets.all(theme.sm),
                    decoration: BoxDecoration(
                      color: theme.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(theme.radiusSm),
                      border: Border.all(color: theme.accent.withValues(alpha: 0.25), width: 1),
                    ),
                    child: Text(
                      selectedDistribution == DistributionStrategy.mirrorAll
                          ? strings.distributionMirrorAllDesc
                          : strings.distributionBalanceDesc,
                      style: TextStyle(fontSize: 11, color: theme.textSecondary),
                    ),
                  ),
                ],

                SizedBox(height: theme.md),

                // --- Cloud Target Folder Mode ---
                Row(
                  children: [
                    Text(strings.targetFolderModeLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    SizedBox(width: theme.xs),
                    _buildInfoTooltip(context, theme, strings.targetFolderTooltip),
                  ],
                ),
                SizedBox(height: theme.xs),
                cupertino.CupertinoSlidingSegmentedControl<TargetFolderMode>(
                  groupValue: selectedTargetFolderMode,
                  children: {
                    TargetFolderMode.root: Padding(
                      padding: EdgeInsets.symmetric(horizontal: theme.xs, vertical: theme.xs),
                      child: Text(strings.targetFolderRoot, style: const TextStyle(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    TargetFolderMode.custom: Padding(
                      padding: EdgeInsets.symmetric(horizontal: theme.xs, vertical: theme.xs),
                      child: Text(strings.targetFolderCustom, style: const TextStyle(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    TargetFolderMode.newFolder: Padding(
                      padding: EdgeInsets.symmetric(horizontal: theme.xs, vertical: theme.xs),
                      child: Text(strings.targetFolderNew, style: const TextStyle(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  },
                  onValueChanged: (val) {
                    if (val != null) onTargetFolderModeChanged(val);
                  },
                ),
                if (selectedTargetFolderMode == TargetFolderMode.custom || selectedTargetFolderMode == TargetFolderMode.newFolder) ...[
                  SizedBox(height: theme.sm),
                  cupertino.CupertinoTextField(
                    controller: targetFolderController,
                    placeholder: selectedTargetFolderMode == TargetFolderMode.newFolder
                        ? strings.newFolderNameHint
                        : 'backup/media',
                    padding: EdgeInsets.all(theme.md),
                    decoration: BoxDecoration(
                      color: theme.surface,
                      border: Border.all(color: cupertino.CupertinoColors.separator, width: 0.5),
                      borderRadius: BorderRadius.circular(theme.radiusSm),
                    ),
                  ),
                ],

                SizedBox(height: theme.md),

                // --- Sync Mode Selection ---
                Row(
                  children: [
                    Text(strings.syncModeLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    SizedBox(width: theme.xs),
                    _buildInfoTooltip(
                      context,
                      theme,
                      selectedSyncMode == SyncMode.incremental
                          ? strings.syncModeTooltipIncremental
                          : strings.syncModeTooltipMirror,
                    ),
                  ],
                ),
                SizedBox(height: theme.xs),
                cupertino.CupertinoSlidingSegmentedControl<SyncMode>(
                  groupValue: selectedSyncMode,
                  children: {
                    SyncMode.incremental: Padding(
                      padding: EdgeInsets.symmetric(horizontal: theme.sm, vertical: theme.xs),
                      child: Text(strings.syncModeIncremental, style: const TextStyle(fontSize: 11)),
                    ),
                    SyncMode.mirror: Padding(
                      padding: EdgeInsets.symmetric(horizontal: theme.sm, vertical: theme.xs),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(cupertino.CupertinoIcons.exclamationmark_triangle_fill, size: 12, color: theme.warning),
                          SizedBox(width: theme.xs / 2),
                          Text(
                            strings.syncModeBadgeMirror,
                            style: TextStyle(
                              fontSize: 11,
                              color: selectedSyncMode == SyncMode.mirror ? theme.warning : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  },
                  onValueChanged: (mode) {
                    if (mode != null) onSyncModeChanged(mode);
                  },
                ),
                SizedBox(height: theme.xs),
                Container(
                  padding: EdgeInsets.all(theme.sm),
                  decoration: BoxDecoration(
                    color: selectedSyncMode == SyncMode.mirror
                        ? theme.warning.withValues(alpha: 0.12)
                        : theme.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(theme.radiusSm),
                    border: Border.all(
                      color: selectedSyncMode == SyncMode.mirror
                          ? theme.warning.withValues(alpha: 0.35)
                          : theme.accent.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        selectedSyncMode == SyncMode.mirror
                            ? cupertino.CupertinoIcons.exclamationmark_triangle_fill
                            : cupertino.CupertinoIcons.checkmark_shield_fill,
                        size: 14,
                        color: selectedSyncMode == SyncMode.mirror ? theme.warning : theme.accent,
                      ),
                      SizedBox(width: theme.xs),
                      Expanded(
                        child: Text(
                          selectedSyncMode == SyncMode.mirror
                              ? strings.syncModeMirrorDescription
                              : strings.syncModeIncrementalDescription,
                          style: TextStyle(
                            fontSize: 11,
                            color: selectedSyncMode == SyncMode.mirror ? theme.warning : theme.textSecondary,
                            fontWeight: selectedSyncMode == SyncMode.mirror ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: theme.md),

                // --- Schedule Selection ---
                Row(
                  children: [
                    Text(strings.scheduleDayLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    SizedBox(width: theme.xs),
                    _buildInfoTooltip(context, theme, strings.tooltipSchedule),
                  ],
                ),
                SizedBox(height: theme.xs),
                cupertino.CupertinoSlidingSegmentedControl<String>(
                  groupValue: selectedScheduleDay,
                  children: {
                    for (final sched in scheduleDayOptions)
                      sched: Text(_getDayLabel(strings, sched), style: const TextStyle(fontSize: 10)),
                  },
                  onValueChanged: onScheduleDayChanged,
                ),
                if (selectedScheduleDay != 'Manual') ...[
                  SizedBox(height: theme.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${strings.scheduleTimeLabel}: ', style: const TextStyle(fontSize: 12)),
                      material.DropdownButton<String>(
                        value: selectedHour,
                        items: hours.map((h) => material.DropdownMenuItem(value: h, child: Text(h, style: const TextStyle(fontSize: 12)))).toList(),
                        onChanged: onHourChanged,
                      ),
                      const Text(' : ', style: TextStyle(fontSize: 12)),
                      material.DropdownButton<String>(
                        value: selectedMinute,
                        items: minutes.map((m) => material.DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12)))).toList(),
                        onChanged: onMinuteChanged,
                      ),
                    ],
                  ),
                ],
                SizedBox(height: theme.lg),
                Row(
                  children: [
                    Text('${strings.activeSyncJob}:', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    cupertino.CupertinoSwitch(
                      value: isActive,
                      onChanged: onActiveChanged,
                    ),
                  ],
                ),
                SizedBox(height: theme.md),
                Row(
                  children: [
                    Icon(
                      cupertino.CupertinoIcons.check_mark_circled_solid,
                      size: 14,
                      color: theme.success,
                      semanticLabel: strings.catchUpNotice,
                    ),
                    SizedBox(width: theme.xs),
                    Expanded(
                      child: Text(
                        strings.catchUpNotice,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(width: theme.xs),
                    _buildInfoTooltip(context, theme, strings.tooltipCatchUp),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // ANDROID ADD / EDIT FORM
  // =========================================================================
  void _showAndroidAddEditDialog(BuildContext context, WidgetRef ref, BackupTask? existingTask) {
    final theme = context.theme;
    final strings = ref.read(stringsProvider);
    final remotesList = _resolveRemotesList(ref);

    final nameController = TextEditingController(text: existingTask?.name ?? '');
    final srcController = TextEditingController(text: existingTask?.sourcePath ?? '');
    final targetFolderController = TextEditingController(text: existingTask?.targetFolderName ?? 'backup/media');

    final List<String> selectedRemotes = existingTask != null && existingTask.targetRemotes.isNotEmpty
        ? List<String>.from(existingTask.targetRemotes)
        : (remotesList.isNotEmpty ? [remotesList.first] : ['GoogleDrive_Backup']);

    DistributionStrategy selectedDistribution = existingTask?.distributionStrategy ?? DistributionStrategy.mirrorAll;
    TargetFolderMode selectedTargetFolderMode = existingTask?.targetFolderMode ?? TargetFolderMode.custom;
    SyncMode selectedSyncMode = existingTask?.syncMode ?? SyncMode.incremental;

    String selectedScheduleDay = existingTask?.scheduleDay ?? 'Daily';
    String selectedHour = '02';
    String selectedMinute = '00';
    if (existingTask != null && existingTask.scheduleTime.contains(':')) {
      final parts = existingTask.scheduleTime.split(':');
      if (parts.length == 2) {
        selectedHour = parts[0];
        selectedMinute = parts[1];
      }
    }
    bool isActive = existingTask?.isActive ?? true;

    final mobileCategories = ['all', 'photos', 'videos', 'folders'];
    String selectedSourceCategory = 'all';
    if (existingTask != null) {
      if (existingTask.sourcePath == 'all' || existingTask.sourcePath == 'Alles') {
        selectedSourceCategory = 'all';
      } else if (existingTask.sourcePath == 'photos' || existingTask.sourcePath == 'Alle Fotos') {
        selectedSourceCategory = 'photos';
      } else if (existingTask.sourcePath == 'videos' || existingTask.sourcePath == 'Alle Videos') {
        selectedSourceCategory = 'videos';
      } else {
        selectedSourceCategory = 'folders';
      }
    }

    String? nameError;
    String? sourceError;
    String? remotesError;

    const scheduleDayOptions = _scheduleDayKeys;
    final hours = List.generate(24, (i) => i.toString().padLeft(2, '0'));
    final minutes = List.generate(12, (i) => (i * 5).toString().padLeft(2, '0'));

    material.showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          void handleSave() {
            final name = nameController.text.trim();
            String finalSourcePath = srcController.text.trim();

            bool hasError = false;
            String? newNameError;
            String? newSourceError;
            String? newRemotesError;

            if (name.isEmpty) {
              newNameError = strings.taskNameRequiredError;
              hasError = true;
            }

            if (selectedSourceCategory == 'folders') {
              if (finalSourcePath.isEmpty) {
                newSourceError = strings.sourcePathRequiredError;
                hasError = true;
              }
            } else {
              finalSourcePath = selectedSourceCategory;
            }

            if (selectedRemotes.isEmpty) {
              newRemotesError = strings.selectAtLeastOneRemote;
              hasError = true;
            }

            if (hasError) {
              setState(() {
                nameError = newNameError;
                sourceError = newSourceError;
                remotesError = newRemotesError;
              });
              return;
            }

            final String finalTime = selectedScheduleDay == 'Manual' ? '12:00' : '$selectedHour:$selectedMinute';
            final String finalSchedule = selectedScheduleDay == 'Daily'
                ? 'Daily at $finalTime'
                : (selectedScheduleDay == 'Manual' ? 'Manual' : 'Weekly on ${selectedScheduleDay}s at $finalTime');

            String finalTargetFolder = targetFolderController.text.trim();
            if (selectedTargetFolderMode == TargetFolderMode.root) {
              finalTargetFolder = '/';
            } else if (finalTargetFolder.isEmpty) {
              finalTargetFolder = selectedTargetFolderMode == TargetFolderMode.newFolder ? 'new_backup' : 'backup/media';
            }

            final task = BackupTask(
              id: existingTask?.id ?? 'task_${DateTime.now().millisecondsSinceEpoch}',
              name: name,
              sourcePath: finalSourcePath,
              targetRemotes: List<String>.from(selectedRemotes),
              schedule: finalSchedule,
              scheduleDay: selectedScheduleDay,
              scheduleTime: finalTime,
              isActive: isActive,
              runMissedOnStartup: true,
              excludedFiles: existingTask?.excludedFiles ?? const [],
              syncMode: selectedSyncMode,
              distributionStrategy: selectedRemotes.length > 1 ? selectedDistribution : DistributionStrategy.mirrorAll,
              targetFolderMode: selectedTargetFolderMode,
              targetFolderName: finalTargetFolder,
            );

            if (existingTask == null) {
              ref.read(tasksListProvider.notifier).addTask(task);
            } else {
              ref.read(tasksListProvider.notifier).updateTask(existingTask.id, task);
            }
            Navigator.pop(dialogContext);
          }

          return material.AlertDialog(
            title: Text(existingTask == null ? strings.addTask : strings.editTask),
            content: _buildAndroidFormFields(
              context: context,
              theme: theme,
              strings: strings,
              nameController: nameController,
              srcController: srcController,
              targetFolderController: targetFolderController,
              nameError: nameError,
              sourceError: sourceError,
              remotesError: remotesError,
              selectedSourceCategory: selectedSourceCategory,
              mobileCategories: mobileCategories,
              onSourceCategoryChanged: (val) {
                if (val != null) {
                  setState(() {
                    selectedSourceCategory = val;
                    if (val != 'folders') sourceError = null;
                  });
                }
              },
              selectedRemotes: selectedRemotes,
              remotesList: remotesList,
              onToggleRemote: (remote, checked) {
                setState(() {
                  if (checked == true) {
                    if (!selectedRemotes.contains(remote)) selectedRemotes.add(remote);
                  } else {
                    selectedRemotes.remove(remote);
                  }
                  if (selectedRemotes.isNotEmpty) remotesError = null;
                });
              },
              selectedDistribution: selectedDistribution,
              onDistributionChanged: (val) => setState(() => selectedDistribution = val),
              selectedTargetFolderMode: selectedTargetFolderMode,
              onTargetFolderModeChanged: (val) => setState(() => selectedTargetFolderMode = val),
              selectedSyncMode: selectedSyncMode,
              onSyncModeChanged: (val) => setState(() => selectedSyncMode = val),
              selectedScheduleDay: selectedScheduleDay,
              scheduleDayOptions: scheduleDayOptions,
              onScheduleDayChanged: (val) {
                if (val != null) setState(() => selectedScheduleDay = val);
              },
              selectedHour: selectedHour,
              hours: hours,
              onHourChanged: (val) {
                if (val != null) setState(() => selectedHour = val);
              },
              selectedMinute: selectedMinute,
              minutes: minutes,
              onMinuteChanged: (val) {
                if (val != null) setState(() => selectedMinute = val);
              },
              isActive: isActive,
              onActiveChanged: (val) => setState(() => isActive = val),
              onNameChanged: () {
                if (nameError != null) setState(() => nameError = null);
              },
              onSourceChanged: () {
                if (sourceError != null) setState(() => sourceError = null);
              },
            ),
            actions: [
              material.TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(strings.cancel),
              ),
              material.FilledButton(
                onPressed: handleSave,
                child: Text(
                  strings.save,
                  style: const TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAndroidFormFields({
    required BuildContext context,
    required AppThemeData theme,
    required AppStrings strings,
    required TextEditingController nameController,
    required TextEditingController srcController,
    required TextEditingController targetFolderController,
    required String? nameError,
    required String? sourceError,
    required String? remotesError,
    required String selectedSourceCategory,
    required List<String> mobileCategories,
    required ValueChanged<String?> onSourceCategoryChanged,
    required List<String> selectedRemotes,
    required List<String> remotesList,
    required void Function(String remote, bool? checked) onToggleRemote,
    required DistributionStrategy selectedDistribution,
    required ValueChanged<DistributionStrategy> onDistributionChanged,
    required TargetFolderMode selectedTargetFolderMode,
    required ValueChanged<TargetFolderMode> onTargetFolderModeChanged,
    required SyncMode selectedSyncMode,
    required ValueChanged<SyncMode> onSyncModeChanged,
    required String selectedScheduleDay,
    required List<String> scheduleDayOptions,
    required ValueChanged<String?> onScheduleDayChanged,
    required String selectedHour,
    required List<String> hours,
    required ValueChanged<String?> onHourChanged,
    required String selectedMinute,
    required List<String> minutes,
    required ValueChanged<String?> onMinuteChanged,
    required bool isActive,
    required ValueChanged<bool> onActiveChanged,
    required VoidCallback onNameChanged,
    required VoidCallback onSourceChanged,
  }) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          material.TextField(
            controller: nameController,
            decoration: material.InputDecoration(
              labelText: strings.taskNameLabel,
              hintText: strings.taskNameHint,
              errorText: nameError,
            ),
            onChanged: (_) => onNameChanged(),
          ),
          SizedBox(height: theme.lg),
          material.DropdownButtonFormField<String>(
            initialValue: selectedSourceCategory,
            decoration: material.InputDecoration(
              labelText: strings.sourceCategoryLabel,
              suffixIcon: _buildInfoTooltip(context, theme, strings.tooltipSourcePath),
            ),
            items: mobileCategories.map((cat) {
              return material.DropdownMenuItem(
                value: cat,
                child: Text(_getCategoryLabel(strings, cat)),
              );
            }).toList(),
            onChanged: onSourceCategoryChanged,
          ),
          if (selectedSourceCategory == 'folders') ...[
            SizedBox(height: theme.sm),
            material.TextField(
              controller: srcController,
              decoration: material.InputDecoration(
                labelText: strings.sourcePathLabel,
                hintText: strings.specificFoldersHint,
                errorText: sourceError,
              ),
              onChanged: (_) => onSourceChanged(),
            ),
          ],
          SizedBox(height: theme.lg),

          // --- Destination Remotes Multi-Select ---
          Row(
            children: [
              Text(strings.destinationRemoteLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(width: theme.xs),
              _buildInfoTooltip(context, theme, strings.tooltipDestinationRemote),
            ],
          ),
          SizedBox(height: theme.xs),
          material.Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(theme.radiusSm),
              side: BorderSide(
                color: remotesError != null ? theme.error : material.Theme.of(context).colorScheme.outlineVariant,
                width: remotesError != null ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: remotesList.map((remote) {
                return material.CheckboxListTile(
                  title: Text(remote, style: const TextStyle(fontSize: 13)),
                  value: selectedRemotes.contains(remote),
                  dense: true,
                  onChanged: (bool? val) => onToggleRemote(remote, val),
                );
              }).toList(),
            ),
          ),
          if (remotesError != null) ...[
            SizedBox(height: theme.xs),
            Text(
              remotesError,
              style: TextStyle(color: theme.error, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],

          // --- Distribution Strategy (If > 1 remote selected) ---
          if (selectedRemotes.length > 1) ...[
            SizedBox(height: theme.lg),
            Row(
              children: [
                Text(strings.distributionStrategyLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(width: theme.xs),
                _buildInfoTooltip(context, theme, strings.distributionTooltip),
              ],
            ),
            SizedBox(height: theme.xs),
            material.Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(theme.radiusSm),
                side: BorderSide(
                  color: selectedDistribution == DistributionStrategy.mirrorAll
                      ? theme.accent
                      : material.Theme.of(context).colorScheme.outlineVariant,
                  width: selectedDistribution == DistributionStrategy.mirrorAll ? 1.5 : 1,
                ),
              ),
              color: selectedDistribution == DistributionStrategy.mirrorAll ? theme.accent.withValues(alpha: 0.08) : null,
              child: material.InkWell(
                borderRadius: BorderRadius.circular(theme.radiusSm),
                onTap: () => onDistributionChanged(DistributionStrategy.mirrorAll),
                child: Padding(
                  padding: EdgeInsets.all(theme.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        selectedDistribution == DistributionStrategy.mirrorAll
                            ? material.Icons.radio_button_checked
                            : material.Icons.radio_button_unchecked,
                        size: 20,
                        color: selectedDistribution == DistributionStrategy.mirrorAll ? theme.accent : theme.textSecondary,
                      ),
                      SizedBox(width: theme.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.distributionMirrorAll,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            SizedBox(height: theme.xs / 2),
                            Text(
                              strings.distributionMirrorAllDesc,
                              style: TextStyle(fontSize: 11, color: theme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: theme.xs),
            material.Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(theme.radiusSm),
                side: BorderSide(
                  color: selectedDistribution == DistributionStrategy.balance
                      ? theme.accent
                      : material.Theme.of(context).colorScheme.outlineVariant,
                  width: selectedDistribution == DistributionStrategy.balance ? 1.5 : 1,
                ),
              ),
              color: selectedDistribution == DistributionStrategy.balance ? theme.accent.withValues(alpha: 0.08) : null,
              child: material.InkWell(
                borderRadius: BorderRadius.circular(theme.radiusSm),
                onTap: () => onDistributionChanged(DistributionStrategy.balance),
                child: Padding(
                  padding: EdgeInsets.all(theme.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        selectedDistribution == DistributionStrategy.balance
                            ? material.Icons.radio_button_checked
                            : material.Icons.radio_button_unchecked,
                        size: 20,
                        color: selectedDistribution == DistributionStrategy.balance ? theme.accent : theme.textSecondary,
                      ),
                      SizedBox(width: theme.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.distributionBalance,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            SizedBox(height: theme.xs / 2),
                            Text(
                              strings.distributionBalanceDesc,
                              style: TextStyle(fontSize: 11, color: theme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          SizedBox(height: theme.lg),

          // --- Cloud Target Folder Mode ---
          material.DropdownButtonFormField<TargetFolderMode>(
            initialValue: selectedTargetFolderMode,
            decoration: material.InputDecoration(
              labelText: strings.targetFolderModeLabel,
              suffixIcon: _buildInfoTooltip(context, theme, strings.targetFolderTooltip),
            ),
            items: [
              material.DropdownMenuItem(
                value: TargetFolderMode.root,
                child: Text(strings.targetFolderRoot),
              ),
              material.DropdownMenuItem(
                value: TargetFolderMode.custom,
                child: Text(strings.targetFolderCustom),
              ),
              material.DropdownMenuItem(
                value: TargetFolderMode.newFolder,
                child: Text(strings.targetFolderNew),
              ),
            ],
            onChanged: (val) {
              if (val != null) onTargetFolderModeChanged(val);
            },
          ),
          if (selectedTargetFolderMode == TargetFolderMode.custom || selectedTargetFolderMode == TargetFolderMode.newFolder) ...[
            SizedBox(height: theme.sm),
            material.TextField(
              controller: targetFolderController,
              decoration: material.InputDecoration(
                labelText: selectedTargetFolderMode == TargetFolderMode.newFolder
                    ? strings.newFolderNameLabel
                    : strings.targetFolderModeLabel,
                hintText: selectedTargetFolderMode == TargetFolderMode.newFolder
                    ? strings.newFolderNameHint
                    : 'backup/media',
              ),
            ),
          ],

          SizedBox(height: theme.lg),

          // --- Sync Mode Selection ---
          Row(
            children: [
              Text(strings.syncModeLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(width: theme.xs),
              _buildInfoTooltip(
                context,
                theme,
                selectedSyncMode == SyncMode.incremental
                    ? strings.syncModeTooltipIncremental
                    : strings.syncModeTooltipMirror,
              ),
            ],
          ),
          SizedBox(height: theme.xs),
          material.Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(theme.radiusSm),
              side: BorderSide(
                color: selectedSyncMode == SyncMode.incremental
                    ? theme.accent
                    : material.Theme.of(context).colorScheme.outlineVariant,
                width: selectedSyncMode == SyncMode.incremental ? 1.5 : 1,
              ),
            ),
            color: selectedSyncMode == SyncMode.incremental ? theme.accent.withValues(alpha: 0.08) : null,
            child: material.InkWell(
              borderRadius: BorderRadius.circular(theme.radiusSm),
              onTap: () => onSyncModeChanged(SyncMode.incremental),
              child: Padding(
                padding: EdgeInsets.all(theme.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      selectedSyncMode == SyncMode.incremental
                          ? material.Icons.radio_button_checked
                          : material.Icons.radio_button_unchecked,
                      size: 20,
                      color: selectedSyncMode == SyncMode.incremental ? theme.accent : theme.textSecondary,
                    ),
                    SizedBox(width: theme.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.syncModeIncremental,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          SizedBox(height: theme.xs / 2),
                          Text(
                            strings.syncModeIncrementalDescription,
                            style: TextStyle(fontSize: 11, color: theme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: theme.xs),
          material.Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(theme.radiusSm),
              side: BorderSide(
                color: selectedSyncMode == SyncMode.mirror
                    ? theme.warning
                    : material.Theme.of(context).colorScheme.outlineVariant,
                width: selectedSyncMode == SyncMode.mirror ? 1.5 : 1,
              ),
            ),
            color: selectedSyncMode == SyncMode.mirror ? theme.warning.withValues(alpha: 0.1) : null,
            child: material.InkWell(
              borderRadius: BorderRadius.circular(theme.radiusSm),
              onTap: () => onSyncModeChanged(SyncMode.mirror),
              child: Padding(
                padding: EdgeInsets.all(theme.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      selectedSyncMode == SyncMode.mirror
                          ? material.Icons.radio_button_checked
                          : material.Icons.radio_button_unchecked,
                      size: 20,
                      color: selectedSyncMode == SyncMode.mirror ? theme.warning : theme.textSecondary,
                    ),
                    SizedBox(width: theme.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                strings.syncModeMirror,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: selectedSyncMode == SyncMode.mirror ? theme.warning : null,
                                ),
                              ),
                              SizedBox(width: theme.xs),
                              Icon(material.Icons.warning_amber_rounded, size: 16, color: theme.warning),
                            ],
                          ),
                          SizedBox(height: theme.xs / 2),
                          Text(
                            strings.syncModeMirrorDescription,
                            style: TextStyle(
                              fontSize: 11,
                              color: selectedSyncMode == SyncMode.mirror ? theme.warning : theme.textSecondary,
                              fontWeight: selectedSyncMode == SyncMode.mirror ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: theme.lg),

          // --- Schedule Selection ---
          material.DropdownButtonFormField<String>(
            initialValue: selectedScheduleDay,
            decoration: material.InputDecoration(
              labelText: strings.scheduleDayLabel,
              suffixIcon: _buildInfoTooltip(context, theme, strings.tooltipSchedule),
            ),
            items: scheduleDayOptions.map((sched) {
              return material.DropdownMenuItem(
                value: sched,
                child: Text(_getDayLabel(strings, sched)),
              );
            }).toList(),
            onChanged: onScheduleDayChanged,
          ),
          if (selectedScheduleDay != 'Manual') ...[
            SizedBox(height: theme.lg),
            Row(
              children: [
                Text('${strings.scheduleTimeLabel}:'),
                SizedBox(width: theme.md),
                Expanded(
                  child: material.DropdownButtonFormField<String>(
                    initialValue: selectedHour,
                    decoration: material.InputDecoration(labelText: strings.hourLabel),
                    items: hours.map((h) => material.DropdownMenuItem(value: h, child: Text(h))).toList(),
                    onChanged: onHourChanged,
                  ),
                ),
                SizedBox(width: theme.sm),
                const Text(':'),
                SizedBox(width: theme.sm),
                Expanded(
                  child: material.DropdownButtonFormField<String>(
                    initialValue: selectedMinute,
                    decoration: material.InputDecoration(labelText: strings.minuteLabel),
                    items: minutes.map((m) => material.DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: onMinuteChanged,
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: theme.lg),
          Row(
            children: [
              Text('${strings.activeSyncJob}:'),
              const Spacer(),
              material.Switch(
                value: isActive,
                onChanged: onActiveChanged,
              ),
            ],
          ),
          SizedBox(height: theme.md),
          Row(
            children: [
              Icon(
                material.Icons.check_circle_outline,
                size: 14,
                color: theme.success,
                semanticLabel: strings.catchUpNotice,
              ),
              SizedBox(width: theme.xs),
              Expanded(
                child: Text(
                  strings.catchUpNotice,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(width: theme.xs),
              _buildInfoTooltip(context, theme, strings.tooltipCatchUp),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // HELPERS
  // =========================================================================
  static const List<String> _scheduleDayKeys = [
    'Daily',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
    'Manual',
  ];

  static List<String> _resolveRemotesList(WidgetRef ref) {
    final remotesAsync = ref.read(remotesProvider);
    const fallback = ['GoogleDrive_Backup', 'OneDrive_Backup', 'Dropbox_Backup'];
    return remotesAsync.maybeWhen(
      data: (list) {
        if (list.isEmpty) return fallback;
        return list.map((e) => e.endsWith(':') ? e.substring(0, e.length - 1) : e).toList();
      },
      orElse: () => fallback,
    );
  }

  static String _getDayLabel(AppStrings strings, String key) {
    switch (key) {
      case 'Daily':
        return strings.dayDaily;
      case 'Monday':
        return strings.dayMonday;
      case 'Tuesday':
        return strings.dayTuesday;
      case 'Wednesday':
        return strings.dayWednesday;
      case 'Thursday':
        return strings.dayThursday;
      case 'Friday':
        return strings.dayFriday;
      case 'Saturday':
        return strings.daySaturday;
      case 'Sunday':
        return strings.daySunday;
      case 'Manual':
        return strings.dayManual;
      default:
        return key;
    }
  }

  static String _getCategoryLabel(AppStrings strings, String key) {
    switch (key) {
      case 'all':
        return strings.allMedia;
      case 'photos':
        return strings.allPhotos;
      case 'videos':
        return strings.allVideos;
      case 'folders':
        return strings.specificFolders;
      default:
        return key;
    }
  }

  static String _formatSourcePath(AppStrings strings, String rawPath) {
    if (rawPath == 'all' || rawPath == 'Alles') return strings.allMedia;
    if (rawPath == 'photos' || rawPath == 'Alle Fotos') return strings.allPhotos;
    if (rawPath == 'videos' || rawPath == 'Alle Videos') return strings.allVideos;
    return rawPath;
  }

  static String _formatTargetFolder(AppStrings strings, BackupTask task) {
    if (task.targetFolderMode == TargetFolderMode.root) {
      return '/ (Root)';
    }
    final folder = task.targetFolderName.trim();
    if (folder.isEmpty || folder == '/') return '/ (Root)';
    return folder.startsWith('/') ? folder : '/$folder';
  }

  static String _formatScheduleDescription(AppStrings strings, BackupTask task) {
    if (task.scheduleDay == 'Manual') {
      return strings.dayManual;
    } else if (task.scheduleDay == 'Daily') {
      return strings.scheduleDisplay(day: 'Daily', time: task.scheduleTime);
    } else {
      return strings.scheduleDisplay(day: _getDayLabel(strings, task.scheduleDay), time: task.scheduleTime);
    }
  }
}

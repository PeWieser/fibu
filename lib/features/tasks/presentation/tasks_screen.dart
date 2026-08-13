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
/// Allows viewing, adding, editing, and deleting backup tasks with persistence and Rule 6 compliance.
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

  // --- Windows (Fluent UI) ---
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
          ? _buildEmptyState(context, TargetPlatform.windows, theme, strings)
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
                      children: [
                        Icon(
                          fluent.FluentIcons.task_manager,
                          size: 28,
                          color: theme.accent,
                          semanticLabel: strings.tasksTitle,
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
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${strings.destinationPrefix} ',
                                      style: TextStyle(
                                        color: theme.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextSpan(
                                      text: task.targetRemote,
                                      style: TextStyle(color: theme.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: theme.sm),
                              Wrap(
                                spacing: theme.sm,
                                runSpacing: theme.xs,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: theme.sm,
                                      vertical: theme.xs / 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.accent.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(theme.radiusSm),
                                    ),
                                    child: Text(
                                      _formatScheduleDescription(strings, task),
                                      style: TextStyle(
                                        color: theme.textPrimary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (task.excludedFiles.isNotEmpty)
                                    _buildExcludedFilesBadge(context, theme, strings, task.excludedFiles),
                                ],
                              ),
                            ],
                          ),
                        ),
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

  // --- iOS (Cupertino UI) ---
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
            ? _buildEmptyState(context, TargetPlatform.iOS, theme, strings)
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
                          Text(
                            '${strings.destinationPrefix} ${task.targetRemote}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text('${strings.schedulePrefix} ${_formatScheduleDescription(strings, task)}'),
                          if (task.excludedFiles.isNotEmpty) ...[
                            SizedBox(height: theme.xs),
                            _buildExcludedFilesBadge(context, theme, strings, task.excludedFiles),
                          ],
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

  // --- Android (Material 3 UI) ---
  Widget _buildAndroid(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final strings = ref.watch(stringsProvider);
    final tasks = ref.watch(tasksListProvider);

    return material.Scaffold(
      appBar: material.AppBar(
        title: Text(strings.tasksTitle),
      ),
      body: tasks.isEmpty
        ? _buildEmptyState(context, TargetPlatform.android, theme, strings)
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
                      Text('${strings.destinationPrefix} ${task.targetRemote}'),
                      SizedBox(height: theme.xs),
                      Wrap(
                        spacing: theme.sm,
                        runSpacing: theme.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          material.Chip(
                            label: Text(
                              _formatScheduleDescription(strings, task),
                              style: const TextStyle(fontSize: 11),
                            ),
                            visualDensity: material.VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
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
          onPressed: () => _showAddEditTaskDialog(context, ref, null, TargetPlatform.android),
          child: Icon(material.Icons.add, semanticLabel: strings.addTask),
        ),
      ),
    );
  }

  // --- Common Empty State ---
  Widget _buildEmptyState(
    BuildContext context,
    TargetPlatform platform,
    AppThemeData theme,
    AppStrings strings,
  ) {
    final iconData = platform == TargetPlatform.windows
        ? fluent.FluentIcons.task_manager
        : (platform == TargetPlatform.iOS ? cupertino.CupertinoIcons.list_bullet : material.Icons.list_alt);

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
          ],
        ),
      ),
    );
  }

  // --- Excluded Files Badge Indicator ---
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

  // --- Destructive Action Confirmation Dialog (Rule 6 Guard) ---
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
              child: Text(strings.delete),
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
              child: Text(strings.delete),
            ),
          ],
        ),
      );
    }
  }

  // --- Main Add/Edit Dialog Dispatcher ---
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
    String selectedRemote = existingTask != null && remotesList.contains(existingTask.targetRemote)
        ? existingTask.targetRemote
        : remotesList.first;

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

            if (name.isEmpty) {
              newNameError = strings.taskNameRequiredError;
              hasError = true;
            }
            if (sourcePath.isEmpty) {
              newSourceError = strings.sourcePathRequiredError;
              hasError = true;
            }

            if (hasError) {
              setState(() {
                nameError = newNameError;
                sourceError = newSourceError;
              });
              return;
            }

            final String finalTime = selectedScheduleDay == 'Manual' ? '12:00' : '$selectedHour:$selectedMinute';
            final String finalSchedule = selectedScheduleDay == 'Daily'
                ? 'Daily at $finalTime'
                : (selectedScheduleDay == 'Manual' ? 'Manual' : 'Weekly on ${selectedScheduleDay}s at $finalTime');

            final task = BackupTask(
              id: existingTask?.id ?? 'task_${DateTime.now().millisecondsSinceEpoch}',
              name: name,
              sourcePath: sourcePath,
              targetRemote: selectedRemote,
              schedule: finalSchedule,
              scheduleDay: selectedScheduleDay,
              scheduleTime: finalTime,
              isActive: isActive,
              runMissedOnStartup: true,
              excludedFiles: existingTask?.excludedFiles ?? const [],
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
              nameError: nameError,
              sourceError: sourceError,
              selectedRemote: selectedRemote,
              remotesList: remotesList,
              onRemoteChanged: (val) {
                if (val != null) setState(() => selectedRemote = val);
              },
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
                child: Text(strings.save),
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
    required String? nameError,
    required String? sourceError,
    required String selectedRemote,
    required List<String> remotesList,
    required ValueChanged<String?> onRemoteChanged,
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
          Text(strings.sourcePathLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
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
          Text(strings.destinationRemoteLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: theme.xs),
          fluent.ComboBox<String>(
            value: selectedRemote,
            items: remotesList.map((remote) {
              return fluent.ComboBoxItem(value: remote, child: Text(remote));
            }).toList(),
            onChanged: onRemoteChanged,
          ),
          SizedBox(height: theme.md),
          Text(strings.scheduleDayLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
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

    String selectedRemote = existingTask != null && remotesList.contains(existingTask.targetRemote)
        ? existingTask.targetRemote
        : remotesList.first;

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

            if (hasError) {
              setState(() {
                nameError = newNameError;
                sourceError = newSourceError;
              });
              return;
            }

            final String finalTime = selectedScheduleDay == 'Manual' ? '12:00' : '$selectedHour:$selectedMinute';
            final String finalSchedule = selectedScheduleDay == 'Daily'
                ? 'Daily at $finalTime'
                : (selectedScheduleDay == 'Manual' ? 'Manual' : 'Weekly on ${selectedScheduleDay}s at $finalTime');

            final task = BackupTask(
              id: existingTask?.id ?? 'task_${DateTime.now().millisecondsSinceEpoch}',
              name: name,
              sourcePath: finalSourcePath,
              targetRemote: selectedRemote,
              schedule: finalSchedule,
              scheduleDay: selectedScheduleDay,
              scheduleTime: finalTime,
              isActive: isActive,
              runMissedOnStartup: true,
              excludedFiles: existingTask?.excludedFiles ?? const [],
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
            nameError: nameError,
            sourceError: sourceError,
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
            selectedRemote: selectedRemote,
            remotesList: remotesList,
            onRemoteChanged: (val) {
              if (val != null) setState(() => selectedRemote = val);
            },
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
    required String? nameError,
    required String? sourceError,
    required String selectedSourceCategory,
    required List<String> mobileCategories,
    required ValueChanged<String?> onSourceCategoryChanged,
    required String selectedRemote,
    required List<String> remotesList,
    required ValueChanged<String?> onRemoteChanged,
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
                Text(strings.sourceCategoryLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                Text(strings.destinationRemoteLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                SizedBox(height: theme.xs),
                cupertino.CupertinoSlidingSegmentedControl<String>(
                  groupValue: selectedRemote,
                  children: {
                    for (final remote in remotesList)
                      remote: Text(
                        remote.split(':').first,
                        style: const TextStyle(fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  },
                  onValueChanged: onRemoteChanged,
                ),
                SizedBox(height: theme.md),
                Text(strings.scheduleDayLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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

    String selectedRemote = existingTask != null && remotesList.contains(existingTask.targetRemote)
        ? existingTask.targetRemote
        : remotesList.first;

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

            if (hasError) {
              setState(() {
                nameError = newNameError;
                sourceError = newSourceError;
              });
              return;
            }

            final String finalTime = selectedScheduleDay == 'Manual' ? '12:00' : '$selectedHour:$selectedMinute';
            final String finalSchedule = selectedScheduleDay == 'Daily'
                ? 'Daily at $finalTime'
                : (selectedScheduleDay == 'Manual' ? 'Manual' : 'Weekly on ${selectedScheduleDay}s at $finalTime');

            final task = BackupTask(
              id: existingTask?.id ?? 'task_${DateTime.now().millisecondsSinceEpoch}',
              name: name,
              sourcePath: finalSourcePath,
              targetRemote: selectedRemote,
              schedule: finalSchedule,
              scheduleDay: selectedScheduleDay,
              scheduleTime: finalTime,
              isActive: isActive,
              runMissedOnStartup: true,
              excludedFiles: existingTask?.excludedFiles ?? const [],
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
              nameError: nameError,
              sourceError: sourceError,
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
              selectedRemote: selectedRemote,
              remotesList: remotesList,
              onRemoteChanged: (val) {
                if (val != null) setState(() => selectedRemote = val);
              },
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
                child: Text(strings.save),
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
    required String? nameError,
    required String? sourceError,
    required String selectedSourceCategory,
    required List<String> mobileCategories,
    required ValueChanged<String?> onSourceCategoryChanged,
    required String selectedRemote,
    required List<String> remotesList,
    required ValueChanged<String?> onRemoteChanged,
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
            decoration: material.InputDecoration(labelText: strings.sourceCategoryLabel),
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
          material.DropdownButtonFormField<String>(
            initialValue: selectedRemote,
            decoration: material.InputDecoration(labelText: strings.destinationRemoteLabel),
            items: remotesList.map((remote) {
              return material.DropdownMenuItem(value: remote, child: Text(remote));
            }).toList(),
            onChanged: onRemoteChanged,
          ),
          SizedBox(height: theme.lg),
          material.DropdownButtonFormField<String>(
            initialValue: selectedScheduleDay,
            decoration: material.InputDecoration(labelText: strings.scheduleDayLabel),
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
    return remotesAsync.maybeWhen(
      data: (list) => list.map((e) => '$e:backup').toList(),
      orElse: () => ['GoogleDrive_Backup:backup', 'OneDrive_Backup:backup', 'Dropbox_Backup:backup'],
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

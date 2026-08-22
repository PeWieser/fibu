import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../theme/theme.dart';
import '../../../theme/ios_theme.dart';
import '../../../core/utils/ios_haptics.dart';
import '../../../core/services/rclone_provider.dart';
import '../../../core/services/remote_registry_service.dart';
import '../../../core/services/sync_config_service.dart';
import '../../../core/localization/app_strings.dart';
import 'tasks_controller.dart';
import 'task_detail_screen.dart';

/// Platform-adaptive Tasks and Backup Jobs screen.
/// Renders layout dynamically based on current platform:
/// - Windows (Fluent Design)
/// - iOS (Cupertino)
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
              onPressed: () => showAddEditTaskDialog(context, ref, null, TargetPlatform.windows),
            ),
          ],
        ),
      ),
      content: !ref.watch(tasksLoadedProvider)
          ? const Center(child: fluent.ProgressRing())
          : tasks.isEmpty
              ? _buildEmptyState(context, ref, TargetPlatform.windows, theme, strings)
              : ListView.separated(
              padding: EdgeInsets.fromLTRB(theme.lg, theme.lg, theme.lg + 16, theme.lg),
              itemCount: tasks.length,
              separatorBuilder: (_, __) => SizedBox(height: theme.sm),
              itemBuilder: (context, index) {
                final task = tasks[index];
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: fluent.Card(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        Navigator.of(context).push(
                          fluent.FluentPageRoute(
                            builder: (_) => TaskDetailScreen(taskId: task.id),
                          ),
                        );
                      },
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Row(
                          children: [
                            Icon(
                              fluent.FluentIcons.task_manager,
                              size: 20,
                              color: theme.accent,
                              semanticLabel: strings.tasksTitle,
                            ),
                            SizedBox(width: theme.md),
                            Expanded(
                              child: Text(
                                task.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: theme.sm, vertical: theme.xs / 2),
                              decoration: BoxDecoration(
                                color: (task.isActive ? theme.accent : theme.textSecondary).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(theme.radiusSm),
                              ),
                              child: Text(
                                task.isActive ? strings.statusActive : strings.statusInactive,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: task.isActive ? theme.accent : theme.textSecondary,
                                ),
                              ),
                            ),
                            SizedBox(width: theme.md),
                            Icon(
                              fluent.FluentIcons.chevron_right,
                              size: 12,
                              color: theme.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  // =========================================================================
  // IOS (Cupertino UI in Apple Minimalist Style)
  // =========================================================================
  Widget _buildIOS(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final strings = ref.watch(stringsProvider);
    final tasks = ref.watch(tasksListProvider);

    // Lade-Gate: Beim Kaltstart kurz Spinner statt falschem Leerzustand.
    if (!ref.watch(tasksLoadedProvider)) {
      return cupertino.CupertinoPageScaffold(
        backgroundColor: theme.canvas,
        child: const SafeArea(
          child: Center(child: cupertino.CupertinoActivityIndicator()),
        ),
      );
    }

    final Widget listContent;
    if (tasks.isEmpty) {
      listContent = _buildEmptyState(context, ref, TargetPlatform.iOS, theme, strings);
    } else {
      listContent = SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(0, 0, 0, theme.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IosTheme.largeTitle(strings.tasksTitle, theme),
            cupertino.CupertinoListSection.insetGrouped(
              children: [
                for (final task in tasks)
                  _buildIOSTaskRow(context, ref, task, theme, strings),
              ],
            ),
          ],
        ),
      );
    }

    return cupertino.CupertinoPageScaffold(
      navigationBar: cupertino.CupertinoNavigationBar(
        middle: const SizedBox.shrink(),
        trailing: SizedBox(
          width: 44,
          height: 44,
          child: cupertino.CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              IosHaptics.light();
              showAddEditTaskDialog(context, ref, null, TargetPlatform.iOS);
            },
            child: Icon(cupertino.CupertinoIcons.add, semanticLabel: strings.addTask),
          ),
        ),
      ),
      backgroundColor: theme.canvas,
      child: SafeArea(child: listContent),
    );
  }

  /// Eine Task-Zeile (iOS) — Apple-konform ohne Swipe-Mülleimer; Löschen
  /// passiert nur in der Detailansicht (Bearbeiten-Modus).
  Widget _buildIOSTaskRow(BuildContext context, WidgetRef ref, BackupTask task,
      AppThemeData theme, AppStrings strings) {
    return cupertino.CupertinoListTile.notched(
      leading: Icon(
        cupertino.CupertinoIcons.folder_fill,
        color: theme.accent,
        size: 22,
        semanticLabel: task.name,
      ),
      title: Text(
        task.name,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      additionalInfo: Text(
        task.isActive ? strings.statusActive : strings.statusInactive,
        style: TextStyle(
          color: task.isActive ? theme.accent : theme.textSecondary,
          fontSize: 14,
        ),
      ),
      trailing: const Icon(
        cupertino.CupertinoIcons.chevron_forward,
        size: 18,
        color: cupertino.CupertinoColors.inactiveGray,
      ),
      onTap: () {
        Navigator.of(context).push(
          cupertino.CupertinoPageRoute(
            builder: (_) => TaskDetailScreen(taskId: task.id),
          ),
        );
      },
    );
  }

  // =========================================================================
  // ANDROID (Material 3 UI in Minimalist Style)
  // =========================================================================
  Widget _buildAndroid(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final strings = ref.watch(stringsProvider);
    final tasks = ref.watch(tasksListProvider);

    // Lade-Gate genauso wie iOS.
    if (!ref.watch(tasksLoadedProvider)) {
      return material.Scaffold(
        backgroundColor: theme.canvas,
        appBar: material.AppBar(title: Text(strings.tasksTitle)),
        body: const Center(child: material.CircularProgressIndicator()),
      );
    }

    return material.Scaffold(
      appBar: material.AppBar(title: Text(strings.tasksTitle)),
      backgroundColor: theme.canvas,
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
                    side: BorderSide(
                        color: material.Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: material.ListTile(
                    leading: Icon(
                      material.Icons.backup_outlined,
                      color: theme.accent,
                      semanticLabel: strings.tasksTitle,
                    ),
                    title: Text(task.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      task.isActive ? strings.statusActive : strings.statusInactive,
                      style: TextStyle(
                        color: task.isActive ? theme.accent : theme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Icon(
                      material.Icons.chevron_right,
                      color: theme.textSecondary,
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        material.MaterialPageRoute(
                          builder: (_) => TaskDetailScreen(taskId: task.id),
                        ),
                      );
                    },
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
          onPressed: () =>
              _showAddEditTaskDialog(context, ref, null, TargetPlatform.android),
          child: const Icon(material.Icons.add,
              color: Color(0xFFFFFFFF), semanticLabel: 'Add Task'),
        ),
      ),
    );
  }

  // =========================================================================
  // COMMON EMPTY STATE (leichter Hinweis auf das „+" oben rechts)
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
            Text(
              strings.tasksAddHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // CONTEXTUAL INFO TOOLTIP (ℹ️)
  // =========================================================================
  static Widget _buildInfoTooltip(
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

    final child = MouseRegion(
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
    );

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return Semantics(
        label: tooltipText,
        child: GestureDetector(
          onTap: () {},
          child: child,
        ),
      );
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
      child: child,
    );
  }

  // =========================================================================
  // DESTRUCTIVE ACTION CONFIRMATION DIALOG (Rule 6 Guard)
  //
  // Fragt NUR die Bestätigung ab (true = löschen bestätigt). Das eigentliche
  // Entfernen aus dem State passiert in onDismissed des Dismissible, damit die
  // Swipe-to-Delete-Animation sauber abschließen kann (kein
  // "A dismissed Dismissible widget is still part of the tree"-Fehler).
  // =========================================================================
  Future<bool> _confirmDeleteTaskAsync(BuildContext context, WidgetRef ref, BackupTask task, TargetPlatform platform) async {
    final strings = ref.read(stringsProvider);
    final theme = context.theme;
    final title = strings.deleteTaskConfirmTitle;
    final message = '${strings.deleteTaskPrompt(task.name)}\n\n${strings.deleteTaskRule6Notice}';

    if (platform == TargetPlatform.iOS) {
      final result = await cupertino.showCupertinoDialog<bool>(
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
              onPressed: () => Navigator.pop(dialogCtx, false),
            ),
            cupertino.CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: Text(strings.delete),
            ),
          ],
        ),
      );
      return result ?? false;
    } else if (platform == TargetPlatform.windows) {
      final result = await fluent.showDialog<bool>(
        context: context,
        builder: (dialogCtx) => fluent.ContentDialog(
          title: fluent.Text(title),
          content: Text(message),
          actions: [
            fluent.FilledButton(
              style: fluent.ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) => theme.error),
              ),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: Text(
                strings.delete,
                style: const TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
              ),
            ),
            fluent.Button(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text(strings.cancel),
            ),
          ],
        ),
      );
      return result ?? false;
    } else {
      final result = await material.showDialog<bool>(
        context: context,
        builder: (dialogCtx) => material.AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            material.TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text(strings.cancel),
            ),
            material.FilledButton(
              style: material.FilledButton.styleFrom(
                backgroundColor: theme.error,
              ),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: Text(
                strings.delete,
                style: const TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
      return result ?? false;
    }
  }

  // =========================================================================
  // MAIN ADD/EDIT DIALOG DISPATCHER (3-Step Wizard)
  // =========================================================================
  void _showAddEditTaskDialog(
    BuildContext context,
    WidgetRef ref,
    BackupTask? existingTask,
    TargetPlatform platform,
  ) {
    showAddEditTaskDialog(context, ref, existingTask, platform);
  }

  void showTaskDialog(
    BuildContext context,
    WidgetRef ref,
    BackupTask? existingTask, [
    TargetPlatform? platform,
  ]) {
    _showAddEditTaskDialog(context, ref, existingTask, platform ?? defaultTargetPlatform);
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
      data: (list) {
        if (list.isEmpty) return [];
        return list.map((e) => e.endsWith(':') ? e.substring(0, e.length - 1) : e).toList();
      },
      orElse: () => [],
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
}

/// Public dialog dispatcher for creating or editing backup tasks across platforms.
void showAddEditTaskDialog(
  BuildContext context,
  WidgetRef ref, [
  BackupTask? existingTask,
  TargetPlatform? platform,
]) {
  final targetPlatform = platform ?? defaultTargetPlatform;
  if (targetPlatform == TargetPlatform.windows) {
    fluent.showDialog(
      context: context,
      builder: (dialogCtx) => TaskWizardDialog(
        existingTask: existingTask,
        platform: TargetPlatform.windows,
      ),
    );
  } else if (targetPlatform == TargetPlatform.iOS) {
    cupertino.showCupertinoModalPopup(
      context: context,
      barrierDismissible: true,
      builder: (sheetCtx) => TaskWizardDialog(
        existingTask: existingTask,
        platform: TargetPlatform.iOS,
      ),
    );
  } else {
    material.showDialog(
      context: context,
      builder: (dialogCtx) => TaskWizardDialog(
        existingTask: existingTask,
        platform: TargetPlatform.android,
      ),
    );
  }
}

/// Ein Album in der iOS-Medienquellauswahl: Anzeigename plus asynchron
/// nachgeladene Anzahl der enthaltenen Fotos/Videos.
///
/// Die Auswahl selbst arbeitet weiterhin nur mit dem Namen ([name]) – [count]
/// ist eine reine Anzeige, die je nach Ladestand auch null sein kann.
class _AlbumOption {
  _AlbumOption(this.entity);

  /// Zugrunde liegende PhotoManager-Entity (für `assetCountAsync`).
  final AssetPathEntity entity;

  /// Anzahl der Medien im Album (null, solange noch geladen wird).
  int? count;

  String get name => entity.name;
}

// ===========================================================================
// 3-STEP TASK WIZARD DIALOG (Windows, iOS, Android)
// ===========================================================================
class TaskWizardDialog extends ConsumerStatefulWidget {
  final BackupTask? existingTask;
  final TargetPlatform platform;

  const TaskWizardDialog({
    super.key,
    this.existingTask,
    required this.platform,
  });

  @override
  ConsumerState<TaskWizardDialog> createState() => _TaskWizardDialogState();
}

class _TaskWizardDialogState extends ConsumerState<TaskWizardDialog> {
  int _currentStep = 0; // 0 = Grundlagen, 1 = Cloud-Ziel, 2 = Zeitplan & Modus

  late final TextEditingController _nameController;
  late final TextEditingController _srcController;
  late final TextEditingController _targetFolderController;

  late List<String> _selectedRemotes;
  late DistributionStrategy _selectedDistribution;
  late TargetFolderMode _selectedTargetFolderMode;
  late SyncMode _selectedSyncMode;

  late String _selectedScheduleDay;
  late String _selectedHour;
  late String _selectedMinute;
  late bool _isActive;

  // Mobile categories: 'all', 'photos', 'videos', 'folders' (Windows/Android)
  late String _selectedSourceCategory;

  // Neue Quell-Auswahl (iOS): Reiter "Fotos & Videos" / "Dateien".
  late String _sourceTab; // 'media' | 'files'
  List<_AlbumOption> _albums = [];
  final Set<String> _selectedAlbums = {};
  List<String> _localFolders = [];
  final Set<String> _selectedFolders = {};
  bool _loadingAlbums = false;
  bool _loadingFolders = false;

  // Zielordner: vorhandene Cloud-Ordner (Remote) durchsuchen.
  List<String> _remoteTargetFolders = [];
  bool _loadingRemoteFolders = false;
  String? _remoteFoldersError;
  String _selectedRemoteTargetFolder = '';
  // Pfad der aktuell durchsuchten Remote-Ebene ("" = Root).
  String _remoteFolderPath = '';
  final List<String> _remoteFolderHistory = [];

  String? _nameError;
  String? _sourceError;
  String? _remotesError;

  final List<String> _hours = List.generate(24, (i) => i.toString().padLeft(2, '0'));
  final List<String> _minutes = List.generate(12, (i) => (i * 5).toString().padLeft(2, '0'));

  @override
  void initState() {
    super.initState();
    final task = widget.existingTask;
    _nameController = TextEditingController(text: task?.name ?? '');
    _srcController = TextEditingController(text: task?.sourcePath ?? '');
    _targetFolderController = TextEditingController(text: task?.targetFolderName ?? 'fibu-backup');

    final remotesList = TasksScreen._resolveRemotesList(ref);
    _selectedRemotes = task != null && task.targetRemotes.isNotEmpty
        ? List<String>.from(task.targetRemotes)
        : (remotesList.isNotEmpty ? [remotesList.first] : []);

    _selectedDistribution = task?.distributionStrategy ?? DistributionStrategy.mirrorAll;
    _selectedTargetFolderMode = task?.targetFolderMode ?? TargetFolderMode.newFolder;
    _selectedSyncMode = task?.syncMode ?? SyncMode.incremental;

    _selectedScheduleDay = task?.scheduleDay ?? (widget.platform == TargetPlatform.iOS ? 'iOS System' : 'Daily');
    _selectedHour = '02';
    _selectedMinute = '00';
    if (task != null && task.scheduleTime.contains(':')) {
      final parts = task.scheduleTime.split(':');
      if (parts.length == 2) {
        _selectedHour = parts[0];
        _selectedMinute = parts[1];
      }
    }
    _isActive = task?.isActive ?? true;

    // iOS nutzt standardmäßig den Reiter "Fotos & Videos".
    _sourceTab = (widget.platform == TargetPlatform.iOS ? 'media' : 'folders');

    if (task != null) {
      if (task.sourcePath == 'all' || task.sourcePath == 'Alles') {
        _selectedSourceCategory = 'all';
      } else if (task.sourcePath == 'photos' || task.sourcePath == 'Alle Fotos') {
        _selectedSourceCategory = 'photos';
      } else if (task.sourcePath == 'videos' || task.sourcePath == 'Alle Videos') {
        _selectedSourceCategory = 'videos';
      } else if (task.sourcePath.startsWith('photos:') ||
          task.sourcePath.startsWith('videos:') ||
          task.sourcePath.startsWith('all:')) {
        // Codierte Album-Auswahl aus der Persistenz wiederherstellen.
        _sourceTab = 'media';
        _selectedSourceCategory = task.sourcePath.split(':').first;
        _selectedAlbums.addAll(task.selectedAlbums);
      } else if (task.sourcePath.startsWith('files:')) {
        _sourceTab = 'files';
        _selectedSourceCategory = 'folders';
        _selectedFolders.addAll(task.selectedFolders);
      } else {
        _selectedSourceCategory = 'folders';
      }
    } else {
      _selectedSourceCategory = 'all';
    }

    if (widget.platform == TargetPlatform.iOS) {
      _loadAlbums();
      _loadLocalFolders();
    }
  }

  /// Anzeigeliste der wählbaren Ziel-Remotes (Registry-IDs) plus evtl.
  /// verwaiste, in der Aufgabe gespeicherte Referenzen ans Ende.
  List<String> _wizardRemoteIds() {
    final entries = ref.watch(remoteEntriesProvider).valueOrNull ?? const [];
    final known = entries.isNotEmpty
        ? entries.map((e) => e.id).toList()
        : TasksScreen._resolveRemotesList(ref);
    final ids = [...known];
    for (final sel in _selectedRemotes) {
      if (!ids.contains(sel)) ids.add(sel);
    }
    return ids;
  }

  /// Zeilen-Label: nur der Anzeigename — verwaiste Kennungen mit Hinweis.
  String _remoteLabel(String id) {
    final entries =
        ref.read(remoteEntriesProvider).valueOrNull ?? const [];
    for (final e in entries) {
      if (e.id == id) return e.name;
    }
    return '$id (${context.strings.remoteMissingBadge})';
  }

  Future<void> _loadAlbums() async {
    try {
      setState(() => _loadingAlbums = true);
      final ps = await PhotoManager.requestPermissionExtend();
      final List<AssetPathEntity> paths = ps.isAuth || ps.hasAccess
          ? await PhotoManager.getAssetPathList(type: RequestType.common, hasAll: true)
          : [];
      if (!mounted) return;
      setState(() {
        _albums = paths.map((p) => _AlbumOption(p)).toList();
        _loadingAlbums = false;
      });
      // Anzahl je Album nicht-blockierend nachladen – die Liste selbst
      // (Name + Auswahl) steht schon ab hier zur Verfügung.
      await _loadAlbumCounts();
    } catch (_) {
      if (mounted) setState(() => _loadingAlbums = false);
    }
  }

  /// Lädt die Anzahl der Fotos/Videos je Album asynchron nach
  /// (assetCountAsync pro Album) und aktualisiert die UI schrittweise.
  Future<void> _loadAlbumCounts() async {
    // Iteration über eine KOPIE: leere Alben werden rausgeschmissen.
    for (final album in List.of(_albums)) {
      try {
        final count = await album.entity.assetCountAsync;
        if (!mounted || !_albums.contains(album)) return;
        setState(() {
          album.count = count;
          if (count == 0) {
            _albums.remove(album);
            _selectedAlbums.remove(album.name);
          }
        });
      } catch (_) {
        // Zähler einzelner Alben ist rein kosmetisch – Auswahl hängt am Namen.
      }
    }
  }

  Future<void> _loadLocalFolders() async {
    try {
      setState(() => _loadingFolders = true);
      final dir = await getApplicationDocumentsDirectory();
      final List<String> folders = [];
      if (await dir.exists()) {
        await for (final e in dir.list(followLinks: false)) {
          if (e is Directory) {
            folders.add(e.path);
          }
        }
      }
      if (mounted) {
        setState(() {
          _localFolders = folders;
          _loadingFolders = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFolders = false);
    }
  }

  /// Lädt die vorhandenen Cloud-Ordner (Remote) für die Zielordner-Auswahl.
  Future<void> _loadRemoteTargetFolders() async {
    if (_selectedRemotes.isEmpty) return;
    setState(() {
      _loadingRemoteFolders = true;
      _remoteFoldersError = null;
    });
    try {
      final remote = _selectedRemotes.first;
      // Nur das Remote-Verzeichnis (aktueller Unterordner), niemals lokal.
      final files = await ref.read(rcloneServiceProvider).listFiles(remote, _remoteFolderPath);
      if (mounted) {
        setState(() {
          _remoteTargetFolders = files
              .where((f) => f.isDir)
              .map((f) => f.name)
              .toList();
          _loadingRemoteFolders = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _remoteFoldersError = stringsRemoteFoldersError();
          _loadingRemoteFolders = false;
        });
      }
    }
  }

  void _openRemoteFolder(String folderName) {
    _remoteFolderHistory.add(_remoteFolderPath);
    _remoteFolderPath = _remoteFolderPath.isEmpty
        ? folderName
        : '$_remoteFolderPath/$folderName';
    _selectedRemoteTargetFolder = '';
    _loadRemoteTargetFolders();
  }

  void _goUpRemoteFolder() {
    if (_remoteFolderHistory.isNotEmpty) {
      _remoteFolderPath = _remoteFolderHistory.removeLast();
    } else {
      _remoteFolderPath = '';
    }
    _selectedRemoteTargetFolder = '';
    _loadRemoteTargetFolders();
  }

  String stringsRemoteFoldersError() {
    final strings = ref.read(stringsProvider);
    return strings.remoteFoldersLoadError;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _srcController.dispose();
    _targetFolderController.dispose();
    super.dispose();
  }

  void _applyPreset(String presetType, AppStrings strings) {
    setState(() {
      if (presetType == 'media_mirror') {
        _nameController.text = strings.presetMediaMirrorTitle;
        _selectedSourceCategory = 'all';
        _srcController.text = widget.platform == TargetPlatform.windows ? 'Pictures' : 'all';
        _selectedSyncMode = SyncMode.mirror;
        _selectedTargetFolderMode = TargetFolderMode.newFolder;
        _targetFolderController.text = 'Mediathek';
        _selectedScheduleDay = widget.platform == TargetPlatform.iOS ? 'iOS System' : 'Daily';
      } else if (presetType == 'media_incremental') {
        _nameController.text = strings.presetMediaIncrementalTitle;
        _selectedSourceCategory = 'all';
        _srcController.text = widget.platform == TargetPlatform.windows ? 'Pictures' : 'all';
        _selectedSyncMode = SyncMode.incremental;
        _selectedTargetFolderMode = TargetFolderMode.newFolder;
        _targetFolderController.text = 'Fotos';
        _selectedScheduleDay = widget.platform == TargetPlatform.iOS ? 'iOS System' : 'Daily';
      } else if (presetType == 'documents') {
        _nameController.text = strings.presetDocsTitle;
        _selectedSourceCategory = 'folders';
        _srcController.text = widget.platform == TargetPlatform.windows ? 'Documents' : 'documents';
        _selectedSyncMode = SyncMode.incremental;
        _selectedTargetFolderMode = TargetFolderMode.newFolder;
        _targetFolderController.text = 'Dokumente';
        _selectedScheduleDay = widget.platform == TargetPlatform.iOS ? 'iOS System' : 'Daily';
      }
      _nameError = null;
      _sourceError = null;
    });
  }

  Widget _buildPresetCard({
    required AppThemeData theme,
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(theme.md),
        decoration: BoxDecoration(
          color: isSelected ? theme.accent.withValues(alpha: 0.08) : theme.surface,
          borderRadius: BorderRadius.circular(theme.radiusSm),
          border: Border.all(
            color: isSelected ? theme.accent : theme.textSecondary.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(theme.xs),
              decoration: BoxDecoration(
                color: theme.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(theme.radiusSm),
              ),
              child: Icon(icon, size: 20, color: theme.accent),
            ),
            SizedBox(width: theme.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? theme.accent : theme.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: theme.xs, vertical: theme.xs / 2),
                        decoration: BoxDecoration(
                          color: isSelected ? theme.accent : theme.textSecondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? const Color(0xFFFFFFFF) : theme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: theme.xs / 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: theme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetSelectionCards(BuildContext context, AppThemeData theme, AppStrings strings) {
    if (widget.existingTask != null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              widget.platform == TargetPlatform.windows
                  ? fluent.FluentIcons.favorite_star
                  : (widget.platform == TargetPlatform.iOS
                      ? cupertino.CupertinoIcons.sparkles
                      : material.Icons.auto_awesome),
              size: 16,
              color: theme.accent,
            ),
            SizedBox(width: theme.xs),
            Text(
              strings.presetSelectHeader,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
        SizedBox(height: theme.xs / 2),
        Text(
          strings.presetSelectSubtitle,
          style: TextStyle(fontSize: 11, color: theme.textSecondary),
        ),
        SizedBox(height: theme.sm),
        // Preset 1: Mediathek-Spiegelung (2-Wege Mirror)
        _buildPresetCard(
          theme: theme,
          title: strings.presetMediaMirrorTitle,
          subtitle: strings.presetMediaMirrorSubtitle,
          badge: strings.presetMediaMirrorBadge,
          icon: widget.platform == TargetPlatform.iOS
              ? cupertino.CupertinoIcons.photo_on_rectangle
              : (widget.platform == TargetPlatform.windows ? fluent.FluentIcons.photo_collection : material.Icons.photo_library_outlined),
          isSelected: _selectedSyncMode == SyncMode.mirror && _targetFolderController.text == 'Mediathek',
          onTap: () => _applyPreset('media_mirror', strings),
        ),
        SizedBox(height: theme.xs),
        // Preset 2: Medien-Sicherung (Inkrementell)
        _buildPresetCard(
          theme: theme,
          title: strings.presetMediaIncrementalTitle,
          subtitle: strings.presetMediaIncrementalSubtitle,
          badge: strings.syncModeIncremental,
          icon: widget.platform == TargetPlatform.iOS
              ? cupertino.CupertinoIcons.camera
              : (widget.platform == TargetPlatform.windows ? fluent.FluentIcons.camera : material.Icons.photo_camera_outlined),
          isSelected: _selectedSyncMode == SyncMode.incremental && _targetFolderController.text == 'Fotos',
          onTap: () => _applyPreset('media_incremental', strings),
        ),
        SizedBox(height: theme.xs),
        // Preset 3: Dokumente & Dateien
        _buildPresetCard(
          theme: theme,
          title: strings.presetDocsTitle,
          subtitle: strings.presetDocsSubtitle,
          badge: strings.syncModeIncremental,
          icon: widget.platform == TargetPlatform.iOS
              ? cupertino.CupertinoIcons.doc_text
              : (widget.platform == TargetPlatform.windows ? fluent.FluentIcons.document : material.Icons.description_outlined),
          isSelected: _targetFolderController.text == 'Dokumente',
          onTap: () => _applyPreset('documents', strings),
        ),
        SizedBox(height: theme.md),
        const material.Divider(height: 1),
        SizedBox(height: theme.md),
      ],
    );
  }

  bool _validateStep0(AppStrings strings) {
    final name = _nameController.text.trim();
    final sourcePath = _srcController.text.trim();

    bool hasError = false;
    String? newNameError;
    String? newSourceError;

    if (name.isEmpty) {
      newNameError = strings.taskNameRequiredError;
      hasError = true;
    }

    if (widget.platform == TargetPlatform.iOS) {
      // iOS: Quelle muss gewählt sein — mindestens ein Album (Medien-Tab)
      // bzw. ein Ordner (Dateien-Tab).
      if (_sourceTab == 'media' && _selectedAlbums.isEmpty) {
        newSourceError = strings.selectAtLeastOneAlbum;
        hasError = true;
      } else if (_sourceTab == 'files' && _selectedFolders.isEmpty) {
        newSourceError = strings.sourcePathRequiredError;
        hasError = true;
      }
    } else if (widget.platform == TargetPlatform.windows || _selectedSourceCategory == 'folders') {
      if (sourcePath.isEmpty) {
        newSourceError = strings.sourcePathRequiredError;
        hasError = true;
      }
    }

    setState(() {
      _nameError = newNameError;
      _sourceError = newSourceError;
    });

    return !hasError;
  }

  bool _validateStep1(AppStrings strings) {
    if (_selectedRemotes.isEmpty) {
      setState(() {
        _remotesError = strings.selectAtLeastOneRemote;
      });
      return false;
    }
    setState(() {
      _remotesError = null;
    });
    return true;
  }

  /// Wenn im Medien-Tab (iOS) noch kein Album gewählt ist, bleibt ‚Weiter'
  /// deaktiviert — leere Auswahl bedeutet nicht mehr still „alles sichern“.
  bool get _nextBlocked =>
      _currentStep == 0 &&
      _sourceTab == 'media' &&
      widget.platform == TargetPlatform.iOS &&
      _selectedAlbums.isEmpty;

  void _handleNext(AppStrings strings) {
    if (_currentStep == 0) {
      if (_validateStep0(strings)) {
        setState(() => _currentStep = 1);
      }
    } else if (_currentStep == 1) {
      if (_validateStep1(strings)) {
        setState(() => _currentStep = 2);
      }
    }
  }

  void _handleBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _handleSave(AppStrings strings) {
    if (!_validateStep0(strings)) {
      setState(() => _currentStep = 0);
      return;
    }
    if (!_validateStep1(strings)) {
      setState(() => _currentStep = 1);
      return;
    }

    final name = _nameController.text.trim();
    String finalSourcePath = _srcController.text.trim();

    // Gespeicherte Album-/Ordner-Auswahl.
    final List<String> selectedAlbums = List<String>.from(_selectedAlbums);
    final List<String> selectedFolders = List<String>.from(_selectedFolders);

    if (widget.platform == TargetPlatform.iOS) {
      if (_sourceTab == 'files') {
        // Dateien: lokale Ordner codiert übergeben.
        finalSourcePath = 'files:${selectedFolders.join('|')}';
      } else {
        // Fotos & Videos: "all:Album1|Album2"; leer = alle Alben.
        if (selectedAlbums.isEmpty) {
          finalSourcePath = 'all';
        } else {
          finalSourcePath = 'all:${selectedAlbums.join('|')}';
        }
      }
    } else if (widget.platform != TargetPlatform.windows && _selectedSourceCategory != 'folders') {
      finalSourcePath = _selectedSourceCategory;
    }

    final String finalTime = _selectedScheduleDay == 'Manual' ? '12:00' : '$_selectedHour:$_selectedMinute';
    final String finalSchedule = _selectedScheduleDay == 'iOS System'
        ? strings.iosBackgroundScheduleBadge
        : (_selectedScheduleDay == 'Daily'
            ? 'Daily at $finalTime'
            : (_selectedScheduleDay == 'Manual' ? 'Manual' : 'Weekly on ${_selectedScheduleDay}s at $finalTime'));

    String finalTargetFolder = _targetFolderController.text.trim();
    if (_selectedTargetFolderMode == TargetFolderMode.root) {
      finalTargetFolder = '/';
    } else if (finalTargetFolder.isEmpty) {
      finalTargetFolder = _selectedTargetFolderMode == TargetFolderMode.newFolder ? 'fibu-backup' : 'backup/media';
    }

    final task = BackupTask(
      id: widget.existingTask?.id ?? 'task_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      sourcePath: finalSourcePath,
      targetRemotes: List<String>.from(_selectedRemotes),
      schedule: finalSchedule,
      scheduleDay: _selectedScheduleDay,
      scheduleTime: finalTime,
      isActive: _isActive,
      runMissedOnStartup: true,
      excludedFiles: widget.existingTask?.excludedFiles ?? const [],
      syncMode: _selectedSyncMode,
      distributionStrategy: _selectedRemotes.length > 1 ? _selectedDistribution : DistributionStrategy.mirrorAll,
      targetFolderMode: _selectedTargetFolderMode,
      targetFolderName: finalTargetFolder,
      // wifiOnly wird bewusst NICHT mehr pro Task gesetzt (Default bleibt für
      // Alt-Daten) – die WLAN-only-Regel ist global (Einstellungen).
      selectedAlbums: selectedAlbums,
      selectedFolders: selectedFolders,
    );

    if (widget.existingTask == null) {
      ref.read(tasksListProvider.notifier).addTask(task);
    } else {
      ref.read(tasksListProvider.notifier).updateTask(widget.existingTask!.id, task);
    }

    // Fibu-Config aufs Remote schreiben, damit ein Neuaufsetzen / weiteres Gerät
    // diese Task automatisch übernehmen kann (.fibu/config.json).
    _writeRemoteConfigFor(task);

    if (widget.platform == TargetPlatform.iOS) IosHaptics.medium();
    Navigator.pop(context);
  }

  /// Schreibt die aktuelle Task-Konfiguration für das erste Ziel-Remote auf.
  Future<void> _writeRemoteConfigFor(BackupTask task) async {
    if (task.targetRemotes.isEmpty) return;
    final remote = task.targetRemotes.first;
    final allTasks = ref.read(tasksListProvider);
    try {
      await ref
          .read(syncConfigServiceProvider)
          .writeConfigToRemote(remote, allTasks, task.targetFolderName);
    } catch (_) {
      // Nicht-blockierend: schlägt das Schreiben fehl, stört es die Task-Erstellung nicht.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final strings = ref.watch(stringsProvider);
    // Registry-basierte Liste der Remote-IDs. In der Aufgabe noch
    // vermerkte, inzwischen getrennte Remotes bleiben sichtbar (Badge),
    // damit das Ziel bewusst neu gewählt werden kann.
    final remotesList = _wizardRemoteIds();

    if (widget.platform == TargetPlatform.iOS) {
      return _buildIOSLayout(context, theme, strings, remotesList);
    } else if (widget.platform == TargetPlatform.windows) {
      return _buildWindowsLayout(context, theme, strings, remotesList);
    } else {
      return _buildAndroidLayout(context, theme, strings, remotesList);
    }
  }

  // =========================================================================
  // STEP INDICATOR HEADER (3 Connected Step Badges)
  // =========================================================================
  Widget _buildStepIndicatorHeader(AppThemeData theme, AppStrings strings) {
    final stepTitles = [
      strings.taskWizardStep1Title,
      strings.taskWizardStep2Title,
      strings.taskWizardStep3Title,
    ];
    final stepSubtitles = [
      strings.taskWizardStep1Subtitle,
      strings.taskWizardStep2Subtitle,
      strings.taskWizardStep3Subtitle,
    ];

    return Container(
      padding: EdgeInsets.fromLTRB(theme.lg, theme.md, theme.lg, theme.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildStepBadge(theme, 0, strings.stepIndicator),
              Expanded(
                child: Container(
                  height: 2,
                  margin: EdgeInsets.symmetric(horizontal: theme.xs),
                  color: _currentStep > 0 ? theme.accent : theme.textSecondary.withValues(alpha: 0.25),
                ),
              ),
              _buildStepBadge(theme, 1, strings.stepIndicator),
              Expanded(
                child: Container(
                  height: 2,
                  margin: EdgeInsets.symmetric(horizontal: theme.xs),
                  color: _currentStep > 1 ? theme.accent : theme.textSecondary.withValues(alpha: 0.25),
                ),
              ),
              _buildStepBadge(theme, 2, strings.stepIndicator),
            ],
          ),
          SizedBox(height: theme.md),
          Text(
            stepTitles[_currentStep],
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: theme.xs / 2),
          Text(
            stepSubtitles[_currentStep],
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBadge(AppThemeData theme, int index, String stepWord) {
    final isCompleted = index < _currentStep;
    final isActive = index == _currentStep;

    final Color badgeBg;
    final Color badgeTextColor;
    final Border? border;

    if (isActive) {
      badgeBg = theme.accent;
      badgeTextColor = const Color(0xFFFFFFFF);
      border = null;
    } else if (isCompleted) {
      badgeBg = theme.accent.withValues(alpha: 0.2);
      badgeTextColor = theme.accent;
      border = Border.all(color: theme.accent, width: 1.5);
    } else {
      badgeBg = theme.surface;
      badgeTextColor = theme.textSecondary;
      border = Border.all(color: theme.textSecondary.withValues(alpha: 0.3), width: 1);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: badgeBg,
            shape: BoxShape.circle,
            border: border,
          ),
          child: Center(
            child: isCompleted
                ? Icon(
                    defaultTargetPlatform == TargetPlatform.windows
                        ? fluent.FluentIcons.check_mark
                        : (defaultTargetPlatform == TargetPlatform.iOS
                            ? cupertino.CupertinoIcons.checkmark
                            : material.Icons.check),
                    size: 13,
                    color: theme.accent,
                    semanticLabel: 'Done',
                  )
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: badgeTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        SizedBox(width: theme.xs),
        Text(
          '$stepWord ${index + 1}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? theme.accent : theme.textSecondary,
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // WINDOWS WIZARD LAYOUT (Fluent Design)
  // =========================================================================
  Widget _buildWindowsLayout(
    BuildContext context,
    AppThemeData theme,
    AppStrings strings,
    List<String> remotesList,
  ) {
    return Center(
      child: material.Material(
        color: material.Colors.transparent,
        child: Container(
          width: 580,
          constraints: const BoxConstraints(maxHeight: 680),
          margin: EdgeInsets.all(theme.lg),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(theme.radiusLg),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
            border: Border.all(color: theme.textSecondary.withValues(alpha: 0.15), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: EdgeInsets.fromLTRB(theme.lg, theme.md, theme.md, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.existingTask == null ? strings.addTask : strings.editTask,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: fluent.IconButton(
                          icon: Icon(fluent.FluentIcons.chrome_close, size: 12, semanticLabel: strings.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _buildStepIndicatorHeader(theme, strings),
              const material.Divider(height: 1),

              // Animated Step Body
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(theme.lg, theme.md, theme.lg + 16, theme.lg),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: KeyedSubtree(
                      key: ValueKey<int>(_currentStep),
                      child: _buildWindowsStepContent(context, theme, strings, remotesList),
                    ),
                  ),
                ),
              ),
              const material.Divider(height: 1),

              // Bottom Actions
              Padding(
                padding: EdgeInsets.all(theme.md),
                child: Row(
                  children: [
                    fluent.Button(
                      onPressed: () => Navigator.pop(context),
                      child: Text(strings.cancel),
                    ),
                    const Spacer(),
                    if (_currentStep > 0) ...[
                      fluent.Button(
                        onPressed: _handleBack,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(fluent.FluentIcons.back, size: 12),
                            SizedBox(width: theme.xs),
                            Text(strings.back),
                          ],
                        ),
                      ),
                      SizedBox(width: theme.sm),
                    ],
                    if (_currentStep < 2)
                      fluent.FilledButton(
                        onPressed: _nextBlocked ? null : () => _handleNext(strings),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              strings.next,
                              style: const TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
                            ),
                            SizedBox(width: theme.xs),
                            const Icon(fluent.FluentIcons.forward, size: 12, color: Color(0xFFFFFFFF)),
                          ],
                        ),
                      )
                    else
                      fluent.FilledButton(
                        onPressed: () => _handleSave(strings),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(fluent.FluentIcons.save, size: 14, color: Color(0xFFFFFFFF)),
                            SizedBox(width: theme.xs),
                            Text(
                              strings.save,
                              style: const TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWindowsStepContent(
    BuildContext context,
    AppThemeData theme,
    AppStrings strings,
    List<String> remotesList,
  ) {
    if (_currentStep == 0) {
      return _buildWindowsStep1(context, theme, strings);
    } else if (_currentStep == 1) {
      return _buildWindowsStep2(context, theme, strings, remotesList);
    } else {
      return _buildWindowsStep3(context, theme, strings);
    }
  }

  Widget _buildWindowsStep1(BuildContext context, AppThemeData theme, AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPresetSelectionCards(context, theme, strings),
        Text(strings.taskNameLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: theme.xs),
        fluent.TextBox(
          controller: _nameController,
          placeholder: strings.taskNameHint,
          decoration: _nameError != null
              ? WidgetStatePropertyAll(
                  BoxDecoration(
                    color: theme.surface,
                    border: Border.all(color: theme.error, width: 1.5),
                    borderRadius: BorderRadius.circular(theme.radiusSm),
                  ),
                )
              : null,
          onChanged: (_) {
            if (_nameError != null) setState(() => _nameError = null);
          },
        ),
        if (_nameError != null) ...[
          SizedBox(height: theme.xs),
          Text(
            _nameError!,
            style: TextStyle(color: theme.error, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
        SizedBox(height: theme.lg),
        Row(
          children: [
            Text(strings.sourcePathLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(width: theme.xs),
            TasksScreen._buildInfoTooltip(context, theme, strings.tooltipSourcePath),
          ],
        ),
        SizedBox(height: theme.xs),
        Row(
          children: [
            Expanded(
              child: fluent.TextBox(
                controller: _srcController,
                placeholder: strings.sourcePathHint,
                decoration: _sourceError != null
                    ? WidgetStatePropertyAll(
                        BoxDecoration(
                          color: theme.surface,
                          border: Border.all(color: theme.error, width: 1.5),
                          borderRadius: BorderRadius.circular(theme.radiusSm),
                        ),
                      )
                    : null,
                onChanged: (_) {
                  if (_sourceError != null) setState(() => _sourceError = null);
                },
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
                  onPressed: () async {
                    final path = await FilePicker.getDirectoryPath();
                    if (path != null) {
                      setState(() {
                        _srcController.text = path;
                        _sourceError = null;
                      });
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        if (_sourceError != null) ...[
          SizedBox(height: theme.xs),
          Text(
            _sourceError!,
            style: TextStyle(color: theme.error, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ],
    );
  }

  Widget _buildWindowsStep2(
    BuildContext context,
    AppThemeData theme,
    AppStrings strings,
    List<String> remotesList,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(strings.destinationRemoteLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(width: theme.xs),
            TasksScreen._buildInfoTooltip(context, theme, strings.tooltipDestinationRemote),
          ],
        ),
        SizedBox(height: theme.xs),
        Container(
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(theme.radiusSm),
            border: Border.all(
              color: _remotesError != null ? theme.error : theme.textSecondary.withValues(alpha: 0.25),
              width: _remotesError != null ? 1.5 : 1,
            ),
          ),
          padding: EdgeInsets.all(theme.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: remotesList.map((remote) {
              final isChecked = _selectedRemotes.contains(remote);
              return Padding(
                padding: EdgeInsets.symmetric(vertical: theme.xs / 2),
                child: fluent.Checkbox(
                  checked: isChecked,
                  content: Text(_remoteLabel(remote)),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        if (!_selectedRemotes.contains(remote)) _selectedRemotes.add(remote);
                      } else {
                        _selectedRemotes.remove(remote);
                      }
                      if (_selectedRemotes.isNotEmpty) _remotesError = null;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
        if (_remotesError != null) ...[
          SizedBox(height: theme.xs),
          Text(
            _remotesError!,
            style: TextStyle(color: theme.error, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],

        // Distribution Strategy (Shown only if > 1 remote selected)
        if (_selectedRemotes.length > 1) ...[
          SizedBox(height: theme.lg),
          Row(
            children: [
              Text(strings.distributionStrategyLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(width: theme.xs),
              TasksScreen._buildInfoTooltip(context, theme, strings.distributionTooltip),
            ],
          ),
          SizedBox(height: theme.xs),
          fluent.Card(
            padding: EdgeInsets.all(theme.sm),
            backgroundColor: _selectedDistribution == DistributionStrategy.mirrorAll
                ? theme.accent.withValues(alpha: 0.08)
                : theme.surface,
            borderColor: _selectedDistribution == DistributionStrategy.mirrorAll ? theme.accent : null,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _selectedDistribution = DistributionStrategy.mirrorAll),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _selectedDistribution == DistributionStrategy.mirrorAll
                          ? fluent.FluentIcons.radio_bullet
                          : fluent.FluentIcons.radio_btn_off,
                      color: _selectedDistribution == DistributionStrategy.mirrorAll ? theme.accent : theme.textSecondary,
                      size: 18,
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
            backgroundColor: _selectedDistribution == DistributionStrategy.balance
                ? theme.accent.withValues(alpha: 0.08)
                : theme.surface,
            borderColor: _selectedDistribution == DistributionStrategy.balance ? theme.accent : null,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _selectedDistribution = DistributionStrategy.balance),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _selectedDistribution == DistributionStrategy.balance
                          ? fluent.FluentIcons.radio_bullet
                          : fluent.FluentIcons.radio_btn_off,
                      color: _selectedDistribution == DistributionStrategy.balance ? theme.accent : theme.textSecondary,
                      size: 18,
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

        // Target Folder Mode
        SizedBox(height: theme.lg),
        Row(
          children: [
            Text(strings.targetFolderModeLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(width: theme.xs),
            TasksScreen._buildInfoTooltip(context, theme, strings.targetFolderTooltip),
          ],
        ),
        SizedBox(height: theme.xs),
        fluent.ComboBox<TargetFolderMode>(
          value: _selectedTargetFolderMode,
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
            if (val != null) setState(() => _selectedTargetFolderMode = val);
          },
        ),
        if (_selectedTargetFolderMode == TargetFolderMode.custom || _selectedTargetFolderMode == TargetFolderMode.newFolder) ...[
          SizedBox(height: theme.xs),
          fluent.TextBox(
            controller: _targetFolderController,
            placeholder: _selectedTargetFolderMode == TargetFolderMode.newFolder
                ? strings.newFolderNameHint
                : 'fibu-backup',
          ),
        ],
      ],
    );
  }

  Widget _buildWindowsStep3(BuildContext context, AppThemeData theme, AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(strings.syncModeLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(width: theme.xs),
            TasksScreen._buildInfoTooltip(
              context,
              theme,
              _selectedSyncMode == SyncMode.incremental
                  ? strings.syncModeTooltipIncremental
                  : strings.syncModeTooltipMirror,
            ),
          ],
        ),
        SizedBox(height: theme.xs),
        fluent.Card(
          padding: EdgeInsets.all(theme.sm),
          backgroundColor: _selectedSyncMode == SyncMode.incremental
              ? theme.accent.withValues(alpha: 0.08)
              : theme.surface,
          borderColor: _selectedSyncMode == SyncMode.incremental ? theme.accent : null,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _selectedSyncMode = SyncMode.incremental),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _selectedSyncMode == SyncMode.incremental
                        ? fluent.FluentIcons.radio_bullet
                        : fluent.FluentIcons.radio_btn_off,
                    color: _selectedSyncMode == SyncMode.incremental ? theme.accent : theme.textSecondary,
                    size: 18,
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
          backgroundColor: _selectedSyncMode == SyncMode.mirror
              ? theme.warning.withValues(alpha: 0.1)
              : theme.surface,
          borderColor: _selectedSyncMode == SyncMode.mirror ? theme.warning : null,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _selectedSyncMode = SyncMode.mirror),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _selectedSyncMode == SyncMode.mirror
                        ? fluent.FluentIcons.radio_bullet
                        : fluent.FluentIcons.radio_btn_off,
                    color: _selectedSyncMode == SyncMode.mirror ? theme.warning : theme.textSecondary,
                    size: 18,
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
                                color: _selectedSyncMode == SyncMode.mirror ? theme.warning : null,
                              ),
                            ),
                            SizedBox(width: theme.xs),
                            Icon(
                              fluent.FluentIcons.warning,
                              size: 14,
                              color: theme.warning,
                            ),
                          ],
                        ),
                        SizedBox(height: theme.xs / 2),
                        Text(
                          strings.syncModeMirrorDescription,
                          style: TextStyle(
                            fontSize: 11,
                            color: _selectedSyncMode == SyncMode.mirror ? theme.warning : theme.textSecondary,
                            fontWeight: _selectedSyncMode == SyncMode.mirror ? FontWeight.w500 : FontWeight.normal,
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

        // Schedule Repeat & Time
        Row(
          children: [
            Text(strings.scheduleDayLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(width: theme.xs),
            TasksScreen._buildInfoTooltip(context, theme, strings.tooltipSchedule),
          ],
        ),
        SizedBox(height: theme.xs),
        fluent.ComboBox<String>(
          value: _selectedScheduleDay,
          items: TasksScreen._scheduleDayKeys.map((sched) {
            return fluent.ComboBoxItem(value: sched, child: Text(TasksScreen._getDayLabel(strings, sched)));
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedScheduleDay = val);
          },
        ),
        if (_selectedScheduleDay != 'Manual') ...[
          SizedBox(height: theme.sm),
          Row(
            children: [
              Text('${strings.scheduleTimeLabel}:'),
              SizedBox(width: theme.sm),
              fluent.ComboBox<String>(
                value: _selectedHour,
                items: _hours.map((h) => fluent.ComboBoxItem(value: h, child: Text(h))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedHour = val);
                },
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: theme.xs),
                child: const Text(':'),
              ),
              fluent.ComboBox<String>(
                value: _selectedMinute,
                items: _minutes.map((m) => fluent.ComboBoxItem(value: m, child: Text(m))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedMinute = val);
                },
              ),
            ],
          ),
        ],
        SizedBox(height: theme.lg),

        // Active Toggle
        Row(
          children: [
            Text('${strings.activeSyncJob}:', style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            fluent.ToggleSwitch(
              checked: _isActive,
              onChanged: (val) => setState(() => _isActive = val),
            ),
          ],
        ),
        SizedBox(height: theme.sm),

        // Catch-up Notice
        Row(
          children: [
            Icon(fluent.FluentIcons.completed, size: 14, color: theme.success, semanticLabel: strings.catchUpNotice),
            SizedBox(width: theme.xs),
            Expanded(
              child: Text(
                strings.catchUpNotice,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(width: theme.xs),
            TasksScreen._buildInfoTooltip(context, theme, strings.tooltipCatchUp),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // IOS WIZARD LAYOUT (Cupertino)
  // =========================================================================
  Widget _buildIOSLayout(
    BuildContext context,
    AppThemeData theme,
    AppStrings strings,
    List<String> remotesList,
  ) {
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
          middle: Text(widget.existingTask == null ? strings.addTask : strings.editTask),
          leading: SizedBox(
            width: 70,
            height: 44,
            child: cupertino.CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.pop(context),
              child: Text(strings.cancel),
            ),
          ),
          trailing: SizedBox(
            width: 80,
            height: 44,
            child: cupertino.CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _currentStep < 2 ? () => _handleNext(strings) : () => _handleSave(strings),
              child: Text(
                _currentStep < 2 ? strings.next : strings.save,
                style: TextStyle(fontWeight: FontWeight.bold, color: theme.accent),
              ),
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStepIndicatorHeader(theme, strings),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(theme.lg, theme.md, theme.lg + 16, theme.lg),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: KeyedSubtree(
                      key: ValueKey<int>(_currentStep),
                      child: _buildIOSStepContent(context, theme, strings, remotesList),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(theme.md),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      cupertino.CupertinoButton(
                        padding: EdgeInsets.symmetric(horizontal: theme.md, vertical: theme.xs),
                        onPressed: _handleBack,
                        child: Text(strings.back),
                      ),
                    const Spacer(),
                    if (_currentStep < 2)
                      cupertino.CupertinoButton.filled(
                        padding: EdgeInsets.symmetric(horizontal: theme.lg, vertical: theme.xs),
                        onPressed: _nextBlocked ? null : () => _handleNext(strings),
                        child: Text(
                          strings.next,
                          style: const TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
                        ),
                      )
                    else
                      cupertino.CupertinoButton.filled(
                        padding: EdgeInsets.symmetric(horizontal: theme.lg, vertical: theme.xs),
                        onPressed: () => _handleSave(strings),
                        child: Text(
                          strings.save,
                          style: const TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // IOS STEP 0: QUELLE (Fotos & Videos / Dateien)
  // =========================================================================
  Widget _buildIOSStep0Source(
    BuildContext context,
    AppThemeData theme,
    AppStrings strings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(strings.taskNameLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        SizedBox(height: theme.xs),
        cupertino.CupertinoTextField(
          controller: _nameController,
          placeholder: strings.taskNameHint,
          padding: EdgeInsets.all(theme.md),
          decoration: BoxDecoration(
            color: theme.surface,
            border: Border.all(
              color: _nameError != null ? theme.error : cupertino.CupertinoColors.separator,
              width: _nameError != null ? 1.5 : 0.5,
            ),
            borderRadius: BorderRadius.circular(theme.radiusSm),
          ),
          onChanged: (_) {
            if (_nameError != null) setState(() => _nameError = null);
          },
        ),
        if (_nameError != null) ...[
          SizedBox(height: theme.xs),
          Text(_nameError!, style: TextStyle(color: theme.error, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
        SizedBox(height: theme.lg),
        Row(
          children: [
            Text(strings.sourceCategoryLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            SizedBox(width: theme.xs),
            TasksScreen._buildInfoTooltip(context, theme, strings.tooltipSourcePath),
          ],
        ),
        SizedBox(height: theme.xs),
        cupertino.CupertinoSlidingSegmentedControl<String>(
          groupValue: _sourceTab,
          children: {
            'media': Padding(
              padding: EdgeInsets.symmetric(horizontal: theme.sm, vertical: theme.xs),
              child: Text(strings.sourceTabPhotosVideos, style: const TextStyle(fontSize: 12)),
            ),
            'files': Padding(
              padding: EdgeInsets.symmetric(horizontal: theme.sm, vertical: theme.xs),
              child: Text(strings.sourceTabFiles, style: const TextStyle(fontSize: 12)),
            ),
          },
          onValueChanged: (v) {
            if (v != null) setState(() => _sourceTab = v);
          },
        ),
        SizedBox(height: theme.md),
        if (_sourceTab == 'media')
          _buildIOSMediaSource(theme, strings)
        else
          _buildIOSFilesSource(theme, strings),
      ],
    );
  }

  Widget _buildIOSMediaSource(AppThemeData theme, AppStrings strings) {
    if (_loadingAlbums) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: cupertino.CupertinoActivityIndicator()),
      );
    }
    if (_albums.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: theme.lg),
        child: Text(
          strings.noAlbumsFound,
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.textSecondary, fontSize: 13),
        ),
      );
    }

    final allSelected = _albums.length == _selectedAlbums.length;

    // Gesamtzahl über alle Alben (Summe der bereits geladenen Zähler).
    final totalCount = _albums.fold<int>(0, (sum, a) => sum + (a.count ?? 0));
    final anyCountKnown = _albums.any((a) => a.count != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // "Alle auswählen" Umschalter (inkl. Gesamtzahl der Medien)
        cupertino.CupertinoListTile(
          leading: Icon(
            allSelected ? cupertino.CupertinoIcons.check_mark_circled_solid : cupertino.CupertinoIcons.circle,
            color: allSelected ? theme.accent : theme.textSecondary,
            size: 22,
            semanticLabel: strings.selectAllAlbums,
          ),
          title: Text(
            strings.selectAllAlbums,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          subtitle: anyCountKnown
              ? Text(
                  strings.albumsTotalMediaCount(totalCount),
                  style: TextStyle(color: theme.textSecondary, fontSize: 12),
                )
              : null,
          onTap: () {
            setState(() {
              if (allSelected) {
                _selectedAlbums.clear();
              } else {
                _selectedAlbums
                  ..clear()
                  ..addAll(_albums.map((a) => a.name));
              }
            });
          },
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(theme.radiusLg),
            border: Border.all(color: cupertino.CupertinoColors.separator, width: 0.5),
          ),
          child: Column(
            children: _albums.map((album) {
              final checked = _selectedAlbums.contains(album.name);
              final count = album.count;
              return Semantics(
                checked: checked,
                toggled: true,
                button: true,
                label: album.name,
                child: cupertino.CupertinoListTile(
                  title: Text(album.name, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                    // Anzahl wird asynchron nachgeladen – bis dahin „…“.
                    count == null ? '…' : strings.albumMediaCount(count),
                    style: TextStyle(color: theme.textSecondary, fontSize: 12),
                  ),
                  trailing: checked
                      ? Icon(cupertino.CupertinoIcons.check_mark_circled_solid, color: theme.accent, size: 22)
                      : Icon(cupertino.CupertinoIcons.circle, color: theme.textSecondary, size: 22),
                  onTap: () {
                    setState(() {
                      if (checked) {
                        _selectedAlbums.remove(album.name);
                      } else {
                        _selectedAlbums.add(album.name);
                      }
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
        // Leere-Auswahl-Hinweis: keine Auswahl = alle Alben werden gesichert.
        if (_selectedAlbums.isEmpty) ...[
          SizedBox(height: theme.sm),
          Container(
            padding: EdgeInsets.all(theme.sm),
            decoration: BoxDecoration(
              color: theme.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(theme.radiusSm),
            ),
            child: Text(
              strings.emptySelectionAlbumsHint,
              style: TextStyle(color: theme.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildIOSFilesSource(AppThemeData theme, AppStrings strings) {
    if (_loadingFolders) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: cupertino.CupertinoActivityIndicator()),
      );
    }
    if (_localFolders.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: theme.lg),
        child: Text(
          strings.noFoldersFound,
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.textSecondary, fontSize: 13),
        ),
      );
    }

    final allSelected = _localFolders.length == _selectedFolders.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        cupertino.CupertinoListTile(
          leading: Icon(
            allSelected ? cupertino.CupertinoIcons.check_mark_circled_solid : cupertino.CupertinoIcons.circle,
            color: allSelected ? theme.accent : theme.textSecondary,
            size: 22,
            semanticLabel: strings.selectAllFolders,
          ),
          title: Text(
            strings.selectAllFolders,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          onTap: () {
            setState(() {
              if (allSelected) {
                _selectedFolders.clear();
              } else {
                _selectedFolders
                  ..clear()
                  ..addAll(_localFolders);
              }
            });
          },
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(theme.radiusLg),
            border: Border.all(color: cupertino.CupertinoColors.separator, width: 0.5),
          ),
          child: Column(
            children: _localFolders.map((folder) {
              final checked = _selectedFolders.contains(folder);
              return Semantics(
                checked: checked,
                toggled: true,
                button: true,
                label: folder.split('/').last,
                child: cupertino.CupertinoListTile(
                  title: Text(folder.split('/').last, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(folder, style: const TextStyle(fontSize: 11)),
                  trailing: checked
                      ? Icon(cupertino.CupertinoIcons.check_mark_circled_solid, color: theme.accent, size: 22)
                      : Icon(cupertino.CupertinoIcons.circle, color: theme.textSecondary, size: 22),
                  onTap: () {
                    setState(() {
                      if (checked) {
                        _selectedFolders.remove(folder);
                      } else {
                        _selectedFolders.add(folder);
                      }
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
        // Leere-Auswahl-Hinweis für Dateien.
        if (_selectedFolders.isEmpty) ...[
          SizedBox(height: theme.sm),
          Container(
            padding: EdgeInsets.all(theme.sm),
            decoration: BoxDecoration(
              color: theme.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(theme.radiusSm),
            ),
            child: Text(
              strings.emptySelectionFoldersHint,
              style: TextStyle(color: theme.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }

  // =========================================================================
  // IOS STEP 1: ZIEL (Cloud-Laufwerk + Zielordner)
  // =========================================================================
  Widget _buildIOSStep1Destination(
    BuildContext context,
    AppThemeData theme,
    AppStrings strings,
    List<String> remotesList,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(strings.destinationRemoteLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            SizedBox(width: theme.xs),
            TasksScreen._buildInfoTooltip(context, theme, strings.tooltipDestinationRemote),
          ],
        ),
        SizedBox(height: theme.xs),
        Container(
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(theme.radiusLg),
            border: Border.all(
              color: _remotesError != null ? theme.error : cupertino.CupertinoColors.separator,
              width: _remotesError != null ? 1.5 : 0.5,
            ),
          ),
          child: Column(
            children: remotesList.map((remote) {
              final isChecked = _selectedRemotes.contains(remote);
              return cupertino.CupertinoListTile(
                title: Text(_remoteLabel(remote), style: const TextStyle(fontSize: 14)),
                trailing: isChecked
                    ? Icon(cupertino.CupertinoIcons.check_mark_circled_solid, color: theme.accent, size: 22)
                    : Icon(cupertino.CupertinoIcons.circle, color: theme.textSecondary, size: 22),
                onTap: () {
                  setState(() {
                    if (isChecked) {
                      _selectedRemotes.remove(remote);
                    } else {
                      _selectedRemotes.add(remote);
                    }
                    if (_selectedRemotes.isNotEmpty) _remotesError = null;
                    _remoteTargetFolders = [];
                    _selectedRemoteTargetFolder = '';
                    _remoteFolderPath = '';
                    _remoteFolderHistory.clear();
                  });
                  if (_selectedRemotes.isNotEmpty) _loadRemoteTargetFolders();
                },
              );
            }).toList(),
          ),
        ),
        if (_remotesError != null) ...[
          SizedBox(height: theme.xs),
          Text(_remotesError!, style: TextStyle(color: theme.error, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
        if (_selectedRemotes.length > 1) ...[
          SizedBox(height: theme.lg),
          Row(
            children: [
              Text(strings.distributionStrategyLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              SizedBox(width: theme.xs),
              TasksScreen._buildInfoTooltip(context, theme, strings.distributionTooltip),
            ],
          ),
          SizedBox(height: theme.xs),
          cupertino.CupertinoSlidingSegmentedControl<DistributionStrategy>(
            groupValue: _selectedDistribution,
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
              if (val != null) setState(() => _selectedDistribution = val);
            },
          ),
        ],
        SizedBox(height: theme.lg),
        // Zielordner – klar & verständlich: Root / Vorhandener Ordner / Neuer Ordner
        Row(
          children: [
            Text(strings.targetFolderModeLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            SizedBox(width: theme.xs),
            TasksScreen._buildInfoTooltip(context, theme, strings.targetFolderTooltip),
          ],
        ),
        SizedBox(height: theme.xs),
        _buildTargetFolderOptions(theme, strings),
        SizedBox(height: theme.md),
        if (_selectedTargetFolderMode == TargetFolderMode.root) ...[
          Container(
            padding: EdgeInsets.all(theme.md),
            decoration: BoxDecoration(
              color: theme.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(theme.radiusSm),
            ),
            child: Text(
              strings.targetFolderRoot,
              style: TextStyle(color: theme.textPrimary, fontSize: 13),
            ),
          ),
        ] else if (_selectedTargetFolderMode == TargetFolderMode.custom) ...[
          _buildIOSRemoteFolderPicker(theme, strings),
        ] else ...[
          Text(strings.targetFolderNameLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          SizedBox(height: theme.xs),
          cupertino.CupertinoTextField(
            controller: _targetFolderController,
            placeholder: strings.newFolderNameHint,
            padding: EdgeInsets.all(theme.md),
            decoration: BoxDecoration(
              color: theme.surface,
              border: Border.all(color: cupertino.CupertinoColors.separator, width: 0.5),
              borderRadius: BorderRadius.circular(theme.radiusSm),
            ),
          ),
        ],
      ],
    );
  }

  /// Drei klare Optionen für den Zielordner.
  Widget _buildTargetFolderOptions(AppThemeData theme, AppStrings strings) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(theme.radiusLg),
        border: Border.all(color: cupertino.CupertinoColors.separator, width: 0.5),
      ),
      child: Column(
        children: [
          cupertino.CupertinoListTile(
            leading: Icon(cupertino.CupertinoIcons.circle_lefthalf_fill, color: theme.accent, size: 22),
            title: Text(strings.targetFolderRoot, style: const TextStyle(fontSize: 14)),
            subtitle: Text(
              strings.isGerman ? 'Direkt ins Hauptverzeichnis der Cloud.' : 'Directly into the cloud root directory.',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: _selectedTargetFolderMode == TargetFolderMode.root
                ? Icon(cupertino.CupertinoIcons.check_mark, color: theme.accent)
                : null,
            onTap: () => setState(() => _selectedTargetFolderMode = TargetFolderMode.root),
          ),
          cupertino.CupertinoListTile(
            leading: Icon(cupertino.CupertinoIcons.folder, color: theme.accent, size: 22),
            title: Text(strings.targetFolderExistingLabel, style: const TextStyle(fontSize: 14)),
            subtitle: Text(
              strings.isGerman ? 'In einen vorhandenen Cloud-Ordner.' : 'Into an existing cloud folder.',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: _selectedTargetFolderMode == TargetFolderMode.custom
                ? Icon(cupertino.CupertinoIcons.check_mark, color: theme.accent)
                : null,
            onTap: () {
              setState(() => _selectedTargetFolderMode = TargetFolderMode.custom);
              if (_remoteTargetFolders.isEmpty) _loadRemoteTargetFolders();
            },
          ),
          cupertino.CupertinoListTile(
            leading: Icon(cupertino.CupertinoIcons.folder_badge_plus, color: theme.accent, size: 22),
            title: Text(strings.targetFolderNew, style: const TextStyle(fontSize: 14)),
            subtitle: Text(
              strings.isGerman ? 'Einen neuen Ordner in der Cloud anlegen.' : 'Create a new folder in the cloud.',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: _selectedTargetFolderMode == TargetFolderMode.newFolder
                ? Icon(cupertino.CupertinoIcons.check_mark, color: theme.accent)
                : null,
            onTap: () => setState(() => _selectedTargetFolderMode = TargetFolderMode.newFolder),
          ),
        ],
      ),
    );
  }

  /// Listet die vorhandenen Cloud-Ordner (Remote) – niemals lokale Ordner.
  /// Bietet Navigation in Unterordner an.
  Widget _buildIOSRemoteFolderPicker(AppThemeData theme, AppStrings strings) {
    if (_loadingRemoteFolders) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: cupertino.CupertinoActivityIndicator()),
      );
    }
    if (_remoteFoldersError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_remoteFoldersError!, style: TextStyle(color: theme.error, fontSize: 12)),
          SizedBox(height: theme.xs),
          cupertino.CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _loadRemoteTargetFolders,
            child: Text(strings.retry, style: TextStyle(color: theme.accent)),
          ),
        ],
      );
    }

    final List<Widget> tiles = [];

    // "Eine Ebene höher" (falls in einem Unterordner)
    if (_remoteFolderPath.isNotEmpty) {
      tiles.add(cupertino.CupertinoListTile(
        leading: Icon(cupertino.CupertinoIcons.arrow_up_circle, color: theme.accent, size: 22),
        title: Text(strings.targetFolderUp, style: const TextStyle(fontSize: 14)),
        onTap: () {
          IosHaptics.light();
          _goUpRemoteFolder();
        },
      ));
      tiles.add(Container(height: 1, color: cupertino.CupertinoColors.separator));
    }

    if (_remoteTargetFolders.isEmpty && _remoteFolderPath.isEmpty) {
      return Text(
        strings.remoteFolderEmpty,
        style: TextStyle(color: theme.textSecondary, fontSize: 13),
      );
    }

    if (_remoteTargetFolders.isEmpty) {
      // Unterordner ohne weitere Unterordner: Aktuellen Pfad wählbar machen.
      tiles.add(cupertino.CupertinoListTile(
        title: Text(
          _remoteFolderPath,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(strings.targetFolderCurrentPath, style: const TextStyle(fontSize: 11)),
        trailing: Icon(cupertino.CupertinoIcons.check_mark_circled_solid, color: theme.accent, size: 22),
        onTap: () {
          setState(() {
            _selectedRemoteTargetFolder = _remoteFolderPath;
            _targetFolderController.text = _remoteFolderPath;
          });
        },
      ));
    }

    tiles.addAll(_remoteTargetFolders.map((folder) {
      final folderPath = _remoteFolderPath.isEmpty ? folder : '$_remoteFolderPath/$folder';
      final checked = folderPath == _selectedRemoteTargetFolder;
      return cupertino.CupertinoListTile(
        leading: Icon(cupertino.CupertinoIcons.folder, color: theme.accent, size: 22),
        title: Text(folder, style: const TextStyle(fontSize: 14)),
        trailing: checked
            ? Icon(cupertino.CupertinoIcons.check_mark_circled_solid, color: theme.accent, size: 22)
            : Icon(cupertino.CupertinoIcons.chevron_forward, color: theme.textSecondary, size: 18),
        onTap: () {
          // Tap öffnet den Unterordner (nicht sofort auswählen).
          IosHaptics.light();
          _openRemoteFolder(folder);
        },
      );
    }).toList());

    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(theme.radiusLg),
        border: Border.all(color: cupertino.CupertinoColors.separator, width: 0.5),
      ),
      child: Column(children: tiles),
    );
  }

  Widget _buildIOSStepContent(
    BuildContext context,
    AppThemeData theme,
    AppStrings strings,
    List<String> remotesList,
  ) {
    if (_currentStep == 0) {
      return _buildIOSStep0Source(context, theme, strings);
    } else if (_currentStep == 1) {
      return _buildIOSStep1Destination(context, theme, strings, remotesList);
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(strings.syncModeLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              SizedBox(width: theme.xs),
              TasksScreen._buildInfoTooltip(
                context,
                theme,
                _selectedSyncMode == SyncMode.incremental
                    ? strings.syncModeTooltipIncremental
                    : strings.syncModeTooltipMirror,
              ),
            ],
          ),
          SizedBox(height: theme.xs),
          cupertino.CupertinoSlidingSegmentedControl<SyncMode>(
            groupValue: _selectedSyncMode,
            children: {
              SyncMode.incremental: Padding(
                padding: EdgeInsets.symmetric(horizontal: theme.sm, vertical: theme.xs),
                child: Text(strings.syncModeIncremental, style: const TextStyle(fontSize: 11)),
              ),
              SyncMode.mirror: Padding(
                padding: EdgeInsets.symmetric(horizontal: theme.sm, vertical: theme.xs),
                child: Text(strings.syncModeBadgeMirror, style: const TextStyle(fontSize: 11)),
              ),
            },
            onValueChanged: (mode) {
              if (mode != null) setState(() => _selectedSyncMode = mode);
            },
          ),
          SizedBox(height: theme.lg),

          // iOS Native Background Scheduling Banner
          Container(
            padding: EdgeInsets.all(theme.md),
            decoration: BoxDecoration(
              color: theme.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(theme.radiusSm),
              border: Border.all(color: theme.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(cupertino.CupertinoIcons.info_circle_fill, color: theme.accent, size: 20),
                SizedBox(width: theme.sm),
                Expanded(
                  child: Text(
                    strings.iosBackgroundScheduleNotice,
                    style: TextStyle(fontSize: 12, color: theme.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: theme.lg),

          Row(
            children: [
              Text('${strings.activeSyncJob}:', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const Spacer(),
              cupertino.CupertinoSwitch(
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
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
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      );
    }
  }

  // =========================================================================
  // ANDROID WIZARD LAYOUT (Material 3)
  // =========================================================================
  Widget _buildAndroidLayout(
    BuildContext context,
    AppThemeData theme,
    AppStrings strings,
    List<String> remotesList,
  ) {
    return material.Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(theme.radiusLg)),
      child: Container(
        width: 540,
        constraints: const BoxConstraints(maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(theme.lg, theme.md, theme.sm, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existingTask == null ? strings.addTask : strings.editTask,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  material.IconButton(
                    icon: const Icon(material.Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            _buildStepIndicatorHeader(theme, strings),
            const material.Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(theme.lg, theme.md, theme.lg + 16, theme.lg),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: KeyedSubtree(
                    key: ValueKey<int>(_currentStep),
                    child: _buildAndroidStepContent(context, theme, strings, remotesList),
                  ),
                ),
              ),
            ),
            const material.Divider(height: 1),
            Padding(
              padding: EdgeInsets.all(theme.md),
              child: Row(
                children: [
                  material.TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(strings.cancel),
                  ),
                  const Spacer(),
                  if (_currentStep > 0) ...[
                    material.OutlinedButton(
                      onPressed: _handleBack,
                      child: Text(strings.back),
                    ),
                    SizedBox(width: theme.sm),
                  ],
                  if (_currentStep < 2)
                    material.FilledButton(
                      onPressed: _nextBlocked ? null : () => _handleNext(strings),
                      child: Text(
                        strings.next,
                        style: const TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
                      ),
                    )
                  else
                    material.FilledButton(
                      onPressed: () => _handleSave(strings),
                      child: Text(
                        strings.save,
                        style: const TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAndroidStepContent(
    BuildContext context,
    AppThemeData theme,
    AppStrings strings,
    List<String> remotesList,
  ) {
    if (_currentStep == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPresetSelectionCards(context, theme, strings),
          material.TextField(
            controller: _nameController,
            decoration: material.InputDecoration(
              labelText: strings.taskNameLabel,
              hintText: strings.taskNameHint,
              errorText: _nameError,
            ),
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
          ),
          SizedBox(height: theme.lg),
          material.DropdownButtonFormField<String>(
            initialValue: _selectedSourceCategory,
            decoration: material.InputDecoration(
              labelText: strings.sourceCategoryLabel,
              suffixIcon: TasksScreen._buildInfoTooltip(context, theme, strings.tooltipSourcePath),
            ),
            items: ['all', 'photos', 'videos', 'folders'].map((cat) {
              return material.DropdownMenuItem(
                value: cat,
                child: Text(TasksScreen._getCategoryLabel(strings, cat)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedSourceCategory = val;
                  if (val != 'folders') _sourceError = null;
                });
              }
            },
          ),
          if (_selectedSourceCategory == 'folders') ...[
            SizedBox(height: theme.sm),
            material.TextField(
              controller: _srcController,
              decoration: material.InputDecoration(
                labelText: strings.sourcePathLabel,
                hintText: strings.specificFoldersHint,
                errorText: _sourceError,
              ),
              onChanged: (_) {
                if (_sourceError != null) setState(() => _sourceError = null);
              },
            ),
          ],
        ],
      );
    } else if (_currentStep == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(strings.destinationRemoteLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(width: theme.xs),
              TasksScreen._buildInfoTooltip(context, theme, strings.tooltipDestinationRemote),
            ],
          ),
          SizedBox(height: theme.xs),
          material.Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(theme.radiusSm),
              side: BorderSide(
                color: _remotesError != null ? theme.error : material.Theme.of(context).colorScheme.outlineVariant,
                width: _remotesError != null ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: remotesList.map((remote) {
                return material.CheckboxListTile(
                  title: Text(_remoteLabel(remote), style: const TextStyle(fontSize: 13)),
                  value: _selectedRemotes.contains(remote),
                  dense: true,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        if (!_selectedRemotes.contains(remote)) _selectedRemotes.add(remote);
                      } else {
                        _selectedRemotes.remove(remote);
                      }
                      if (_selectedRemotes.isNotEmpty) _remotesError = null;
                    });
                  },
                );
              }).toList(),
            ),
          ),
          if (_remotesError != null) ...[
            SizedBox(height: theme.xs),
            Text(_remotesError!, style: TextStyle(color: theme.error, fontSize: 11, fontWeight: FontWeight.w500)),
          ],
          if (_selectedRemotes.length > 1) ...[
            SizedBox(height: theme.lg),
            Row(
              children: [
                Text(strings.distributionStrategyLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(width: theme.xs),
                TasksScreen._buildInfoTooltip(context, theme, strings.distributionTooltip),
              ],
            ),
            SizedBox(height: theme.xs),
            material.Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(theme.radiusSm),
                side: BorderSide(
                  color: _selectedDistribution == DistributionStrategy.mirrorAll
                      ? theme.accent
                      : material.Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              color: _selectedDistribution == DistributionStrategy.mirrorAll ? theme.accent.withValues(alpha: 0.08) : null,
              child: material.InkWell(
                onTap: () => setState(() => _selectedDistribution = DistributionStrategy.mirrorAll),
                child: Padding(
                  padding: EdgeInsets.all(theme.sm),
                  child: Row(
                    children: [
                      Icon(
                        _selectedDistribution == DistributionStrategy.mirrorAll
                            ? material.Icons.radio_button_checked
                            : material.Icons.radio_button_unchecked,
                        color: _selectedDistribution == DistributionStrategy.mirrorAll ? theme.accent : theme.textSecondary,
                      ),
                      SizedBox(width: theme.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(strings.distributionMirrorAll, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            SizedBox(height: theme.xs / 2),
                            Text(strings.distributionMirrorAllDesc, style: TextStyle(fontSize: 11, color: theme.textSecondary)),
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
                  color: _selectedDistribution == DistributionStrategy.balance
                      ? theme.accent
                      : material.Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              color: _selectedDistribution == DistributionStrategy.balance ? theme.accent.withValues(alpha: 0.08) : null,
              child: material.InkWell(
                onTap: () => setState(() => _selectedDistribution = DistributionStrategy.balance),
                child: Padding(
                  padding: EdgeInsets.all(theme.sm),
                  child: Row(
                    children: [
                      Icon(
                        _selectedDistribution == DistributionStrategy.balance
                            ? material.Icons.radio_button_checked
                            : material.Icons.radio_button_unchecked,
                        color: _selectedDistribution == DistributionStrategy.balance ? theme.accent : theme.textSecondary,
                      ),
                      SizedBox(width: theme.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(strings.distributionBalance, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            SizedBox(height: theme.xs / 2),
                            Text(strings.distributionBalanceDesc, style: TextStyle(fontSize: 11, color: theme.textSecondary)),
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
          material.DropdownButtonFormField<TargetFolderMode>(
            initialValue: _selectedTargetFolderMode,
            decoration: material.InputDecoration(
              labelText: strings.targetFolderModeLabel,
              suffixIcon: TasksScreen._buildInfoTooltip(context, theme, strings.targetFolderTooltip),
            ),
            items: [
              material.DropdownMenuItem(value: TargetFolderMode.root, child: Text(strings.targetFolderRoot)),
              material.DropdownMenuItem(value: TargetFolderMode.custom, child: Text(strings.targetFolderCustom)),
              material.DropdownMenuItem(value: TargetFolderMode.newFolder, child: Text(strings.targetFolderNew)),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedTargetFolderMode = val);
            },
          ),
          if (_selectedTargetFolderMode != TargetFolderMode.root) ...[
            SizedBox(height: theme.sm),
            material.TextField(
              controller: _targetFolderController,
              decoration: material.InputDecoration(
                labelText: _selectedTargetFolderMode == TargetFolderMode.newFolder
                    ? strings.newFolderNameLabel
                    : strings.targetFolderModeLabel,
                hintText: _selectedTargetFolderMode == TargetFolderMode.newFolder
                    ? strings.newFolderNameHint
                    : 'fibu-backup',
              ),
            ),
          ],
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(strings.syncModeLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(width: theme.xs),
              TasksScreen._buildInfoTooltip(
                context,
                theme,
                _selectedSyncMode == SyncMode.incremental
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
                color: _selectedSyncMode == SyncMode.incremental
                    ? theme.accent
                    : material.Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            color: _selectedSyncMode == SyncMode.incremental ? theme.accent.withValues(alpha: 0.08) : null,
            child: material.InkWell(
              onTap: () => setState(() => _selectedSyncMode = SyncMode.incremental),
              child: Padding(
                padding: EdgeInsets.all(theme.sm),
                child: Row(
                  children: [
                    Icon(
                      _selectedSyncMode == SyncMode.incremental
                          ? material.Icons.radio_button_checked
                          : material.Icons.radio_button_unchecked,
                      color: _selectedSyncMode == SyncMode.incremental ? theme.accent : theme.textSecondary,
                    ),
                    SizedBox(width: theme.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(strings.syncModeIncremental, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(height: theme.xs / 2),
                          Text(strings.syncModeIncrementalDescription, style: TextStyle(fontSize: 11, color: theme.textSecondary)),
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
                color: _selectedSyncMode == SyncMode.mirror
                    ? theme.warning
                    : material.Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            color: _selectedSyncMode == SyncMode.mirror ? theme.warning.withValues(alpha: 0.1) : null,
            child: material.InkWell(
              onTap: () => setState(() => _selectedSyncMode = SyncMode.mirror),
              child: Padding(
                padding: EdgeInsets.all(theme.sm),
                child: Row(
                  children: [
                    Icon(
                      _selectedSyncMode == SyncMode.mirror
                          ? material.Icons.radio_button_checked
                          : material.Icons.radio_button_unchecked,
                      color: _selectedSyncMode == SyncMode.mirror ? theme.warning : theme.textSecondary,
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
                                  color: _selectedSyncMode == SyncMode.mirror ? theme.warning : null,
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
                              color: _selectedSyncMode == SyncMode.mirror ? theme.warning : theme.textSecondary,
                              fontWeight: _selectedSyncMode == SyncMode.mirror ? FontWeight.w600 : FontWeight.normal,
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
          material.DropdownButtonFormField<String>(
            initialValue: _selectedScheduleDay,
            decoration: material.InputDecoration(
              labelText: strings.scheduleDayLabel,
              suffixIcon: TasksScreen._buildInfoTooltip(context, theme, strings.tooltipSchedule),
            ),
            items: TasksScreen._scheduleDayKeys.map((sched) {
              return material.DropdownMenuItem(
                value: sched,
                child: Text(TasksScreen._getDayLabel(strings, sched)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedScheduleDay = val);
            },
          ),
          if (_selectedScheduleDay != 'Manual') ...[
            SizedBox(height: theme.lg),
            Row(
              children: [
                Text('${strings.scheduleTimeLabel}:'),
                SizedBox(width: theme.md),
                Expanded(
                  child: material.DropdownButtonFormField<String>(
                    initialValue: _selectedHour,
                    decoration: material.InputDecoration(labelText: strings.hourLabel),
                    items: _hours.map((h) => material.DropdownMenuItem(value: h, child: Text(h))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedHour = val);
                    },
                  ),
                ),
                SizedBox(width: theme.sm),
                const Text(':'),
                SizedBox(width: theme.sm),
                Expanded(
                  child: material.DropdownButtonFormField<String>(
                    initialValue: _selectedMinute,
                    decoration: material.InputDecoration(labelText: strings.minuteLabel),
                    items: _minutes.map((m) => material.DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedMinute = val);
                    },
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
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
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
              TasksScreen._buildInfoTooltip(context, theme, strings.tooltipCatchUp),
            ],
          ),
        ],
      );
    }
  }
}

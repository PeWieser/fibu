import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/theme.dart';
import '../../../theme/ios_theme.dart';
import '../../../core/utils/ios_haptics.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/services/network_status_service.dart';
import '../../../core/services/rclone_service.dart';
import '../../../core/services/rclone_provider.dart';
import '../../../core/services/remote_registry_service.dart';
import 'dashboard_controller.dart';
import '../../tasks/presentation/tasks_controller.dart';
import 'widgets/multi_remote_storage_card.dart';
import 'widgets/dashboard_dialogs.dart';
import 'cloud_explorer_screen.dart';

/// Platform-adaptive Dashboard Screen. Renders layout dynamically based on current platform.
/// Handles page-refresh commands with animated spinning indicators and feedback toasts,
/// and provides rich contextual tooltips across cards, status banner, and actions.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> with SingleTickerProviderStateMixin {
  late AnimationController _spinController;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh(BuildContext context, AppStrings strings) async {
    if (_isRefreshing) return;
    IosHaptics.light();
    setState(() => _isRefreshing = true);
    _spinController.repeat();

    ref.invalidate(remoteEntriesProvider);
    ref.invalidate(remotesProvider);
    ref.invalidate(primaryQuotaProvider);

    // Provide tactile feedback duration
    await Future.delayed(const Duration(milliseconds: 650));

    if (!mounted) return;
    _spinController.stop();
    _spinController.reset();
    setState(() => _isRefreshing = false);

    _showRefreshFeedback(this.context, strings);
  }

  void _showRefreshFeedback(BuildContext context, AppStrings strings) {
    final platform = defaultTargetPlatform;
    if (platform == TargetPlatform.windows) {
      fluent.displayInfoBar(
        context,
        builder: (context, close) => fluent.InfoBar(
          title: fluent.Text(strings.refreshedSuccess),
          content: fluent.Text(strings.drivesRefreshed),
          severity: fluent.InfoBarSeverity.success,
          onClose: close,
        ),
      );
    } else if (platform == TargetPlatform.iOS) {
      final overlay = Overlay.of(context);
      final entry = OverlayEntry(
        builder: (context) => Positioned(
          bottom: 50.0,
          left: 20.0,
          right: 20.0,
          child: SafeArea(
            child: cupertino.CupertinoPopupSurface(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Text(
                  strings.drivesRefreshed,
                  style: cupertino.CupertinoTheme.of(context).textTheme.textStyle,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      );
      overlay.insert(entry);
      Future.delayed(const Duration(seconds: 2), () {
        if (entry.mounted) entry.remove();
      });
    } else {
      material.ScaffoldMessenger.of(context).showSnackBar(
        material.SnackBar(
          content: Text(strings.drivesRefreshed),
          duration: const Duration(seconds: 2),
          behavior: material.SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final platform = defaultTargetPlatform;

    if (platform == TargetPlatform.windows) {
      return _buildWindows(context);
    } else if (platform == TargetPlatform.iOS) {
      return _buildIOS(context);
    } else {
      return _buildAndroid(context);
    }
  }

  /// Liefert den Setup-Hinweis, solange Cloud-Laufwerk und/oder Aufgabe fehlen.
  /// null, wenn beides eingerichtet ist (dann erscheint die normale Übersicht).
  Widget? _buildSetupHint(BuildContext context, AppStrings strings) {
    final remotesAsync = ref.watch(remotesProvider);
    // Erst anzeigen, wenn Remotes UND Task-Liste wirklich geladen sind —
    // sonst blitzt der Hinweis beim Kaltstart kurz auf.
    if (remotesAsync.isLoading || !ref.watch(tasksLoadedProvider)) return null;
    final remotes = remotesAsync.valueOrNull ?? const <String>[];
    final tasks = ref.watch(tasksListProvider);
    final hasRemotes = remotes.isNotEmpty;
    final hasTasks = tasks.isNotEmpty;
    if (hasRemotes && hasTasks) return null;

    final String title;
    if (!hasRemotes && !hasTasks) {
      title = strings.setupDriveAndTask;
    } else if (!hasRemotes) {
      title = strings.setupFirstDrive;
    } else {
      title = strings.setupFirstTask;
    }
    final theme = context.theme;
    final platform = defaultTargetPlatform;

    if (platform == TargetPlatform.windows) {
      return fluent.Card(
        padding: EdgeInsets.all(theme.lg),
        child: Row(
          children: [
            Icon(fluent.FluentIcons.cloud_add, color: theme.textSecondary, size: 24),
            SizedBox(width: theme.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  SizedBox(height: theme.xs),
                  Text(strings.setupHintSubtitle,
                      style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    if (platform == TargetPlatform.iOS) {
      return Container(
        padding: EdgeInsets.all(theme.lg),
        decoration: BoxDecoration(
          color: cupertino.CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(theme.radiusLg),
          border: Border.all(
            color: cupertino.CupertinoColors.separator.resolveFrom(context),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              cupertino.CupertinoIcons.cloud,
              color: cupertino.CupertinoColors.secondaryLabel.resolveFrom(context),
              size: 24,
              semanticLabel: title,
            ),
            SizedBox(width: theme.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  SizedBox(height: theme.xs),
                  Text(strings.setupHintSubtitle,
                      style: TextStyle(
                        color: cupertino.CupertinoColors.secondaryLabel.resolveFrom(context),
                        fontSize: 12,
                      )),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return material.Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.radiusLg),
        side: BorderSide(color: material.Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.lg),
        child: Row(
          children: [
            Icon(material.Icons.cloud_off_outlined, color: theme.textSecondary, size: 24),
            SizedBox(width: theme.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  SizedBox(height: theme.xs),
                  Text(strings.setupHintSubtitle,
                      style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Windows (Fluent Design) ---
  Widget _buildWindows(BuildContext context) {
    final theme = context.theme;
    final strings = ref.watch(stringsProvider);
    final activeJob = ref.watch(activeJobProvider);
    final quotaAsync = ref.watch(primaryQuotaProvider);
    final setupHint = _buildSetupHint(context, strings);

    return fluent.ScaffoldPage(
      header: fluent.PageHeader(
        title: fluent.Text(
          strings.navDashboard,
          style: fluent.FluentTheme.of(context).typography.title,
        ),
        commandBar: fluent.CommandBar(
          primaryItems: [
            fluent.CommandBarButton(
              icon: _isRefreshing
                  ? const SizedBox(width: 16, height: 16, child: fluent.ProgressRing())
                  : RotationTransition(
                      turns: _spinController,
                      child: Icon(fluent.FluentIcons.refresh, semanticLabel: strings.refresh),
                    ),
              label: Text(strings.refresh),
              onPressed: _isRefreshing ? null : () => _handleRefresh(context, strings),
            ),
          ],
        ),
      ),
      content: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: theme.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOfflineHint(context, strings),
            _buildClickableStatusBanner(context, activeJob, strings),
            SizedBox(height: theme.lg),
            if (setupHint != null) ...[
              setupHint,
            ] else ...[
              quotaAsync.when(
                data: (quota) {
                  if (quota == null) {
                    return fluent.Tooltip(
                      message: strings.tooltipStorageCard,
                      child: fluent.Card(
                        padding: EdgeInsets.all(theme.md),
                        child: Row(
                          children: [
                            Icon(
                              fluent.FluentIcons.cloud_add,
                              color: theme.textSecondary,
                              size: 20,
                              semanticLabel: strings.noDrivesConfigured,
                            ),
                            SizedBox(width: theme.md),
                            Expanded(
                              child: Text(
                                strings.noDrivesConfigured,
                                style: TextStyle(color: theme.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return const MultiRemoteStorageCard();
                },
                loading: () => const fluent.ProgressBar(),
                error: (err, stack) => fluent.Text('${strings.error}: $err', style: TextStyle(color: theme.error)),
              ),
              SizedBox(height: theme.xl),
              _buildActiveJobPanelWindows(context, activeJob, strings),
              SizedBox(height: theme.xl),
              _buildSyncActionsWindows(context, activeJob, strings),
              SizedBox(height: theme.xl),
              fluent.Tooltip(
                message: strings.exploreRemoteFiles,
                child: fluent.Button(
                  onPressed: () {
                    Navigator.push(
                      context,
                      fluent.FluentPageRoute(builder: (context) => const CloudExplorerScreen()),
                    );
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(fluent.FluentIcons.cloud, size: 16, color: theme.accent, semanticLabel: strings.exploreRemoteFiles),
                          const SizedBox(width: 8),
                          Text(strings.exploreRemoteFiles),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: theme.xl),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveJobPanelWindows(BuildContext context, ActiveJobState job, AppStrings strings) {
    final theme = context.theme;
    if (job.status == RcloneJobStatus.completed && job.jobId == null) {
      return const SizedBox.shrink();
    }

    return fluent.Card(
      padding: EdgeInsets.all(theme.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          fluent.Text(
            strings.activeTaskProgress,
            style: fluent.FluentTheme.of(context).typography.subtitle,
          ),
          SizedBox(height: theme.sm),
          fluent.Text(
            '${strings.currentFile} ${job.currentFile.isEmpty ? strings.preparing : job.currentFile}',
            style: fluent.FluentTheme.of(context).typography.body,
          ),
          SizedBox(height: theme.sm),
          fluent.ProgressBar(value: job.percentage, activeColor: theme.accent),
          if (job.itemsTotal > 0) ...[
            SizedBox(height: theme.sm),
            fluent.Text(strings.syncItemsProgress(job.itemsDone, job.itemsTotal)),
          ],
          SizedBox(height: theme.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (job.eta.isNotEmpty) fluent.Text('ETA: ${job.eta}') else fluent.Text(''),
              fluent.Text('${job.percentage.toStringAsFixed(1)}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSyncActionsWindows(BuildContext context, ActiveJobState job, AppStrings strings) {
    final isSyncing = job.status == RcloneJobStatus.syncing || job.status == RcloneJobStatus.pending;
    final theme = context.theme;

    if (isSyncing) {
      return fluent.Tooltip(
        message: strings.cancelSync,
        child: fluent.Button(
          onPressed: () => ref.read(activeJobProvider.notifier).cancelActiveSync(),
          style: fluent.ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(theme.error),
            foregroundColor: const WidgetStatePropertyAll(Color(0xffffffff)),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(theme.radiusSm)),
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(fluent.FluentIcons.cancel, size: 16, color: Color(0xffffffff), semanticLabel: 'Cancel'),
                  const SizedBox(width: 8),
                  Text(
                    strings.cancelSync,
                    style: const TextStyle(color: Color(0xffffffff), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return fluent.Tooltip(
      message: strings.syncAll,
      child: fluent.FilledButton(
        onPressed: () => ref.read(activeJobProvider.notifier).triggerSyncAll(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(fluent.FluentIcons.sync, size: 16, semanticLabel: 'Sync'),
                const SizedBox(width: 8),
                Text(strings.syncAll),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- iOS (Cupertino Design) ---
  Widget _buildIOS(BuildContext context) {
    final theme = context.theme;
    final strings = ref.watch(stringsProvider);
    final activeJob = ref.watch(activeJobProvider);
    final quotaAsync = ref.watch(primaryQuotaProvider);
    final isSyncing = activeJob.status == RcloneJobStatus.syncing || activeJob.status == RcloneJobStatus.pending;
    final setupHint = _buildSetupHint(context, strings);

    return cupertino.CupertinoPageScaffold(
      navigationBar: cupertino.CupertinoNavigationBar(
        // Großer, natives iOS-Titel wird im Scroll-Content gerendert (Large Title).
        middle: const SizedBox.shrink(),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Semantics(
            label: strings.refresh,
            child: cupertino.CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              onPressed: _isRefreshing ? null : () => _handleRefresh(context, strings),
              child: _isRefreshing
                  ? const cupertino.CupertinoActivityIndicator(radius: 9)
                  : RotationTransition(
                      turns: _spinController,
                      child: Icon(cupertino.CupertinoIcons.refresh, size: 22, semanticLabel: strings.refresh),
                    ),
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IosTheme.largeTitle(strings.navDashboard, theme),
              Padding(
                padding: EdgeInsets.fromLTRB(theme.lg, 0, theme.lg, theme.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              _buildOfflineHint(context, strings),
              _buildClickableStatusBanner(context, activeJob, strings),
              SizedBox(height: theme.lg),
              if (setupHint != null) ...[
                setupHint!,
              ] else ...[
              quotaAsync.when(
                data: (quota) {
                  if (quota == null) {
                    // Nativer, aktionsfähiger Leerzustand: CTA öffnet die Cloud-Laufwerke.
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: EdgeInsets.all(theme.lg),
                          decoration: BoxDecoration(
                            color: cupertino.CupertinoColors.systemBackground.resolveFrom(context),
                            borderRadius: BorderRadius.circular(theme.radiusLg),
                            border: Border.all(
                              color: cupertino.CupertinoColors.separator.resolveFrom(context),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                cupertino.CupertinoIcons.cloud,
                                color: cupertino.CupertinoColors.secondaryLabel.resolveFrom(context),
                                size: 24,
                                semanticLabel: strings.noDrivesConfigured,
                              ),
                              SizedBox(width: theme.md),
                              Expanded(
                                child: Text(
                                  strings.noDrivesConfigured,
                                  style: TextStyle(
                                    color: cupertino.CupertinoColors.secondaryLabel.resolveFrom(context),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  return const MultiRemoteStorageCard();
                },
                loading: () => const cupertino.CupertinoActivityIndicator(),
                error: (err, stack) => Text('${strings.error}: $err', style: TextStyle(color: theme.error)),
              ),
              SizedBox(height: theme.xl),
              if (isSyncing) ...[
                _buildActiveJobPanelIOS(context, activeJob, strings),
                SizedBox(height: theme.xl),
              ],
              if (isSyncing)
                Semantics(
                  label: strings.cancelSync,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: cupertino.CupertinoButton(
                      color: theme.error,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      borderRadius: BorderRadius.circular(theme.radiusSm),
                      onPressed: () {
                        IosHaptics.light();
                        ref.read(activeJobProvider.notifier).cancelActiveSync();
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            cupertino.CupertinoIcons.stop_circle,
                            color: cupertino.CupertinoColors.white,
                            size: 20,
                            semanticLabel: 'Cancel',
                          ),
                          const SizedBox(width: 8),
                          Text(
                            strings.cancelSync,
                            style: const TextStyle(color: cupertino.CupertinoColors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Semantics(
                  label: strings.syncAll,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: cupertino.CupertinoButton.filled(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      borderRadius: BorderRadius.circular(theme.radiusSm),
                      onPressed: () {
                        IosHaptics.medium();
                        ref.read(activeJobProvider.notifier).triggerSyncAll();
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            cupertino.CupertinoIcons.arrow_2_circlepath,
                            color: cupertino.CupertinoColors.white,
                            size: 20,
                            semanticLabel: 'Sync',
                          ),
                          const SizedBox(width: 8),
                          Text(strings.syncAll),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Semantics(
                label: strings.exploreRemoteFiles,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: cupertino.CupertinoButton(
                    color: theme.accent.withValues(alpha: 0.15),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    borderRadius: BorderRadius.circular(theme.radiusSm),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          cupertino.CupertinoIcons.folder,
                          color: theme.accent,
                          size: 18,
                          semanticLabel: strings.exploreRemoteFiles,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          strings.exploreRemoteFiles,
                          style: TextStyle(color: theme.accent, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        cupertino.CupertinoPageRoute(builder: (context) => const CloudExplorerScreen()),
                      );
                    },
                  ),
                ),
              ),
              ],
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildActiveJobPanelIOS(BuildContext context, ActiveJobState job, AppStrings strings) {
    final theme = context.theme;
    return Container(
      padding: EdgeInsets.all(theme.lg),
      decoration: BoxDecoration(
        color: cupertino.CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(theme.radiusLg),
        border: Border.all(color: cupertino.CupertinoColors.separator.resolveFrom(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.syncActive, style: const TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: theme.sm),
          Text(job.currentFile.isEmpty ? strings.preparing : job.currentFile, maxLines: 1, overflow: TextOverflow.ellipsis),
          SizedBox(height: theme.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(theme.radiusSm),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Container(color: cupertino.CupertinoColors.systemGrey5.resolveFrom(context)),
                  FractionallySizedBox(
                    widthFactor: job.percentage / 100,
                    child: Container(color: theme.accent),
                  ),
                ],
              ),
            ),
          ),
          if (job.itemsTotal > 0) ...[
            SizedBox(height: theme.sm),
            Text(
              strings.syncItemsProgress(job.itemsDone, job.itemsTotal),
              style: TextStyle(fontSize: 13, color: theme.textSecondary),
            ),
          ],
          SizedBox(height: theme.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (job.eta.isNotEmpty)
                Text('ETA: ${job.eta}', style: TextStyle(fontSize: 12, color: theme.textSecondary))
              else
                const SizedBox.shrink(),
              Text('${job.percentage.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, color: theme.textSecondary)),
            ],
          )
        ],
      ),
    );
  }

  // --- Android (Material 3 Design) ---
  Widget _buildAndroid(BuildContext context) {
    final theme = context.theme;
    final strings = ref.watch(stringsProvider);
    final activeJob = ref.watch(activeJobProvider);
    final quotaAsync = ref.watch(primaryQuotaProvider);
    final isSyncing = activeJob.status == RcloneJobStatus.syncing || activeJob.status == RcloneJobStatus.pending;
    final setupHint = _buildSetupHint(context, strings);

    return material.Scaffold(
      appBar: material.AppBar(
        title: Text(strings.navDashboard),
        elevation: 0,
        actions: [
          material.Tooltip(
            message: strings.refresh,
            child: material.IconButton(
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: material.CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : RotationTransition(
                      turns: _spinController,
                      child: Icon(material.Icons.refresh, semanticLabel: strings.refresh),
                    ),
              onPressed: _isRefreshing ? null : () => _handleRefresh(context, strings),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(theme.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildOfflineHint(context, strings),
            _buildClickableStatusBanner(context, activeJob, strings),
            SizedBox(height: theme.lg),
            if (setupHint != null) ...[
              setupHint!,
            ] else ...[
            quotaAsync.when(
              data: (quota) {
                if (quota == null) {
                  return material.Tooltip(
                    message: strings.tooltipStorageCard,
                    child: material.Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(theme.radiusLg),
                        side: BorderSide(
                          color: material.Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(theme.lg),
                        child: Row(
                          children: [
                            Icon(
                              material.Icons.cloud_off_outlined,
                              color: theme.textSecondary,
                              size: 24,
                              semanticLabel: strings.noDrivesConfigured,
                            ),
                            SizedBox(width: theme.md),
                            Expanded(
                              child: Text(
                                strings.noDrivesConfigured,
                                style: TextStyle(
                                  color: theme.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return const MultiRemoteStorageCard();
              },
              loading: () => const material.CircularProgressIndicator(),
              error: (err, stack) => Text('${strings.error}: $err', style: TextStyle(color: theme.error)),
            ),
            SizedBox(height: theme.xl),
            if (isSyncing) ...[
              _buildActiveJobPanelAndroid(context, activeJob, strings),
              SizedBox(height: theme.xl),
            ],
            if (isSyncing)
              material.Tooltip(
                message: strings.cancelSync,
                child: material.ElevatedButton.icon(
                  onPressed: () => ref.read(activeJobProvider.notifier).cancelActiveSync(),
                  icon: const Icon(material.Icons.stop_circle_outlined, semanticLabel: 'Cancel'),
                  label: Text(strings.cancelSync),
                  style: material.ElevatedButton.styleFrom(
                    backgroundColor: theme.error,
                    foregroundColor: material.Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(theme.radiusSm)),
                  ),
                ),
              )
            else
              material.Tooltip(
                message: strings.syncAll,
                child: material.ElevatedButton.icon(
                  onPressed: () => ref.read(activeJobProvider.notifier).triggerSyncAll(),
                  icon: const Icon(material.Icons.sync, semanticLabel: 'Sync'),
                  label: Text(strings.syncAll),
                  style: material.ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(theme.radiusSm)),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            material.Tooltip(
              message: strings.exploreRemoteFiles,
              child: material.OutlinedButton.icon(
                icon: Icon(material.Icons.folder_open, semanticLabel: strings.exploreRemoteFiles),
                label: Text(strings.exploreRemoteFiles),
                style: material.OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(theme.radiusSm)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    material.MaterialPageRoute(builder: (context) => const CloudExplorerScreen()),
                  );
                },
              ),
            ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveJobPanelAndroid(BuildContext context, ActiveJobState job, AppStrings strings) {
    final theme = context.theme;
    return material.Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(theme.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.activeTaskProgress, style: material.Theme.of(context).textTheme.titleSmall),
            SizedBox(height: theme.sm),
            Text(
              '${strings.currentFile} ${job.currentFile.isEmpty ? strings.preparing : job.currentFile}',
              style: material.Theme.of(context).textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: theme.sm),
            material.LinearProgressIndicator(value: job.percentage / 100, valueColor: material.AlwaysStoppedAnimation(theme.accent)),
            if (job.itemsTotal > 0) ...[
              SizedBox(height: theme.sm),
              Text(
                strings.syncItemsProgress(job.itemsDone, job.itemsTotal),
                style: material.Theme.of(context).textTheme.bodySmall,
              ),
            ],
            SizedBox(height: theme.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (job.eta.isNotEmpty) Text('ETA: ${job.eta}', style: material.Theme.of(context).textTheme.bodySmall) else const SizedBox.shrink(),
                Text('${job.percentage.toStringAsFixed(1)}%', style: material.Theme.of(context).textTheme.bodySmall),
              ],
            )
          ],
        ),
      ),
    );
  }

  /// Live-Offline-Hinweis: sichtbar, solange keine Internetverbindung besteht.
  /// Verschwindet automatisch (live über networkStatusProvider), sobald die
  /// Verbindung zurückkehrt.
  Widget _buildOfflineHint(BuildContext context, AppStrings strings) {
    final theme = context.theme;
    final net = ref.watch(networkStatusProvider);
    if (net.online) return const SizedBox.shrink();

    final platform = defaultTargetPlatform;
    final icon = platform == TargetPlatform.windows
        ? fluent.FluentIcons.error
        : (platform == TargetPlatform.iOS
            ? cupertino.CupertinoIcons.wifi_slash
            : material.Icons.wifi_off);

    return Padding(
      padding: EdgeInsets.only(bottom: theme.md),
      child: Semantics(
        label: '${strings.offlineBannerTitle}. ${strings.offlineBannerMessage}',
        child: Container(
          padding: EdgeInsets.all(theme.md),
          decoration: BoxDecoration(
            color: theme.offline.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(theme.radiusSm),
            border: Border.all(color: theme.offline.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(icon, color: theme.offline, size: 22, semanticLabel: strings.offlineBannerTitle),
              SizedBox(width: theme.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.offlineBannerTitle.toUpperCase(),
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      strings.offlineBannerMessage,
                      style: TextStyle(color: theme.textSecondary, fontSize: 12, height: 1.3),
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

  // --- Clickable Status Banner Wrapper ---
  Widget _buildClickableStatusBanner(BuildContext context, ActiveJobState job, AppStrings strings) {
    final platform = defaultTargetPlatform;
    final bannerWidget = GestureDetector(
      onTap: () => showSyncLogsDialog(context, job.logs, job.status),
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        label: '${strings.activityLogsTitle}. ${strings.viewActivityLogs}',
        button: true,
        child: _buildGlobalStatusWidget(context, job.status, strings),
      ),
    );

    if (platform == TargetPlatform.windows) {
      return fluent.Tooltip(
        message: strings.tooltipSyncBanner,
        child: bannerWidget,
      );
    } else if (platform == TargetPlatform.iOS) {
      return Semantics(
        label: strings.tooltipSyncBanner,
        child: bannerWidget,
      );
    }

    return material.Tooltip(
      message: strings.tooltipSyncBanner,
      child: bannerWidget,
    );
  }

  // --- Common Helper Widgets ---
  Widget _buildGlobalStatusWidget(BuildContext context, RcloneJobStatus status, AppStrings strings) {
    final theme = context.theme;
    Color statusColor;
    String statusText;
    IconData icon;

    switch (status) {
      case RcloneJobStatus.pending:
      case RcloneJobStatus.syncing:
        statusColor = theme.accent;
        statusText = strings.syncActive;
        icon = defaultTargetPlatform == TargetPlatform.windows
            ? fluent.FluentIcons.sync_status
            : (defaultTargetPlatform == TargetPlatform.iOS ? cupertino.CupertinoIcons.arrow_2_circlepath : material.Icons.sync);
        break;
      case RcloneJobStatus.failed:
        statusColor = theme.error;
        statusText = strings.syncFailed;
        icon = defaultTargetPlatform == TargetPlatform.windows
            ? fluent.FluentIcons.error
            : (defaultTargetPlatform == TargetPlatform.iOS ? cupertino.CupertinoIcons.exclamationmark_triangle : material.Icons.error);
        break;
      case RcloneJobStatus.cancelled:
        statusColor = theme.offline;
        statusText = strings.syncCancelled;
        icon = defaultTargetPlatform == TargetPlatform.windows
            ? fluent.FluentIcons.cancel
            : (defaultTargetPlatform == TargetPlatform.iOS ? cupertino.CupertinoIcons.xmark_circle : material.Icons.cancel);
        break;
      case RcloneJobStatus.completed:
        statusColor = theme.success;
        statusText = strings.allFilesSynced;
        icon = defaultTargetPlatform == TargetPlatform.windows
            ? fluent.FluentIcons.completed
            : (defaultTargetPlatform == TargetPlatform.iOS ? cupertino.CupertinoIcons.check_mark_circled : material.Icons.check_circle);
        break;
    }

    final chevronIcon = defaultTargetPlatform == TargetPlatform.windows
        ? fluent.FluentIcons.chevron_right
        : (defaultTargetPlatform == TargetPlatform.iOS ? cupertino.CupertinoIcons.chevron_forward : material.Icons.chevron_right);

    final infoIcon = defaultTargetPlatform == TargetPlatform.windows
        ? fluent.FluentIcons.info
        : (defaultTargetPlatform == TargetPlatform.iOS ? cupertino.CupertinoIcons.info_circle : material.Icons.info_outline);

    return Container(
      padding: EdgeInsets.all(theme.md),
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(theme.radiusSm),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.0),
      ),
      child: Row(
        children: [
          Icon(icon, color: statusColor, size: 24, semanticLabel: statusText),
          SizedBox(width: theme.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      infoIcon,
                      size: 12,
                      color: theme.textSecondary,
                      semanticLabel: strings.viewActivityLogs,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      strings.viewActivityLogs,
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            chevronIcon,
            color: statusColor,
            size: 16,
            semanticLabel: strings.viewActivityLogs,
          ),
        ],
      ),
    );
  }
}

import 'dart:ui' show FontFeature;
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
import '../../../core/services/widget_status_service.dart';
import 'dashboard_controller.dart';
import '../../tasks/presentation/tasks_controller.dart';
import '../../settings/presentation/cloud_drives_screen.dart';
import '../../shell/presentation/shell_controller.dart';
import 'widgets/multi_remote_storage_card.dart';
import 'cloud_explorer_screen.dart';

/// Platform-adaptive Dashboard Screen. Renders layout dynamically based on
/// the current platform. Alle Live-Daten aktualisieren sich automatisch
/// (AutoRefreshService) — keine manuellen Refresh-Buttons mehr.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Beim ersten Aufbau sofort prüfen, ob es lokal (Mediathek) oder remote
    // (Speicherstand) Änderungen gibt — nicht erst auf den 10-s-Takt warten.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForChangesNow());
  }

  /// Sofortige Bedarfsprüfung: Sync-Bedarf (lokal) + Speicherstände (remote).
  void _checkForChangesNow() {
    if (!mounted) return;
    ref.read(widgetStatusProvider.notifier).recomputeAndPush();
    ref.invalidate(primaryQuotaProvider);
    ref.invalidate(remoteQuotaProvider);
    ref.invalidate(remoteFibuUsageProvider);
  }

  @override
  Widget build(BuildContext context) {
    final platform = defaultTargetPlatform;

    // Jedes Mal, wenn der Nutzer in den Dashboard-Tab wechselt, sofort prüfen.
    ref.listen<int>(shellIndexProvider, (previous, next) {
      if (next == 0 && previous != 0) _checkForChangesNow();
    });

    if (platform == TargetPlatform.windows) {
      return _buildWindows(context);
    } else if (platform == TargetPlatform.iOS) {
      return _buildIOS(context);
    } else {
      return _buildAndroid(context);
    }
  }

  /// Liefert den Setup-Hinweis, solange Cloud-Laufwerk und/oder Aufgabe fehlen.
  /// Jede Zeile ist tappbar und führt direkt zur fehlenden Aktion:
  /// Laufwerk → Cloud-Laufwerke, Aufgabe → Aufgaben-Tab. null, wenn alles da ist.
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

    final theme = context.theme;
    final platform = defaultTargetPlatform;

    final rows = <Widget>[
      if (!hasRemotes)
        _setupActionRow(
            context, theme, strings.addCloudDrive, () => _openCloudDrives(context)),
      if (!hasTasks)
        _setupActionRow(context, theme, strings.addTask, _goToTasks),
    ];

    final divider = Container(
        height: 0.5, color: theme.textSecondary.withValues(alpha: 0.2));

    final inner = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) divider,
          rows[i],
        ],
      ],
    );

    if (platform == TargetPlatform.windows) {
      return fluent.Card(
        padding: EdgeInsets.only(bottom: theme.xs),
        child: inner,
      );
    }
    if (platform == TargetPlatform.iOS) {
      return Container(
        decoration: BoxDecoration(
          color: cupertino.CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(theme.radiusLg),
          border: Border.all(
            color: cupertino.CupertinoColors.separator.resolveFrom(context),
            width: 0.5,
          ),
        ),
        child: inner,
      );
    }
    return material.Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.radiusLg),
        side: BorderSide(
            color: material.Theme.of(context).colorScheme.outlineVariant),
      ),
      child: inner,
    );
  }

  void _goToTasks() {
    ref.read(shellIndexProvider.notifier).state = 1;
  }

  void _openCloudDrives(BuildContext context) {
    // Ein Navigationsmodell: wie „Aufgabe erstellen“ in den Aufgaben-Tab
    // wechselt, führt „Laufwerk hinzufügen“ in den Einstellungen-Tab — und
    // öffnet dort direkt die Cloud-Laufwerke.
    ref.read(shellIndexProvider.notifier).state = 2;
    final platform = defaultTargetPlatform;
    final route = platform == TargetPlatform.windows
        ? fluent.FluentPageRoute(builder: (_) => const CloudDrivesScreen())
        : platform == TargetPlatform.iOS
            ? cupertino.CupertinoPageRoute(builder: (_) => const CloudDrivesScreen())
            : material.MaterialPageRoute(builder: (_) => const CloudDrivesScreen());
    Navigator.of(context).push(route);
  }

  Widget _setupActionRow(
      BuildContext context, AppThemeData theme, String label, VoidCallback onTap) {
    final platform = defaultTargetPlatform;
    final chevron = platform == TargetPlatform.windows
        ? Icon(fluent.FluentIcons.chevron_right, size: 14, color: theme.textSecondary)
        : platform == TargetPlatform.iOS
            ? const Icon(cupertino.CupertinoIcons.chevron_forward,
                size: 16, color: cupertino.CupertinoColors.inactiveGray)
            : Icon(material.Icons.chevron_right, color: theme.textSecondary);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.md, vertical: theme.sm),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: theme.accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              chevron,
            ],
          ),
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
      ),
      content: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: theme.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusBanner(context, activeJob, strings),
            if (setupHint != null) ...[
              setupHint!,
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
                message: ref.watch(networkStatusProvider).online
                    ? strings.exploreRemoteFiles
                    : strings.statusOffline,
                child: fluent.Button(
                  // Offline gibt es nichts zu durchsuchen — ausgegraut.
                  onPressed: !ref.watch(networkStatusProvider).online
                      ? null
                      : () {
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
              fluent.Text('${job.percentage.toStringAsFixed(1)}%',
                  style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
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

    // Sync erst erlauben, wenn tasks.json fertig gelesen ist UND eine
    // Internetverbindung besteht.
    final tasksLoaded = ref.watch(tasksLoadedProvider);
    final online = ref.watch(networkStatusProvider).online;
    final canSync = tasksLoaded && online;
    return fluent.Tooltip(
      message: !online
          ? strings.statusOffline
          : (tasksLoaded ? strings.syncAll : strings.syncButtonWaitTasks),
      child: fluent.FilledButton(
        onPressed: canSync
            ? () => ref.read(activeJobProvider.notifier).triggerSyncAll()
            : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Spinner statt stummem Grau, solange tasks.json lädt —
                // der Button erklärt sich selbst.
                if (!tasksLoaded)
                  const SizedBox(
                      width: 16, height: 16, child: fluent.ProgressRing(strokeWidth: 2))
                else
                  const Icon(fluent.FluentIcons.sync, size: 16, semanticLabel: 'Sync'),
                const SizedBox(width: 8),
                Text(tasksLoaded ? strings.syncAll : strings.syncButtonWaitTasks),
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
      navigationBar: const cupertino.CupertinoNavigationBar(
        // Großer, natives iOS-Titel wird im Scroll-Content gerendert (Large Title).
        // Kein Refresh-Button mehr — alles aktualisiert sich automatisch.
        middle: SizedBox.shrink(),
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
                _buildStatusBanner(context, activeJob, strings),
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
                  label: !ref.watch(networkStatusProvider).online
                      ? strings.statusOffline
                      : (ref.watch(tasksLoadedProvider)
                          ? strings.syncAll
                          : strings.syncButtonWaitTasks),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: cupertino.CupertinoButton.filled(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      borderRadius: BorderRadius.circular(theme.radiusSm),
                      // Ausgegraut, bis tasks.json gelesen ist UND online —
                      // offline kann kein Backup laufen.
                      onPressed: !ref.watch(tasksLoadedProvider) ||
                              !ref.watch(networkStatusProvider).online
                          ? null
                          : () {
                              IosHaptics.medium();
                              ref.read(activeJobProvider.notifier).triggerSyncAll();
                            },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Spinner + Klartext, solange die Aufgaben laden —
                          // sonst wirkt der graue Button wie ein Fehler.
                          if (!ref.watch(tasksLoadedProvider))
                            const cupertino.CupertinoActivityIndicator(
                                color: cupertino.CupertinoColors.white)
                          else
                            const Icon(
                              cupertino.CupertinoIcons.arrow_2_circlepath,
                              color: cupertino.CupertinoColors.white,
                              size: 20,
                              semanticLabel: 'Sync',
                            ),
                          const SizedBox(width: 8),
                          Text(ref.watch(tasksLoadedProvider)
                              ? strings.syncAll
                              : strings.syncButtonWaitTasks),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Semantics(
                label: ref.watch(networkStatusProvider).online
                    ? strings.exploreRemoteFiles
                    : strings.statusOffline,
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
                          color: ref.watch(networkStatusProvider).online
                              ? theme.accent
                              : theme.textSecondary,
                          size: 18,
                          semanticLabel: strings.exploreRemoteFiles,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          strings.exploreRemoteFiles,
                          style: TextStyle(
                            color: ref.watch(networkStatusProvider).online
                                ? theme.accent
                                : theme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    // Offline gibt es nichts zu durchsuchen — ausgegraut.
                    onPressed: !ref.watch(networkStatusProvider).online
                        ? null
                        : () {
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
              Text('${job.percentage.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 12, color: theme.textSecondary, fontFeatures: const [FontFeature.tabularFigures()])),
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
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(theme.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusBanner(context, activeJob, strings),
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
                message: !ref.watch(networkStatusProvider).online
                    ? strings.statusOffline
                    : (ref.watch(tasksLoadedProvider)
                        ? strings.syncAll
                        : strings.syncButtonWaitTasks),
                child: material.ElevatedButton.icon(
                  // Ausgegraut, bis tasks.json gelesen ist UND online.
                  onPressed: ref.watch(tasksLoadedProvider) &&
                          ref.watch(networkStatusProvider).online
                      ? () => ref.read(activeJobProvider.notifier).triggerSyncAll()
                      : null,
                  icon: ref.watch(tasksLoadedProvider)
                      ? const Icon(material.Icons.sync, semanticLabel: 'Sync')
                      : const SizedBox(
                          width: 18,
                          height: 18,
                          child: material.CircularProgressIndicator(strokeWidth: 2),
                        ),
                  label: Text(ref.watch(tasksLoadedProvider)
                      ? strings.syncAll
                      : strings.syncButtonWaitTasks),
                  style: material.ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(theme.radiusSm)),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            material.Tooltip(
              message: ref.watch(networkStatusProvider).online
                  ? strings.exploreRemoteFiles
                  : strings.statusOffline,
              child: material.OutlinedButton.icon(
                icon: Icon(material.Icons.folder_open, semanticLabel: strings.exploreRemoteFiles),
                label: Text(strings.exploreRemoteFiles),
                style: material.OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(theme.radiusSm)),
                ),
                // Offline gibt es nichts zu durchsuchen — ausgegraut.
                onPressed: !ref.watch(networkStatusProvider).online
                    ? null
                    : () {
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
                Text('${job.percentage.toStringAsFixed(1)}%',
                    style: material.Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
              ],
            )
          ],
        ),
      ),
    );
  }

  /// Ein einziges, ruhiges Status-Banner — nicht tappbar, eine Zeile.
  /// Zustände: Offline (grau) → Sync läuft (Akzent) → Fehler (rot) →
  /// Abgebrochen (grau) → Sync fällig (orange) → Alles aktuell (grün).
  ///
  /// EHRLICHKEIT: Ohne konfigurierte Aufgaben gibt es nichts zu melden —
  /// dann erscheint KEIN Banner (kein „Alles synchronisiert“-Pseudoerfolg;
  /// der Einrichtungshinweis übernimmt die Führung).
  Widget _buildStatusBanner(BuildContext context, ActiveJobState job, AppStrings strings) {
    final hasTasks = ref.watch(tasksListProvider).isNotEmpty;
    final jobIdle = job.status == RcloneJobStatus.completed ||
        job.status == RcloneJobStatus.cancelled;
    if (!hasTasks && jobIdle) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: context.theme.lg),
      child: _buildGlobalStatusWidget(context, job.status, strings),
    );
  }

  // --- Common Helper Widgets ---
  Widget _buildGlobalStatusWidget(BuildContext context, RcloneJobStatus status, AppStrings strings) {
    final theme = context.theme;
    Color statusColor;
    String statusText;
    IconData icon;

    final isWindows = defaultTargetPlatform == TargetPlatform.windows;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    // Handlungsbedarf (Mediathek geändert seit letztem Sync / Task nie
    // gelaufen): Im Ruhezustand wird das grüne Banner orange.
    final needsSync = ref.watch(widgetStatusProvider).needsSync;
    // Offline schlägt alles außer einem aktiv laufenden Sync-Status.
    final online = ref.watch(networkStatusProvider).online;

    if (!online) {
      statusColor = theme.offline;
      statusText = strings.statusOffline;
      icon = isWindows
          ? fluent.FluentIcons.error
          : (isIOS ? cupertino.CupertinoIcons.wifi_slash : material.Icons.wifi_off);
    } else {
      switch (status) {
        case RcloneJobStatus.pending:
        case RcloneJobStatus.syncing:
          statusColor = theme.accent;
          statusText = strings.syncActive;
          icon = isWindows
              ? fluent.FluentIcons.sync_status
              : (isIOS ? cupertino.CupertinoIcons.arrow_2_circlepath : material.Icons.sync);
          break;
        case RcloneJobStatus.failed:
          statusColor = theme.error;
          statusText = strings.syncFailed;
          icon = isWindows
              ? fluent.FluentIcons.error
              : (isIOS ? cupertino.CupertinoIcons.exclamationmark_triangle : material.Icons.error);
          break;
        case RcloneJobStatus.cancelled:
          statusColor = theme.offline;
          statusText = strings.syncCancelled;
          icon = isWindows
              ? fluent.FluentIcons.cancel
              : (isIOS ? cupertino.CupertinoIcons.xmark_circle : material.Icons.cancel);
          break;
        case RcloneJobStatus.completed:
          if (needsSync) {
            statusColor = theme.warning;
            statusText = strings.syncNeededBanner;
            icon = isWindows
                ? fluent.FluentIcons.warning
                : (isIOS ? cupertino.CupertinoIcons.exclamationmark_circle : material.Icons.warning_amber);
          } else {
            statusColor = theme.success;
            statusText = strings.allFilesSynced;
            icon = isWindows
                ? fluent.FluentIcons.completed
                : (isIOS ? cupertino.CupertinoIcons.check_mark_circled : material.Icons.check_circle);
          }
          break;
      }
    }

    // Ein Banner, eine Zeile: Icon + Status. Nicht tappbar, kein Chevron.
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
            child: Text(
              statusText,
              style: TextStyle(
                color: theme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

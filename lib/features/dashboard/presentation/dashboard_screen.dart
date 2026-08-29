import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/theme.dart';
import '../../../core/utils/ios_haptics.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/services/network_status_service.dart';
import '../../../core/services/rclone_service.dart';
import '../../../core/services/rclone_provider.dart';
import '../../../core/services/widget_status_service.dart';
import 'dashboard_controller.dart';
import '../../tasks/presentation/tasks_controller.dart';
import '../../settings/presentation/cloud_drives_screen.dart';
import '../../shell/presentation/shell_controller.dart';
import 'widgets/multi_remote_storage_card.dart';
import 'cloud_explorer_screen.dart';
import '../../../core/widgets/liquid_glass.dart';

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
    // Theme live verfolgen, damit Dark-/Light-/Palettenwechsel sofort greift.
    ref.watch(appThemeProvider);
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

  /// Liefert den Setup-Hinweis für den nächsten fehlenden Schritt.
  ///
  /// Reihenfolge (bewusst nur EIN Hinweis, nie beide gleichzeitig):
  ///  1. Kein Cloud-Laufwerk → nur „Laufwerk hinzufügen“
  ///  2. Laufwerk da, aber keine Aufgabe → nur „Aufgabe erstellen“
  ///  3. Beides da → null (normales Dashboard)
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

    // Ohne Laufwerk zuerst das Laufwerk — eine Aufgabe ohne Ziel wäre sinnlos.
    // Erst wenn mindestens ein Laufwerk existiert, die Aufgabe anbieten.
    final rows = <Widget>[
      if (!hasRemotes)
        _setupActionRow(
            context, theme, strings.addCloudDrive, () => _openCloudDrives(context))
      else if (!hasTasks)
        _setupActionRow(context, theme, strings.addTask, _goToTasks),
    ];
    if (rows.isEmpty) return null;

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
          color: theme.surface,
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

  /// „Letztes Backup: 23.08.2026, 12:15“ — dezent unter dem Sync-Button.
  /// Ohne konfigurierte Aufgaben unsichtbar (nichts versprechen).
  Widget _lastSyncInfo(BuildContext context, AppStrings strings) {
    final theme = context.theme;
    if (ref.watch(tasksListProvider).isEmpty) return const SizedBox.shrink();
    final iso = ref.watch(widgetStatusProvider).lastSyncIso;
    final dt = DateTime.tryParse(iso);
    final text = dt == null
        ? strings.lastBackupNever
        : strings.lastBackupAt(strings.formatDateTime(dt));
    return Padding(
      padding: EdgeInsets.only(top: theme.sm),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: theme.textSecondary,
          fontSize: 12,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
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
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.lg, vertical: theme.md),
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
              SizedBox(height: theme.sm),
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
              _lastSyncInfo(context, strings),
              SizedBox(height: theme.xl),
              Builder(builder: (context) {
                final online = ref.watch(networkStatusProvider).online;
                return fluent.Tooltip(
                  message: online ? strings.exploreRemoteFiles : strings.statusOffline,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      fluent.Button(
                        // Offline gibt es nichts zu durchsuchen — ausgegraut.
                        onPressed: online
                            ? () {
                                Navigator.push(
                                  context,
                                  fluent.FluentPageRoute(builder: (context) => const CloudExplorerScreen()),
                                );
                              }
                            : null,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  fluent.FluentIcons.cloud,
                                  size: 16,
                                  color: online ? theme.accent : theme.textSecondary,
                                  semanticLabel: strings.exploreRemoteFiles,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  strings.exploreRemoteFiles,
                                  style: TextStyle(
                                    color: online ? null : theme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (!online) ...[
                        SizedBox(height: theme.xs),
                        Text(
                          strings.offlineActionHint,
                          style: TextStyle(color: theme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                );
              }),
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
          if (job.warning.isNotEmpty) ...[
            Container(
              padding: EdgeInsets.all(theme.sm),
              decoration: BoxDecoration(
                color: theme.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(theme.radiusSm),
              ),
              child: Row(
                children: [
                  const Icon(fluent.FluentIcons.warning,
                      size: 16, semanticLabel: 'Warning'),
                  SizedBox(width: theme.xs),
                  Expanded(
                    child: Text(job.warning,
                        style: TextStyle(
                            color: theme.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            SizedBox(height: theme.sm),
          ],
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
          fluent.ProgressBar(
            value: job.percentage,
            activeColor: theme.accent,
            backgroundColor: theme.secondary.withValues(alpha: 0.28),
          ),
          // Zähler und Prozentzahl in einer Zeile; Zähler immer sichtbar
          // (vor dem ersten Transfer „Überprüfen"), damit nichts nachploppt.
          SizedBox(height: theme.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Normales Flutter-Text statt fluent.Text: maxLines/overflow
              // sind dort nicht überall verfügbar, und die Darstellung ist
              // identisch (fluent.Text wrappt ohnehin Flutter-Text).
              Expanded(
                child: Text(
                  job.itemsTotal > 0
                      ? strings.syncItemsProgress(job.itemsDone, job.itemsTotal)
                      : strings.syncPhaseScan,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              fluent.Text('${job.percentage.toStringAsFixed(1)}%',
                  style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
            ],
          ),
          if (job.eta.isNotEmpty) ...[
            const SizedBox(height: 4),
            fluent.Text('ETA: ${job.eta}'),
          ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!online) ...[
          Padding(
            padding: EdgeInsets.only(bottom: theme.xs),
            child: Text(
              strings.offlineActionHint,
              style: TextStyle(color: theme.textSecondary, fontSize: 12),
            ),
          ),
        ],
        fluent.Tooltip(
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
        ),
      ],
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
    final online = ref.watch(networkStatusProvider).online;
    final tasksLoaded = ref.watch(tasksLoadedProvider);
    final canSync = tasksLoaded && online;

    // Large Title mit fixierter Navigationsleiste: Der Titel bleibt beim
    // Scrollen sichtbar (er kollabiert in die kompakte Leiste, HIG-konform).
    // Kein Refresh-Button — alles aktualisiert sich automatisch.
    return cupertino.CupertinoPageScaffold(
      backgroundColor: theme.canvas,
      child: CustomScrollView(
        slivers: [
          cupertino.CupertinoSliverNavigationBar(
            largeTitle: Text(strings.navDashboard),
            // iOS 26+: transparent → natives Liquid Glass der System-Bar;
            // darunter opakes surface wie bisher.
            backgroundColor: iosBarBackground(ref, theme),
          ),
          SliverSafeArea(
            top: false,
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  // iPad: volle Bildschirmbreite liest sich schlecht — Inhalt
                  // mittig auf max. 700 pt begrenzen (iPhone bleibt unverändert).
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(theme.lg, theme.sm, theme.lg, theme.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                _buildStatusBanner(context, activeJob, strings),
              if (setupHint != null) ...[
                SizedBox(height: theme.sm),
                setupHint,
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
                            color: theme.surface,
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
                  label: !online
                      ? strings.statusOffline
                      : (tasksLoaded ? strings.syncAll : strings.syncButtonWaitTasks),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: cupertino.CupertinoButton(
                          color: theme.accent,
                          // Deutlich ausgegraut statt nur reduziert opak:
                          // Offline/tastend-graue Fläche + gedimmter Text.
                          disabledColor: theme.offline.withValues(alpha: 0.35),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          borderRadius: BorderRadius.circular(theme.radiusSm),
                          // Eindeutig deaktiviert, bis tasks.json gelesen ist
                          // UND eine Internetverbindung besteht.
                          onPressed: canSync
                              ? () {
                                  IosHaptics.medium();
                                  ref.read(activeJobProvider.notifier).triggerSyncAll();
                                }
                              : null,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Spinner + Klartext, solange die Aufgaben laden —
                              // sonst wirkt der graue Button wie ein Fehler.
                              if (!tasksLoaded)
                                cupertino.CupertinoActivityIndicator(
                                  color: theme.accentText
                                      .withValues(alpha: canSync ? 1 : 0.7),
                                )
                              else
                                Icon(
                                  cupertino.CupertinoIcons.arrow_2_circlepath,
                                  color: theme.accentText
                                      .withValues(alpha: canSync ? 1 : 0.7),
                                  size: 20,
                                  semanticLabel: 'Sync',
                                ),
                              const SizedBox(width: 8),
                              Text(
                                tasksLoaded ? strings.syncAll : strings.syncButtonWaitTasks,
                                style: TextStyle(
                                  color: theme.accentText
                                      .withValues(alpha: canSync ? 1 : 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!online) ...[
                        SizedBox(height: theme.xs),
                        Text(
                          strings.offlineActionHint,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              _lastSyncInfo(context, strings),
              const SizedBox(height: 12),
              Semantics(
                label: online ? strings.exploreRemoteFiles : strings.statusOffline,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: cupertino.CupertinoButton(
                        color: theme.accent.withValues(alpha: 0.15),
                        // Offline deutlich ausgegraut: graue Fläche statt
                        // Akzentfarbe, damit der Zustand sofort erkennbar ist.
                        disabledColor: theme.textSecondary.withValues(alpha: 0.12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        borderRadius: BorderRadius.circular(theme.radiusSm),
                        // Offline gibt es nichts zu durchsuchen — deaktiviert.
                        onPressed: online
                            ? () {
                                Navigator.push(
                                  context,
                                  cupertino.CupertinoPageRoute(builder: (context) => const CloudExplorerScreen()),
                                );
                              }
                            : null,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              cupertino.CupertinoIcons.folder,
                              color: online ? theme.accent : theme.textSecondary,
                              size: 18,
                              semanticLabel: strings.exploreRemoteFiles,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              strings.exploreRemoteFiles,
                              style: TextStyle(
                                color: online ? theme.accent : theme.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!online) ...[
                      SizedBox(height: theme.xs),
                      Text(
                        strings.offlineActionHint,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ],
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
        ),
      ),
          ],
        ),
    );
  }

  Widget _buildActiveJobPanelIOS(BuildContext context, ActiveJobState job, AppStrings strings) {
    final theme = context.theme;
    return LiquidGlassGroupedBox(
      child: Padding(
        padding: EdgeInsets.all(theme.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (job.warning.isNotEmpty) ...[
              Container(
                padding: EdgeInsets.all(theme.sm),
                decoration: BoxDecoration(
                  color: theme.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(theme.radiusSm),
                ),
                child: Row(
                  children: [
                    Icon(cupertino.CupertinoIcons.exclamationmark_triangle,
                        color: theme.warning, size: 16, semanticLabel: 'Warning'),
                    SizedBox(width: theme.xs),
                    Expanded(
                      child: Text(job.warning,
                          style: TextStyle(
                              color: theme.warning,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              SizedBox(height: theme.sm),
            ],
            Text(strings.syncActive, style: const TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: theme.sm),
            Text(job.currentFile.isEmpty ? strings.preparing : job.currentFile, maxLines: 2, overflow: TextOverflow.ellipsis),
            SizedBox(height: theme.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(theme.radiusSm),
              child: SizedBox(
                height: 6,
                child: Stack(
                  children: [
                    Container(
                        // Track in der zweiten Paletten-Charakterfarbe —
                        // dekorativ, der Fortschritt selbst bleibt eindeutig.
                        color: theme.secondary.withValues(alpha: 0.28)),
                    FractionallySizedBox(
                      widthFactor: job.percentage / 100,
                      child: Container(color: theme.accent),
                    ),
                  ],
                ),
              ),
            ),
            // Zähler UND Prozentzahl in EINER Zeile. Der Zähler ist immer
            // sichtbar — vor dem ersten Transfer steht dort „Überprüfen"
            // statt nichts, damit die Zeile nicht erst mitten im Sync
            // „hineinploppt" und der Balken nicht springt.
            SizedBox(height: theme.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    job.itemsTotal > 0
                        ? strings.syncItemsProgress(job.itemsDone, job.itemsTotal)
                        : strings.syncPhaseScan,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: theme.textSecondary),
                  ),
                ),
                SizedBox(width: theme.sm),
                Text('${job.percentage.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 12, color: theme.textSecondary, fontFeatures: const [FontFeature.tabularFigures()])),
              ],
            ),
            if (job.eta.isNotEmpty) ...[
              SizedBox(height: theme.xs),
              Text('ETA: ${job.eta}',
                  style: TextStyle(fontSize: 12, color: theme.textSecondary)),
            ],
          ],
        ),
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
              SizedBox(height: theme.sm),
              setupHint,
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
              Builder(builder: (context) {
                final online = ref.watch(networkStatusProvider).online;
                final tasksLoaded = ref.watch(tasksLoadedProvider);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!online) ...[
                      Padding(
                        padding: EdgeInsets.only(bottom: theme.xs),
                        child: Text(
                          strings.offlineActionHint,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.textSecondary, fontSize: 12),
                        ),
                      ),
                    ],
                    material.Tooltip(
                      message: !online
                          ? strings.statusOffline
                          : (tasksLoaded ? strings.syncAll : strings.syncButtonWaitTasks),
                      child: material.ElevatedButton.icon(
                        // Ausgegraut, bis tasks.json gelesen ist UND online.
                        onPressed: tasksLoaded && online
                            ? () => ref.read(activeJobProvider.notifier).triggerSyncAll()
                            : null,
                        icon: tasksLoaded
                            ? const Icon(material.Icons.sync, semanticLabel: 'Sync')
                            : const SizedBox(
                                width: 18,
                                height: 18,
                                child: material.CircularProgressIndicator(strokeWidth: 2),
                              ),
                        label: Text(tasksLoaded ? strings.syncAll : strings.syncButtonWaitTasks),
                        style: material.ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          disabledBackgroundColor: theme.offline.withValues(alpha: 0.25),
                          disabledForegroundColor: material.Colors.white.withValues(alpha: 0.7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(theme.radiusSm)),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            _lastSyncInfo(context, strings),
            const SizedBox(height: 12),
            Builder(builder: (context) {
              final online = ref.watch(networkStatusProvider).online;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  material.Tooltip(
                    message: online ? strings.exploreRemoteFiles : strings.statusOffline,
                    child: material.OutlinedButton.icon(
                      icon: Icon(material.Icons.folder_open, semanticLabel: strings.exploreRemoteFiles),
                      label: Text(strings.exploreRemoteFiles),
                      style: material.OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        disabledForegroundColor: theme.textSecondary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(theme.radiusSm)),
                      ),
                      // Offline gibt es nichts zu durchsuchen — ausgegraut.
                      onPressed: online
                          ? () {
                              Navigator.push(
                                context,
                                material.MaterialPageRoute(builder: (context) => const CloudExplorerScreen()),
                              );
                            }
                          : null,
                    ),
                  ),
                  if (!online) ...[
                    SizedBox(height: theme.xs),
                    Text(
                      strings.offlineActionHint,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.textSecondary, fontSize: 12),
                    ),
                  ],
                ],
              );
            }),
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
            if (job.warning.isNotEmpty) ...[
              Container(
                padding: EdgeInsets.all(theme.sm),
                decoration: BoxDecoration(
                  color: theme.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(theme.radiusSm),
                ),
                child: Row(
                  children: [
                    Icon(material.Icons.warning_amber_rounded,
                        color: theme.warning, size: 18, semanticLabel: 'Warning'),
                    SizedBox(width: theme.xs),
                    Expanded(
                      child: Text(job.warning,
                          style: TextStyle(
                              color: theme.warning,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              SizedBox(height: theme.sm),
            ],
            Text(strings.activeTaskProgress, style: material.Theme.of(context).textTheme.titleSmall),
            SizedBox(height: theme.sm),
            Text(
              '${strings.currentFile} ${job.currentFile.isEmpty ? strings.preparing : job.currentFile}',
              style: material.Theme.of(context).textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: theme.sm),
            material.LinearProgressIndicator(
              value: job.percentage / 100,
              valueColor: material.AlwaysStoppedAnimation(theme.accent),
              backgroundColor: theme.secondary.withValues(alpha: 0.28),
            ),
            // Zähler und Prozentzahl in einer Zeile; Zähler immer sichtbar
            // (vor dem ersten Transfer „Überprüfen"), damit nichts nachploppt.
            SizedBox(height: theme.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    job.itemsTotal > 0
                        ? strings.syncItemsProgress(job.itemsDone, job.itemsTotal)
                        : strings.syncPhaseScan,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: material.Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                SizedBox(width: theme.sm),
                Text('${job.percentage.toStringAsFixed(1)}%',
                    style: material.Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
              ],
            ),
            if (job.eta.isNotEmpty) ...[
              SizedBox(height: theme.xs),
              Text('ETA: ${job.eta}',
                  style: material.Theme.of(context).textTheme.bodySmall),
            ]
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
    // iOS 26+: dezentes Liquid Glass unter der getönten Fläche.
    final row = Row(
      children: [
        Icon(icon, color: statusColor, size: 24, semanticLabel: statusText),
        SizedBox(width: theme.md),
        Expanded(
          child: Text(
            statusText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
    final radius = BorderRadius.circular(theme.radiusSm);
    final tinted = Container(
      padding: EdgeInsets.all(theme.md),
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: radius,
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.0),
      ),
      child: row,
    );
    if (defaultTargetPlatform != TargetPlatform.iOS) return tinted;
    return LiquidGlassPanel(
      borderRadius: radius,
      fallback: tinted,
      child: Container(
        padding: EdgeInsets.all(theme.md),
        constraints: const BoxConstraints(minHeight: 52),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.10),
          borderRadius: radius,
        ),
        child: row,
      ),
    );
  }
}

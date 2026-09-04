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
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/services/pending_deletions_store.dart';

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
    // Windows bekommt eine echte ListTile (Fokus, Semantik, Fokus-Ring).
    // iOS und Android fallen unverändert auf den bestehenden Pfad darunter.
    if (platform == TargetPlatform.windows) {
      return fluent.ListTile(
        title: Text(label),
        trailing: chevron,
        semanticLabel: label,
        onPressed: onTap,
      );
    }
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
          // Status: genau einer von drei Texten (siehe `_syncStatusText`).
          Text(
            _syncStatusText(job, strings),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: theme.textPrimary, fontSize: 14, height: 1.35),
          ),
          SizedBox(height: theme.sm),
          fluent.ProgressBar(
            value: job.percentage.clamp(0.0, 100.0),
            activeColor: theme
                .syncProgressFor(theme.surface.computeLuminance() < 0.25),
            backgroundColor: theme.syncTrack,
          ),
          // Restdauer mittig unter dem Balken — ohne „ETA", ohne Prozentzahl.
          if (job.isTransferring) ...[
            SizedBox(height: theme.sm),
            Center(
              child: Text(
                job.etaSeconds >= 0
                    ? strings.etaRemaining(job.etaSeconds)
                    : strings.etaCalculating,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: theme.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSyncActionsWindows(BuildContext context, ActiveJobState job, AppStrings strings) {
    final isSyncing = job.status == RcloneJobStatus.syncing || job.status == RcloneJobStatus.pending;
    final theme = context.theme;

    // Sync erst erlauben, wenn tasks.json fertig gelesen ist, eine
    // Internetverbindung besteht und kein Sync läuft.
    final tasksLoaded = ref.watch(tasksLoadedProvider);
    final online = ref.watch(networkStatusProvider).online;
    final canSync = tasksLoaded && online;
    final enabled = canSync && !isSyncing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        fluent.Tooltip(
      message: !online
          ? strings.statusOffline
          : (tasksLoaded ? strings.syncAll : strings.syncButtonWaitTasks),
      child: fluent.FilledButton(
        // Während eines Laufs ausgegraut statt durch einen Abbrechen-Block
        // ersetzt — die Aktion bleibt an derselben Stelle.
        onPressed: enabled
            ? () => ref.read(activeJobProvider.notifier).triggerSyncAll()
            : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Spinner statt stummem Grau, solange tasks.json lädt oder
                // ein Sync läuft — der Button erklärt sich selbst.
                if (isSyncing || !tasksLoaded)
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
        if (isSyncing) _buildCancelLinkWindows(context, strings, theme),
      ],
    );
  }

  /// Ruhiger Abbrechen-Link unter dem ausgegrauten Sync-Button (Windows).
  Widget _buildCancelLinkWindows(
      BuildContext context, AppStrings strings, AppThemeData theme) {
    final blue =
        theme.syncProgressFor(theme.surface.computeLuminance() < 0.25);
    // HyperlinkButton statt GestureDetector + MouseRegion: bringt
    // Tastaturfokus, Semantik und Fokus-Ring selbst mit. Vorher war der
    // Abbrechen-Link mit der Tastatur nicht erreichbar — ausgerechnet die
    // Aktion, mit der man einen laufenden Sync stoppt.
    return Center(
      child: fluent.HyperlinkButton(
        onPressed: () => ref.read(activeJobProvider.notifier).cancelActiveSync(),
        style: fluent.ButtonStyle(
          foregroundColor: fluent.WidgetStatePropertyAll(blue),
        ),
        child: Text(
          strings.cancel,
          style: const TextStyle(
            fontSize: 14,
            decoration: TextDecoration.underline,
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
              _buildPendingDeletionsIOS(context, theme, strings),
              if (isSyncing) ...[
                _buildActiveJobPanelIOS(context, activeJob, strings),
                SizedBox(height: theme.xl),
              ],
              // Der Sync-Button bleibt immer an derselben Stelle — während
              // eines Laufs ausgegraut statt durch einen Abbrechen-Block
              // ersetzt. Darunter erscheint der ruhige Abbrechen-Link.
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
                        // Eindeutig deaktiviert, bis tasks.json gelesen ist,
                        // eine Internetverbindung besteht und kein Sync läuft.
                        onPressed: (canSync && !isSyncing)
                            ? () {
                                IosHaptics.medium();
                                ref.read(activeJobProvider.notifier).triggerSyncAll();
                              }
                            : null,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Spinner während des Laufs und solange die
                            // Aufgaben laden — sonst wirkt der graue Button
                            // wie ein Fehler.
                            if (isSyncing || !tasksLoaded)
                              cupertino.CupertinoActivityIndicator(
                                color: theme.accentText.withValues(
                                    alpha: (canSync && !isSyncing) ? 1 : 0.7),
                              )
                            else
                              Icon(
                                cupertino.CupertinoIcons.arrow_2_circlepath,
                                color: theme.accentText
                                    .withValues(alpha: (canSync && !isSyncing) ? 1 : 0.7),
                                size: 20,
                                semanticLabel: 'Sync',
                              ),
                            const SizedBox(width: 8),
                            Text(
                              tasksLoaded ? strings.syncAll : strings.syncButtonWaitTasks,
                              style: TextStyle(
                                color: theme.accentText
                                    .withValues(alpha: (canSync && !isSyncing) ? 1 : 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isSyncing) _buildCancelLinkIOS(context, strings),
                  ],
                ),
              ),
              _lastSyncInfo(context, strings),
              const SizedBox(height: 12),
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

  /// Hinweis auf lokale Löschungen, die ein Hintergrundtask erkannt, aber
  /// nicht ausführen konnte (iOS verlangt dafür einen Bestätigungsdialog).
  /// Antippen führt sie aus.
  Widget _buildPendingDeletionsIOS(
      BuildContext context, AppThemeData theme, AppStrings strings) {
    final pending = ref.watch(pendingDeletionsProvider).valueOrNull ?? const [];
    if (pending.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: theme.xl),
      child: GestureDetector(
        onTap: () => _executePendingDeletions(context, strings),
        child: Container(
          padding: EdgeInsets.all(theme.md),
          decoration: BoxDecoration(
            color: theme.warning.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(theme.radiusSm),
            border: Border.all(color: theme.warning, width: 1),
          ),
          child: Row(
            children: [
              Icon(cupertino.CupertinoIcons.trash,
                  color: theme.warning, size: 20, semanticLabel: 'Pending'),
              SizedBox(width: theme.sm),
              Expanded(
                child: Text(
                  strings.pendingDeletionsNotice(pending.length),
                  style: TextStyle(
                      color: theme.textPrimary, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(cupertino.CupertinoIcons.chevron_forward,
                  color: theme.warning, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _executePendingDeletions(
      BuildContext context, AppStrings strings) async {
    final pending =
        ref.read(pendingDeletionsProvider).valueOrNull ?? const [];
    if (pending.isEmpty) return;
    final confirmed = await cupertino.showCupertinoDialog<bool>(
      context: context,
      builder: (dialogCtx) => cupertino.CupertinoAlertDialog(
        title: Text(strings.pendingDeletionsTitle),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(strings.pendingDeletionsConfirm(pending.length)),
        ),
        actions: [
          cupertino.CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(strings.cancel),
          ),
          cupertino.CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final done = await ref
        .read(rcloneServiceProvider)
        .deletePendingLocalDeletions(pending);
    await PendingDeletionsStore.removeAll(done.map((d) => d.assetId));
    ref.invalidate(pendingDeletionsProvider);
    if (context.mounted) {
      cupertino.showCupertinoDialog<void>(
        context: context,
        builder: (dialogCtx) => cupertino.CupertinoAlertDialog(
          content: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(strings.pendingDeletionsDone(done.length)),
          ),
          actions: [
            cupertino.CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(strings.ok),
            ),
          ],
        ),
      );
    }
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
            // Status: genau einer von drei Texten — „Auf Änderungen
            // überprüfen", „„Datei" auf/von „Cloud" übertragen", „Abschließen".
            Text(
              _syncStatusText(job, strings),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: theme.textPrimary, fontSize: 14, height: 1.35),
            ),
            SizedBox(height: theme.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(theme.radiusSm),
              child: SizedBox(
                height: 6,
                child: Stack(
                  children: [
                    Container(color: theme.syncTrack),
                    FractionallySizedBox(
                      // Apples Systemblau, nicht der Paletten-Akzent: Der
                      // Fortschritt ist eine Systemrückmeldung und soll auf
                      // jedem Hintergrund gleich aussehen.
                      widthFactor: (job.percentage / 100).clamp(0.0, 1.0),
                      child: Container(
                          color: theme.syncProgressFor(
                              theme.surface.computeLuminance() < 0.25)),
                    ),
                  ],
                ),
              ),
            ),
            // Restdauer mittig unter dem Balken — ohne das Wort „ETA" und
            // ohne Prozentzahl. Nur während eines echten Transfers, denn nur
            // dort kennt die Engine eine Gesamtbytezahl.
            if (job.isTransferring) ...[
              SizedBox(height: theme.sm),
              Center(
                child: Text(
                  job.etaSeconds >= 0
                      ? strings.etaRemaining(job.etaSeconds)
                      : strings.etaCalculating,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: theme.textSecondary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Der eine Status-Text der Statusleiste.
  ///
  /// Genau drei Zustände, aus der rohen Engine-Phase abgeleitet:
  ///  * `upload`/`download` mit Dateinamen → „„Datei" auf/von „Cloud" übertragen"
  ///  * `tombstones`/`delete-local`/`done`  → „Abschließen"
  ///  * alles andere (Scan, Staging, Lösch-Erkennung) → „Auf Änderungen überprüfen"
  String _syncStatusText(ActiveJobState job, AppStrings strings) {
    if (job.phase == 'upload' || job.phase == 'download') {
      // Ohne Dateiname oder ohne Laufwerksnamen bleibt der neutrale Text —
      // lieber weniger sagen als eine halbe oder falsche Zeile zeigen.
      if (job.fileName.isNotEmpty && job.remoteLabel.isNotEmpty) {
        return strings.syncStatusTransfer(
            job.fileName, job.remoteLabel, job.phase == 'upload');
      }
    }
    if (job.phase == 'conflict') {
      // Ein Konflikt ist keine Zwischenstufe, die man übersehen darf: Beide
      // Geräte haben dieselbe Datei geändert, beide Fassungen bleiben liegen.
      // Ohne eigenen Text fiele das auf „Auf Änderungen überprüfen" zurück.
      return strings.syncStatusConflict(job.fileName);
    }
    if (job.phase == 'tombstones' ||
        job.phase == 'delete-local' ||
        job.phase == 'done') {
      return strings.syncStatusFinishing;
    }
    return strings.syncStatusChecking;
  }

  /// Ruhiger Abbrechen-Link unter dem ausgegrauten Sync-Button.
  ///
  /// Blau unterstrichen, ohne Hintergrund — kein roter Block mehr. Die
  /// Trefferfläche bleibt 44 pt, auch wenn der Text klein ist.
  Widget _buildCancelLinkIOS(BuildContext context, AppStrings strings) {
    final theme = context.theme;
    final blue =
        theme.syncProgressFor(theme.surface.computeLuminance() < 0.25);
    return Center(
      child: cupertino.CupertinoButton(
        padding: EdgeInsets.symmetric(horizontal: theme.md, vertical: theme.sm),
        // 44 pt Trefferfläche, auch wenn der Text selbst klein ist.
        // `minimumSize` statt des seit Flutter 3.28 veralteten `minSize`.
        minimumSize: const Size(44, 44),
        onPressed: () {
          IosHaptics.light();
          ref.read(activeJobProvider.notifier).cancelActiveSync();
        },
        child: Text(
          strings.cancel,
          style: TextStyle(
            color: blue,
            fontSize: 15,
            decoration: TextDecoration.underline,
            decorationColor: blue,
          ),
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
            // Der Sync-Button bleibt immer an derselben Stelle — während
            // eines Laufs ausgegraut statt durch einen Abbrechen-Block
            // ersetzt. Darunter erscheint der ruhige Abbrechen-Link.
            Builder(builder: (context) {
              final online = ref.watch(networkStatusProvider).online;
              final tasksLoaded = ref.watch(tasksLoadedProvider);
              final enabled = tasksLoaded && online && !isSyncing;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  material.Tooltip(
                    message: !online
                        ? strings.statusOffline
                        : (tasksLoaded ? strings.syncAll : strings.syncButtonWaitTasks),
                    child: material.ElevatedButton.icon(
                      // Ausgegraut, bis tasks.json gelesen ist, online besteht
                      // und kein Sync läuft.
                      onPressed: enabled
                          ? () => ref.read(activeJobProvider.notifier).triggerSyncAll()
                          : null,
                      icon: (tasksLoaded && !isSyncing)
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
                  if (isSyncing) _buildCancelLinkAndroid(context, strings, theme),
                ],
              );
            }),
            _lastSyncInfo(context, strings),
            const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  /// Ruhiger Abbrechen-Link unter dem ausgegrauten Sync-Button (Android).
  Widget _buildCancelLinkAndroid(
      BuildContext context, AppStrings strings, AppThemeData theme) {
    final blue =
        theme.syncProgressFor(theme.surface.computeLuminance() < 0.25);
    return material.TextButton(
      onPressed: () => ref.read(activeJobProvider.notifier).cancelActiveSync(),
      style: material.TextButton.styleFrom(
        minimumSize: const Size(0, 44),
        foregroundColor: blue,
        tapTargetSize: material.MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        strings.cancel,
        style: TextStyle(
          color: blue,
          decoration: TextDecoration.underline,
          decorationColor: blue,
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
            // Status: genau einer von drei Texten (siehe `_syncStatusText`).
            Text(
              _syncStatusText(job, strings),
              style: TextStyle(
                  color: theme.textPrimary, fontSize: 14, height: 1.35),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: theme.sm),
            material.LinearProgressIndicator(
              value: (job.percentage / 100).clamp(0.0, 1.0),
              valueColor: material.AlwaysStoppedAnimation(theme
                  .syncProgressFor(theme.surface.computeLuminance() < 0.25)),
              backgroundColor: theme.syncTrack,
            ),
            // Restdauer mittig unter dem Balken — ohne „ETA", ohne Prozentzahl.
            if (job.isTransferring) ...[
              SizedBox(height: theme.sm),
              Center(
                child: Text(
                  job.etaSeconds >= 0
                      ? strings.etaRemaining(job.etaSeconds)
                      : strings.etaCalculating,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: theme.textSecondary),
                ),
              ),
            ],
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

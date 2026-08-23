import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/services/rclone_provider.dart';
import '../../../core/services/remote_registry_service.dart';
import '../../../core/utils/format.dart';
import '../../../core/services/oauth_service.dart';
import '../../../core/services/sync_config_service.dart';
import '../../../theme/theme.dart';
import '../../../theme/ios_theme.dart';
import '../../tasks/presentation/tasks_controller.dart';
import 'add_remote_wizard.dart';

/// Platform-adaptive screen to view, add, and remove configured cloud drives (remotes).
/// Supports Windows (Fluent Design), iOS (Cupertino), and Android (Material 3).
class CloudDrivesScreen extends ConsumerStatefulWidget {
  const CloudDrivesScreen({super.key});

  @override
  ConsumerState<CloudDrivesScreen> createState() => _CloudDrivesScreenState();
}

class _CloudDrivesScreenState extends ConsumerState<CloudDrivesScreen> {
  String? _deletingRemote;
  String? _bannerMessage;
  bool _isBannerError = false;
  bool _isRefreshing = false;

  void _showNotification(String message, {bool isError = false}) {
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

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
    });
    try {
      // Per-Remote Statistiken (Quota + Fibu-Beleg) ebenfalls erneuern.
      final known = ref.read(remotesProvider).valueOrNull ?? const <String>[];
      for (final remote in known) {
        ref.invalidate(remoteQuotaProvider(remote));
        ref.invalidate(remoteFibuUsageProvider(remote));
      }
      // Registry zuerst — remotesProvider hängt davon ab.
      ref.invalidate(remoteEntriesProvider);
      ref.invalidate(remotesProvider);
      ref.invalidate(primaryQuotaProvider);
      await ref.read(remotesProvider.future);
      await ref.read(primaryQuotaProvider.future);
      if (mounted) {
        _showNotification(context.strings.drivesRefreshed, isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showNotification(e.toString(), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch locale to trigger reactive rebuilds when language changes
    ref.watch(localeProvider);
    final platform = defaultTargetPlatform;
    final theme = context.theme;

    if (platform == TargetPlatform.windows) {
      return _buildWindows(context, theme);
    } else if (platform == TargetPlatform.iOS) {
      return _buildIOS(context, theme);
    } else {
      return _buildAndroid(context, theme);
    }
  }

  // --- Windows (Fluent Design) ---
  Widget _buildWindows(BuildContext context, AppThemeData theme) {
    final strings = context.strings;
    final remotesAsync = ref.watch(remotesProvider);

    return fluent.ScaffoldPage(
      header: fluent.PageHeader(
        title: fluent.Text(strings.cloudDrivesTitle),
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
              icon: const Icon(fluent.FluentIcons.add, size: 16, semanticLabel: 'Add Drive'),
              label: Text(strings.addCloudDrive),
              onPressed: () => _openAddRemoteWizard(context, TargetPlatform.windows),
            ),
          ],
        ),
      ),
      content: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(theme.lg, theme.lg, theme.lg + 16, theme.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_bannerMessage != null) ...[
              fluent.InfoBar(
                title: Text(_isBannerError ? strings.error : strings.success),
                content: Text(_bannerMessage!),
                severity: _isBannerError
                    ? fluent.InfoBarSeverity.error
                    : fluent.InfoBarSeverity.success,
                onClose: () => setState(() => _bannerMessage = null),
              ),
              SizedBox(height: theme.md),
            ],
            remotesAsync.when(
              data: (remotes) => _buildWindowsRemotesList(context, theme, remotes),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: fluent.ProgressRing()),
              ),
              error: (err, _) => fluent.InfoBar(
                title: Text(strings.error),
                content: Text(err.toString()),
                severity: fluent.InfoBarSeverity.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWindowsRemotesList(
      BuildContext context, AppThemeData theme, List<String> remotes) {
    final strings = context.strings;
    if (remotes.isEmpty) {
      return fluent.Card(
        child: Padding(
          padding: EdgeInsets.all(theme.xl),
          child: Column(
            children: [
              Icon(fluent.FluentIcons.cloud, size: 48, color: theme.textSecondary, semanticLabel: 'No Drives'),
              SizedBox(height: theme.md),
              Text(
                strings.noDrivesConnected,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: theme.xs),
              Text(
                strings.noDrivesDescription,
                style: TextStyle(color: theme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: remotes.length,
      separatorBuilder: (_, __) => SizedBox(height: theme.sm),
      itemBuilder: (context, index) {
        final remote = remotes[index];
        final entry = ref.watch(remoteEntryProvider(remote));
        final displayName = entry?.name ?? remote;
        final isDeleting = _deletingRemote == remote;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: isDeleting
              ? null
              : () => _showRemoteActions(context, remote, TargetPlatform.windows),
          child: fluent.Card(
            padding: EdgeInsets.fromLTRB(theme.md, theme.md, theme.md + 4, theme.md),
            child: Row(
              children: [
                Icon(fluent.FluentIcons.cloud, color: theme.accent, size: 28, semanticLabel: 'Cloud Remote'),
                SizedBox(width: theme.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: theme.xs),
                      _remoteStorageInfo(theme, strings, remote),
                    ],
                  ),
                ),
                if (isDeleting)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: fluent.ProgressRing(strokeWidth: 2.5),
                  )
                else
                  Icon(fluent.FluentIcons.chevron_right, size: 14, color: theme.textSecondary, semanticLabel: strings.openInDefaultApp),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- iOS (Cupertino Design) ---
  Widget _buildIOS(BuildContext context, AppThemeData theme) {
    final strings = context.strings;
    final remotesAsync = ref.watch(remotesProvider);

    return cupertino.CupertinoPageScaffold(
      backgroundColor: theme.canvas,
      navigationBar: cupertino.CupertinoNavigationBar(
        middle: Text(strings.cloudDrivesTitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: cupertino.CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Icon(cupertino.CupertinoIcons.add, semanticLabel: 'Add Drive'),
                  onPressed: () => _openAddRemoteWizard(context, TargetPlatform.iOS),
                ),
              ),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(theme.lg, theme.lg, theme.lg + 16, theme.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_bannerMessage != null) ...[
                Container(
                  padding: EdgeInsets.all(theme.md),
                  decoration: BoxDecoration(
                    color: _isBannerError
                        ? theme.error.withValues(alpha: 0.15)
                        : theme.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(theme.radiusSm),
                    border: Border.all(
                      color: _isBannerError ? theme.error : theme.success,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isBannerError
                            ? cupertino.CupertinoIcons.exclamationmark_circle
                            : cupertino.CupertinoIcons.checkmark_circle,
                        color: _isBannerError ? theme.error : theme.success,
                        size: 20,
                        semanticLabel: _isBannerError ? 'Error' : 'Success',
                      ),
                      SizedBox(width: theme.sm),
                      Expanded(
                        child: Text(
                          _bannerMessage!,
                          style: TextStyle(
                            color: _isBannerError ? theme.error : theme.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: theme.md),
              ],
              remotesAsync.when(
                data: (remotes) => _buildIOSRemotesSection(context, theme, remotes),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: cupertino.CupertinoActivityIndicator()),
                ),
                error: (err, _) => Padding(
                  padding: EdgeInsets.only(top: theme.xxl),
                  child: Center(
                    child: Text('${strings.error}: $err', style: TextStyle(color: theme.error)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIOSRemotesSection(
      BuildContext context, AppThemeData theme, List<String> remotes) {
    final strings = context.strings;
    if (remotes.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: theme.xxl),
        child: Column(
          children: [
            Icon(cupertino.CupertinoIcons.cloud, size: 56, color: theme.textSecondary, semanticLabel: 'No Drives'),
            SizedBox(height: theme.md),
            Text(
              strings.noDrivesConnected,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: theme.xs),
            Text(
              strings.noDrivesDescription,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textSecondary),
            ),
          ],
        ),
      );
    }

    return cupertino.CupertinoListSection.insetGrouped(
      header: IosTheme.sectionHeader(strings.connectedDrives, theme),
      children: [
        for (final remote in remotes)
          () {
            final entry = ref.watch(remoteEntryProvider(remote));
            final displayName = entry?.name ?? remote;
            final isDeleting = _deletingRemote == remote;
            return cupertino.CupertinoListTile.notched(
              title: Text(displayName),
              subtitle: _remoteStorageInfo(theme, strings, remote),
              leading: Icon(cupertino.CupertinoIcons.cloud,
                  color: theme.accent, semanticLabel: 'Cloud Remote'),
              trailing: isDeleting
                  ? const cupertino.CupertinoActivityIndicator()
                  : const Icon(cupertino.CupertinoIcons.chevron_forward,
                      size: 18, color: cupertino.CupertinoColors.inactiveGray),
              onTap: isDeleting
                  ? null
                  : () => _showRemoteActions(context, remote, TargetPlatform.iOS),
            );
          }(),
      ],
    );
  }

  // --- Android (Material 3 Design) ---
  Widget _buildAndroid(BuildContext context, AppThemeData theme) {
    final strings = context.strings;
    final remotesAsync = ref.watch(remotesProvider);

    return material.Scaffold(
      appBar: material.AppBar(
        title: Text(strings.cloudDrivesTitle),
        elevation: 0,
        actions: [
          material.IconButton(
            icon: const Icon(material.Icons.add, semanticLabel: 'Add Drive'),
            tooltip: strings.addCloudDrive,
            onPressed: () => _openAddRemoteWizard(context, TargetPlatform.android),
          ),
          SizedBox(width: theme.sm),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(theme.lg, theme.lg, theme.lg + 16, theme.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_bannerMessage != null) ...[
              material.MaterialBanner(
                content: Text(_bannerMessage!),
                backgroundColor: _isBannerError
                    ? theme.error.withValues(alpha: 0.15)
                    : theme.success.withValues(alpha: 0.15),
                leading: Icon(
                  _isBannerError ? material.Icons.error_outline : material.Icons.check_circle_outline,
                  color: _isBannerError ? theme.error : theme.success,
                  semanticLabel: _isBannerError ? 'Error' : 'Success',
                ),
                actions: [
                  material.TextButton(
                    onPressed: () => setState(() => _bannerMessage = null),
                    child: Text(strings.close),
                  ),
                ],
              ),
              SizedBox(height: theme.md),
            ],
            remotesAsync.when(
              data: (remotes) => _buildAndroidRemotesList(context, theme, remotes),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: material.CircularProgressIndicator()),
              ),
              error: (err, _) => material.MaterialBanner(
                content: Text(err.toString()),
                backgroundColor: theme.error.withValues(alpha: 0.15),
                leading: Icon(material.Icons.error_outline, color: theme.error, semanticLabel: 'Error'),
                actions: [
                  material.TextButton(
                    onPressed: _handleRefresh,
                    child: Text(strings.retry),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAndroidRemotesList(
      BuildContext context, AppThemeData theme, List<String> remotes) {
    final strings = context.strings;
    if (remotes.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: theme.xxl),
        child: Column(
          children: [
            Icon(material.Icons.cloud_off_outlined, size: 56, color: theme.textSecondary, semanticLabel: 'No Drives'),
            SizedBox(height: theme.md),
            Text(
              strings.noDrivesConnected,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: theme.xs),
            Text(
              strings.noDrivesDescription,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: remotes.length,
      separatorBuilder: (_, __) => SizedBox(height: theme.sm),
      itemBuilder: (context, index) {
        final remote = remotes[index];
        final entry = ref.watch(remoteEntryProvider(remote));
        final displayName = entry?.name ?? remote;
        final isDeleting = _deletingRemote == remote;

        return material.Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(theme.radiusSm),
            side: BorderSide(
                color: material.Theme.of(context).colorScheme.outlineVariant),
          ),
          child: material.ListTile(
            contentPadding: EdgeInsets.fromLTRB(theme.md, 0, theme.md + 4, 0),
            leading: Icon(material.Icons.cloud_queue,
                color: theme.accent, semanticLabel: 'Cloud Remote'),
            title: Text(displayName),
            subtitle: _remoteStorageInfo(theme, strings, remote),
            trailing: isDeleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: material.CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Icon(material.Icons.chevron_right),
            onTap: isDeleting
                ? null
                : () => _showRemoteActions(context, remote, TargetPlatform.android),
          ),
        );
      },
    );
  }

  // --- Helper Methods ---

  /// Speicherplatz-Angaben je Remote (Apple-dezent, als Subtitle-Zeilen):
  ///
  /// * Quota: „<belegt> von <gesamt> belegt“ – bei Providern ohne `about`
  ///   (getQuota == null oder 0-Total) stattdessen „Speicherplatz n. v.“.
  /// * Fibu-Beleg: rekursive Byte-Summe des Fibu-Backup-Zielordners im Remote.
  ///
  /// Beide Werte werden pro Remote asynchron nachgeladen.
  Widget _remoteStorageInfo(AppThemeData theme, AppStrings strings, String remote,
      {TextStyle? style}) {
    final quotaAsync = ref.watch(remoteQuotaProvider(remote));
    final fibuAsync = ref.watch(remoteFibuUsageProvider(remote));
    final textStyle =
        style ?? TextStyle(color: theme.textSecondary, fontSize: 12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        quotaAsync.when(
          data: (quota) => Text(
            (quota == null || quota.totalBytes <= 0)
                ? strings.quotaSummaryUnavailable
                : strings.quotaSummaryUsedOf(
                    formatBytes(quota.usedBytes), formatBytes(quota.totalBytes)),
            style: textStyle,
          ),
          loading: () => Text('…', style: textStyle),
          error: (err, _) => Text(strings.quotaSummaryUnavailable, style: textStyle),
        ),
        fibuAsync.when(
          data: (bytes) => Text(
            '${strings.fibuSpaceLabel}: ${formatBytes(bytes)}',
            style: textStyle,
          ),
          loading: () => Text('${strings.fibuSpaceLabel}: …', style: textStyle),
          error: (err, _) => Text('${strings.fibuSpaceLabel}: –', style: textStyle),
        ),
      ],
    );
  }


  // --- Remote Deletion Confirmation (Destructive Action Rule 6) ---
  /// Aktionsmenü nach Tap auf einen Remote — Übersicht bleibt clean,
  /// Trennen passiert gezielt über das Aktionsblatt (kein Trash-Symbol mehr).
  Future<void> _showRemoteActions(
      BuildContext context, String remote, TargetPlatform platform) async {
    final strings = context.strings;
    final theme = context.theme;
    // Anzeigename aus der App-Registry (Fallback: Kennung).
    final displayName = ref.read(remoteDisplayNameProvider(remote));
    if (platform == TargetPlatform.iOS) {
      await cupertino.showCupertinoModalPopup(
        context: context,
        builder: (sheetCtx) => cupertino.CupertinoActionSheet(
          title: Text(displayName),
          actions: [
            cupertino.CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.pop(sheetCtx);
                await _showRenameDialog(context, remote, platform);
              },
              child: Text(strings.renameDrive),
            ),
            cupertino.CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.pop(sheetCtx);
                final confirmed =
                    await _confirmDeleteRemoteAsync(context, remote, platform);
                if (confirmed) _performDelete(remote);
              },
              child: Text(strings.disconnect),
            ),
          ],
          cancelButton: cupertino.CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetCtx),
            child: Text(strings.cancel),
          ),
        ),
      );
    } else if (platform == TargetPlatform.android) {
      await material.showModalBottomSheet(
        context: context,
        builder: (sheetCtx) => material.SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              material.ListTile(title: Text(displayName)),
              const material.Divider(height: 1),
              material.ListTile(
                leading: Icon(material.Icons.drive_file_rename_outline,
                    color: theme.accent),
                title: Text(strings.renameDrive),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await _showRenameDialog(context, remote, platform);
                },
              ),
              material.ListTile(
                leading: Icon(material.Icons.link_off, color: theme.error),
                title: Text(strings.disconnect,
                    style: TextStyle(color: theme.error)),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final confirmed = await _confirmDeleteRemoteAsync(
                      context, remote, platform);
                  if (confirmed) _performDelete(remote);
                },
              ),
            ],
          ),
        ),
      );
    } else {
      // Windows: Aktionswahl über ContentDialog (Umbenennen / Trennen).
      final action = await fluent.showDialog<String>(
        context: context,
        builder: (dialogCtx) => fluent.ContentDialog(
          title: fluent.Text(displayName),
          actions: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 80, minHeight: 44),
                child: fluent.Button(
                  onPressed: () => Navigator.pop(dialogCtx, 'rename'),
                  child: Text(strings.renameDrive),
                ),
              ),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 80, minHeight: 44),
                child: fluent.FilledButton(
                  style: fluent.ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(theme.error),
                  ),
                  onPressed: () => Navigator.pop(dialogCtx, 'disconnect'),
                  child: Text(strings.disconnect,
                      style: const TextStyle(color: Color(0xFFFFFFFF))),
                ),
              ),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 80, minHeight: 44),
                child: fluent.Button(
                  onPressed: () => Navigator.pop(dialogCtx, null),
                  child: Text(strings.cancel),
                ),
              ),
            ),
          ],
        ),
      );
      if (action == 'rename') {
        await _showRenameDialog(context, remote, platform);
      } else if (action == 'disconnect') {
        final confirmed =
            await _confirmDeleteRemoteAsync(context, remote, platform);
        if (confirmed) _performDelete(remote);
      }
    }
  }

  /// Umbenennen-Dialog: ändert NUR den lokalen Anzeigenamen in der Registry —
  /// rclone.conf, Verbindung und alle Aufgaben-Referenzen bleiben unberührt
  /// (das war früher die Fehlerquelle „Remote nicht gefunden“).
  Future<void> _showRenameDialog(
      BuildContext context, String remoteId, TargetPlatform platform) async {
    final strings = context.strings;
    final theme = context.theme;
    final currentName = ref.read(remoteDisplayNameProvider(remoteId));
    final controller = TextEditingController(text: currentName);
    String? newName;

    if (platform == TargetPlatform.iOS) {
      newName = await cupertino.showCupertinoDialog<String>(
        context: context,
        builder: (dialogCtx) => cupertino.CupertinoAlertDialog(
          title: Text(strings.renameDriveTitle),
          content: Column(
            children: [
              const SizedBox(height: 8),
              Text(
                strings.renameDriveDescription,
                style: TextStyle(fontSize: 12, color: theme.textSecondary),
              ),
              const SizedBox(height: 12),
              cupertino.CupertinoTextField(
                controller: controller,
                autofocus: true,
                autocorrect: false,
              ),
            ],
          ),
          actions: [
            cupertino.CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(strings.cancel),
            ),
            cupertino.CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(dialogCtx, controller.text.trim()),
              child: Text(strings.save),
            ),
          ],
        ),
      );
    } else if (platform == TargetPlatform.android) {
      newName = await material.showDialog<String>(
        context: context,
        builder: (dialogCtx) => material.AlertDialog(
          title: material.Text(strings.renameDriveTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              material.Text(
                strings.renameDriveDescription,
                style: material.TextStyle(fontSize: 12, color: theme.textSecondary),
              ),
              const SizedBox(height: 12),
              material.TextField(
                controller: controller,
                autofocus: true,
                autocorrect: false,
                decoration: const material.InputDecoration(),
              ),
            ],
          ),
          actions: [
            material.TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: material.Text(strings.cancel),
            ),
            material.FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, controller.text.trim()),
              child: material.Text(strings.save),
            ),
          ],
        ),
      );
    } else {
      newName = await fluent.showDialog<String>(
        context: context,
        builder: (dialogCtx) => fluent.ContentDialog(
          title: fluent.Text(strings.renameDriveTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.renameDriveDescription,
                  style: TextStyle(fontSize: 12, color: theme.textSecondary)),
              const SizedBox(height: 12),
              fluent.TextBox(controller: controller, autofocus: true),
            ],
          ),
          actions: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 80, minHeight: 44),
                child: fluent.FilledButton(
                  onPressed: () =>
                      Navigator.pop(dialogCtx, controller.text.trim()),
                  child: Text(strings.save),
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
    }

    final trimmed = newName?.trim() ?? '';
    if (trimmed.isEmpty || trimmed == currentName) return;
    await ref
        .read(remoteRegistryServiceProvider)
        .rename(remoteId, trimmed);
    if (!mounted) return;
    ref.invalidate(remoteEntriesProvider);
    ref.invalidate(remotesProvider);
    _showNotification(strings.driveRenamedSuccess(trimmed), isError: false);
  }

  Future<bool> _confirmDeleteRemoteAsync(
      BuildContext context, String remoteName, TargetPlatform platform) async {
    final strings = context.strings;
    // Immer den Anzeigenamen zeigen (Registry), nie die interne Kennung.
    final displayName = ref.read(remoteDisplayNameProvider(remoteName));
    // Transparenz vor dem Trennen: wie viele Aufgaben verlieren ihr Ziel?
    final affectedTasks = ref
        .read(tasksListProvider)
        .where((t) => t.targetRemotes.contains(remoteName))
        .length;
    final title = strings.deleteDriveConfirmTitle;
    var message =
        '${strings.deleteDrivePrompt(displayName)}\n\n${strings.deleteDriveRule6Notice}';
    if (affectedTasks > 0) {
      message = '$message\n\n${strings.deleteDriveTasksWarning(affectedTasks)}';
    }

    if (platform == TargetPlatform.windows) {
      final result = await fluent.showDialog<bool>(
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
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  child: Text(
                    strings.disconnect,
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
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: Text(strings.cancel),
                ),
              ),
            ),
          ],
        ),
      );
      return result ?? false;
    } else if (platform == TargetPlatform.iOS) {
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
              child: Text(strings.disconnect),
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
              style: material.FilledButton.styleFrom(backgroundColor: context.theme.error),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: Text(
                strings.disconnect,
                style: const TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
      return result ?? false;
    }
  }

  void _confirmDeleteRemote(
      BuildContext context, String remoteName, TargetPlatform platform) {
    _confirmDeleteRemoteAsync(context, remoteName, platform);
  }

  Future<void> _performDelete(String remoteName) async {
    final strings = context.strings;
    setState(() {
      _deletingRemote = remoteName;
    });

    final displayName = ref.read(remoteDisplayNameProvider(remoteName));
    try {
      await ref.read(rcloneServiceProvider).removeRemote(remoteName);
      // Registry-Eintrag entfernen (nur die Kennung löscht rclone bereits).
      await ref.read(remoteRegistryServiceProvider).unregister(remoteName);
      // Geparkte OAuth-Tokens zum alten Namen/zur Kennung wegräumen.
      try {
        final oauth = ref.read(oauthServiceProvider);
        await oauth.clearToken(remoteName);
        await oauth.clearToken(displayName);
      } catch (_) {}
      ref.invalidate(remoteEntriesProvider);
      ref.invalidate(remotesProvider);
      ref.invalidate(primaryQuotaProvider);
      _showNotification(strings.driveDeletedSuccess(displayName), isError: false);
    } catch (e) {
      _showNotification(e.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _deletingRemote = null;
        });
      }
    }
  }


  // --- Show 2-Step Wizard Dialog ---
  Future<void> _openAddRemoteWizard(BuildContext context, TargetPlatform platform) async {
    final strings = context.strings;
    String? addedRemoteName;
    
    if (platform == TargetPlatform.iOS) {
      addedRemoteName = await Navigator.of(context).push<String>(
        cupertino.CupertinoPageRoute(
          fullscreenDialog: true,
          builder: (_) => AddRemoteWizardDialog(platform: platform),
        ),
      );
    } else if (platform == TargetPlatform.android) {
      addedRemoteName = await Navigator.of(context).push<String>(
        material.MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => AddRemoteWizardDialog(platform: platform),
        ),
      );
    } else {
      addedRemoteName = await showGeneralDialog<String>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Add Remote Wizard',
        pageBuilder: (dialogContext, _, __) {
          return AddRemoteWizardDialog(platform: platform);
        },
      );
    }

    if (addedRemoteName != null && mounted) {
      // Der Wizard liefert jetzt die interne Kennung (Registry-ID) zurück.
      // Für die Erfolgsmeldung den Anzeigenamen auflösen, für die
      // Config-Erkennung aber die Kennung verwenden (die rclone kennt).
      final displayName = ref.read(remoteDisplayNameProvider(addedRemoteName));
      _showNotification(strings.driveAddedSuccess(displayName), isError: false);
      // Neu erreichbare Remote-Configs für das Plus-Menü der Aufgaben laden.
      ref.invalidate(remoteTaskCandidatesProvider);
      await _checkAndPromptRemoteConfig(addedRemoteName, platform);
    }
  }

  // --- Remote Config Detection Confirmation Dialog ---
  Future<void> _checkAndPromptRemoteConfig(
      String remoteName, TargetPlatform platform) async {
    final hasConfig = await ref.read(syncConfigServiceProvider).checkRemoteForConfig(remoteName);
    if (!hasConfig || !mounted) return;

    final strings = context.strings;
    final title = strings.existingConfigDetectedTitle;
    // remoteName ist die interne Kennung — im Dialog den Anzeigenamen zeigen.
    final displayName = ref.read(remoteDisplayNameProvider(remoteName));
    final message = strings.existingConfigDetectedMessage(displayName);

    Future<void> handleImport() async {
      final config = await ref.read(syncConfigServiceProvider).readRemoteConfig(remoteName);
      if (config != null) {
        // Lokale Remotes laden: Die Config stammt von einem anderen Gerät —
        // ihre Remote-Namen/IDs werden dynamisch aufgelöst (ID → Name →
        // Provider → dieses Remote), damit das Backup-Ziel nie „nicht
        // gefunden“ ist.
        final localRemotes =
            await ref.read(remoteRegistryServiceProvider).entries();
        final tasks = ref.read(syncConfigServiceProvider).convertConfigToTasks(
              config,
              remoteName,
              null,
              localRemotes,
            );
        ref.read(tasksListProvider.notifier).importTasks(tasks);
        ref.invalidate(remoteTaskCandidatesProvider);
        
        // Download existing cloud files to local task directory
        for (final task in tasks) {
          try {
            await ref.read(syncConfigServiceProvider).downloadRemoteFiles(
              remoteName,
              task.targetFolderName,
              task.sourcePath,
            );
          } catch (_) {}
        }

        if (mounted) {
          _showNotification(strings.configImportSuccess, isError: false);
        }
      }
    }

    if (platform == TargetPlatform.windows) {
      await fluent.showDialog(
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
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    await handleImport();
                  },
                  child: Text(
                    strings.importConfigAndSync,
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
                  child: Text(strings.skipConfigImport),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (platform == TargetPlatform.iOS) {
      await cupertino.showCupertinoDialog(
        context: context,
        builder: (dialogCtx) => cupertino.CupertinoAlertDialog(
          title: Text(title),
          content: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(message),
          ),
          actions: [
            cupertino.CupertinoDialogAction(
              child: Text(strings.skipConfigImport),
              onPressed: () => Navigator.pop(dialogCtx),
            ),
            cupertino.CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () async {
                Navigator.pop(dialogCtx);
                await handleImport();
              },
              child: Text(strings.importConfigAndSync),
            ),
          ],
        ),
      );
    } else {
      await material.showDialog(
        context: context,
        builder: (dialogCtx) => material.AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            material.TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(strings.skipConfigImport),
            ),
            material.FilledButton(
              onPressed: () async {
                Navigator.pop(dialogCtx);
                await handleImport();
              },
              child: Text(
                strings.importConfigAndSync,
                style: const TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }
  }
}

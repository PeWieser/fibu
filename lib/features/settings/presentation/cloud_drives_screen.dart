import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/services/rclone_provider.dart';
import '../../../core/utils/format.dart';
import '../../../core/services/ios_rclone_service.dart';
import '../../../core/services/oauth_service.dart';
import '../../../core/services/sync_config_service.dart';
import '../../../theme/theme.dart';
import '../../tasks/presentation/tasks_controller.dart';

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
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: fluent.ProgressRing(strokeWidth: 2.0),
                    )
                  : const Icon(fluent.FluentIcons.refresh, size: 16, semanticLabel: 'Refresh'),
              label: Text(strings.refresh),
              onPressed: _isRefreshing ? null : _handleRefresh,
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
            SizedBox(height: theme.xl),
            Center(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 160, minHeight: 44),
                  child: fluent.FilledButton(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(fluent.FluentIcons.add, size: 16, color: Color(0xFFFFFFFF), semanticLabel: 'Add Drive'),
                        SizedBox(width: theme.sm),
                        Text(
                          strings.addCloudDrive,
                          style: const TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    onPressed: () => _openAddRemoteWizard(context, TargetPlatform.windows),
                  ),
                ),
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
        final type = _getProviderType(remote);
        final isDeleting = _deletingRemote == remote;

        return fluent.Card(
          padding: EdgeInsets.fromLTRB(theme.md, theme.md, theme.md + 4, theme.md),
          child: Row(
            children: [
              Icon(fluent.FluentIcons.cloud, color: theme.accent, size: 28, semanticLabel: 'Cloud Remote'),
              SizedBox(width: theme.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(remote, style: const TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: theme.xs),
                    Text(type, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
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
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    child: fluent.IconButton(
                      icon: Icon(fluent.FluentIcons.delete, color: theme.error, semanticLabel: strings.delete),
                      onPressed: () => _confirmDeleteRemote(context, remote, TargetPlatform.windows),
                    ),
                  ),
                ),
            ],
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
                  onPressed: _isRefreshing ? null : _handleRefresh,
                  child: _isRefreshing
                      ? const cupertino.CupertinoActivityIndicator()
                      : const Icon(cupertino.CupertinoIcons.arrow_clockwise, semanticLabel: 'Refresh'),
                ),
              ),
            ),
            SizedBox(width: theme.xs),
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
            SizedBox(height: theme.lg),
            // Aktionsfähiger Leerzustand (Apple HIG): CTA zum Hinzufügen.
            Semantics(
              label: strings.addCloudDrive,
              button: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: cupertino.CupertinoButton(
                  color: theme.accent,
                  padding: EdgeInsets.symmetric(horizontal: theme.lg, vertical: theme.sm),
                  borderRadius: BorderRadius.circular(theme.radiusSm),
                  onPressed: () => _openAddRemoteWizard(context, TargetPlatform.iOS),
                  child: Text(
                    strings.addCloudDrive,
                    style: const TextStyle(
                      color: cupertino.CupertinoColors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return cupertino.CupertinoListSection.insetGrouped(
      header: Text(strings.connectedDrives.toUpperCase()),
      children: remotes.map((remote) {
        final type = _getProviderType(remote);
        final isDeleting = _deletingRemote == remote;

        return Dismissible(
          key: ValueKey(remote),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: theme.error,
            child: const Icon(
              cupertino.CupertinoIcons.trash,
              color: cupertino.CupertinoColors.white,
              size: 22,
            ),
          ),
          confirmDismiss: (_) async {
            final confirmed =
                await _confirmDeleteRemoteAsync(context, remote, TargetPlatform.iOS);
            if (confirmed) {
              // Löschung läuft asynchron über Provider-Invalidierung. return false,
              // damit Dismissible die Zeile NICHT selbst animiert/entfernt
              // (kein "dismissed Dismissible still part of tree"-Fehler).
              _performDelete(remote);
            }
            return false;
          },
          child: cupertino.CupertinoListTile(
            title: Text(remote),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type),
                _remoteStorageInfo(theme, strings, remote),
              ],
            ),
            leading: Icon(cupertino.CupertinoIcons.cloud, color: theme.accent, semanticLabel: 'Cloud Remote'),
            trailing: isDeleting
                ? const cupertino.CupertinoActivityIndicator()
                : MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      child: cupertino.CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Icon(cupertino.CupertinoIcons.trash, color: theme.error, size: 20, semanticLabel: strings.delete),
                        onPressed: () => _confirmDeleteRemote(context, remote, TargetPlatform.iOS),
                      ),
                    ),
                  ),
          ),
        );
      }).toList(),
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
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              child: material.IconButton(
                icon: _isRefreshing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: material.CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Icon(material.Icons.refresh, semanticLabel: 'Refresh'),
                onPressed: _isRefreshing ? null : _handleRefresh,
                tooltip: strings.refresh,
              ),
            ),
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
            SizedBox(height: theme.xl),
            Center(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 160, minHeight: 44),
                  child: material.FilledButton.icon(
                    icon: const Icon(material.Icons.add, semanticLabel: 'Add Drive'),
                    label: Text(strings.addCloudDrive),
                    onPressed: () => _openAddRemoteWizard(context, TargetPlatform.android),
                  ),
                ),
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
        final type = _getProviderType(remote);
        final isDeleting = _deletingRemote == remote;

        return Dismissible(
          key: ValueKey(remote),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: theme.error,
              borderRadius: BorderRadius.circular(theme.radiusSm),
            ),
            child: const Icon(
              material.Icons.delete_outline,
              color: material.Colors.white,
              size: 24,
            ),
          ),
          confirmDismiss: (_) async {
            return await _confirmDeleteRemoteAsync(context, remote, TargetPlatform.android);
          },
          child: material.Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(theme.radiusSm),
              side: BorderSide(color: material.Theme.of(context).colorScheme.outlineVariant),
            ),
            child: material.ListTile(
              contentPadding: EdgeInsets.fromLTRB(theme.md, 0, theme.md + 4, 0),
              leading: Icon(material.Icons.cloud_queue, color: theme.accent, semanticLabel: 'Cloud Remote'),
              title: Text(remote),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type),
                  _remoteStorageInfo(theme, strings, remote),
                ],
              ),
              trailing: isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: material.CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                        child: material.IconButton(
                          icon: Icon(material.Icons.delete_outline, color: theme.error, semanticLabel: strings.delete),
                          onPressed: () => _confirmDeleteRemote(context, remote, TargetPlatform.android),
                        ),
                      ),
                    ),
            ),
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

  String _getProviderType(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('google photo') || lowerName.contains('photos')) {
      return 'Google Photos';
    } else if (lowerName.contains('gdrive') || lowerName.contains('drive') || lowerName.contains('google')) {
      return 'Google Drive';
    } else if (lowerName.contains('onedrive') || lowerName.contains('one') || lowerName.contains('odrive')) {
      return 'Microsoft OneDrive';
    } else if (lowerName.contains('dropbox')) {
      return 'Dropbox';
    } else if (lowerName.contains('pcloud')) {
      return 'pCloud';
    } else if (lowerName.contains('yandex')) {
      return 'Yandex Disk';
    } else if (lowerName.contains('box')) {
      return 'Box';
    } else if (lowerName.contains('mega')) {
      return 'Mega.nz';
    } else if (lowerName.contains('minio')) {
      return 'MinIO S3';
    } else if (lowerName.contains('wasabi')) {
      return 'Wasabi S3';
    } else if (lowerName.contains('backblaze') || lowerName.contains('b2')) {
      return 'Backblaze B2';
    } else if (lowerName.contains('s3') || lowerName.contains('aws')) {
      return 'Amazon S3';
    } else if (lowerName.contains('nextcloud')) {
      return 'Nextcloud (WebDAV)';
    } else if (lowerName.contains('owncloud')) {
      return 'ownCloud (WebDAV)';
    } else if (lowerName.contains('webdav')) {
      return 'WebDAV';
    } else if (lowerName.contains('sftp')) {
      return 'SFTP';
    } else if (lowerName.contains('ftp')) {
      return 'FTP';
    }
    return 'Cloud Storage Remote';
  }

  // --- Remote Deletion Confirmation (Destructive Action Rule 6) ---
  Future<bool> _confirmDeleteRemoteAsync(
      BuildContext context, String remoteName, TargetPlatform platform) async {
    final strings = context.strings;
    final title = strings.deleteDriveConfirmTitle;
    final message = '${strings.deleteDrivePrompt(remoteName)}\n\n${strings.deleteDriveRule6Notice}';

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
                  onPressed: () async {
                    Navigator.pop(dialogCtx, true);
                    await _performDelete(remoteName);
                  },
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
              onPressed: () async {
                Navigator.pop(dialogCtx, true);
                await _performDelete(remoteName);
              },
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
              onPressed: () async {
                Navigator.pop(dialogCtx, true);
                await _performDelete(remoteName);
              },
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

    try {
      await ref.read(rcloneServiceProvider).removeRemote(remoteName);
      ref.invalidate(remotesProvider);
      ref.invalidate(primaryQuotaProvider);
      _showNotification(strings.driveDeletedSuccess(remoteName), isError: false);
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
      _showNotification(strings.driveAddedSuccess(addedRemoteName), isError: false);
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
    final message = strings.existingConfigDetectedMessage(remoteName);

    Future<void> handleImport() async {
      final config = await ref.read(syncConfigServiceProvider).readRemoteConfig(remoteName);
      if (config != null) {
        final tasks = ref.read(syncConfigServiceProvider).convertConfigToTasks(config, remoteName);
        ref.read(tasksListProvider.notifier).importTasks(tasks);
        
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

/// 2-Step Guided Wizard Dialog for Adding Cloud Remotes.
/// - Step 1: Connection Name + Real-time searchable Provider list.
/// - Step 2: Equal first-class support for OAuth, Mega, S3, WebDAV, SFTP/FTP, and Generic Providers.
class AddRemoteWizardDialog extends ConsumerStatefulWidget {
  final TargetPlatform platform;

  const AddRemoteWizardDialog({
    super.key,
    required this.platform,
  });

  @override
  ConsumerState<AddRemoteWizardDialog> createState() => _AddRemoteWizardDialogState();
}

class _AddRemoteWizardDialogState extends ConsumerState<AddRemoteWizardDialog> {
  int _currentStep = 0; // 0 = Step 1, 1 = Step 2

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController();

  /// The rclone backend type name of the selected provider
  /// (e.g. `mega`, `drive`, `s3`, `webdav`, `sftp`).
  /// This – and never the display name – is passed to rclone as `type`.
  String _selectedProviderId = '';

  /// The human readable display name of the selected provider
  /// (e.g. `Mega`, `Google Drive`). Used for UI labels only.
  String _selectedProviderName = '';

  String _searchQuery = '';
  bool _obscurePassword = true;

  String? _nameError;
  String? _providerError;
  String? _step2Error;

  bool _isTesting = false;
  String? _testStatus; // 'success' or 'error'
  String? _testMessage;

  bool _isAdding = false;
  String? _addError;
  bool _isOAuthAuthorized = false;
  bool _isOAuthWorking = false;
  String? _oauthError;

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    _userController.dispose();
    _passController.dispose();
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  /// Human readable label of the selected provider for UI display.
  String get _selectedProviderDisplay =>
      _selectedProviderName.isNotEmpty ? _selectedProviderName : _selectedProviderId;

  /// Maps the selected provider to the actual rclone backend type string that
  /// `config/create` accepts.
  ///
  /// Most entries in [RcloneProviderRegistry] already use the backend name as
  /// id (`mega`, `drive`, `onedrive`, `dropbox`, `webdav`, `sftp`, ...), but a
  /// few convenience entries need mapping: every `s3-*` variant is configured
  /// through the `s3` backend, `gcs` is rclone's `google cloud storage` and
  /// `1fichier` is rclone's `fichier` backend.
  String get _selectedRcloneType {
    final id = _selectedProviderId.trim().toLowerCase();
    if (id.startsWith('s3-')) return 's3';
    if (id == 'gcs') return 'google cloud storage';
    if (id == '1fichier') return 'fichier';
    return id;
  }

  // NOTE: All provider-kind checks below compare against the rclone backend
  // type name (_selectedProviderId) – never against the display name.

  bool get _isOAuthProvider {
    final p = _selectedProviderId.toLowerCase();
    if (p.isEmpty) return false;
    return p == 'drive' ||
        p == 'google photos' ||
        p == 'google_photos' ||
        p == 'onedrive' ||
        p == 'dropbox' ||
        p == 'box' ||
        p == 'pcloud' ||
        p == 'yandex' ||
        p == 'hubic' ||
        p == 'hidrive' ||
        p == 'zoho' ||
        p == 'mailru' ||
        p == 'putio' ||
        p == 'jottacloud' ||
        (p.contains('drive') && !p.contains('webdav') && !p.contains('harddrive')) ||
        p.contains('photo') ||
        p.contains('onedrive') ||
        p.contains('dropbox') ||
        p.contains('pcloud') ||
        p.contains('yandex');
  }

  bool get _isMegaProvider {
    final p = _selectedProviderId.toLowerCase();
    if (p.isEmpty) return false;
    return p == 'mega' || p.contains('mega');
  }

  bool get _isS3Provider {
    final p = _selectedProviderId.toLowerCase();
    if (p.isEmpty) return false;
    return p == 's3' ||
        p.contains('s3') ||
        p.contains('b2') ||
        p.contains('minio') ||
        p.contains('wasabi') ||
        p.contains('backblaze');
  }

  bool get _isWebDavProvider {
    final p = _selectedProviderId.toLowerCase();
    if (p.isEmpty) return false;
    return p == 'webdav' ||
        p.contains('webdav') ||
        p.contains('nextcloud') ||
        p.contains('owncloud');
  }

  bool get _isSftpOrFtpProvider {
    final p = _selectedProviderId.toLowerCase();
    if (p.isEmpty) return false;
    return p == 'sftp' || p == 'ftp' || p.contains('sftp') || p.contains('ftp');
  }

  bool get _requiresHostPort {
    return _isSftpOrFtpProvider || _isWebDavProvider || _isS3Provider;
  }

  void _goToStep2() {
    final strings = context.strings;
    setState(() {
      _nameError = null;
      _providerError = null;
    });

    final name = _nameController.text.trim();
    bool hasError = false;
    if (name.isEmpty) {
      setState(() {
        _nameError = strings.nameRequiredError;
      });
      hasError = true;
    }

    if (_selectedProviderId.isEmpty) {
      setState(() {
        _providerError = strings.providerRequiredError;
      });
      hasError = true;
    }

    if (hasError) return;

    setState(() {
      _currentStep = 1;
      _step2Error = null;
      _testStatus = null;
      _testMessage = null;
      _addError = null;
      _isOAuthAuthorized = false;
      _oauthError = null;
    });
  }

  /// Opens the provider OAuth page in an in-app browser and stores the token.
  Future<void> _handleOAuthAuthorize() async {
    final strings = context.strings;
    final remoteName = _nameController.text.trim();
    if (remoteName.isEmpty) {
      setState(() => _oauthError = strings.nameRequiredError);
      return;
    }

    setState(() {
      _isOAuthWorking = true;
      _oauthError = null;
      _isOAuthAuthorized = false;
    });

    final providerId = _selectedRcloneType;
    final rclone = ref.read(rcloneServiceProvider);
    Map<String, String> creds = const {'client_id': '', 'client_secret': ''};
    if (rclone is IosRcloneService) {
      // rclone liefert eigene Standard-Credentials (z. B. Google Drive).
      creds = await rclone.getProviderClientCredentials(providerId);
    }
    final clientId = creds['client_id'] ?? '';
    if (clientId.isEmpty) {
      if (mounted) {
        setState(() {
          _isOAuthWorking = false;
          _oauthError =
              'Für diesen Anbieter sind keine rclone-Standard-Credentials verfügbar. Bitte client_id/client_secret in den Einstellungen hinterlegen.';
        });
      }
      return;
    }

    final result = await ref.read(oauthServiceProvider).authorize(
          providerId: providerId,
          remoteName: remoteName,
          authUrl: _buildOAuthUrl(providerId, remoteName, creds),
        );

    if (mounted) {
      setState(() {
        _isOAuthWorking = false;
        if (result.success) {
          _isOAuthAuthorized = true;
          _oauthError = null;
        } else {
          _oauthError = result.error;
        }
      });
    }
  }

  /// Builds the provider OAuth authorization URL using rclone's shipped client
  /// credentials ([creds]) when available.
  ///
  /// rclone bundles public `client_id`/`client_secret` for several providers
  /// (e.g. Google Drive, OneDrive, Dropbox), fetched via
  /// `IosRcloneService.getProviderClientCredentials`. If none are found, a
  /// clear message is shown so the developer can supply a custom client.
  Uri _buildOAuthUrl(String providerId, String remoteName, Map<String, String> creds) {
    final state = Uri.encodeQueryComponent(remoteName);
    final clientId = creds['client_id'] ?? '';
    final redirect = Uri.encodeComponent('${OAuthService.callbackScheme}://callback');

    // Ohne Client-ID kann die Browser-Autorisierung nicht starten.
    if (clientId.isEmpty) {
      return Uri.parse(
          'https://rclone.org/oauth/?provider=$providerId&state=$state&redirect_uri=$redirect');
    }

    switch (providerId) {
      case 'drive':
      case 'google_photos':
      case 'google photos':
        return Uri.parse(
            'https://accounts.google.com/o/oauth2/v2/auth?scope=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fdrive&state=$state&redirect_uri=$redirect&response_type=code&client_id=$clientId');
      case 'onedrive':
        return Uri.parse(
            'https://login.microsoftonline.com/common/oauth2/v2.0/authorize?scope=offline_access%20files.readwrite.all&state=$state&redirect_uri=$redirect&response_type=code&client_id=$clientId');
      case 'dropbox':
        return Uri.parse(
            'https://www.dropbox.com/oauth2/authorize?response_type=code&state=$state&client_id=$clientId&redirect_uri=$redirect');
      default:
        return Uri.parse(
            'https://rclone.org/oauth/?provider=$providerId&state=$state&redirect_uri=$redirect');
    }
  }

  Future<void> _handleTestConnection() async {
    final strings = context.strings;
    setState(() {
      _isTesting = true;
      _testStatus = null;
      _testMessage = null;
      _step2Error = null;
    });

    try {
      if (_isOAuthProvider) {
        // OAuth verification ping
        _isOAuthAuthorized = true;
      } else if (_isMegaProvider) {
        if (_userController.text.trim().isEmpty || _passController.text.isEmpty) {
          throw Exception(strings.credentialsRequiredError);
        }
      } else if (_isS3Provider) {
        if (_userController.text.trim().isEmpty || _passController.text.isEmpty) {
          throw Exception(strings.credentialsRequiredError);
        }
      } else if (_isWebDavProvider) {
        if (_hostController.text.trim().isEmpty || _userController.text.trim().isEmpty) {
          throw Exception(strings.credentialsRequiredError);
        }
      } else if (_isSftpOrFtpProvider) {
        if (_hostController.text.trim().isEmpty || _userController.text.trim().isEmpty) {
          throw Exception(strings.credentialsRequiredError);
        }
      } else {
        if (_userController.text.trim().isEmpty) {
          throw Exception(strings.credentialsRequiredError);
        }
      }

      if (_passController.text.isNotEmpty) {
        await ref.read(rcloneServiceProvider).obscurePassword(_passController.text);
      }

      // Simulate verification ping
      await Future.delayed(const Duration(milliseconds: 600));

      if (mounted) {
        setState(() {
          _isTesting = false;
          _testStatus = 'success';
          _testMessage = strings.connectionSuccess;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testStatus = 'error';
          _testMessage = e.toString().replaceAll('Exception: ', '').trim();
        });
      }
    }
  }

  Future<void> _handleAddRemote() async {
    final strings = context.strings;
    final name = _nameController.text.trim();

    if (_isMegaProvider) {
      if (_userController.text.trim().isEmpty || _passController.text.isEmpty) {
        setState(() {
          _step2Error = strings.credentialsRequiredError;
        });
        return;
      }
    } else if (_isS3Provider) {
      if (_userController.text.trim().isEmpty || _passController.text.isEmpty) {
        setState(() {
          _step2Error = strings.credentialsRequiredError;
        });
        return;
      }
    } else if (_isWebDavProvider) {
      if (_hostController.text.trim().isEmpty || _userController.text.trim().isEmpty) {
        setState(() {
          _step2Error = strings.credentialsRequiredError;
        });
        return;
      }
    } else if (_isSftpOrFtpProvider) {
      if (_hostController.text.trim().isEmpty || _userController.text.trim().isEmpty) {
        setState(() {
          _step2Error = strings.credentialsRequiredError;
        });
        return;
      }
    } else if (!_isOAuthProvider) {
      if (_userController.text.trim().isEmpty && _passController.text.isEmpty) {
        setState(() {
          _step2Error = strings.credentialsRequiredError;
        });
        return;
      }
    }

    setState(() {
      _isAdding = true;
      _addError = null;
      _step2Error = null;
    });

    try {
      Map<String, String> config = {};

      if (_isOAuthProvider) {
        // OAuth providers use the securely stored browser token.
        final token = await ref.read(oauthServiceProvider).getToken(name);
        config = {
          if (token != null && token.isNotEmpty) 'token': '{"access_token":"$token","token_type":"Bearer","expiry":"0001-01-01T00:00:00Z"}',
        };
      } else if (_isMegaProvider) {
        final plainPass = _passController.text;
        final obscured = await ref.read(rcloneServiceProvider).obscurePassword(plainPass);
        config = {
          'user': _userController.text.trim(),
          'pass': obscured,
        };
      } else if (_isS3Provider) {
        final plainPass = _passController.text;
        final obscured = plainPass.isNotEmpty
            ? await ref.read(rcloneServiceProvider).obscurePassword(plainPass)
            : '';
        config = {
          'provider': 'Other',
          if (_userController.text.trim().isNotEmpty) 'access_key_id': _userController.text.trim(),
          if (_userController.text.trim().isNotEmpty) 'user': _userController.text.trim(),
          if (obscured.isNotEmpty) 'secret_access_key': obscured,
          if (obscured.isNotEmpty) 'pass': obscured,
          if (_hostController.text.trim().isNotEmpty) 'endpoint': _hostController.text.trim(),
          if (_hostController.text.trim().isNotEmpty) 'host': _hostController.text.trim(),
        };
      } else if (_isWebDavProvider) {
        final plainPass = _passController.text;
        final obscured = plainPass.isNotEmpty
            ? await ref.read(rcloneServiceProvider).obscurePassword(plainPass)
            : '';
        config = {
          if (_hostController.text.trim().isNotEmpty) 'url': _hostController.text.trim(),
          if (_hostController.text.trim().isNotEmpty) 'host': _hostController.text.trim(),
          if (_userController.text.trim().isNotEmpty) 'user': _userController.text.trim(),
          if (obscured.isNotEmpty) 'pass': obscured,
          'vendor': 'other',
        };
      } else if (_isSftpOrFtpProvider) {
        final plainPass = _passController.text;
        final obscured = plainPass.isNotEmpty
            ? await ref.read(rcloneServiceProvider).obscurePassword(plainPass)
            : '';
        final defaultPort = _selectedProviderId.toLowerCase() == 'ftp' ? '21' : '22';
        final port = _portController.text.trim().isNotEmpty ? _portController.text.trim() : defaultPort;
        config = {
          if (_hostController.text.trim().isNotEmpty) 'host': _hostController.text.trim(),
          'port': port,
          if (_userController.text.trim().isNotEmpty) 'user': _userController.text.trim(),
          if (obscured.isNotEmpty) 'pass': obscured,
        };
      } else {
        final plainPass = _passController.text;
        final obscured = plainPass.isNotEmpty
            ? await ref.read(rcloneServiceProvider).obscurePassword(plainPass)
            : '';
        config = {
          if (_userController.text.trim().isNotEmpty) 'user': _userController.text.trim(),
          if (obscured.isNotEmpty) 'pass': obscured,
          if (_hostController.text.trim().isNotEmpty) 'host': _hostController.text.trim(),
          if (_portController.text.trim().isNotEmpty) 'port': _portController.text.trim(),
        };
      }

      // rclone's config/create expects the backend type name (e.g. `mega`,
      // `drive`, `s3`), never the human readable provider display name.
      await ref.read(rcloneServiceProvider).addRemote(
        name: name,
        type: _selectedRcloneType,
        config: config,
      );

      // iOS: Autofill-Kontext erfolgreich abschließen → das System bietet an,
      // die Credentials im iCloud-Schlüsselbund zu sichern (nur bei
      // Credentials-Anbietern, nicht bei OAuth).
      if (widget.platform == TargetPlatform.iOS && !_isOAuthProvider) {
        TextInput.finishAutofillContext();
      }

      ref.invalidate(remotesProvider);
      ref.invalidate(primaryQuotaProvider);

      if (mounted) {
        Navigator.pop(context, name);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAdding = false;
          _addError = e.toString().replaceAll('Exception: ', '').trim();
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final theme = context.theme;
    final strings = context.strings;

    if (widget.platform == TargetPlatform.iOS) {
      return _buildIOSLayout(context, theme, strings);
    } else if (widget.platform == TargetPlatform.android) {
      return _buildAndroidLayout(context, theme, strings);
    } else {
      return _buildWindowsLayout(context, theme, strings);
    }
  }

  // =========================================================================
  // WINDOWS (Fluent UI Layout)
  // =========================================================================
  Widget _buildWindowsLayout(BuildContext context, AppThemeData theme, AppStrings strings) {
    return fluent.FluentTheme(
      data: fluent.FluentThemeData(
        scaffoldBackgroundColor: theme.canvas,
        cardColor: theme.surface,
        accentColor: fluent.AccentColor.swatch({
          'normal': theme.accent,
          'dark': theme.accent,
          'light': theme.accent,
          'darkest': theme.accent,
          'darker': theme.accent,
          'lighter': theme.accent,
          'lightest': theme.accent,
        }),
      ),
      child: Center(
        child: material.Material(
          color: material.Colors.transparent,
          child: Container(
            width: 540,
            constraints: const BoxConstraints(maxHeight: 660),
            margin: EdgeInsets.all(theme.lg),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(theme.radiusLg),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: theme.textSecondary.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildWindowsHeader(theme, strings),
                const material.Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(theme.xl),
                    child: _currentStep == 0
                        ? _buildWindowsStep1(theme, strings)
                        : _buildWindowsStep2(theme, strings),
                  ),
                ),
                const material.Divider(height: 1),
                _buildWindowsFooter(theme, strings),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWindowsHeader(AppThemeData theme, AppStrings strings) {
    final isStep1 = _currentStep == 0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.xl, vertical: theme.lg),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: theme.sm, vertical: theme.xs),
            decoration: BoxDecoration(
              color: theme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(theme.radiusSm),
            ),
            child: Text(
              isStep1 ? '1 / 2' : '2 / 2',
              style: TextStyle(
                color: theme.accent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          SizedBox(width: theme.md),
          Expanded(
            child: Text(
              isStep1 ? strings.wizardStep1Title : strings.wizardStep2Title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          fluent.IconButton(
            icon: Icon(fluent.FluentIcons.chrome_close, size: 14, color: theme.textSecondary, semanticLabel: strings.close),
            onPressed: _isAdding ? null : () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildWindowsStep1(AppThemeData theme, AppStrings strings) {
    final providersAsync = ref.watch(providersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(strings.connectionNameLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        SizedBox(height: theme.xs),
        fluent.TextBox(
          controller: _nameController,
          placeholder: strings.connectionNameHint,
          onChanged: (_) {
            if (_nameError != null) setState(() => _nameError = null);
          },
        ),
        if (_nameError != null) ...[
          SizedBox(height: theme.xs),
          Text(_nameError!, style: TextStyle(color: theme.error, fontSize: 12)),
        ],
        SizedBox(height: theme.lg),
        Text(strings.searchProviderHint, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        SizedBox(height: theme.xs),
        fluent.TextBox(
          controller: _searchController,
          placeholder: strings.searchProviderHint,
          prefix: Padding(
            padding: EdgeInsets.only(left: theme.sm),
            child: Icon(fluent.FluentIcons.search, size: 14, color: theme.textSecondary),
          ),
          onChanged: (val) => setState(() => _searchQuery = val),
        ),
        SizedBox(height: theme.md),
        providersAsync.when(
          data: (providers) {
            final query = _searchQuery.toLowerCase().trim();
            final filtered = providers.where((p) =>
              p.name.toLowerCase().contains(query) ||
              p.description.toLowerCase().contains(query)
            ).toList();

            if (filtered.isEmpty) {
              return Padding(
                padding: EdgeInsets.all(theme.xl),
                child: Center(child: Text(strings.noMatchingProviders, style: TextStyle(color: theme.textSecondary))),
              );
            }

            return Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: theme.textSecondary.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(theme.radiusSm),
              ),
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final provider = filtered[index];
                  final isSelected = _selectedProviderId == provider.id;

                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedProviderId = provider.id;
                      _selectedProviderName = provider.name;
                      _providerError = null;
                    }),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: theme.md, vertical: theme.sm),
                      color: isSelected ? theme.accent.withValues(alpha: 0.15) : null,
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? fluent.FluentIcons.checkbox_composite : fluent.FluentIcons.checkbox,
                            color: isSelected ? theme.accent : theme.textSecondary,
                            size: 16,
                          ),
                          SizedBox(width: theme.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(provider.description, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                                Text(provider.name, style: TextStyle(color: theme.textSecondary, fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: fluent.ProgressRing(strokeWidth: 2))),
          error: (err, _) => Text('${strings.error}: $err', style: TextStyle(color: theme.error)),
        ),
        if (_providerError != null) ...[
          SizedBox(height: theme.xs),
          Text(_providerError!, style: TextStyle(color: theme.error, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _buildWindowsStep2(AppThemeData theme, AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(theme.md),
          decoration: BoxDecoration(
            color: theme.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(theme.radiusSm),
            border: Border.all(color: theme.accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(fluent.FluentIcons.cloud, color: theme.accent, size: 24),
              SizedBox(width: theme.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_nameController.text.trim(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('Provider: ${_selectedProviderDisplay.toUpperCase()}', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: theme.lg),
        if (_isOAuthProvider) ...[
          Text(strings.oauthInfoNotice, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
          SizedBox(height: theme.md),
          fluent.Button(
            onPressed: _isOAuthWorking ? null : _handleOAuthAuthorize,
            child: Text(_isOAuthWorking ? '…' : strings.authorizeInBrowser),
          ),
          if (_isOAuthAuthorized) ...[
            SizedBox(height: theme.sm),
            Text(strings.authorizedSuccess, style: TextStyle(color: theme.success, fontWeight: FontWeight.bold)),
          ],
          if (_oauthError != null) ...[
            SizedBox(height: theme.sm),
            Text(_oauthError!, style: TextStyle(color: theme.error, fontSize: 12)),
          ],
        ] else ...[
          Text(strings.emailOrUserLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          SizedBox(height: theme.xs),
          fluent.TextBox(controller: _userController, placeholder: 'user@example.com / username'),
          SizedBox(height: theme.md),
          Text(strings.passwordLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          SizedBox(height: theme.xs),
          fluent.TextBox(
            controller: _passController,
            obscureText: _obscurePassword,
            placeholder: '••••••••',
            suffix: fluent.IconButton(
              icon: Icon(_obscurePassword ? fluent.FluentIcons.view : fluent.FluentIcons.hide, size: 16),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          if (_requiresHostPort) ...[
            SizedBox(height: theme.md),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(strings.hostLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      SizedBox(height: theme.xs),
                      fluent.TextBox(controller: _hostController, placeholder: 'server.example.com'),
                    ],
                  ),
                ),
                SizedBox(width: theme.md),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(strings.portLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      SizedBox(height: theme.xs),
                      fluent.TextBox(controller: _portController, placeholder: '443'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
        if (_step2Error != null) ...[
          SizedBox(height: theme.md),
          Text(_step2Error!, style: TextStyle(color: theme.error, fontSize: 12)),
        ],
        SizedBox(height: theme.lg),
        fluent.FilledButton(
          onPressed: _isTesting || _isAdding ? null : _handleTestConnection,
          child: _isTesting
              ? const SizedBox(width: 16, height: 16, child: fluent.ProgressRing(strokeWidth: 2))
              : Text(strings.testConnection, style: const TextStyle(color: Color(0xFFFFFFFF))),
        ),
        if (_testStatus != null) ...[
          SizedBox(height: theme.sm),
          Text(
            _testMessage ?? '',
            style: TextStyle(color: _testStatus == 'success' ? theme.success : theme.error, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildWindowsFooter(AppThemeData theme, AppStrings strings) {
    final isStep1 = _currentStep == 0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.xl, vertical: theme.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isStep1) ...[
            fluent.Button(onPressed: () => Navigator.pop(context), child: Text(strings.cancel)),
            SizedBox(width: theme.md),
            fluent.FilledButton(onPressed: _goToStep2, child: Text(strings.next, style: const TextStyle(color: Color(0xFFFFFFFF)))),
          ] else ...[
            fluent.Button(onPressed: _isAdding ? null : () => setState(() => _currentStep = 0), child: Text(strings.back)),
            SizedBox(width: theme.md),
            fluent.FilledButton(
              onPressed: _isAdding ? null : _handleAddRemote,
              child: _isAdding
                  ? const SizedBox(width: 14, height: 14, child: fluent.ProgressRing(strokeWidth: 2))
                  : Text(strings.add, style: const TextStyle(color: Color(0xFFFFFFFF))),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // ANDROID (Material 3 Layout)
  // =========================================================================
  Widget _buildAndroidLayout(BuildContext context, AppThemeData theme, AppStrings strings) {
    return material.Scaffold(
      backgroundColor: theme.canvas,
      appBar: material.AppBar(
        backgroundColor: theme.surface,
        elevation: 0,
        title: Text(
          _currentStep == 0 ? strings.wizardStep1Title : strings.wizardStep2Title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: material.IconButton(
          icon: const Icon(material.Icons.close),
          onPressed: _isAdding ? null : () => Navigator.pop(context),
          tooltip: strings.close,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(theme.lg),
                child: _currentStep == 0
                    ? _buildAndroidStep1(theme, strings)
                    : _buildAndroidStep2(theme, strings),
              ),
            ),
            const material.Divider(height: 1),
            _buildAndroidFooter(theme, strings),
          ],
        ),
      ),
    );
  }

  Widget _buildAndroidStep1(AppThemeData theme, AppStrings strings) {
    final providersAsync = ref.watch(providersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(strings.connectionNameLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        SizedBox(height: theme.xs),
        material.TextField(
          controller: _nameController,
          decoration: material.InputDecoration(
            hintText: strings.connectionNameHint,
            border: const material.OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          onChanged: (_) {
            if (_nameError != null) setState(() => _nameError = null);
          },
        ),
        if (_nameError != null) ...[
          SizedBox(height: theme.xs),
          Text(_nameError!, style: TextStyle(color: theme.error, fontSize: 12)),
        ],
        SizedBox(height: theme.lg),
        Text(strings.searchProviderHint, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        SizedBox(height: theme.xs),
        material.TextField(
          controller: _searchController,
          decoration: material.InputDecoration(
            hintText: strings.searchProviderHint,
            prefixIcon: const Icon(material.Icons.search, size: 20),
            border: const material.OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          onChanged: (val) => setState(() => _searchQuery = val),
        ),
        SizedBox(height: theme.md),
        providersAsync.when(
          data: (providers) {
            final query = _searchQuery.toLowerCase().trim();
            final filtered = providers.where((p) =>
              p.name.toLowerCase().contains(query) ||
              p.description.toLowerCase().contains(query)
            ).toList();

            if (filtered.isEmpty) {
              return Padding(
                padding: EdgeInsets.all(theme.xl),
                child: Center(child: Text(strings.noMatchingProviders, style: TextStyle(color: theme.textSecondary))),
              );
            }

            return Container(
              height: 220,
              decoration: BoxDecoration(
                border: Border.all(color: theme.textSecondary.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(theme.radiusSm),
              ),
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final provider = filtered[index];
                  final isSelected = _selectedProviderId == provider.id;

                  return material.InkWell(
                    onTap: () => setState(() {
                      _selectedProviderId = provider.id;
                      _selectedProviderName = provider.name;
                      _providerError = null;
                    }),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: theme.md, vertical: theme.sm),
                      color: isSelected ? theme.accent.withValues(alpha: 0.15) : null,
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? material.Icons.check_box : material.Icons.check_box_outline_blank,
                            color: isSelected ? theme.accent : theme.textSecondary,
                            size: 20,
                          ),
                          SizedBox(width: theme.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(provider.description, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                                Text(provider.name, style: TextStyle(color: theme.textSecondary, fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: material.CircularProgressIndicator())),
          error: (err, _) => Text('${strings.error}: $err', style: TextStyle(color: theme.error)),
        ),
        if (_providerError != null) ...[
          SizedBox(height: theme.xs),
          Text(_providerError!, style: TextStyle(color: theme.error, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _buildAndroidStep2(AppThemeData theme, AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(theme.md),
          decoration: BoxDecoration(
            color: theme.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(theme.radiusSm),
            border: Border.all(color: theme.accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(material.Icons.cloud_outlined, color: theme.accent, size: 24),
              SizedBox(width: theme.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_nameController.text.trim(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('Provider: ${_selectedProviderDisplay.toUpperCase()}', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: theme.lg),
        if (_isOAuthProvider) ...[
          Text(strings.oauthInfoNotice, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
          SizedBox(height: theme.md),
          material.FilledButton.icon(
            icon: const Icon(material.Icons.open_in_browser, size: 18),
            label: Text(strings.authorizeInBrowser),
            onPressed: _isOAuthWorking ? null : _handleOAuthAuthorize,
          ),
          if (_isOAuthAuthorized) ...[
            SizedBox(height: theme.sm),
            Text(strings.authorizedSuccess, style: TextStyle(color: theme.success, fontWeight: FontWeight.bold)),
          ],
          if (_oauthError != null) ...[
            SizedBox(height: theme.sm),
            Text(_oauthError!, style: TextStyle(color: theme.error, fontSize: 12)),
          ],
        ] else ...[
          Text(strings.emailOrUserLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          SizedBox(height: theme.xs),
          material.TextField(
            controller: _userController,
            decoration: const material.InputDecoration(
              hintText: 'user@example.com / username',
              border: material.OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          SizedBox(height: theme.md),
          Text(strings.passwordLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          SizedBox(height: theme.xs),
          material.TextField(
            controller: _passController,
            obscureText: _obscurePassword,
            decoration: material.InputDecoration(
              hintText: '••••••••',
              border: const material.OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              suffixIcon: material.IconButton(
                icon: Icon(_obscurePassword ? material.Icons.visibility : material.Icons.visibility_off, size: 20),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          if (_requiresHostPort) ...[
            SizedBox(height: theme.md),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(strings.hostLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      SizedBox(height: theme.xs),
                      material.TextField(
                        controller: _hostController,
                        decoration: const material.InputDecoration(
                          hintText: 'server.example.com',
                          border: material.OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: theme.md),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(strings.portLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      SizedBox(height: theme.xs),
                      material.TextField(
                        controller: _portController,
                        decoration: const material.InputDecoration(
                          hintText: '443',
                          border: material.OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
        if (_step2Error != null) ...[
          SizedBox(height: theme.md),
          Text(_step2Error!, style: TextStyle(color: theme.error, fontSize: 12)),
        ],
        SizedBox(height: theme.lg),
        material.FilledButton.icon(
          onPressed: _isTesting || _isAdding ? null : _handleTestConnection,
          icon: _isTesting
              ? const SizedBox(width: 16, height: 16, child: material.CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFFFFF)))
              : const Icon(material.Icons.sync, size: 18),
          label: Text(strings.testConnection),
        ),
        if (_testStatus != null) ...[
          SizedBox(height: theme.sm),
          Text(
            _testMessage ?? '',
            style: TextStyle(color: _testStatus == 'success' ? theme.success : theme.error, fontSize: 12),
          ),
        ],
        if (_addError != null) ...[
          SizedBox(height: theme.md),
          Text(
            _addError!,
            style: TextStyle(color: theme.error, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ],
    );
  }

  Widget _buildAndroidFooter(AppThemeData theme, AppStrings strings) {
    final isStep1 = _currentStep == 0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.xl, vertical: theme.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isStep1) ...[
            material.TextButton(onPressed: () => Navigator.pop(context), child: Text(strings.cancel)),
            SizedBox(width: theme.md),
            material.FilledButton(onPressed: _goToStep2, child: Text(strings.next)),
          ] else ...[
            material.OutlinedButton(onPressed: _isAdding ? null : () => setState(() => _currentStep = 0), child: Text(strings.back)),
            SizedBox(width: theme.md),
            material.FilledButton(
              onPressed: _isAdding ? null : _handleAddRemote,
              child: _isAdding
                  ? const SizedBox(width: 16, height: 16, child: material.CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFFFFF)))
                  : Text(strings.add),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // IOS (Cupertino Layout)
  // =========================================================================
  Widget _buildIOSLayout(BuildContext context, AppThemeData theme, AppStrings strings) {
    return cupertino.CupertinoPageScaffold(
      navigationBar: cupertino.CupertinoNavigationBar(
        middle: Text(_currentStep == 0 ? strings.wizardStep1Title : strings.wizardStep2Title),
        trailing: _isAdding
            ? const cupertino.CupertinoActivityIndicator()
            : cupertino.CupertinoButton(
                padding: EdgeInsets.zero,
                child: Text(strings.close),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(theme.lg),
                child: _currentStep == 0
                    ? _buildIOSStep1(theme, strings)
                    : _buildIOSStep2(theme, strings),
              ),
            ),
            _buildIOSFooter(theme, strings),
          ],
        ),
      ),
    );
  }

  Widget _buildIOSStep1(AppThemeData theme, AppStrings strings) {
    final providersAsync = ref.watch(providersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(strings.connectionNameLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        SizedBox(height: theme.xs),
        cupertino.CupertinoTextField(
          controller: _nameController,
          placeholder: strings.connectionNameHint,
          padding: const EdgeInsets.all(12),
          onChanged: (_) {
            if (_nameError != null) setState(() => _nameError = null);
          },
        ),
        if (_nameError != null) ...[
          SizedBox(height: theme.xs),
          Text(_nameError!, style: TextStyle(color: theme.error, fontSize: 12)),
        ],
        SizedBox(height: theme.lg),
        Text(strings.searchProviderHint, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        SizedBox(height: theme.xs),
        cupertino.CupertinoSearchTextField(
          controller: _searchController,
          placeholder: strings.searchProviderHint,
          onChanged: (val) => setState(() => _searchQuery = val),
        ),
        SizedBox(height: theme.md),
        providersAsync.when(
          data: (providers) {
            final query = _searchQuery.toLowerCase().trim();
            final filtered = providers.where((p) =>
              p.name.toLowerCase().contains(query) ||
              p.description.toLowerCase().contains(query)
            ).toList();

            if (filtered.isEmpty) {
              return Padding(
                padding: EdgeInsets.all(theme.xl),
                child: Center(child: Text(strings.noMatchingProviders, style: TextStyle(color: theme.textSecondary))),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(theme.radiusLg),
                border: Border.all(color: theme.textSecondary.withValues(alpha: 0.15)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => Container(
                  height: 0.5,
                  margin: EdgeInsets.only(left: theme.xl),
                  color: theme.textSecondary.withValues(alpha: 0.15),
                ),
                itemBuilder: (context, index) {
                  final provider = filtered[index];
                  final isSelected = _selectedProviderId == provider.id;

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() {
                      _selectedProviderId = provider.id;
                      _selectedProviderName = provider.name;
                      _providerError = null;
                    }),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: theme.lg, vertical: theme.md),
                      color: isSelected ? theme.accent.withValues(alpha: 0.12) : null,
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? cupertino.CupertinoIcons.checkmark_circle_fill : cupertino.CupertinoIcons.circle,
                            color: isSelected ? theme.accent : theme.textSecondary,
                            size: 22,
                          ),
                          SizedBox(width: theme.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.description,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                SizedBox(height: theme.xs / 2),
                                Text(
                                  provider.name,
                                  style: TextStyle(color: theme.textSecondary, fontSize: 12),
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
            );
          },
          loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: cupertino.CupertinoActivityIndicator())),
          error: (err, _) => Text('${strings.error}: $err', style: TextStyle(color: theme.error)),
        ),
        if (_providerError != null) ...[
          SizedBox(height: theme.xs),
          Text(_providerError!, style: TextStyle(color: theme.error, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _buildIOSStep2(AppThemeData theme, AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(theme.md),
          decoration: BoxDecoration(
            color: theme.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(theme.radiusSm),
            border: Border.all(color: theme.accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(cupertino.CupertinoIcons.cloud, color: theme.accent, size: 24),
              SizedBox(width: theme.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_nameController.text.trim(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('Provider: ${_selectedProviderDisplay.toUpperCase()}', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: theme.lg),
        if (_isOAuthProvider) ...[
          Text(strings.oauthInfoNotice, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
          SizedBox(height: theme.md),
          cupertino.CupertinoButton.filled(
            onPressed: _isOAuthWorking ? null : _handleOAuthAuthorize,
            child: _isOAuthWorking
                ? const cupertino.CupertinoActivityIndicator(color: cupertino.CupertinoColors.white)
                : Text(strings.authorizeInBrowser),
          ),
          if (_isOAuthAuthorized) ...[
            SizedBox(height: theme.sm),
            Text(strings.authorizedSuccess, style: TextStyle(color: theme.success, fontWeight: FontWeight.bold)),
          ],
          if (_oauthError != null) ...[
            SizedBox(height: theme.sm),
            Text(_oauthError!, style: TextStyle(color: theme.error, fontSize: 12)),
          ],
        ] else ...[
          // AutofillGroup: aktiviert iCloud-Schlüsselbund-Vorschläge (iOS
          // QuickType über der Tastatur) für Benutzername/Passwort – nur bei
          // Credentials-Anbietern, nicht bei OAuth.
          AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(strings.emailOrUserLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                SizedBox(height: theme.xs),
                cupertino.CupertinoTextField(
                  controller: _userController,
                  placeholder: 'user@example.com / username',
                  padding: const EdgeInsets.all(12),
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.emailAddress,
                ),
                SizedBox(height: theme.md),
                Text(strings.passwordLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                SizedBox(height: theme.xs),
                cupertino.CupertinoTextField(
                  controller: _passController,
                  obscureText: _obscurePassword,
                  placeholder: '••••••••',
                  padding: const EdgeInsets.all(12),
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  suffix: cupertino.CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(_obscurePassword ? cupertino.CupertinoIcons.eye : cupertino.CupertinoIcons.eye_slash, size: 20),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                if (_requiresHostPort) ...[
                  SizedBox(height: theme.md),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(strings.hostLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            SizedBox(height: theme.xs),
                            cupertino.CupertinoTextField(
                              controller: _hostController,
                              placeholder: 'server.example.com',
                              padding: const EdgeInsets.all(12),
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.url,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: theme.md),
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(strings.portLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            SizedBox(height: theme.xs),
                            cupertino.CupertinoTextField(
                              controller: _portController,
                              placeholder: '443',
                              padding: const EdgeInsets.all(12),
                              textInputAction: TextInputAction.done,
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
        if (_step2Error != null) ...[
          SizedBox(height: theme.md),
          Text(_step2Error!, style: TextStyle(color: theme.error, fontSize: 12)),
        ],
        SizedBox(height: theme.lg),
        cupertino.CupertinoButton(
          color: theme.accent,
          onPressed: _isTesting || _isAdding ? null : _handleTestConnection,
          child: _isTesting
              ? const cupertino.CupertinoActivityIndicator()
              : Text(strings.testConnection, style: const TextStyle(color: Color(0xFFFFFFFF))),
        ),
        if (_testStatus != null) ...[
          SizedBox(height: theme.sm),
          Text(
            _testMessage ?? '',
            style: TextStyle(color: _testStatus == 'success' ? theme.success : theme.error, fontSize: 12),
          ),
        ],
        if (_addError != null) ...[
          SizedBox(height: theme.md),
          Text(
            _addError!,
            style: TextStyle(color: theme.error, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ],
    );
  }

  Widget _buildIOSFooter(AppThemeData theme, AppStrings strings) {
    final isStep1 = _currentStep == 0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.xl, vertical: theme.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isStep1) ...[
            cupertino.CupertinoButton(onPressed: () => Navigator.pop(context), child: Text(strings.cancel)),
            SizedBox(width: theme.md),
            cupertino.CupertinoButton.filled(onPressed: _goToStep2, child: Text(strings.next)),
          ] else ...[
            cupertino.CupertinoButton(onPressed: _isAdding ? null : () => setState(() => _currentStep = 0), child: Text(strings.back)),
            SizedBox(width: theme.md),
            cupertino.CupertinoButton.filled(
              onPressed: _isAdding ? null : _handleAddRemote,
              child: _isAdding
                  ? const cupertino.CupertinoActivityIndicator()
                  : Text(strings.add),
            ),
          ],
        ],
      ),
    );
  }
}

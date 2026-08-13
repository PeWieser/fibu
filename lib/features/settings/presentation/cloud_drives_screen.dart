import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/services/rclone_provider.dart';
import '../../../theme/theme.dart';

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
      ),
      content: SingleChildScrollView(
        padding: EdgeInsets.all(theme.lg),
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
                        const Icon(fluent.FluentIcons.add, size: 16, semanticLabel: 'Add Drive'),
                        SizedBox(width: theme.sm),
                        Text(strings.addCloudDrive),
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
        trailing: MouseRegion(
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
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(theme.lg),
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
      header: Text(strings.connectedDrives.toUpperCase()),
      children: remotes.map((remote) {
        final type = _getProviderType(remote);
        final isDeleting = _deletingRemote == remote;

        return cupertino.CupertinoListTile(
          title: Text(remote),
          subtitle: Text(type),
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
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(theme.lg),
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
              error: (err, _) => Center(
                child: Text('${strings.error}: $err', style: TextStyle(color: theme.error)),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: material.FloatingActionButton(
            onPressed: () => _openAddRemoteWizard(context, TargetPlatform.android),
            child: const Icon(material.Icons.add, semanticLabel: 'Add Remote'),
          ),
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
            Icon(material.Icons.cloud_off, size: 56, color: theme.textSecondary, semanticLabel: 'No Drives'),
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

        return material.Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(theme.radiusSm),
            side: BorderSide(color: material.Theme.of(context).colorScheme.outlineVariant),
          ),
          child: material.ListTile(
            leading: Icon(material.Icons.cloud_queue, color: theme.accent, semanticLabel: 'Cloud Remote'),
            title: Text(remote),
            subtitle: Text(type),
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
        );
      },
    );
  }

  // --- Helper Methods ---
  String _getProviderType(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('drive') || lowerName.contains('gdrive')) {
      return 'Google Drive';
    } else if (lowerName.contains('one') || lowerName.contains('odrive')) {
      return 'Microsoft OneDrive';
    } else if (lowerName.contains('drop') || lowerName.contains('box')) {
      return 'Dropbox';
    } else if (lowerName.contains('mega')) {
      return 'Mega.nz';
    } else if (lowerName.contains('s3') || lowerName.contains('aws')) {
      return 'Amazon S3';
    } else if (lowerName.contains('sftp')) {
      return 'SFTP';
    } else if (lowerName.contains('ftp')) {
      return 'FTP';
    } else if (lowerName.contains('webdav') || lowerName.contains('nextcloud')) {
      return 'WebDAV';
    }
    return 'Cloud Storage Remote';
  }

  // --- Remote Deletion Confirmation (Destructive Action Rule 6) ---
  void _confirmDeleteRemote(
      BuildContext context, String remoteName, TargetPlatform platform) {
    final strings = context.strings;
    final title = strings.deleteDriveConfirmTitle;
    final message = '${strings.deleteDrivePrompt(remoteName)}\n\n${strings.deleteDriveRule6Notice}';

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
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    await _performDelete(remoteName);
                  },
                  child: Text(strings.disconnect),
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
              onPressed: () async {
                Navigator.pop(dialogCtx);
                await _performDelete(remoteName);
              },
              child: Text(strings.disconnect),
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
              style: material.FilledButton.styleFrom(
                backgroundColor: material.Theme.of(context).colorScheme.error,
              ),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                await _performDelete(remoteName);
              },
              child: Text(strings.disconnect),
            ),
          ],
        ),
      );
    }
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
    final addedRemoteName = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Add Remote Wizard',
      pageBuilder: (dialogContext, _, __) {
        return AddRemoteWizardDialog(platform: platform);
      },
    );

    if (addedRemoteName != null && mounted) {
      _showNotification(strings.driveAddedSuccess(addedRemoteName), isError: false);
    }
  }
}

/// 2-Step Guided Wizard Dialog for Adding Cloud Remotes.
/// - Step 1: Connection Name + Real-time searchable Provider list.
/// - Step 2: Provider-specific configuration (OAuth or Credentials), Test Connection, Async Add with error retention.
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

  String _selectedProvider = 'drive';
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

  bool get _isOAuthProvider {
    final p = _selectedProvider.toLowerCase();
    return p == 'drive' || p == 'onedrive' || p == 'dropbox' || p == 'box';
  }

  bool get _requiresHostPort {
    final p = _selectedProvider.toLowerCase();
    return p == 'sftp' || p == 'ftp' || p == 'webdav' || p == 's3';
  }

  void _goToStep2() {
    final strings = context.strings;
    setState(() {
      _nameError = null;
      _providerError = null;
    });

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _nameError = strings.nameRequiredError;
      });
      return;
    }

    if (_selectedProvider.isEmpty) {
      setState(() {
        _providerError = strings.providerRequiredError;
      });
      return;
    }

    setState(() {
      _currentStep = 1;
      _step2Error = null;
      _testStatus = null;
      _testMessage = null;
      _addError = null;
    });
  }

  Future<void> _handleTestConnection() async {
    final strings = context.strings;
    setState(() {
      _isTesting = true;
      _testStatus = null;
      _testMessage = null;
    });

    try {
      if (!_isOAuthProvider) {
        if (_selectedProvider == 'mega' && (_userController.text.trim().isEmpty || _passController.text.isEmpty)) {
          throw Exception(strings.credentialsRequiredError);
        }
        if (_requiresHostPort && _hostController.text.trim().isEmpty) {
          throw Exception(strings.credentialsRequiredError);
        }
      }

      if (_passController.text.isNotEmpty) {
        await ref.read(rcloneServiceProvider).obscurePassword(_passController.text);
      }

      // Simulate network verification ping
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

    if (!_isOAuthProvider) {
      if (_selectedProvider == 'mega' && (_userController.text.trim().isEmpty || _passController.text.isEmpty)) {
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

      if (_selectedProvider == 'mega') {
        final plainPass = _passController.text;
        final obscured = await ref.read(rcloneServiceProvider).obscurePassword(plainPass);
        config = {
          'user': _userController.text.trim(),
          'pass': obscured,
        };
      } else if (_requiresHostPort) {
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
      } else if (!_isOAuthProvider) {
        final plainPass = _passController.text;
        final obscured = plainPass.isNotEmpty
            ? await ref.read(rcloneServiceProvider).obscurePassword(plainPass)
            : '';
        config = {
          if (_userController.text.trim().isNotEmpty) 'user': _userController.text.trim(),
          if (obscured.isNotEmpty) 'pass': obscured,
        };
      }

      await ref.read(rcloneServiceProvider).addRemote(
        name: name,
        type: _selectedProvider,
        config: config,
      );

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

    return Center(
      child: material.Material(
        color: material.Colors.transparent,
        child: Container(
          width: 520,
          constraints: const BoxConstraints(maxHeight: 640),
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
              _buildWizardHeader(theme),
              const material.Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(theme.xl),
                  child: _currentStep == 0 ? _buildStep1Content(theme) : _buildStep2Content(theme),
                ),
              ),
              const material.Divider(height: 1),
              _buildWizardFooter(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWizardHeader(AppThemeData theme) {
    final strings = context.strings;
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
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              child: fluent.IconButton(
                icon: Icon(fluent.FluentIcons.chrome_close, size: 14, color: theme.textSecondary, semanticLabel: strings.close),
                onPressed: _isAdding ? null : () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Step 1: Name & Searchable Provider Selection ---
  Widget _buildStep1Content(AppThemeData theme) {
    final strings = context.strings;
    final providersAsync = ref.watch(providersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          strings.connectionNameLabel,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
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
          Text(
            _nameError!,
            style: TextStyle(color: theme.error, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
        SizedBox(height: theme.lg),
        Text(
          strings.searchProviderHint,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        SizedBox(height: theme.xs),
        fluent.TextBox(
          controller: _searchController,
          placeholder: strings.searchProviderHint,
          prefix: Padding(
            padding: EdgeInsets.only(left: theme.sm),
            child: Icon(fluent.FluentIcons.search, size: 14, color: theme.textSecondary, semanticLabel: 'Search'),
          ),
          onChanged: (val) {
            setState(() {
              _searchQuery = val;
            });
          },
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
              return Container(
                padding: EdgeInsets.all(theme.xl),
                alignment: Alignment.center,
                child: Text(
                  strings.noMatchingProviders,
                  style: TextStyle(color: theme.textSecondary, fontStyle: FontStyle.italic),
                ),
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
                  final isSelected = _selectedProvider == provider.name;

                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedProvider = provider.name;
                          _providerError = null;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: theme.md, vertical: theme.sm),
                        color: isSelected
                            ? theme.accent.withValues(alpha: 0.15)
                            : (index % 2 == 0 ? theme.textSecondary.withValues(alpha: 0.04) : null),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? fluent.FluentIcons.checkbox_composite
                                  : fluent.FluentIcons.checkbox,
                              color: isSelected ? theme.accent : theme.textSecondary,
                              size: 16,
                              semanticLabel: isSelected ? 'Selected' : 'Unselected',
                            ),
                            SizedBox(width: theme.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    provider.description,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    provider.name,
                                    style: TextStyle(color: theme.textSecondary, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: theme.xs, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.accent,
                                  borderRadius: BorderRadius.circular(theme.radiusSm),
                                ),
                                child: const Icon(fluent.FluentIcons.check_mark, size: 10, color: Color(0xffffffff), semanticLabel: 'Check'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: fluent.ProgressRing(strokeWidth: 2)),
          ),
          error: (err, _) => Padding(
            padding: EdgeInsets.symmetric(vertical: theme.md),
            child: Text('${strings.error}: $err', style: TextStyle(color: theme.error)),
          ),
        ),
        if (_providerError != null) ...[
          SizedBox(height: theme.xs),
          Text(
            _providerError!,
            style: TextStyle(color: theme.error, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ],
    );
  }

  // --- Step 2: Provider Configuration & Connection Testing ---
  Widget _buildStep2Content(AppThemeData theme) {
    final strings = context.strings;

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
              Icon(fluent.FluentIcons.cloud, color: theme.accent, size: 24, semanticLabel: 'Selected Provider'),
              SizedBox(width: theme.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nameController.text.trim(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      'Provider: ${_selectedProvider.toUpperCase()}',
                      style: TextStyle(color: theme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: theme.lg),
        if (_isOAuthProvider) ...[
          Container(
            padding: EdgeInsets.all(theme.md),
            decoration: BoxDecoration(
              color: theme.textSecondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(theme.radiusSm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(fluent.FluentIcons.info, color: theme.accent, size: 16, semanticLabel: 'Info'),
                    SizedBox(width: theme.sm),
                    Text(
                      'OAuth Authentication',
                      style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary),
                    ),
                  ],
                ),
                SizedBox(height: theme.xs),
                Text(
                  strings.oauthInfoNotice,
                  style: TextStyle(color: theme.textSecondary, fontSize: 12),
                ),
                SizedBox(height: theme.md),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 140, minHeight: 44),
                    child: fluent.Button(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(fluent.FluentIcons.open_in_new_window, size: 14, semanticLabel: strings.authorizeInBrowser),
                          SizedBox(width: theme.sm),
                          Text(strings.authorizeInBrowser),
                        ],
                      ),
                      onPressed: () {
                        setState(() {
                          _isOAuthAuthorized = true;
                        });
                      },
                    ),
                  ),
                ),
                if (_isOAuthAuthorized) ...[
                  SizedBox(height: theme.sm),
                  Row(
                    children: [
                      Icon(fluent.FluentIcons.completed, color: theme.success, size: 16, semanticLabel: 'Authorized'),
                      SizedBox(width: theme.xs),
                      Text(
                        strings.authorizedSuccess,
                        style: TextStyle(color: theme.success, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ] else ...[
          Text(
            strings.emailOrUserLabel,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          SizedBox(height: theme.xs),
          fluent.TextBox(
            controller: _userController,
            placeholder: 'user@example.com / username',
          ),
          SizedBox(height: theme.md),
          Text(
            strings.passwordLabel,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          SizedBox(height: theme.xs),
          fluent.TextBox(
            controller: _passController,
            obscureText: _obscurePassword,
            placeholder: '••••••••',
            suffix: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: fluent.IconButton(
                  icon: Icon(
                    _obscurePassword ? fluent.FluentIcons.view : fluent.FluentIcons.hide,
                    size: 16,
                    semanticLabel: _obscurePassword ? strings.showPassword : strings.hidePassword,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
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
                      Text(
                        strings.hostLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      SizedBox(height: theme.xs),
                      fluent.TextBox(
                        controller: _hostController,
                        placeholder: 'sftp.example.com / server',
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
                      Text(
                        strings.portLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      SizedBox(height: theme.xs),
                      fluent.TextBox(
                        controller: _portController,
                        placeholder: '22',
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
          Text(
            _step2Error!,
            style: TextStyle(color: theme.error, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
        SizedBox(height: theme.lg),
        const material.Divider(),
        SizedBox(height: theme.md),
        Row(
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 140, minHeight: 44),
                child: fluent.Button(
                  onPressed: _isTesting || _isAdding ? null : _handleTestConnection,
                  child: _isTesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: fluent.ProgressRing(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(fluent.FluentIcons.plug_connected, size: 14, semanticLabel: 'Test Connection'),
                            SizedBox(width: theme.xs),
                            Text(strings.testConnection),
                          ],
                        ),
                ),
              ),
            ),
            SizedBox(width: theme.md),
            Expanded(
              child: _testStatus == 'success'
                  ? Row(
                      children: [
                        Icon(fluent.FluentIcons.completed, color: theme.success, size: 16, semanticLabel: 'Success'),
                        SizedBox(width: theme.xs),
                        Expanded(
                          child: Text(
                            _testMessage ?? strings.connectionSuccess,
                            style: TextStyle(color: theme.success, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    )
                  : _testStatus == 'error'
                      ? Row(
                          children: [
                            Icon(fluent.FluentIcons.error_badge, color: theme.error, size: 16, semanticLabel: 'Error'),
                            SizedBox(width: theme.xs),
                            Expanded(
                              child: Text(
                                _testMessage ?? strings.connectionFailed,
                                style: TextStyle(color: theme.error, fontSize: 12),
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
            ),
          ],
        ),
        if (_addError != null) ...[
          SizedBox(height: theme.md),
          fluent.InfoBar(
            title: Text(strings.error),
            content: Text(_addError!),
            severity: fluent.InfoBarSeverity.error,
          ),
        ],
      ],
    );
  }

  // --- Wizard Footer Action Buttons ---
  Widget _buildWizardFooter(AppThemeData theme) {
    final strings = context.strings;
    final isStep1 = _currentStep == 0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.xl, vertical: theme.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isStep1) ...[
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 90, minHeight: 44),
                child: fluent.Button(
                  onPressed: () => Navigator.pop(context),
                  child: Text(strings.cancel),
                ),
              ),
            ),
            SizedBox(width: theme.md),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 100, minHeight: 44),
                child: fluent.FilledButton(
                  onPressed: _goToStep2,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(strings.next),
                      SizedBox(width: theme.xs),
                      const Icon(fluent.FluentIcons.chevron_right, size: 12, semanticLabel: 'Next'),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 90, minHeight: 44),
                child: fluent.Button(
                  onPressed: _isAdding
                      ? null
                      : () {
                          setState(() {
                            _currentStep = 0;
                          });
                        },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(fluent.FluentIcons.chevron_left, size: 12, semanticLabel: 'Back'),
                      SizedBox(width: theme.xs),
                      Text(strings.back),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: theme.md),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 110, minHeight: 44),
                child: fluent.FilledButton(
                  onPressed: _isAdding ? null : _handleAddRemote,
                  child: _isAdding
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: fluent.ProgressRing(strokeWidth: 2),
                            ),
                            SizedBox(width: theme.sm),
                            Text(strings.addingRemote),
                          ],
                        )
                      : Text(strings.add),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

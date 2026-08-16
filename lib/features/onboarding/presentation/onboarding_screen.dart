import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/theme.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/services/rclone_provider.dart';
import '../../settings/presentation/cloud_drives_screen.dart';
import '../../tasks/presentation/tasks_controller.dart';
import '../../tasks/presentation/tasks_screen.dart';
import 'onboarding_controller.dart';

/// Platform-adaptive Onboarding Walkthrough Flow.
/// Guides new users through Fibu's core capabilities in 3 guided steps:
/// - Step 1: Welcome & Overview (Feature cards)
/// - Step 2: Connect Cloud Remote (Add remote wizard)
/// - Step 3: First Backup Task & Get Started (Create task & complete onboarding)
///
/// Fully supports Windows (Fluent Design), iOS (Cupertino), and Android (Material 3)
/// with strict Sanzo Wada color tokens, 44pt minimum touch targets, and WCAG AA contrast.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _enableMediaBackup = true;
  bool _enableDocsBackup = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _openAddRemoteWizard(BuildContext context, TargetPlatform platform) async {
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
      ref.invalidate(remotesProvider);
    }
  }

  void _openCreateTaskDialog(BuildContext context, TargetPlatform platform) {
    showAddEditTaskDialog(context, ref, null, platform);
  }

  void _completeOnboarding() {
    final platform = defaultTargetPlatform;
    final remotes = ref.read(remotesProvider).value ?? [];
    final defaultRemote = remotes.isNotEmpty ? remotes.first : '';
    final isIOS = platform == TargetPlatform.iOS;
    final List<BackupTask> autoTasks = [];

    if (_enableMediaBackup) {
      autoTasks.add(BackupTask.createMediaMirrorPresetTask(remoteName: defaultRemote, isIOS: isIOS));
    }
    if (_enableDocsBackup) {
      autoTasks.add(BackupTask.createDocumentsPresetTask(remoteName: defaultRemote, isIOS: isIOS));
    }

    if (autoTasks.isNotEmpty) {
      ref.read(tasksListProvider.notifier).importTasks(autoTasks);
    }

    ref.read(onboardingControllerProvider.notifier).completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final platform = defaultTargetPlatform;
    final theme = context.theme;
    final strings = context.strings;

    if (platform == TargetPlatform.windows) {
      return _buildWindows(context, theme, strings);
    } else if (platform == TargetPlatform.iOS) {
      return _buildIOS(context, theme, strings);
    } else {
      return _buildAndroid(context, theme, strings);
    }
  }

  // =========================================================================
  // WINDOWS (Fluent UI Layout)
  // =========================================================================
  Widget _buildWindows(BuildContext context, AppThemeData theme, AppStrings strings) {
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
      child: fluent.ScaffoldPage(
        header: fluent.PageHeader(
          title: Row(
            children: [
              Icon(fluent.FluentIcons.cloud_download, color: theme.accent, size: 24, semanticLabel: 'Fibu'),
              SizedBox(width: theme.sm),
              Text(
                'Fibu',
                style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          commandBar: fluent.CommandBar(
            mainAxisAlignment: MainAxisAlignment.end,
            primaryItems: [
              if (_currentPage < 2)
                fluent.CommandBarButton(
                  label: Text(strings.onboardingSkip),
                  onPressed: _completeOnboarding,
                ),
            ],
          ),
        ),
        content: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (page) => setState(() => _currentPage = page),
                    children: [
                      _buildStep1(context, theme, strings, TargetPlatform.windows),
                      _buildStep2(context, theme, strings, TargetPlatform.windows),
                      _buildStep3(context, theme, strings, TargetPlatform.windows),
                    ],
                  ),
                ),
                _buildBottomBar(context, theme, strings, TargetPlatform.windows),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // IOS (Cupertino Layout)
  // =========================================================================
  Widget _buildIOS(BuildContext context, AppThemeData theme, AppStrings strings) {
    return cupertino.CupertinoPageScaffold(
      backgroundColor: theme.canvas,
      navigationBar: cupertino.CupertinoNavigationBar(
        backgroundColor: theme.surface,
        middle: Text(
          'Fibu',
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold),
        ),
        trailing: _currentPage < 2
            ? MouseRegion(
                cursor: SystemMouseCursors.click,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  child: cupertino.CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _completeOnboarding,
                    child: Text(
                      strings.onboardingSkip,
                      style: TextStyle(color: theme.textSecondary, fontSize: 14),
                    ),
                  ),
                ),
              )
            : null,
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (page) => setState(() => _currentPage = page),
                    children: [
                      _buildStep1(context, theme, strings, TargetPlatform.iOS),
                      _buildStep2(context, theme, strings, TargetPlatform.iOS),
                      _buildStep3(context, theme, strings, TargetPlatform.iOS),
                    ],
                  ),
                ),
                _buildBottomBar(context, theme, strings, TargetPlatform.iOS),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // ANDROID (Material 3 Layout)
  // =========================================================================
  Widget _buildAndroid(BuildContext context, AppThemeData theme, AppStrings strings) {
    return material.Scaffold(
      backgroundColor: theme.canvas,
      appBar: material.AppBar(
        backgroundColor: theme.surface,
        elevation: 0,
        title: Row(
          children: [
            Icon(material.Icons.cloud_sync, color: theme.accent, semanticLabel: 'Fibu'),
            SizedBox(width: theme.sm),
            Text(
              'Fibu',
              style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          if (_currentPage < 2)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: material.TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(
                    strings.onboardingSkip,
                    style: TextStyle(color: theme.textSecondary, fontSize: 14),
                  ),
                ),
              ),
            ),
          SizedBox(width: theme.sm),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (page) => setState(() => _currentPage = page),
                    children: [
                      _buildStep1(context, theme, strings, TargetPlatform.android),
                      _buildStep2(context, theme, strings, TargetPlatform.android),
                      _buildStep3(context, theme, strings, TargetPlatform.android),
                    ],
                  ),
                ),
                _buildBottomBar(context, theme, strings, TargetPlatform.android),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // STEP 1: WELCOME & OVERVIEW
  // =========================================================================
  Widget _buildStep1(
    BuildContext context,
    AppThemeData theme,
    AppStrings strings,
    TargetPlatform platform,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: theme.lg, vertical: theme.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // App Logo / Hero Icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: theme.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: theme.accent.withValues(alpha: 0.35), width: 2),
            ),
            child: Center(
              child: Icon(
                platform == TargetPlatform.windows
                    ? fluent.FluentIcons.cloud_download
                    : (platform == TargetPlatform.iOS
                        ? cupertino.CupertinoIcons.cloud_fill
                        : material.Icons.cloud_sync),
                size: 38,
                color: theme.accent,
                semanticLabel: 'Fibu Logo',
              ),
            ),
          ),
          SizedBox(height: theme.md),
          Text(
            strings.onboardingWelcomeTitle,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: theme.xs),
          Text(
            strings.onboardingWelcomeSubtitle,
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: theme.xl),

          // 3 Feature Cards
          _buildFeatureCard(
            theme: theme,
            platform: platform,
            icon: platform == TargetPlatform.windows
                ? fluent.FluentIcons.cloud
                : (platform == TargetPlatform.iOS
                    ? cupertino.CupertinoIcons.cloud_upload_fill
                    : material.Icons.cloud_upload_outlined),
            title: strings.onboardingFeature1Title,
            description: strings.onboardingFeature1Desc,
          ),
          SizedBox(height: theme.sm),
          _buildFeatureCard(
            theme: theme,
            platform: platform,
            icon: platform == TargetPlatform.windows
                ? fluent.FluentIcons.sync
                : (platform == TargetPlatform.iOS
                    ? cupertino.CupertinoIcons.arrow_2_circlepath
                    : material.Icons.sync),
            title: strings.onboardingFeature2Title,
            description: strings.onboardingFeature2Desc,
          ),
          SizedBox(height: theme.sm),
          _buildFeatureCard(
            theme: theme,
            platform: platform,
            icon: platform == TargetPlatform.windows
                ? fluent.FluentIcons.shield
                : (platform == TargetPlatform.iOS
                    ? cupertino.CupertinoIcons.shield_fill
                    : material.Icons.security),
            title: strings.onboardingFeature3Title,
            description: strings.onboardingFeature3Desc,
          ),
          SizedBox(height: theme.lg),

          // Primary CTA to Step 2
          _buildPrimaryButton(
            context: context,
            theme: theme,
            platform: platform,
            label: strings.next,
            onPressed: () => _goToPage(1),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required AppThemeData theme,
    required TargetPlatform platform,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: EdgeInsets.all(theme.md),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(theme.radiusLg),
        border: Border.all(
          color: theme.textSecondary.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(theme.sm),
            decoration: BoxDecoration(
              color: theme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(theme.radiusSm),
            ),
            child: Icon(icon, color: theme.accent, size: 22, semanticLabel: title),
          ),
          SizedBox(width: theme.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: theme.xs / 2),
                Text(
                  description,
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // STEP 2: CONNECT CLOUD REMOTE
  // =========================================================================
  Widget _buildStep2(
    BuildContext context,
    AppThemeData theme,
    AppStrings strings,
    TargetPlatform platform,
  ) {
    final remotesAsync = ref.watch(remotesProvider);
    final List<String> remotes = remotesAsync.valueOrNull ?? const [];

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: theme.lg, vertical: theme.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon Header
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: theme.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: theme.accent.withValues(alpha: 0.35), width: 2),
            ),
            child: Center(
              child: Icon(
                platform == TargetPlatform.windows
                    ? fluent.FluentIcons.cloud_add
                    : (platform == TargetPlatform.iOS
                        ? cupertino.CupertinoIcons.cloud_upload
                        : material.Icons.add_to_drive),
                size: 36,
                color: theme.accent,
                semanticLabel: strings.onboardingStep1ConnectTitle,
              ),
            ),
          ),
          SizedBox(height: theme.md),
          Text(
            strings.onboardingStep1ConnectTitle,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: theme.xs),
          Text(
            strings.onboardingStep1ConnectDesc,
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: theme.lg),

          // Informative Providers / Connected Status Card
          Container(
            padding: EdgeInsets.all(theme.lg),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(theme.radiusLg),
              border: Border.all(
                color: theme.textSecondary.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (remotes.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        platform == TargetPlatform.windows
                            ? fluent.FluentIcons.completed
                            : (platform == TargetPlatform.iOS
                                ? cupertino.CupertinoIcons.checkmark_circle_fill
                                : material.Icons.check_circle),
                        color: theme.success,
                        size: 20,
                        semanticLabel: 'Success',
                      ),
                      SizedBox(width: theme.sm),
                      Text(
                        strings.connectedDrives,
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: theme.sm),
                  Wrap(
                    spacing: theme.sm,
                    runSpacing: theme.xs,
                    children: remotes.map((remote) {
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: theme.sm, vertical: theme.xs),
                        decoration: BoxDecoration(
                          color: theme.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(theme.radiusSm),
                          border: Border.all(color: theme.success.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              platform == TargetPlatform.windows
                                  ? fluent.FluentIcons.cloud
                                  : (platform == TargetPlatform.iOS
                                      ? cupertino.CupertinoIcons.cloud
                                      : material.Icons.cloud_done),
                              size: 14,
                              color: theme.success,
                              semanticLabel: remote,
                            ),
                            SizedBox(width: theme.xs),
                            Text(
                              remote,
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ] else ...[
                  Text(
                    'Unterstützte Cloud-Dienste:',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: theme.sm),
                  Wrap(
                    spacing: theme.sm,
                    runSpacing: theme.xs,
                    children: [
                      _buildProviderBadge(theme, 'Google Drive', platform),
                      _buildProviderBadge(theme, 'OneDrive', platform),
                      _buildProviderBadge(theme, 'Dropbox', platform),
                      _buildProviderBadge(theme, 'Mega.nz', platform),
                      _buildProviderBadge(theme, 'Amazon S3 / MinIO', platform),
                      _buildProviderBadge(theme, 'Nextcloud (WebDAV)', platform),
                      _buildProviderBadge(theme, 'SFTP / FTP', platform),
                    ],
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: theme.lg),

          // Primary CTA: Connect Drive
          _buildPrimaryButton(
            context: context,
            theme: theme,
            platform: platform,
            label: strings.onboardingConnectDriveButton,
            icon: platform == TargetPlatform.windows
                ? fluent.FluentIcons.add
                : (platform == TargetPlatform.iOS
                    ? cupertino.CupertinoIcons.add
                    : material.Icons.add),
            onPressed: () => _openAddRemoteWizard(context, platform),
          ),
          SizedBox(height: theme.sm),

          // Navigation Links
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSecondaryLink(
                context: context,
                theme: theme,
                label: strings.back,
                onPressed: () => _goToPage(0),
              ),
              SizedBox(width: theme.lg),
              _buildSecondaryLink(
                context: context,
                theme: theme,
                label: remotes.isNotEmpty ? strings.next : strings.onboardingSkip,
                onPressed: () => _goToPage(2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProviderBadge(AppThemeData theme, String name, TargetPlatform platform) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: theme.sm, vertical: theme.xs / 1.5),
      decoration: BoxDecoration(
        color: theme.canvas,
        borderRadius: BorderRadius.circular(theme.radiusSm),
        border: Border.all(color: theme.textSecondary.withValues(alpha: 0.2)),
      ),
      child: Text(
        name,
        style: TextStyle(
          color: theme.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // =========================================================================
  // STEP 3: FIRST BACKUP TASK & GET STARTED
  // =========================================================================
  Widget _buildStep3(
    BuildContext context,
    AppThemeData theme,
    AppStrings strings,
    TargetPlatform platform,
  ) {
    final tasks = ref.watch(tasksListProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: theme.lg, vertical: theme.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon Header
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: theme.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: theme.accent.withValues(alpha: 0.35), width: 2),
            ),
            child: Center(
              child: Icon(
                platform == TargetPlatform.windows
                    ? fluent.FluentIcons.task_manager
                    : (platform == TargetPlatform.iOS
                        ? cupertino.CupertinoIcons.list_bullet_indent
                        : material.Icons.checklist),
                size: 36,
                color: theme.accent,
                semanticLabel: strings.onboardingStep2TaskTitle,
              ),
            ),
          ),
          SizedBox(height: theme.md),
          Text(
            strings.onboardingStep2TaskTitle,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: theme.xs),
          Text(
            strings.onboardingStep2TaskDesc,
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: theme.lg),

          SizedBox(height: theme.lg),

          if (platform != TargetPlatform.windows) ...[
            // Mobile Direct Backup Selection Header
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                strings.onboardingSelectBackupsHeader,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: theme.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                strings.onboardingSelectBackupsSubtitle,
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
            SizedBox(height: theme.md),

            // 1. Photos & Media Backup Option Card
            Container(
              padding: EdgeInsets.all(theme.md),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(theme.radiusLg),
                border: Border.all(
                  color: _enableMediaBackup ? theme.accent : theme.textSecondary.withValues(alpha: 0.2),
                  width: _enableMediaBackup ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    platform == TargetPlatform.iOS
                        ? cupertino.CupertinoIcons.photo_on_rectangle
                        : material.Icons.photo_library_outlined,
                    color: theme.accent,
                    size: 28,
                  ),
                  SizedBox(width: theme.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.onboardingMediaBackupTitle,
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: theme.xs / 2),
                        Text(
                          strings.onboardingMediaBackupDesc,
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: theme.sm),
                  if (platform == TargetPlatform.iOS)
                    cupertino.CupertinoSwitch(
                      value: _enableMediaBackup,
                      onChanged: (val) => setState(() => _enableMediaBackup = val),
                    )
                  else
                    material.Switch(
                      value: _enableMediaBackup,
                      onChanged: (val) => setState(() => _enableMediaBackup = val),
                    ),
                ],
              ),
            ),
            SizedBox(height: theme.md),

            // 2. Documents & Local Files Backup Option Card
            Container(
              padding: EdgeInsets.all(theme.md),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(theme.radiusLg),
                border: Border.all(
                  color: _enableDocsBackup ? theme.accent : theme.textSecondary.withValues(alpha: 0.2),
                  width: _enableDocsBackup ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    platform == TargetPlatform.iOS
                        ? cupertino.CupertinoIcons.folder_badge_plus
                        : material.Icons.folder_outlined,
                    color: theme.accent,
                    size: 28,
                  ),
                  SizedBox(width: theme.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.onboardingDocsBackupTitle,
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: theme.xs / 2),
                        Text(
                          strings.onboardingDocsBackupDesc,
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: theme.sm),
                  if (platform == TargetPlatform.iOS)
                    cupertino.CupertinoSwitch(
                      value: _enableDocsBackup,
                      onChanged: (val) => setState(() => _enableDocsBackup = val),
                    )
                  else
                    material.Switch(
                      value: _enableDocsBackup,
                      onChanged: (val) => setState(() => _enableDocsBackup = val),
                    ),
                ],
              ),
            ),
            SizedBox(height: theme.md),

            // iOS Background Task Notice on iOS
            if (platform == TargetPlatform.iOS) ...[
              Container(
                padding: EdgeInsets.all(theme.md),
                decoration: BoxDecoration(
                  color: theme.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(theme.radiusSm),
                  border: Border.all(color: theme.accent.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(cupertino.CupertinoIcons.info_circle_fill, color: theme.accent, size: 18),
                    SizedBox(width: theme.sm),
                    Expanded(
                      child: Text(
                        strings.iosBackgroundScheduleNotice,
                        style: TextStyle(fontSize: 11, color: theme.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: theme.md),
            ],
          ] else ...[
            // Windows Overview or Tasks List Card
            Container(
              padding: EdgeInsets.all(theme.lg),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(theme.radiusLg),
                border: Border.all(
                  color: theme.textSecondary.withValues(alpha: 0.18),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tasks.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          fluent.FluentIcons.completed,
                          color: theme.success,
                          size: 20,
                          semanticLabel: 'Success',
                        ),
                        SizedBox(width: theme.sm),
                        Text(
                          strings.tasksTitle,
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: theme.sm),
                    ...tasks.map((t) => Padding(
                          padding: EdgeInsets.symmetric(vertical: theme.xs / 2),
                          child: Row(
                            children: [
                              Icon(
                                fluent.FluentIcons.task_manager,
                                size: 14,
                                color: theme.accent,
                                semanticLabel: t.name,
                              ),
                              SizedBox(width: theme.xs),
                              Expanded(
                                child: Text(
                                  '${t.name} (${t.scheduleDescription})',
                                  style: TextStyle(
                                    color: theme.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )),
                  ] else ...[
                    _buildWorkflowStepRow(theme, '1', 'Quellordner wählen', 'Lokalen Ordner (z.B. Bilder, Dokumente) auswählen'),
                    SizedBox(height: theme.sm),
                    _buildWorkflowStepRow(theme, '2', 'Cloud-Ziel festlegen', 'Verbundenes Cloud-Laufwerk und Zielordner wählen'),
                    SizedBox(height: theme.sm),
                    _buildWorkflowStepRow(theme, '3', 'Zeitplan & Modus wählen', 'Täglich, wöchentlich oder manuell synchronisieren'),
                  ],
                ],
              ),
            ),
            SizedBox(height: theme.lg),

            // Primary CTA: Create First Task (Windows)
            _buildPrimaryButton(
              context: context,
              theme: theme,
              platform: platform,
              label: strings.onboardingCreateTaskButton,
              icon: fluent.FluentIcons.add,
              onPressed: () => _openCreateTaskDialog(context, platform),
            ),
            SizedBox(height: theme.sm),
          ],

          // Final CTA: Complete Onboarding ("Jetzt loslegen")
          _buildAccentFinishButton(
            context: context,
            theme: theme,
            platform: platform,
            label: strings.onboardingGetStarted,
            onPressed: _completeOnboarding,
          ),
          SizedBox(height: theme.sm),

          // Back link
          _buildSecondaryLink(
            context: context,
            theme: theme,
            label: strings.back,
            onPressed: () => _goToPage(1),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowStepRow(AppThemeData theme, String num, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: theme.accent.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              num,
              style: TextStyle(
                color: theme.accent,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ),
        SizedBox(width: theme.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              Text(
                desc,
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // BOTTOM BAR & STEP INDICATOR DOTS
  // =========================================================================
  Widget _buildBottomBar(
    BuildContext context,
    AppThemeData theme,
    AppStrings strings,
    TargetPlatform platform,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: theme.lg, vertical: theme.md),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(
          top: BorderSide(
            color: theme.textSecondary.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 3 Indicator Dots
          for (int i = 0; i < 3; i++) ...[
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _goToPage(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  margin: EdgeInsets.symmetric(horizontal: theme.xs),
                  width: _currentPage == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? theme.accent
                        : theme.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(theme.radiusSm),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // COMMON BUTTON BUILDERS (Strict 44pt Touch Targets & Design Tokens)
  // =========================================================================
  Widget _buildPrimaryButton({
    required BuildContext context,
    required AppThemeData theme,
    required TargetPlatform platform,
    required String label,
    IconData? icon,
    required VoidCallback onPressed,
  }) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: const Color(0xFFFFFFFF)),
          SizedBox(width: theme.sm),
        ],
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFFFFFFF),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );

    if (platform == TargetPlatform.windows) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 220, minHeight: 44),
          child: fluent.FilledButton(
            onPressed: onPressed,
            style: fluent.ButtonStyle(
              backgroundColor: fluent.WidgetStatePropertyAll(theme.accent),
              padding: fluent.WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: theme.xl, vertical: theme.sm),
              ),
            ),
            child: child,
          ),
        ),
      );
    } else if (platform == TargetPlatform.iOS) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 220, minHeight: 44),
          child: cupertino.CupertinoButton.filled(
            padding: EdgeInsets.symmetric(horizontal: theme.xl, vertical: theme.sm),
            onPressed: onPressed,
            child: child,
          ),
        ),
      );
    } else {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 220, minHeight: 44),
          child: material.FilledButton(
            style: material.FilledButton.styleFrom(
              backgroundColor: theme.accent,
              padding: EdgeInsets.symmetric(horizontal: theme.xl, vertical: theme.sm),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(theme.radiusSm),
              ),
            ),
            onPressed: onPressed,
            child: child,
          ),
        ),
      );
    }
  }

  Widget _buildAccentFinishButton({
    required BuildContext context,
    required AppThemeData theme,
    required TargetPlatform platform,
    required String label,
    required VoidCallback onPressed,
  }) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          platform == TargetPlatform.windows
              ? fluent.FluentIcons.accept
              : (platform == TargetPlatform.iOS
                  ? cupertino.CupertinoIcons.checkmark_alt
                  : material.Icons.check),
          size: 16,
          color: const Color(0xFFFFFFFF),
        ),
        SizedBox(width: theme.sm),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFFFFFFF),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );

    if (platform == TargetPlatform.windows) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 220, minHeight: 44),
          child: fluent.FilledButton(
            onPressed: onPressed,
            style: fluent.ButtonStyle(
              backgroundColor: fluent.WidgetStatePropertyAll(theme.success),
              padding: fluent.WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: theme.xl, vertical: theme.sm),
              ),
            ),
            child: child,
          ),
        ),
      );
    } else if (platform == TargetPlatform.iOS) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 220, minHeight: 44),
          child: cupertino.CupertinoButton(
            color: theme.success,
            padding: EdgeInsets.symmetric(horizontal: theme.xl, vertical: theme.sm),
            onPressed: onPressed,
            child: child,
          ),
        ),
      );
    } else {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 220, minHeight: 44),
          child: material.FilledButton(
            style: material.FilledButton.styleFrom(
              backgroundColor: theme.success,
              padding: EdgeInsets.symmetric(horizontal: theme.xl, vertical: theme.sm),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(theme.radiusSm),
              ),
            ),
            onPressed: onPressed,
            child: child,
          ),
        ),
      );
    }
  }

  Widget _buildSecondaryLink({
    required BuildContext context,
    required AppThemeData theme,
    required String label,
    required VoidCallback onPressed,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        child: Center(
          child: GestureDetector(
            onTap: onPressed,
            child: Text(
              label,
              style: TextStyle(
                color: theme.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

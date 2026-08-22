import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/theme.dart';
import '../../../theme/ios_theme.dart';
import '../../../core/utils/ios_haptics.dart';
import '../../../theme/sanzo_wada_palettes.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/services/settings_service.dart';
import 'cloud_drives_screen.dart';
import 'debug_log_screen.dart';

/// Platform-adaptive Settings screen structured according to Apple HIG:
/// 1. Cloud Storage (Manage Cloud Drives)
/// 2. Network & Cellular (Wi-Fi Only Sync toggle)
/// 3. Appearance & Design (Sync with System, Dark mode, Sanzo Wada palettes)
/// 4. Language (System Auto / Deutsch / English)
/// 5. About (App Version, Developer, Cloud Engine, License, Credits)
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _navigateToCloudDrives(BuildContext context) {
    final platform = defaultTargetPlatform;
    final route = platform == TargetPlatform.windows
        ? fluent.FluentPageRoute(builder: (_) => const CloudDrivesScreen())
        : (platform == TargetPlatform.iOS
            ? cupertino.CupertinoPageRoute(builder: (_) => const CloudDrivesScreen())
            : material.MaterialPageRoute(builder: (_) => const CloudDrivesScreen()));
    Navigator.of(context).push(route);
  }

  void _navigateToDebugLog(BuildContext context) {
    final platform = defaultTargetPlatform;
    final route = platform == TargetPlatform.windows
        ? fluent.FluentPageRoute(builder: (_) => const DebugLogScreen())
        : (platform == TargetPlatform.iOS
            ? cupertino.CupertinoPageRoute(builder: (_) => const DebugLogScreen())
            : material.MaterialPageRoute(builder: (_) => const DebugLogScreen()));
    Navigator.of(context).push(route);
  }

  void _showIOSLanguagePicker(BuildContext context, WidgetRef ref, AppLocaleMode currentMode, AppStrings strings) {
    cupertino.showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => cupertino.CupertinoActionSheet(
        title: Text(strings.languageSection),
        message: Text(strings.systemLanguageSubtitle),
        actions: AppLocaleMode.values.map((mode) {
          final isSelected = mode == currentMode;
          return cupertino.CupertinoActionSheetAction(
            onPressed: () {
              ref.read(localeModeProvider.notifier).setLocaleMode(mode);
              Navigator.of(ctx).pop();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  mode.displayName,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    cupertino.CupertinoIcons.check_mark,
                    size: 18,
                    semanticLabel: 'Selected',
                  ),
                ],
              ],
            ),
          );
        }).toList(),
        cancelButton: cupertino.CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(strings.cancel),
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context, AppStrings strings, AppThemeData theme) {
    final platform = defaultTargetPlatform;
    if (platform == TargetPlatform.iOS) {
      cupertino.showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => cupertino.CupertinoAlertDialog(
          title: Text(strings.aboutSectionTitle),
          content: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              '${strings.aboutAppSubtitle}\n\n'
              '${strings.appVersionLabel}: ${strings.appVersionValue}\n'
              '${strings.developerLabel}: ${strings.developerValue}\n'
              '${strings.cloudEngineLabel}: ${strings.cloudEngineValue}\n'
              '${strings.licenseLabel}: ${strings.licenseValue}\n\n'
              '${strings.aboutDescription}',
              textAlign: TextAlign.start,
            ),
          ),
          actions: [
            cupertino.CupertinoDialogAction(
              isDefaultAction: true,
              child: Text(strings.close),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      );
    } else if (platform == TargetPlatform.windows) {
      fluent.showDialog<void>(
        context: context,
        builder: (ctx) => fluent.ContentDialog(
          title: Text(strings.aboutSectionTitle),
          content: Text(
            '${strings.aboutAppSubtitle}\n\n'
            '${strings.appVersionLabel}: ${strings.appVersionValue}\n'
            '${strings.developerLabel}: ${strings.developerValue}\n'
            '${strings.cloudEngineLabel}: ${strings.cloudEngineValue}\n'
            '${strings.licenseLabel}: ${strings.licenseValue}\n\n'
            '${strings.aboutDescription}',
          ),
          actions: [
            fluent.FilledButton(
              child: Text(strings.close),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      );
    } else {
      material.showDialog<void>(
        context: context,
        builder: (ctx) => material.AlertDialog(
          title: Text(strings.aboutSectionTitle),
          content: Text(
            '${strings.aboutAppSubtitle}\n\n'
            '${strings.appVersionLabel}: ${strings.appVersionValue}\n'
            '${strings.developerLabel}: ${strings.developerValue}\n'
            '${strings.cloudEngineLabel}: ${strings.cloudEngineValue}\n'
            '${strings.licenseLabel}: ${strings.licenseValue}\n\n'
            '${strings.aboutDescription}',
          ),
          actions: [
            material.FilledButton(
              child: Text(strings.close),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appThemeProvider);
    ref.watch(themeConfigProvider);
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
  // WINDOWS (Fluent Design Settings)
  // =========================================================================
  Widget _buildWindows(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final strings = ref.watch(stringsProvider);
    final currentLocaleMode = ref.watch(localeModeProvider);
    final config = ref.watch(themeConfigProvider);

    return fluent.ScaffoldPage.scrollable(
      header: fluent.PageHeader(
        title: fluent.Text(strings.settingsTitle),
      ),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Cloud Drives
              fluent.Text(strings.cloudStorage, style: fluent.FluentTheme.of(context).typography.subtitle),
              SizedBox(height: theme.md),
              fluent.Card(
                child: GestureDetector(
                  onTap: () => _navigateToCloudDrives(context),
                  behavior: HitTestBehavior.opaque,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Row(
                      children: [
                        Icon(fluent.FluentIcons.cloud, color: theme.accent, size: 18, semanticLabel: strings.manageCloudDrives),
                        const SizedBox(width: 12),
                        Text(strings.manageCloudDrives, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Icon(fluent.FluentIcons.chevron_right, size: 12, color: theme.textSecondary, semanticLabel: strings.manageCloudDrives),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: theme.xl),

              // 2. Network & Cellular
              fluent.Text(strings.networkSectionTitle, style: fluent.FluentTheme.of(context).typography.subtitle),
              SizedBox(height: theme.md),
              fluent.Tooltip(
                child: fluent.Card(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(strings.wifiOnlySyncLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                              SizedBox(height: theme.xs / 2),
                            ],
                          ),
                        ),
                        fluent.ToggleSwitch(
                          checked: ref.watch(wifiOnlySyncProvider),
                          onChanged: (val) {
                            ref.read(wifiOnlySyncProvider.notifier).setWifiOnly(val);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: theme.xl),

              // 3. Appearance & Design
              fluent.Text(strings.appearanceSection, style: fluent.FluentTheme.of(context).typography.subtitle),
              SizedBox(height: theme.md),
              fluent.Tooltip(
                message: strings.tooltipThemeMode,
                child: fluent.Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Row(
                          children: [
                            Text(strings.syncWithSystem),
                            const Spacer(),
                            fluent.ToggleSwitch(
                              checked: config.syncWithSystem,
                              onChanged: (val) {
                                ref.read(themeConfigProvider.notifier).setSyncWithSystem(val);
                              },
                            ),
                          ],
                        ),
                      ),
                      if (!config.syncWithSystem) ...[
                        const SizedBox(height: 8),
                        const fluent.Divider(),
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Row(
                            children: [
                              Text(strings.useDarkMode),
                              const Spacer(),
                              fluent.ToggleSwitch(
                                checked: config.forceDarkMode,
                                onChanged: (val) {
                                  ref.read(themeConfigProvider.notifier).setForceDarkMode(val);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(height: theme.lg),
              fluent.Tooltip(
                message: strings.tooltipWadaPalette,
                child: fluent.Text(strings.lightModePalette, style: fluent.FluentTheme.of(context).typography.bodyStrong),
              ),
              SizedBox(height: theme.sm),
              _buildWadaPaletteRow(context, ref, config, false, strings),
              SizedBox(height: theme.lg),
              fluent.Tooltip(
                message: strings.tooltipWadaPalette,
                child: fluent.Text(strings.darkModePalette, style: fluent.FluentTheme.of(context).typography.bodyStrong),
              ),
              SizedBox(height: theme.sm),
              _buildWadaPaletteRow(context, ref, config, true, strings),
              SizedBox(height: theme.xl),

              // 4. Language
              fluent.Text(strings.appConfiguration, style: fluent.FluentTheme.of(context).typography.subtitle),
              SizedBox(height: theme.md),
              fluent.Tooltip(
                message: strings.tooltipLanguage,
                child: fluent.Card(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Row(
                      children: [
                        Text(strings.languageSection),
                        const Spacer(),
                        fluent.ComboBox<AppLocaleMode>(
                          value: currentLocaleMode,
                          items: AppLocaleMode.values.map((mode) {
                            return fluent.ComboBoxItem<AppLocaleMode>(
                              value: mode,
                              child: Text(mode.displayName),
                            );
                          }).toList(),
                          onChanged: (mode) {
                            if (mode != null) {
                              ref.read(localeModeProvider.notifier).setLocaleMode(mode);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: theme.xl),

              // 5. About
              fluent.Text(strings.aboutSectionTitle, style: fluent.FluentTheme.of(context).typography.subtitle),
              SizedBox(height: theme.md),
              fluent.Card(
                child: Column(
                  children: [
                    _buildInfoRow(strings.appVersionLabel, strings.appVersionValue, theme),
                    const SizedBox(height: 8),
                    const fluent.Divider(),
                    const SizedBox(height: 8),
                    _buildInfoRow(strings.developerLabel, strings.developerValue, theme),
                    const SizedBox(height: 8),
                    const fluent.Divider(),
                    const SizedBox(height: 8),
                    _buildInfoRow(strings.cloudEngineLabel, strings.cloudEngineValue, theme),
                    const SizedBox(height: 8),
                    const fluent.Divider(),
                    const SizedBox(height: 8),
                    _buildInfoRow(strings.licenseLabel, strings.licenseValue, theme),
                    const SizedBox(height: 8),
                    const fluent.Divider(),
                    const SizedBox(height: 8),
                    fluent.ListTile(
                      title: fluent.Text(strings.debugLogTitle),
                      subtitle: fluent.Text(strings.debugLogSubtitle, style: TextStyle(color: theme.textSecondary, fontSize: 11)),
                      trailing: const Icon(fluent.FluentIcons.chevron_right, size: 14, semanticLabel: 'Open log'),
                      onPressed: () => _navigateToDebugLog(context),
                    ),
                  ],
                ),
              ),
              SizedBox(height: theme.xl),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // IOS (Cupertino Design Settings)
  // =========================================================================
  Widget _buildIOS(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final strings = ref.watch(stringsProvider);
    final currentLocaleMode = ref.watch(localeModeProvider);
    final config = ref.watch(themeConfigProvider);

    return cupertino.CupertinoPageScaffold(
      navigationBar: const cupertino.CupertinoNavigationBar(
        // Großer, natives iOS-Titel wird im Scroll-Content gerendert (Large Title).
        middle: SizedBox.shrink(),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IosTheme.largeTitle(strings.settingsTitle, theme),
              // 1. Cloud Drives Section
              cupertino.CupertinoListSection.insetGrouped(
                header: Text(strings.cloudStorage.toUpperCase()),
                children: [
                  cupertino.CupertinoListTile(
                    leading: Icon(
                      cupertino.CupertinoIcons.cloud,
                      color: theme.accent,
                      size: 22,
                      semanticLabel: strings.manageCloudDrives,
                    ),
                    title: Text(
                      strings.manageCloudDrives,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    trailing: const Icon(
                      cupertino.CupertinoIcons.chevron_forward,
                      size: 18,
                      color: cupertino.CupertinoColors.inactiveGray,
                    ),
                    onTap: () => _navigateToCloudDrives(context),
                  ),
                ],
              ),

              // 2. Network & Cellular Section
              cupertino.CupertinoListSection.insetGrouped(
                header: Text(strings.networkSectionTitle.toUpperCase()),
                children: [
                  cupertino.CupertinoListTile(
                    title: Text(strings.wifiOnlySyncLabel, style: const TextStyle(fontSize: 16)),
                    trailing: cupertino.CupertinoSwitch(
                      value: ref.watch(wifiOnlySyncProvider),
                      onChanged: (val) {
                        IosHaptics.selection();
                        ref.read(wifiOnlySyncProvider.notifier).setWifiOnly(val);
                      },
                    ),
                  ),
                ],
              ),

              // 3. Appearance & Design Section
              Semantics(
                label: strings.tooltipThemeMode,
                child: cupertino.CupertinoListSection.insetGrouped(
                  header: Text(strings.themeMode.toUpperCase()),
                  children: [
                    cupertino.CupertinoListTile(
                      title: Text(strings.syncWithSystem, style: const TextStyle(fontSize: 16)),
                      trailing: cupertino.CupertinoSwitch(
                        value: config.syncWithSystem,
                        onChanged: (val) {
                          IosHaptics.selection();
                          ref.read(themeConfigProvider.notifier).setSyncWithSystem(val);
                        },
                      ),
                    ),
                    if (!config.syncWithSystem)
                      cupertino.CupertinoListTile(
                        title: Text(strings.useDarkMode, style: const TextStyle(fontSize: 16)),
                        trailing: cupertino.CupertinoSwitch(
                          value: config.forceDarkMode,
                          onChanged: (val) {
                            IosHaptics.selection();
                            ref.read(themeConfigProvider.notifier).setForceDarkMode(val);
                          },
                        ),
                      ),
                  ],
                ),
              ),

              // Sanzo Wada Palette Swatches
              Padding(
                padding: EdgeInsets.symmetric(horizontal: theme.xl, vertical: theme.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      label: strings.tooltipWadaPalette,
                      child: Text(
                        strings.lightModeSection.toUpperCase(),
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: theme.sm),
                    _buildWadaPaletteRow(context, ref, config, false, strings),
                    SizedBox(height: theme.lg),
                    Semantics(
                      label: strings.tooltipWadaPalette,
                      child: Text(
                        strings.darkModeSection.toUpperCase(),
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: theme.sm),
                    _buildWadaPaletteRow(context, ref, config, true, strings),
                  ],
                ),
              ),

              // 4. Language Section
              Semantics(
                label: strings.tooltipLanguage,
                child: cupertino.CupertinoListSection.insetGrouped(
                  header: Text(strings.preferences.toUpperCase()),
                  children: [
                    cupertino.CupertinoListTile(
                      title: Text(strings.languageSection, style: const TextStyle(fontSize: 16)),
                      subtitle: Text(strings.systemLanguageSubtitle, style: const TextStyle(fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(currentLocaleMode.displayName, style: TextStyle(color: theme.accent, fontSize: 15)),
                          const SizedBox(width: 4),
                          const Icon(
                            cupertino.CupertinoIcons.chevron_up_chevron_down,
                            size: 14,
                            color: cupertino.CupertinoColors.inactiveGray,
                          ),
                        ],
                      ),
                      onTap: () => _showIOSLanguagePicker(context, ref, currentLocaleMode, strings),
                    ),
                  ],
                ),
              ),

              // 5. About / Über Fibu Section
              cupertino.CupertinoListSection.insetGrouped(
                header: Text(strings.aboutSectionTitle.toUpperCase()),
                children: [
                  cupertino.CupertinoListTile(
                    title: Text(strings.appVersionLabel, style: const TextStyle(fontSize: 16)),
                    trailing: Text(strings.appVersionValue, style: TextStyle(color: theme.textSecondary, fontSize: 15)),
                    onTap: () async {
                      await Clipboard.setData(
                        ClipboardData(text: strings.appVersionValue),
                      );
                      IosHaptics.success();
                    },
                  ),
                  cupertino.CupertinoListTile(
                    title: Text(strings.developerLabel, style: const TextStyle(fontSize: 16)),
                    trailing: Text(strings.developerValue, style: TextStyle(color: theme.textSecondary, fontSize: 15)),
                  ),
                  cupertino.CupertinoListTile(
                    title: Text(strings.cloudEngineLabel, style: const TextStyle(fontSize: 16)),
                    trailing: Text(strings.cloudEngineValue, style: TextStyle(color: theme.textSecondary, fontSize: 15)),
                  ),
                  cupertino.CupertinoListTile(
                    title: Text(strings.licenseLabel, style: const TextStyle(fontSize: 16)),
                    trailing: Text(strings.licenseValue, style: TextStyle(color: theme.textSecondary, fontSize: 15)),
                  ),
                  cupertino.CupertinoListTile(
                    leading: Icon(cupertino.CupertinoIcons.doc_text, color: theme.accent, size: 22),
                    title: Text(strings.debugLogTitle, style: const TextStyle(fontSize: 16)),
                    subtitle: Text(strings.debugLogSubtitle, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                    trailing: const Icon(
                      cupertino.CupertinoIcons.chevron_forward,
                      size: 18,
                      color: cupertino.CupertinoColors.inactiveGray,
                    ),
                    onTap: () {
                      IosHaptics.selection();
                      _navigateToDebugLog(context);
                    },
                  ),
                  cupertino.CupertinoListTile(
                    title: Text(strings.aboutAppTitle, style: TextStyle(color: theme.accent, fontWeight: FontWeight.w600, fontSize: 16)),
                    trailing: const Icon(
                      cupertino.CupertinoIcons.info_circle,
                      size: 20,
                      color: cupertino.CupertinoColors.inactiveGray,
                    ),
                    onTap: () => _showAboutDialog(context, strings, theme),
                  ),
                ],
              ),
              SizedBox(height: theme.xl),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // ANDROID (Material 3 Settings)
  // =========================================================================
  Widget _buildAndroid(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final strings = ref.watch(stringsProvider);
    final currentLocaleMode = ref.watch(localeModeProvider);
    final config = ref.watch(themeConfigProvider);

    return material.Scaffold(
      appBar: material.AppBar(
        title: Text(strings.settingsTitle),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(theme.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Cloud Storage
            Text(strings.cloudStorage, style: material.Theme.of(context).textTheme.titleSmall),
            SizedBox(height: theme.md),
            material.Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(theme.radiusLg),
                side: BorderSide(color: material.Theme.of(context).colorScheme.outlineVariant),
              ),
              child: material.ListTile(
                minTileHeight: 48,
                leading: Icon(material.Icons.cloud_queue, color: theme.accent, semanticLabel: strings.manageCloudDrives),
                title: Text(strings.manageCloudDrives, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Icon(material.Icons.chevron_right, color: theme.textSecondary, semanticLabel: strings.manageCloudDrives),
                onTap: () => _navigateToCloudDrives(context),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(theme.radiusSm)),
              ),
            ),
            SizedBox(height: theme.xl),

            // 2. Network & Cellular
            Text(strings.networkSectionTitle, style: material.Theme.of(context).textTheme.titleSmall),
            SizedBox(height: theme.md),
            material.Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(theme.radiusLg),
                side: BorderSide(color: material.Theme.of(context).colorScheme.outlineVariant),
              ),
              child: material.SwitchListTile(
                title: Text(strings.wifiOnlySyncLabel),
                value: ref.watch(wifiOnlySyncProvider),
                onChanged: (val) {
                  ref.read(wifiOnlySyncProvider.notifier).setWifiOnly(val);
                },
              ),
            ),
            SizedBox(height: theme.xl),

            // 3. Appearance & Design
            Text(strings.appearanceSection, style: material.Theme.of(context).textTheme.titleSmall),
            SizedBox(height: theme.md),
            material.Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(theme.radiusLg),
                side: BorderSide(color: material.Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  material.SwitchListTile(
                    title: Text(strings.syncWithSystem),
                    value: config.syncWithSystem,
                    onChanged: (val) {
                      ref.read(themeConfigProvider.notifier).setSyncWithSystem(val);
                    },
                  ),
                  if (!config.syncWithSystem) ...[
                    const material.Divider(height: 1),
                    material.SwitchListTile(
                      title: Text(strings.useDarkMode),
                      value: config.forceDarkMode,
                      onChanged: (val) {
                        ref.read(themeConfigProvider.notifier).setForceDarkMode(val);
                      },
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: theme.lg),
            material.Tooltip(
              message: strings.tooltipWadaPalette,
              child: Text(strings.lightModePalette, style: material.Theme.of(context).textTheme.titleSmall),
            ),
            SizedBox(height: theme.sm),
            _buildWadaPaletteRow(context, ref, config, false, strings),
            SizedBox(height: theme.lg),
            material.Tooltip(
              message: strings.tooltipWadaPalette,
              child: Text(strings.darkModePalette, style: material.Theme.of(context).textTheme.titleSmall),
            ),
            SizedBox(height: theme.sm),
            _buildWadaPaletteRow(context, ref, config, true, strings),
            SizedBox(height: theme.xl),

            // 4. Language
            Text(strings.preferences, style: material.Theme.of(context).textTheme.titleSmall),
            SizedBox(height: theme.md),
            material.Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(theme.radiusLg),
                side: BorderSide(color: material.Theme.of(context).colorScheme.outlineVariant),
              ),
              child: material.ListTile(
                minTileHeight: 48,
                title: Text(strings.languageSection),
                subtitle: Text(strings.systemLanguageSubtitle, style: TextStyle(fontSize: 12, color: theme.textSecondary)),
                trailing: material.DropdownButton<AppLocaleMode>(
                  value: currentLocaleMode,
                  underline: const SizedBox.shrink(),
                  items: AppLocaleMode.values.map((mode) {
                    return material.DropdownMenuItem(
                      value: mode,
                      child: Text(mode.displayName),
                    );
                  }).toList(),
                  onChanged: (mode) {
                    if (mode != null) {
                      ref.read(localeModeProvider.notifier).setLocaleMode(mode);
                    }
                  },
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(theme.radiusSm)),
              ),
            ),
            SizedBox(height: theme.xl),

            // 5. About
            Text(strings.aboutSectionTitle, style: material.Theme.of(context).textTheme.titleSmall),
            SizedBox(height: theme.md),
            material.Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(theme.radiusLg),
                side: BorderSide(color: material.Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  material.ListTile(
                    title: Text(strings.appVersionLabel),
                    trailing: Text(strings.appVersionValue, style: TextStyle(color: theme.textSecondary)),
                  ),
                  const material.Divider(height: 1),
                  material.ListTile(
                    title: Text(strings.developerLabel),
                    trailing: Text(strings.developerValue, style: TextStyle(color: theme.textSecondary)),
                  ),
                  const material.Divider(height: 1),
                  material.ListTile(
                    title: Text(strings.cloudEngineLabel),
                    trailing: Text(strings.cloudEngineValue, style: TextStyle(color: theme.textSecondary)),
                  ),
                  const material.Divider(height: 1),
                  material.ListTile(
                    title: Text(strings.licenseLabel),
                    trailing: Text(strings.licenseValue, style: TextStyle(color: theme.textSecondary)),
                  ),
                  const material.Divider(height: 1),
                  material.ListTile(
                    leading: Icon(material.Icons.article_outlined, color: theme.accent),
                    title: Text(strings.debugLogTitle),
                    subtitle: Text(strings.debugLogSubtitle, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                    trailing: const Icon(material.Icons.chevron_right),
                    onTap: () => _navigateToDebugLog(context),
                  ),
                  const material.Divider(height: 1),
                  material.ListTile(
                    title: Text(strings.aboutAppTitle, style: TextStyle(color: theme.accent, fontWeight: FontWeight.bold)),
                    trailing: const Icon(material.Icons.info_outline),
                    onTap: () => _showAboutDialog(context, strings, theme),
                  ),
                ],
              ),
            ),
            SizedBox(height: theme.xl),
          ],
        ),
      ),
    );
  }

  // --- Helper Row for Windows Info Card ---
  Widget _buildInfoRow(String label, String value, AppThemeData theme) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 28),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(value, style: TextStyle(color: theme.textSecondary)),
        ],
      ),
    );
  }

  // --- Wada Color Palette Grid Swatch Selector Row ---
  Widget _buildWadaPaletteRow(
    BuildContext context,
    WidgetRef ref,
    ThemeConfig config,
    bool isDarkRow,
    AppStrings strings,
  ) {
    final theme = context.theme;
    final platform = defaultTargetPlatform;

    final palettes = isDarkRow
        ? [null, ...SanzoWadaPalette.darkPalettes]
        : [null, ...SanzoWadaPalette.lightPalettes];

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: palettes.length,
        itemBuilder: (context, index) {
          final palette = palettes[index];
          final isSelected = isDarkRow
              ? config.selectedDarkPalette == palette
              : config.selectedLightPalette == palette;

          final cardColor = palette != null
              ? palette.surface
              : (isDarkRow ? const Color(0xff18181b) : const Color(0xffffffff));
          final textPrimaryColor = palette != null
              ? palette.textPrimary
              : (isDarkRow ? const Color(0xffffffff) : const Color(0xff1c1a17));

          final dot1Color = palette?.primary ?? (isDarkRow ? const Color(0xff0a84ff) : const Color(0xff007aff));
          final dot2Color = palette?.accent ?? (isDarkRow ? const Color(0xff30d158) : const Color(0xff34c759));
          final dot3Color = palette?.background ?? (isDarkRow ? const Color(0xff0c0c0e) : const Color(0xfffcfbfa));

          final paletteLabel = palette?.name ?? (isDarkRow ? strings.useDarkMode : strings.syncWithSystem);

          final swatchCard = GestureDetector(
            onTap: () {
              if (isDarkRow) {
                ref.read(themeConfigProvider.notifier).setDarkPalette(palette);
              } else {
                ref.read(themeConfigProvider.notifier).setLightPalette(palette);
              }
            },
            child: Semantics(
              label: palette == null
                  ? (isDarkRow ? 'Standard Dark theme' : 'Standard Light theme')
                  : 'Sanzo Wada Palette ${palette.name}',
              selected: isSelected,
              button: true,
              child: Container(
                width: 130,
                margin: EdgeInsets.only(right: theme.md),
                padding: EdgeInsets.all(theme.sm),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(theme.radiusLg),
                  border: Border.all(
                    color: isSelected ? theme.accent : theme.textSecondary.withValues(alpha: 0.2),
                    width: isSelected ? 2.5 : 1.0,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      palette?.name ?? (isDarkRow ? 'System Dark' : 'System Light'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textPrimaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildColorDot(dot1Color),
                        const SizedBox(width: 6),
                        _buildColorDot(dot2Color),
                        const SizedBox(width: 6),
                        _buildColorDot(dot3Color),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );

          if (platform == TargetPlatform.windows) {
            return fluent.Tooltip(
              message: '$paletteLabel — ${strings.tooltipWadaPalette}',
              child: swatchCard,
            );
          } else if (platform == TargetPlatform.iOS) {
            return Semantics(
              label: '$paletteLabel — ${strings.tooltipWadaPalette}',
              child: swatchCard,
            );
          }

          return material.Tooltip(
            message: '$paletteLabel — ${strings.tooltipWadaPalette}',
            child: swatchCard,
          );
        },
      ),
    );
  }

  Widget _buildColorDot(Color color) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x33000000), width: 0.5),
      ),
    );
  }
}

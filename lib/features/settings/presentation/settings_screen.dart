import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/theme.dart';
import '../../../theme/sanzo_wada_palettes.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_provider.dart';
import 'cloud_drives_screen.dart';

/// Platform-adaptive Settings screen.
/// Contains the Appearance / Design Menu enabling switching between:
/// - Sync with System theme mode or manual Light/Dark overrides.
/// - Two separate rows of Sanzo Wada color palettes (4 Light palettes & 4 Dark palettes).
/// - Manage Cloud Drives sub-page navigation.
/// - Functional Language configuration (German & English) with immediate UI update.
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

  void _showIOSLanguagePicker(BuildContext context, WidgetRef ref, AppLocale currentLocale, AppStrings strings) {
    cupertino.showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => cupertino.CupertinoActionSheet(
        title: Text(strings.languageSection),
        actions: AppLocale.values.map((loc) {
          final isSelected = loc == currentLocale;
          return cupertino.CupertinoActionSheetAction(
            onPressed: () {
              ref.read(localeProvider.notifier).setLocale(loc);
              Navigator.of(ctx).pop();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  loc.displayName,
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

  // --- Windows (Fluent Design Settings) ---
  Widget _buildWindows(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final strings = ref.watch(stringsProvider);
    final currentLocale = ref.watch(localeProvider);
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
                        Icon(fluent.FluentIcons.cloud, color: theme.accent, size: 16, semanticLabel: strings.manageCloudDrives),
                        const SizedBox(width: 12),
                        Text(strings.manageCloudDrives, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Icon(fluent.FluentIcons.chevron_right, size: 12, color: theme.textSecondary, semanticLabel: strings.manageCloudDrives),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: theme.lg),
              fluent.Text(strings.appearanceSection, style: fluent.FluentTheme.of(context).typography.subtitle),
              SizedBox(height: theme.md),
              fluent.Card(
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
              SizedBox(height: theme.lg),
              fluent.Text(strings.lightModePalette, style: fluent.FluentTheme.of(context).typography.bodyStrong),
              SizedBox(height: theme.sm),
              _buildWadaPaletteRow(context, ref, config, false),
              SizedBox(height: theme.lg),
              fluent.Text(strings.darkModePalette, style: fluent.FluentTheme.of(context).typography.bodyStrong),
              SizedBox(height: theme.sm),
              _buildWadaPaletteRow(context, ref, config, true),
              SizedBox(height: theme.xl),
              fluent.Text(strings.appConfiguration, style: fluent.FluentTheme.of(context).typography.subtitle),
              SizedBox(height: theme.md),
              fluent.Card(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Row(
                    children: [
                      Text(strings.languageSection),
                      const Spacer(),
                      fluent.ComboBox<AppLocale>(
                        value: currentLocale,
                        items: AppLocale.values.map((loc) {
                          return fluent.ComboBoxItem<AppLocale>(
                            value: loc,
                            child: Text(loc.displayName),
                          );
                        }).toList(),
                        onChanged: (loc) {
                          if (loc != null) {
                            ref.read(localeProvider.notifier).setLocale(loc);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: theme.xl),
            ],
          ),
        ),
      ],
    );
  }

  // --- iOS (Cupertino Design Settings) ---
  Widget _buildIOS(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final strings = ref.watch(stringsProvider);
    final currentLocale = ref.watch(localeProvider);
    final config = ref.watch(themeConfigProvider);

    return cupertino.CupertinoPageScaffold(
      navigationBar: cupertino.CupertinoNavigationBar(
        middle: Text(strings.settingsTitle),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              cupertino.CupertinoFormSection.insetGrouped(
                header: Text(strings.cloudStorage.toUpperCase()),
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _navigateToCloudDrives(context),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: cupertino.CupertinoFormRow(
                        prefix: Row(
                          children: [
                            Icon(
                              cupertino.CupertinoIcons.cloud,
                              color: theme.accent,
                              size: 20,
                              semanticLabel: strings.manageCloudDrives,
                            ),
                            const SizedBox(width: 8),
                            Text(strings.manageCloudDrives, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        child: const Icon(
                          cupertino.CupertinoIcons.chevron_forward,
                          size: 18,
                          color: cupertino.CupertinoColors.inactiveGray,
                          semanticLabel: 'Chevron forward',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              cupertino.CupertinoFormSection.insetGrouped(
                header: Text(strings.themeMode.toUpperCase()),
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: cupertino.CupertinoFormRow(
                      prefix: Text(strings.syncWithSystem),
                      child: cupertino.CupertinoSwitch(
                        value: config.syncWithSystem,
                        onChanged: (val) {
                          ref.read(themeConfigProvider.notifier).setSyncWithSystem(val);
                        },
                      ),
                    ),
                  ),
                  if (!config.syncWithSystem)
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: cupertino.CupertinoFormRow(
                        prefix: Text(strings.useDarkMode),
                        child: cupertino.CupertinoSwitch(
                          value: config.forceDarkMode,
                          onChanged: (val) {
                            ref.read(themeConfigProvider.notifier).setForceDarkMode(val);
                          },
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: theme.xl, vertical: theme.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      strings.lightModeSection.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: cupertino.CupertinoColors.secondaryLabel,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: theme.sm),
                    _buildWadaPaletteRow(context, ref, config, false),
                    SizedBox(height: theme.lg),
                    Text(
                      strings.darkModeSection.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: cupertino.CupertinoColors.secondaryLabel,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: theme.sm),
                    _buildWadaPaletteRow(context, ref, config, true),
                  ],
                ),
              ),
              cupertino.CupertinoFormSection.insetGrouped(
                header: Text(strings.preferences.toUpperCase()),
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showIOSLanguagePicker(context, ref, currentLocale, strings),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: cupertino.CupertinoFormRow(
                        prefix: Text(strings.languageSection),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(currentLocale.displayName, style: const TextStyle(color: cupertino.CupertinoColors.activeBlue)),
                            const SizedBox(width: 4),
                            const Icon(
                              cupertino.CupertinoIcons.chevron_up_chevron_down,
                              size: 14,
                              color: cupertino.CupertinoColors.inactiveGray,
                              semanticLabel: 'Select language',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Android (Material 3 Settings) ---
  Widget _buildAndroid(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final strings = ref.watch(stringsProvider);
    final currentLocale = ref.watch(localeProvider);
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
            SizedBox(height: theme.lg),
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
            Text(strings.lightModePalette, style: material.Theme.of(context).textTheme.titleSmall),
            SizedBox(height: theme.sm),
            _buildWadaPaletteRow(context, ref, config, false),
            SizedBox(height: theme.lg),
            Text(strings.darkModePalette, style: material.Theme.of(context).textTheme.titleSmall),
            SizedBox(height: theme.sm),
            _buildWadaPaletteRow(context, ref, config, true),
            SizedBox(height: theme.xl),
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
                trailing: material.DropdownButton<AppLocale>(
                  value: currentLocale,
                  underline: const SizedBox.shrink(),
                  items: AppLocale.values.map((loc) {
                    return material.DropdownMenuItem(
                      value: loc,
                      child: Text(loc.displayName),
                    );
                  }).toList(),
                  onChanged: (loc) {
                    if (loc != null) {
                      ref.read(localeProvider.notifier).setLocale(loc);
                    }
                  },
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(theme.radiusSm)),
              ),
            ),
            SizedBox(height: theme.xl),
          ],
        ),
      ),
    );
  }

  // --- Wada Color Palette Grid Swatch Selector Row ---
  Widget _buildWadaPaletteRow(BuildContext context, WidgetRef ref, ThemeConfig config, bool isDarkRow) {
    final theme = context.theme;

    // Build items: Standard/Default first, then the 4 curated palettes
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

          // Compute static color dots for the standard cards (null palette) to prevent bleed-through
          final dot1Color = palette?.primary ?? (isDarkRow ? const Color(0xff0a84ff) : const Color(0xff007aff));
          final dot2Color = palette?.accent ?? (isDarkRow ? const Color(0xff30d158) : const Color(0xff34c759));
          final dot3Color = palette?.background ?? (isDarkRow ? const Color(0xff0c0c0e) : const Color(0xfffcfbfa));

          return GestureDetector(
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

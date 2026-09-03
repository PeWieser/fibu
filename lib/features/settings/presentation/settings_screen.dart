import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/theme.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../theme/ios_theme.dart';
import '../../../core/utils/ios_haptics.dart';
import '../../../theme/sanzo_wada_palettes.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/services/autostart_service.dart';
import '../../../core/services/settings_service.dart';
import 'cloud_drives_screen.dart';
import 'debug_log_screen.dart';
import 'legal_documents_screen.dart';
import 'licenses_screen.dart';

/// Platform-adaptive Settings screen structured according to Apple HIG:
/// 1. Cloud Storage (Manage Cloud Drives)
/// 2. Network & Cellular (Wi-Fi Only Sync toggle)
/// 3. Appearance & Design (Sync with System, Dark mode, Sanzo Wada palettes)
/// 4. Language (System Auto / Deutsch / English)
/// 5. About (App Version, Developer, Cloud Engine, License, Credits)
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// Lokalisiertes Label eines Sprachmodus (System / Deutsch / English).
  String _localeModeLabel(AppStrings strings, AppLocaleMode mode) {
    switch (mode) {
      case AppLocaleMode.system:
        return strings.languageModeSystem;
      case AppLocaleMode.de:
        return 'Deutsch';
      case AppLocaleMode.en:
        return 'English';
    }
  }

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

  /// Öffnet alle Open-Source-Lizenzen als EIN durchscrollbares Dokument
  /// (LicenseRegistry: alle Dart-Pakete plus manuell registrierte
  /// Komponenten wie rclone/librclone und gomobile — siehe main.dart).
  void _openLicenses(BuildContext context, AppStrings strings, AppThemeData theme) {
    final platform = defaultTargetPlatform;
    final route = platform == TargetPlatform.windows
        ? fluent.FluentPageRoute(builder: (_) => const LicensesScreen())
        : (platform == TargetPlatform.iOS
            ? cupertino.CupertinoPageRoute(builder: (_) => const LicensesScreen())
            : material.MaterialPageRoute(builder: (_) => const LicensesScreen()));
    Navigator.of(context).push(route);
  }

  /// Öffnet einen statischen Rechtstext (Datenschutzerklärung / Impressum).
  void _openLegalDocument(
    BuildContext context,
    String title,
    List<LegalDocSection> sections,
  ) {
    final screen = LegalDocumentScreen(title: title, sections: sections);
    final platform = defaultTargetPlatform;
    final route = platform == TargetPlatform.windows
        ? fluent.FluentPageRoute(builder: (_) => screen)
        : (platform == TargetPlatform.iOS
            ? cupertino.CupertinoPageRoute(builder: (_) => screen)
            : material.MaterialPageRoute(builder: (_) => screen));
    Navigator.of(context).push(route);
  }

  void _showIOSLanguagePicker(BuildContext context, WidgetRef ref, AppLocaleMode currentMode, AppStrings strings) {
    cupertino.showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => cupertino.CupertinoActionSheet(
        title: Text(strings.languageSection),
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
                  _localeModeLabel(strings, mode),
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
                message: strings.tooltipNetwork,
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
              SizedBox(height: theme.md),
              // Autostart: ohne ihn läuft der Zeitplan nur, solange die App
              // von Hand geöffnet ist. Der Schalter schreibt den Run-Schlüssel
              // des eigenen Benutzerkontums (keine Admin-Rechte nötig).
              fluent.Card(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(strings.autostartLabel,
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            SizedBox(height: theme.xs / 2),
                            Text(
                              strings.autostartDescription,
                              style: TextStyle(
                                  color: theme.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: theme.md),
                      ref.watch(autostartEnabledProvider).when(
                            data: (on) => fluent.ToggleSwitch(
                              checked: on,
                              onChanged: (val) =>
                                  setAutostartEnabled(ref, val),
                            ),
                            loading: () => const fluent.ProgressRing(
                                strokeWidth: 2),
                            error: (_, __) => Text(strings.error,
                                style: TextStyle(
                                    color: theme.error, fontSize: 11)),
                          ),
                    ],
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
                              child: Text(_localeModeLabel(strings, mode)),
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

              // 6. Rechtliches
              fluent.Text(strings.legalSectionTitle, style: fluent.FluentTheme.of(context).typography.subtitle),
              SizedBox(height: theme.md),
              fluent.Card(
                child: fluent.ListTile(
                  title: fluent.Text(strings.openSourceLicenses),
                  subtitle: fluent.Text(strings.openSourceLicensesSubtitle, style: TextStyle(color: theme.textSecondary, fontSize: 11)),
                  trailing: const Icon(fluent.FluentIcons.chevron_right, size: 14, semanticLabel: 'Open licenses'),
                  onPressed: () => _openLicenses(context, strings, theme),
                ),
              ),
              SizedBox(height: theme.sm),
              fluent.Card(
                child: fluent.ListTile(
                  title: fluent.Text(strings.privacyNoticeTitle),
                  subtitle: fluent.Text(strings.privacyNoticeSubtitle, style: TextStyle(color: theme.textSecondary, fontSize: 11)),
                  trailing: const Icon(fluent.FluentIcons.chevron_right, size: 14, semanticLabel: 'Open privacy policy'),
                  onPressed: () => _openLegalDocument(
                    context,
                    strings.privacyNoticeTitle,
                    LegalDocuments.privacy(strings.isGerman),
                  ),
                ),
              ),
              SizedBox(height: theme.sm),
              fluent.Card(
                child: fluent.ListTile(
                  title: fluent.Text(strings.imprintTitle),
                  subtitle: fluent.Text(strings.imprintSubtitle, style: TextStyle(color: theme.textSecondary, fontSize: 11)),
                  trailing: const Icon(fluent.FluentIcons.chevron_right, size: 14, semanticLabel: 'Open imprint'),
                  onPressed: () => _openLegalDocument(
                    context,
                    strings.imprintTitle,
                    LegalDocuments.imprint(strings.isGerman),
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

  // =========================================================================
  // IOS (Cupertino Design Settings)
  // =========================================================================
  Widget _buildIOS(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final strings = ref.watch(stringsProvider);
    final currentLocaleMode = ref.watch(localeModeProvider);
    final config = ref.watch(themeConfigProvider);

    // Large Title mit fixierter Navigationsleiste: Der Titel bleibt beim
    // Scrollen sichtbar (er kollabiert in die kompakte Leiste, HIG-konform).
    return cupertino.CupertinoPageScaffold(
      backgroundColor: theme.canvas,
      child: CustomScrollView(
        slivers: [
          cupertino.CupertinoSliverNavigationBar(
            largeTitle: Text(strings.settingsTitle),
            backgroundColor: iosBarBackground(ref, theme),
          ),
          SliverSafeArea(
            top: false,
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              // 1. Cloud Drives Section
              cupertino.CupertinoListSection.insetGrouped(
                backgroundColor: theme.surface,
                header: IosTheme.sectionHeader(strings.cloudStorage, theme),
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
                backgroundColor: theme.surface,
                header: IosTheme.sectionHeader(strings.networkSectionTitle, theme),
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
                  backgroundColor: theme.surface,
                  header: IosTheme.sectionHeader(strings.themeMode, theme),
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
                        strings.lightModeSection,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.textSecondary,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    SizedBox(height: theme.sm),
                    _buildWadaPaletteRow(context, ref, config, false, strings),
                    SizedBox(height: theme.lg),
                    Semantics(
                      label: strings.tooltipWadaPalette,
                      child: Text(
                        strings.darkModeSection,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.textSecondary,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
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
                  backgroundColor: theme.surface,
                  header: IosTheme.sectionHeader(strings.preferences, theme),
                  children: [
                    cupertino.CupertinoListTile(
                      title: Text(strings.languageSection, style: const TextStyle(fontSize: 16)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_localeModeLabel(strings, currentLocaleMode), style: TextStyle(color: theme.accent, fontSize: 15)),
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
                backgroundColor: theme.surface,
                header: IosTheme.sectionHeader(strings.aboutSectionTitle, theme),
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
                ],
              ),

              // 6. Rechtliches — ganz unten, wie es sich gehört.
              cupertino.CupertinoListSection.insetGrouped(
                backgroundColor: theme.surface,
                header: IosTheme.sectionHeader(strings.legalSectionTitle, theme),
                children: [
                  cupertino.CupertinoListTile(
                    leading: Icon(cupertino.CupertinoIcons.doc_plaintext, color: theme.accent, size: 22),
                    title: Text(strings.openSourceLicenses, style: const TextStyle(fontSize: 16)),
                    subtitle: Text(strings.openSourceLicensesSubtitle, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                    trailing: const Icon(
                      cupertino.CupertinoIcons.chevron_forward,
                      size: 18,
                      color: cupertino.CupertinoColors.inactiveGray,
                    ),
                    onTap: () {
                      IosHaptics.selection();
                      _openLicenses(context, strings, theme);
                    },
                  ),
                  cupertino.CupertinoListTile(
                    leading: Icon(cupertino.CupertinoIcons.eye, color: theme.accent, size: 22),
                    title: Text(strings.privacyNoticeTitle, style: const TextStyle(fontSize: 16)),
                    subtitle: Text(strings.privacyNoticeSubtitle, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                    trailing: const Icon(
                      cupertino.CupertinoIcons.chevron_forward,
                      size: 18,
                      color: cupertino.CupertinoColors.inactiveGray,
                    ),
                    onTap: () {
                      IosHaptics.selection();
                      _openLegalDocument(
                        context,
                        strings.privacyNoticeTitle,
                        LegalDocuments.privacy(strings.isGerman),
                      );
                    },
                  ),
                  cupertino.CupertinoListTile(
                    leading: Icon(cupertino.CupertinoIcons.info_circle, color: theme.accent, size: 22),
                    title: Text(strings.imprintTitle, style: const TextStyle(fontSize: 16)),
                    subtitle: Text(strings.imprintSubtitle, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                    trailing: const Icon(
                      cupertino.CupertinoIcons.chevron_forward,
                      size: 18,
                      color: cupertino.CupertinoColors.inactiveGray,
                    ),
                    onTap: () {
                      IosHaptics.selection();
                      _openLegalDocument(
                        context,
                        strings.imprintTitle,
                        LegalDocuments.imprint(strings.isGerman),
                      );
                    },
                  ),
                ],
              ),
                  SizedBox(height: theme.xl),
                ],
              ),
            ),
          ),
        ],
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
                trailing: material.DropdownButton<AppLocaleMode>(
                  value: currentLocaleMode,
                  underline: const SizedBox.shrink(),
                  items: AppLocaleMode.values.map((mode) {
                    return material.DropdownMenuItem(
                      value: mode,
                      child: Text(_localeModeLabel(strings, mode)),
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
                ],
              ),
            ),
            SizedBox(height: theme.xl),

            // 6. Rechtliches
            Text(strings.legalSectionTitle, style: material.Theme.of(context).textTheme.titleSmall),
            SizedBox(height: theme.md),
            material.Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(theme.radiusLg),
                side: BorderSide(color: material.Theme.of(context).colorScheme.outlineVariant),
              ),
              child: material.ListTile(
                leading: Icon(material.Icons.gavel_outlined, color: theme.accent),
                title: Text(strings.openSourceLicenses),
                subtitle: Text(strings.openSourceLicensesSubtitle, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                trailing: const Icon(material.Icons.chevron_right),
                onTap: () => _openLicenses(context, strings, theme),
              ),
            ),
            SizedBox(height: theme.sm),
            material.Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(theme.radiusLg),
                side: BorderSide(color: material.Theme.of(context).colorScheme.outlineVariant),
              ),
              child: material.ListTile(
                leading: Icon(material.Icons.visibility, color: theme.accent),
                title: Text(strings.privacyNoticeTitle),
                subtitle: Text(strings.privacyNoticeSubtitle, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                trailing: const Icon(material.Icons.chevron_right),
                onTap: () => _openLegalDocument(
                  context,
                  strings.privacyNoticeTitle,
                  LegalDocuments.privacy(strings.isGerman),
                ),
              ),
            ),
            SizedBox(height: theme.sm),
            material.Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(theme.radiusLg),
                side: BorderSide(color: material.Theme.of(context).colorScheme.outlineVariant),
              ),
              child: material.ListTile(
                leading: Icon(material.Icons.info_outline, color: theme.accent),
                title: Text(strings.imprintTitle),
                subtitle: Text(strings.imprintSubtitle, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                trailing: const Icon(material.Icons.chevron_right),
                onTap: () => _openLegalDocument(
                  context,
                  strings.imprintTitle,
                  LegalDocuments.imprint(strings.isGerman),
                ),
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

    final palettes = [null, ...SanzoWadaPalette.values];

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

          // Modusgerechtes Farb-Set: Die Hell-Reihe zeigt das Light-Set,
          // die Dunkel-Reihe das Dark-Set — so ist sofort sichtbar, wie die
          // Palette im jeweiligen Modus aussieht (grün bleibt grün).
          final cardColor = palette != null
              ? (isDarkRow ? palette.darkSurface : palette.lightSurface)
              : (isDarkRow ? AppThemeData.dark.surface : AppThemeData.light.surface);
          final textPrimaryColor = palette != null
              ? (isDarkRow ? palette.darkTextPrimary : palette.lightTextPrimary)
              : (isDarkRow ? AppThemeData.dark.textPrimary : AppThemeData.light.textPrimary);

          final dot1Color = palette?.accentFor(isDarkRow) ??
              (isDarkRow ? AppThemeData.dark.accent : AppThemeData.light.accent);
          final dot2Color = palette?.secondary ??
              (isDarkRow ? AppThemeData.dark.success : AppThemeData.light.success);
          final dot3Color = palette != null
              ? (isDarkRow ? palette.darkTextSecondary : palette.lightTextSecondary)
              : (isDarkRow ? AppThemeData.dark.textSecondary : AppThemeData.light.textSecondary);

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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/theme.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/navigation/app_nav.dart';
import '../../../core/widgets/windows_controls.dart';
import '../../../theme/ios_theme.dart';
import '../../../core/utils/ios_haptics.dart';
import '../../../theme/sanzo_wada_palettes.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/services/autostart_service.dart';
import 'device_pairing_screen.dart';
import '../../../core/services/settings_service.dart';
import 'cloud_drives_screen.dart';
import 'debug_log_screen.dart';
import 'legal_documents_screen.dart';
import 'licenses_screen.dart';

/// Platform-adaptive Settings screen structured according to Apple HIG:
/// 1. Cloud Storage (Manage Cloud Drives)
/// 2. Network & Cellular (Wi-Fi Only Sync toggle)
/// 3. Appearance & Design (eine Palette — Hell/Dunkel folgt dem System)
/// 4. Language (System Auto / Deutsch / English) — liegt bei 3.
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

  // Alle fünf Ziele öffnen über [AppNav.push]: eine Plattform-Weiche für das
  // ganze Projekt statt einer pro Ziel. Die Übergänge bleiben plattformeigen.

  /// Gerät-zu-Gerät-Übertragung der Konfiguration.
  void _navigateToPairing(BuildContext context) =>
      AppNav.push(context, const DevicePairingScreen());

  void _navigateToCloudDrives(BuildContext context) =>
      AppNav.push(context, const CloudDrivesScreen());

  void _navigateToDebugLog(BuildContext context) =>
      AppNav.push(context, const DebugLogScreen());

  /// Öffnet alle Open-Source-Lizenzen als EIN durchscrollbares Dokument
  /// (LicenseRegistry: alle Dart-Pakete plus manuell registrierte
  /// Komponenten wie rclone/librclone und gomobile — siehe main.dart).
  void _openLicenses(BuildContext context) =>
      AppNav.push(context, const LicensesScreen());

  /// Öffnet einen statischen Rechtstext (Datenschutzerklärung / Impressum).
  void _openLegalDocument(
    BuildContext context,
    String title,
    List<LegalDocSection> sections,
  ) =>
      AppNav.push(
          context, LegalDocumentScreen(title: title, sections: sections));

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
              Win.sectionHeader(strings.cloudStorage, theme),
              Win.group(
                theme: theme,
                children: [
                  // Echte ListTile statt GestureDetector: bringt Tastaturfokus,
                  // Semantik und Fokus-Ring selbst mit.
                  Win.tile(
                    theme: theme,
                    title: strings.manageCloudDrives,
                    subtitle: strings.manageCloudDrivesSubtitle,
                    leading: fluent.FluentIcons.cloud,
                    trailing: const Icon(fluent.FluentIcons.chevron_right, size: 12),
                    onPressed: () => _navigateToCloudDrives(context),
                    semanticLabel: strings.manageCloudDrives,
                    first: true,
                  ),
                  Win.tile(
                    theme: theme,
                    title: strings.pairingTitle,
                    subtitle: strings.pairingSubtitle,
                    leading: fluent.FluentIcons.sync,
                    trailing: const Icon(fluent.FluentIcons.chevron_right, size: 12),
                    onPressed: () => _navigateToPairing(context),
                    semanticLabel: strings.pairingTitle,
                    last: true,
                  ),
                ],
              ),

              // 2. Network & Cellular
              fluent.Text(strings.networkSectionTitle, style: fluent.FluentTheme.of(context).typography.subtitle),
              SizedBox(height: theme.md),
              Win.group(
                theme: theme,
                children: [
                  Win.toggle(
                    theme: theme,
                    title: strings.wifiOnlySyncLabel,
                    subtitle: strings.tooltipNetwork,
                    value: ref.watch(wifiOnlySyncProvider),
                    onChanged: (val) =>
                        ref.read(wifiOnlySyncProvider.notifier).setWifiOnly(val),
                    first: true,
                  ),
                  // Autostart: ohne ihn läuft der Zeitplan nur, solange die App
                  // von Hand geöffnet ist. Der Schalter schreibt den
                  // Run-Schlüssel des eigenen Benutzerkontos (keine
                  // Admin-Rechte nötig).
                  Win.toggle(
                    theme: theme,
                    title: strings.autostartLabel,
                    subtitle: strings.autostartDescription,
                    value: ref.watch(autostartEnabledProvider).valueOrNull ?? false,
                    // Solange der Registry-Wert noch nicht gelesen ist, ist der
                    // Schalter deaktiviert — er soll keinen Zustand behaupten,
                    // den er nicht kennt. Bewusst kein ProgressRing: Der ist
                    // eine Endlos-Animation, an der pumpAndSettle in Tests nie
                    // zur Ruhe kommt.
                    onChanged: ref.watch(autostartEnabledProvider).isLoading
                        ? null
                        : (val) => setAutostartEnabled(ref, val),
                    last: true,
                  ),
                ],
              ),
              SizedBox(height: theme.xl),

              // 3. Erscheinungsbild: eine Palette, Hell/Dunkel folgt dem
              // System. Zwei Reihen (Hell/Dunkel) plus zwei Modus-Schalter
              // wären 18 Entscheidungen für etwas, das man einmal festlegt.
              Win.sectionHeader(strings.appearanceSection, theme),
              Win.group(
                theme: theme,
                children: [
                  Padding(
                    padding:
                        EdgeInsets.fromLTRB(theme.md, theme.md, theme.md, 0),
                    child: Text(
                      strings.appearanceAutoHint,
                      style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 12,
                          height: 1.4),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        theme.md, theme.sm, theme.md, theme.md),
                    child: _buildPaletteRow(context, ref, config, strings),
                  ),
                ],
              ),

              // Sprache gehoert zum Erscheinungsbild, nicht in eine eigene
              // Sektion: Eine Sektion mit genau einem Eintrag kostet
              // Ueberschrift und Rahmen fuer nichts.
              Win.tile(
                theme: theme,
                title: strings.languageSection,
                subtitle: strings.tooltipLanguage,
                trailing: fluent.ComboBox<AppLocaleMode>(
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
              ),
              SizedBox(height: theme.xl),

              // 5. About
              Win.sectionHeader(strings.aboutSectionTitle, theme),
              Win.group(
                theme: theme,
                children: [
                  Win.infoRow(
                      theme: theme,
                      label: strings.appVersionLabel,
                      value: strings.appVersionValue),
                  Win.infoRow(
                      theme: theme,
                      label: strings.developerLabel,
                      value: strings.developerValue),
                  Win.infoRow(
                      theme: theme,
                      label: strings.cloudEngineLabel,
                      value: strings.cloudEngineValue),
                  Win.infoRow(
                      theme: theme,
                      label: strings.licenseLabel,
                      value: strings.licenseValue),
                  Win.tile(
                    theme: theme,
                    title: strings.debugLogTitle,
                    subtitle: strings.debugLogSubtitle,
                    leading: fluent.FluentIcons.document,
                    trailing:
                        const Icon(fluent.FluentIcons.chevron_right, size: 14),
                    onPressed: () => _navigateToDebugLog(context),
                    semanticLabel: strings.debugLogTitle,
                    last: true,
                  ),
                ],
              ),

              // 6. Rechtliches
              Win.sectionHeader(strings.legalSectionTitle, theme),
              Win.group(
                theme: theme,
                children: [
                  Win.tile(
                    theme: theme,
                    title: strings.openSourceLicenses,
                    subtitle: strings.openSourceLicensesSubtitle,
                    leading: fluent.FluentIcons.page,
                    trailing:
                        const Icon(fluent.FluentIcons.chevron_right, size: 14),
                    onPressed: () => _openLicenses(context),
                    semanticLabel: strings.openSourceLicenses,
                    first: true,
                  ),
                  Win.tile(
                    theme: theme,
                    title: strings.privacyNoticeTitle,
                    subtitle: strings.privacyNoticeSubtitle,
                    leading: fluent.FluentIcons.red_eye,
                    trailing:
                        const Icon(fluent.FluentIcons.chevron_right, size: 14),
                    onPressed: () => _openLegalDocument(
                      context,
                      strings.privacyNoticeTitle,
                      LegalDocuments.privacy(strings.isGerman),
                    ),
                    semanticLabel: strings.privacyNoticeTitle,
                  ),
                  Win.tile(
                    theme: theme,
                    title: strings.imprintTitle,
                    subtitle: strings.imprintSubtitle,
                    leading: fluent.FluentIcons.info,
                    trailing:
                        const Icon(fluent.FluentIcons.chevron_right, size: 14),
                    onPressed: () => _openLegalDocument(
                      context,
                      strings.imprintTitle,
                      LegalDocuments.imprint(strings.isGerman),
                    ),
                    semanticLabel: strings.imprintTitle,
                    last: true,
                  ),
                ],
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
                  cupertino.CupertinoListTile(
                    leading: Icon(cupertino.CupertinoIcons.arrow_2_squarepath,
                        color: theme.accent, size: 22),
                    title: Text(strings.pairingTitle,
                        style: const TextStyle(fontSize: 16)),
                    trailing: const Icon(
                      cupertino.CupertinoIcons.chevron_forward,
                      size: 18,
                      color: cupertino.CupertinoColors.inactiveGray,
                    ),
                    onTap: () => _navigateToPairing(context),
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

              // 3. Erscheinungsbild: eine Palette, Hell/Dunkel folgt dem
              // System. Kein Modus-Schalter, keine zweite Reihe — die
              // gewählte Palette bringt beide Farbsets mit.
              Padding(
                padding: EdgeInsets.symmetric(horizontal: theme.xl, vertical: theme.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    IosTheme.sectionHeader(strings.appearanceSection, theme),
                    Text(
                      strings.appearanceAutoHint,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: theme.sm),
                    _buildPaletteRow(context, ref, config, strings),
                    // Sprache gehoert hierher. Eine eigene Sektion mit genau
                    // einem Eintrag kostet Ueberschrift und Rahmen fuer nichts
                    // und zwingt zum Scrollen, wo eine Zeile gereicht haette.
                    // Keine eigene Trennlinie: CupertinoListSection zieht sie
                    // zwischen den Zeilen selbst.
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
                      _openLicenses(context);
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
            SizedBox(height: theme.sm),
            material.Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(theme.radiusLg),
                side: BorderSide(color: material.Theme.of(context).colorScheme.outlineVariant),
              ),
              child: material.ListTile(
                minTileHeight: 48,
                leading: Icon(material.Icons.swap_horiz, color: theme.accent),
                title: Text(strings.pairingTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Icon(material.Icons.chevron_right,
                    color: theme.textSecondary),
                onTap: () => _navigateToPairing(context),
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

            // 3. Erscheinungsbild: eine Palette, Hell/Dunkel folgt dem System
            Text(strings.appearanceSection, style: material.Theme.of(context).textTheme.titleSmall),
            SizedBox(height: theme.xs),
            Text(
              strings.appearanceAutoHint,
              style: TextStyle(color: theme.textSecondary, fontSize: 12, height: 1.4),
            ),
            SizedBox(height: theme.md),
            _buildPaletteRow(context, ref, config, strings),
            // Sprache gehoert zum Erscheinungsbild, nicht in eine eigene
            // Sektion: Eine Sektion mit genau einem Eintrag kostet
            // Ueberschrift und Rahmen fuer nichts.
            material.ListTile(
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
                onTap: () => _openLicenses(context),
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

  // --- Farbwähler: eine Reihe für beide Modi ------------------------------

  /// Eine Reihe Farbwähler: Standard plus die acht Sanzo-Wada-Paletten.
  ///
  /// **Eine Wahl gilt für Hell und Dunkel.** Früher gab es zwei Reihen
  /// (Hell-Palette, Dunkel-Palette) — dieselben acht Paletten zweimal, und
  /// wer beide gleich wollte, musste zweimal dasselbe tippen. Jetzt zeigt die
  /// Vorschau das Farbset des Modus, der gerade aktiv ist: schaltet das
  /// System um, zeigt dieselbe Reihe die andere Seite derselben Palette.
  Widget _buildPaletteRow(
    BuildContext context,
    WidgetRef ref,
    ThemeConfig config,
    AppStrings strings,
  ) {
    final theme = context.theme;
    final platform = defaultTargetPlatform;
    // Aktiver Modus — dieselbe Regel wie in main.dart: die Helligkeit des
    // aufgelösten Canvas. So zeigt die Vorschau immer das, was gilt.
    final isDark = theme.canvas.computeLuminance() < 0.5;

    final palettes = [null, ...SanzoWadaPalette.values];

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: palettes.length,
        itemBuilder: (context, index) {
          final palette = palettes[index];
          final isSelected = config.selectedPalette == palette;

          // Farbset des aktiven Modus: Die Vorschau zeigt, wie die Palette
          // hier und jetzt aussieht — nicht zwei Varianten nebeneinander.
          final cardColor = palette?.surfaceFor(isDark) ??
              (isDark ? AppThemeData.dark.surface : AppThemeData.light.surface);
          final textPrimaryColor = palette != null
              ? (isDark ? palette.darkTextPrimary : palette.lightTextPrimary)
              : (isDark
                  ? AppThemeData.dark.textPrimary
                  : AppThemeData.light.textPrimary);

          final dot1Color = palette?.accentFor(isDark) ??
              (isDark ? AppThemeData.dark.accent : AppThemeData.light.accent);
          final dot2Color = palette?.secondary ??
              (isDark ? AppThemeData.dark.success : AppThemeData.light.success);
          final dot3Color = palette != null
              ? (isDark ? palette.darkTextSecondary : palette.lightTextSecondary)
              : (isDark
                  ? AppThemeData.dark.textSecondary
                  : AppThemeData.light.textSecondary);

          final paletteLabel = palette?.name ?? strings.paletteStandard;

          final swatchCard = GestureDetector(
            onTap: () => ref.read(themeConfigProvider.notifier).setPalette(palette),
            child: Semantics(
              label: paletteLabel,
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
                    color: isSelected
                        ? theme.accent
                        : theme.textSecondary.withValues(alpha: 0.2),
                    width: isSelected ? 2.5 : 1.0,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      paletteLabel,
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

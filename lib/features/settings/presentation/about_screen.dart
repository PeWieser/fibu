import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/navigation/app_nav.dart';
import '../../../core/utils/ios_haptics.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../theme/ios_theme.dart';
import '../../../theme/theme.dart';
import 'legal_documents_screen.dart';
import 'licenses_screen.dart';

/// „Über Fibu" auf iOS: Fakten und Rechtliches — zwei Gruppen, keine
/// Erklärtexte. Was weiterführt, hat einen Pfeil; was eine Tatsache ist,
/// steht einfach da. Diese Bündelung hält die Einstellungen kurz: acht
/// Zeilen verschwinden hinter einem Eintrag.
class IosAboutScreen extends ConsumerWidget {
  const IosAboutScreen({super.key});

  void _openLicenses(BuildContext context) =>
      AppNav.push(context, const LicensesScreen());

  void _openLegalDocument(
    BuildContext context,
    String title,
    List<LegalDocSection> sections,
  ) =>
      AppNav.push(
          context, LegalDocumentScreen(title: title, sections: sections));

  /// Zeile ohne Weg: eine Tatsache, kein Ziel.
  Widget _factRow(AppThemeData theme, String label, String value) {
    return cupertino.CupertinoListTile(
      title: Text(label, style: const TextStyle(fontSize: 16)),
      trailing:
          Text(value, style: TextStyle(color: theme.textSecondary, fontSize: 15)),
    );
  }

  /// Zeile mit Weg: ein Ziel, ein Pfeil.
  Widget _linkRow(String label, {required VoidCallback onTap}) {
    return cupertino.CupertinoListTile(
      title: Text(label, style: const TextStyle(fontSize: 16)),
      trailing: const Icon(
        cupertino.CupertinoIcons.chevron_forward,
        size: 18,
        color: cupertino.CupertinoColors.inactiveGray,
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final strings = ref.watch(stringsProvider);

    return cupertino.CupertinoPageScaffold(
      backgroundColor: theme.canvas,
      child: CustomScrollView(
        slivers: [
          cupertino.CupertinoSliverNavigationBar(
            largeTitle: Text(strings.aboutSectionTitle),
            backgroundColor: iosBarBackground(ref, theme),
          ),
          SliverSafeArea(
            top: false,
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  cupertino.CupertinoListSection.insetGrouped(
                    backgroundColor: theme.surface,
                    children: [
                      _factRow(
                          theme, strings.appVersionLabel, strings.appVersionValue),
                      _factRow(
                          theme, strings.developerLabel, strings.developerValue),
                      _factRow(theme, strings.cloudEngineLabel,
                          strings.cloudEngineValue),
                      _factRow(
                          theme, strings.licenseLabel, strings.licenseValue),
                    ],
                  ),
                  cupertino.CupertinoListSection.insetGrouped(
                    backgroundColor: theme.surface,
                    header: IosTheme.sectionHeader(strings.legalSectionTitle, theme),
                    children: [
                      _linkRow(
                        strings.openSourceLicenses,
                        onTap: () {
                          IosHaptics.selection();
                          _openLicenses(context);
                        },
                      ),
                      _linkRow(
                        strings.privacyNoticeTitle,
                        onTap: () {
                          IosHaptics.selection();
                          _openLegalDocument(
                            context,
                            strings.privacyNoticeTitle,
                            LegalDocuments.privacy(strings.isGerman),
                          );
                        },
                      ),
                      _linkRow(
                        strings.imprintTitle,
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
}

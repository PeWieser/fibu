import 'dart:io';

import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fibu/core/localization/app_strings.dart';
import 'package:fibu/core/localization/locale_provider.dart';
import 'package:fibu/core/services/active_cloud.dart';
import 'package:fibu/core/services/mock_rclone_service.dart';
import 'package:fibu/core/services/rclone_provider.dart';
import 'package:fibu/features/settings/presentation/settings_screen.dart';
import '../helpers/platform_mocks.dart';

/// Die iOS-Einstellungen als kurze, lesbare Liste:
/// Cloud · Sicherung · Darstellung · Allgemein · Über.
///
/// Der Test hält die Struktur fest, damit sie nicht wieder zerfasert:
/// jedes Ziel genau einmal, keine Untertitel in „Allgemein“, und die
/// Fakten/Rechtliches-Ebene liegt hinter „Über Fibu“.
void main() {
  late Directory mockDir;
  setUpAll(() async {
    mockDir = await installPathProviderMock();
  });
  tearDownAll(() async {
    await removePathProviderMock(mockDir);
  });

  const strings = AppStrings(AppLocale.de);

  testWidgets('jedes Ziel genau einmal — und alles Weitere hinter „Über Fibu“',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final mockRcloneService = MockRcloneService();
      addTearDown(mockRcloneService.dispose);
      final container = ProviderContainer(overrides: [
        localeProvider.overrideWith((ref) => AppLocale.de),
        rcloneServiceProvider.overrideWithValue(mockRcloneService),
        // Eine Cloud ist da — sonst kleidet sich die Sicherungs-Sektion als
        // „Sicherung“-Kachel und der Kopfzeilen-Zählung wäre nicht zu trauen.
        activeRemoteIdProvider
            .overrideWith((ref) async => 'fibu-test-cloud'),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const cupertino.CupertinoApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Die vier Kopfzeilen der Hauptliste.
      expect(find.text(strings.cloudSection), findsOneWidget);
      expect(find.text(strings.backupSection), findsOneWidget);
      expect(find.text(strings.appearanceSection), findsOneWidget);
      expect(find.text(strings.generalSectionTitle), findsOneWidget);

      // Allgemein: zwei Ziele, keine Untertitel — und kein „System“ mehr.
      expect(find.text(strings.systemSection), findsNothing);
      expect(find.text(strings.pairingTitle), findsOneWidget);
      expect(find.text(strings.debugLogTitle), findsOneWidget);
      expect(find.text(strings.pairingSubtitle), findsNothing);
      expect(find.text(strings.debugLogSubtitle), findsNothing);

      // „Über Fibu“ ist die einzige Zeile, die weiterführt. Fakten und
      // Rechtliches stehen eine Ebene tiefer — nicht mehr hier.
      expect(find.text(strings.aboutSectionTitle), findsOneWidget);
      expect(find.text(strings.appVersionLabel), findsNothing);
      expect(find.text(strings.openSourceLicenses), findsNothing);
      expect(find.text(strings.privacyNoticeTitle), findsNothing);
      expect(find.text(strings.imprintTitle), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

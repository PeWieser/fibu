import 'dart:io';

import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fibu/core/localization/app_strings.dart';
import 'package:fibu/core/localization/locale_provider.dart';
import 'package:fibu/features/settings/presentation/about_screen.dart';
import '../helpers/platform_mocks.dart';

/// „Über Fibu“ auf iOS: die gebündelte Ablage für Fakten und Rechtliches.
///
/// Die Seite ist bewusst statisch (nur Präsentation plus drei Wege) — mehr
/// Logik steckt nicht darin, mehr wird hier nicht geprüft.
void main() {
  late Directory mockDir;
  setUpAll(() async {
    mockDir = await installPathProviderMock();
  });
  tearDownAll(() async {
    await removePathProviderMock(mockDir);
  });

  const strings = AppStrings(AppLocale.de);

  testWidgets('zeigt Fakten und Rechtliches — ohne Erklärtexte',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final container = ProviderContainer(overrides: [
        localeProvider.overrideWith((ref) => AppLocale.de),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const cupertino.CupertinoApp(
            home: IosAboutScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Fakten: vier Zeilen, keine davon ein Ziel.
      expect(find.text(strings.appVersionLabel), findsOneWidget);
      expect(find.text(strings.developerLabel), findsOneWidget);
      expect(find.text(strings.cloudEngineLabel), findsOneWidget);
      expect(find.text(strings.licenseLabel), findsOneWidget);

      // Rechtliches: drei Wege ohne Untertitel-Lawine.
      expect(find.text(strings.legalSectionTitle), findsOneWidget);
      expect(find.text(strings.openSourceLicenses), findsOneWidget);
      expect(find.text(strings.privacyNoticeTitle), findsOneWidget);
      expect(find.text(strings.imprintTitle), findsOneWidget);
      expect(find.text(strings.openSourceLicensesSubtitle), findsNothing);
      expect(find.text(strings.privacyNoticeSubtitle), findsNothing);
      expect(find.text(strings.imprintSubtitle), findsNothing);

      // Ein Weg ins Dokument darf nichts kaputt machen.
      await tester.tap(find.text(strings.imprintTitle));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

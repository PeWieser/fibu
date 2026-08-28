import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fibu/core/localization/app_strings.dart';
import 'package:fibu/core/localization/locale_provider.dart';
import 'package:fibu/core/services/mock_rclone_service.dart';
import 'package:fibu/features/settings/presentation/settings_screen.dart';
import 'package:fibu/theme/theme.dart';
import 'package:fibu/theme/sanzo_wada_palettes.dart';
import '../helpers/platform_mocks.dart';
import 'package:fibu/features/tasks/presentation/tasks_controller.dart';

void main() {
  // path_provider mocken: Die Screens lesen tasks.json / settings.json und
  // den Mirror-Zustand darüber — ohne Mock gäbe es MissingPluginException.
  late Directory mockDir;
  setUpAll(() async {
    mockDir = await installPathProviderMock();
  });
  tearDownAll(() async {
    await removePathProviderMock(mockDir);
  });

  group('Theme Configurations & Design Menu Tests', () {
    late MockRcloneService mockRcloneService;
    const strings = AppStrings(AppLocale.de);

    setUp(() {
      mockRcloneService = MockRcloneService();
    });

    tearDown(() {
      mockRcloneService.dispose();
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Toggling Wada Palettes changes theme configuration state', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      
      try {
        final container = ProviderContainer(overrides: [
          tasksLoadedProvider.overrideWith((ref) => true),
          localeModeProvider.overrideWith((ref) => AppLocaleMode.de),
        ]);
        
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const fluent.FluentApp(
              home: SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check initial configuration (no custom light/dark palette)
        expect(container.read(themeConfigProvider).selectedLightPalette, isNull);
        expect(container.read(themeConfigProvider).selectedDarkPalette, isNull);
        
        // Tap on Autumn Aki palette swatch card. Identify by text Aki (Autumn)
        final akiFinder = find.text('Aki (Autumn)');
        expect(akiFinder, findsOneWidget);
        await tester.tap(akiFinder);
        await tester.pumpAndSettle();

        // Check that selectedLightPalette state is updated to autumnAki
        expect(container.read(themeConfigProvider).selectedLightPalette, equals(SanzoWadaPalette.autumnAki));
        
        // Tap on Fuyu (Winter) palette card in the Dark row
        final fuyuFinder = find.text('Fuyu (Winter)');
        expect(fuyuFinder, findsOneWidget);
        await tester.ensureVisible(fuyuFinder);
        await tester.pumpAndSettle();
        await tester.tap(fuyuFinder);
        await tester.pumpAndSettle();

        // Check that selectedDarkPalette state is updated to winterFuyu
        expect(container.read(themeConfigProvider).selectedDarkPalette, equals(SanzoWadaPalette.winterFuyu));
        
        // Tap on System Light card to revert light palette
        final standardLightFinder = find.text('System Light');
        expect(standardLightFinder, findsOneWidget);
        await tester.ensureVisible(standardLightFinder);
        await tester.pumpAndSettle();
        await tester.tap(standardLightFinder);
        await tester.pumpAndSettle();
        
        // Check selectedLightPalette is null again
        expect(container.read(themeConfigProvider).selectedLightPalette, isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Toggling System Sync switches syncWithSystem and forceDarkMode states', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      
      try {
        final container = ProviderContainer(overrides: [
          tasksLoadedProvider.overrideWith((ref) => true),
          localeModeProvider.overrideWith((ref) => AppLocaleMode.de),
        ]);
        
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const material.MaterialApp(
              home: SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially syncWithSystem is true
        expect(container.read(themeConfigProvider).syncWithSystem, isTrue);

        // Tap the Sync with System Theme switch
        final syncSwitchFinder = find.widgetWithText(material.SwitchListTile, strings.syncWithSystem);
        expect(syncSwitchFinder, findsOneWidget);
        await tester.tap(syncSwitchFinder);
        await tester.pumpAndSettle();

        // Now syncWithSystem is false
        expect(container.read(themeConfigProvider).syncWithSystem, isFalse);
        expect(container.read(themeConfigProvider).forceDarkMode, isFalse);

        // Tap the Use Dark Mode switch that appeared
        final darkSwitchFinder = find.widgetWithText(material.SwitchListTile, strings.useDarkMode);
        expect(darkSwitchFinder, findsOneWidget);
        await tester.tap(darkSwitchFinder);
        await tester.pumpAndSettle();

        // Now forceDarkMode is true
        expect(container.read(themeConfigProvider).forceDarkMode, isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}

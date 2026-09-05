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

/// Erscheinungsbild: **ein** Farbwähler, Hell/Dunkel folgt dem System.
///
/// Früher gab es hier zwei Paletten-Reihen (Hell, Dunkel) plus zwei
/// Modus-Schalter. Beides ist weg — diese Tests prüfen deshalb genau die zwei
/// Zusagen, die übrig bleiben:
///   1. Ein Tipp wählt die Palette für beide Modi.
///   2. Welcher Modus gilt, entscheidet die Systemhelligkeit — nicht die App.
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

  group('Erscheinungsbild', () {
    late MockRcloneService mockRcloneService;
    const strings = AppStrings(AppLocale.de);

    setUp(() {
      mockRcloneService = MockRcloneService();
    });

    tearDown(() {
      mockRcloneService.dispose();
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Ein Farbwähler setzt die Palette — und Standard setzt sie zurück',
        (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      // Die Einstellungsseite ist länger als das Standard-Testfenster
      // (800×600). Was außerhalb liegt, wird von den faulen Listen gar nicht
      // erst gebaut — find.text findet dann nichts, und ensureVisible kann
      // auch nicht helfen, weil es den Finder selbst braucht.
      await tester.binding.setSurfaceSize(const material.Size(1200, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      try {
        final container = ProviderContainer(overrides: [
          tasksLoadedProvider.overrideWith((ref) => true),
          localeProvider.overrideWith((ref) => AppLocale.de),
        ]);
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const fluent.FluentApp(
              home: SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Ausgangszustand: Standard, keine Palette.
        expect(container.read(themeConfigProvider).selectedPalette, isNull);

        // Genau EINE Reihe: Jede Palette steht jetzt einmal da, nicht zweimal
        // (früher Hell- und Dunkel-Reihe).
        final akiFinder = find.text('Aki (Autumn)');
        expect(akiFinder, findsOneWidget);

        await tester.ensureVisible(akiFinder);
        await tester.pumpAndSettle();
        await tester.tap(akiFinder);
        await tester.pumpAndSettle();

        expect(
          container.read(themeConfigProvider).selectedPalette,
          equals(SanzoWadaPalette.autumnAki),
        );

        // Zurück auf Standard — der erste Swatch in der Reihe.
        final standardFinder = find.text(strings.paletteStandard);
        expect(standardFinder, findsOneWidget);
        await tester.ensureVisible(standardFinder);
        await tester.pumpAndSettle();
        await tester.tap(standardFinder);
        await tester.pumpAndSettle();

        expect(container.read(themeConfigProvider).selectedPalette, isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('Die gewählte Palette liefert Hell und Dunkel aus demselben Eintrag',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(themeConfigProvider.notifier)
          .setPalette(SanzoWadaPalette.autumnAki);

      // Hell: System sagt hell → Light-Set der Palette.
      container.read(systemBrightnessProvider.notifier).state =
          material.Brightness.light;
      final light = container.read(appThemeProvider);
      expect(light.canvas, equals(SanzoWadaPalette.autumnAki.lightSurface));
      expect(
        light.textPrimary,
        equals(SanzoWadaPalette.autumnAki.lightTextPrimary),
      );
      expect(light.accent, equals(SanzoWadaPalette.autumnAki.lightAccent));

      // Dunkel: dieselbe Palette, anderes Set — ohne dass irgendwo in der App
      // ein Modus gewählt worden wäre.
      container.read(systemBrightnessProvider.notifier).state =
          material.Brightness.dark;
      final dark = container.read(appThemeProvider);
      expect(dark.canvas, equals(SanzoWadaPalette.autumnAki.darkSurface));
      expect(
        dark.textPrimary,
        equals(SanzoWadaPalette.autumnAki.darkTextPrimary),
      );
      expect(dark.accent, equals(SanzoWadaPalette.autumnAki.darkAccent));
    });

    test('Ohne Palette gilt das neutrale Standard-Farbschema', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(systemBrightnessProvider.notifier).state =
          material.Brightness.light;
      expect(container.read(appThemeProvider).canvas,
          equals(AppThemeData.light.canvas));

      container.read(systemBrightnessProvider.notifier).state =
          material.Brightness.dark;
      expect(
          container.read(appThemeProvider).canvas, equals(AppThemeData.dark.canvas));
    });

    test('Alte Einstellungen mit zwei Paletten wandern auf eine um', () {
      // Ältere Versionen haben Hell und Dunkel getrennt gespeichert.
      final legacy = <String, dynamic>{
        'syncWithSystem': false,
        'forceDarkMode': true,
        'selectedLightPalette': SanzoWadaPalette.forestMori.name,
        'selectedDarkPalette': SanzoWadaPalette.midnightYoru.name,
      };
      // Die Hell-Wahl gewinnt — sie war die sichtbare.
      expect(
        ThemeNotifier.paletteFromSettings(legacy),
        equals(SanzoWadaPalette.forestMori),
      );

      // Nur Dunkel gesetzt → Dunkel-Wahl bleibt erhalten.
      expect(
        ThemeNotifier.paletteFromSettings(<String, dynamic>{
          'selectedDarkPalette': SanzoWadaPalette.midnightYoru.name,
        }),
        equals(SanzoWadaPalette.midnightYoru),
      );

      // Neuer Schlüssel gewinnt immer.
      expect(
        ThemeNotifier.paletteFromSettings(<String, dynamic>{
          'selectedPalette': SanzoWadaPalette.oceanUmi.name,
          'selectedLightPalette': SanzoWadaPalette.forestMori.name,
        }),
        equals(SanzoWadaPalette.oceanUmi),
      );

      // Unbekannter Name → Standard, kein Absturz.
      expect(
        ThemeNotifier.paletteFromSettings(
            <String, dynamic>{'selectedPalette': 'Gibt es nicht'}),
        isNull,
      );
    });
  });
}

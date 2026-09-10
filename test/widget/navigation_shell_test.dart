import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';

import 'package:fibu/core/localization/app_strings.dart';
import 'package:fibu/core/localization/locale_provider.dart';
import 'package:fibu/core/services/rclone_provider.dart';
import 'package:fibu/core/services/mock_rclone_service.dart';
import 'package:fibu/features/shell/presentation/shell_screen.dart';
import 'package:fibu/features/dashboard/presentation/dashboard_screen.dart';
import 'package:fibu/features/settings/presentation/settings_screen.dart';
import '../helpers/platform_mocks.dart';
import 'package:fibu/features/tasks/presentation/tasks_controller.dart';

/// Die Screens zeigen unbestimmte Lade-Indikatoren (z. B. Quota), die endlos
/// animieren — `pumpAndSettle` wartet dort bis zum Timeout. Stattdessen eine
/// feste, kurze Folge von Frames pumpen.
Future<void> settleBounded(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

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

  group('ShellScreen Navigation Tests', () {
    late MockRcloneService mockRcloneService;
    const strings = AppStrings(AppLocale.de);

    setUp(() {
      mockRcloneService = MockRcloneService();
    });

    tearDown(() {
      mockRcloneService.dispose();
      debugDefaultTargetPlatformOverride = null;
    });

    Widget createWidgetUnderTest() {
      return ProviderScope(
        overrides: [
          tasksLoadedProvider.overrideWith((ref) => true),
          localeProvider.overrideWith((ref) => AppLocale.de),
          rcloneServiceProvider.overrideWithValue(mockRcloneService),
        ],
        child: const fluent.FluentApp(
          home: ShellScreen(),
        ),
      );
    }

    testWidgets('Windows Shell Navigation transitions screens successfully', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      
      try {
        await tester.pumpWidget(createWidgetUnderTest());
        await settleBounded(tester);

        // Zwei Einträge, nicht drei: Den Aufgaben-Tab gibt es auf Windows
        // nicht mehr — Modell ist „eine Cloud, eine Sicherung", und die
        // Sicherung wird in den Einstellungen eingerichtet.
        expect(find.text(strings.navDashboard), findsWidgets);
        expect(find.byIcon(fluent.FluentIcons.task_manager), findsNothing);

        // Tap on Settings Pane Item
        final settingsItemFinder = find.byIcon(fluent.FluentIcons.settings);
        expect(settingsItemFinder, findsOneWidget);
        await tester.tap(settingsItemFinder);
        await settleBounded(tester);

        // Check Settings screen is loaded
        expect(find.byType(SettingsScreen), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Android Shell Navigation transitions screens successfully', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tasksLoadedProvider.overrideWith((ref) => true),
              localeProvider.overrideWith((ref) => AppLocale.de),
              rcloneServiceProvider.overrideWithValue(mockRcloneService),
            ],
            child: const material.MaterialApp(
              home: ShellScreen(),
            ),
          ),
        );
        await settleBounded(tester);

        // Dashboard sichtbar (per Typ gesucht, damit Titel/AppBar-Text nicht
        // kollidieren).
        expect(find.byType(DashboardScreen), findsOneWidget);

        // Zwei Einträge, nicht drei: Den Aufgaben-Tab gibt es nicht mehr,
        // die Sicherung wird in den Einstellungen eingerichtet.
        expect(find.byIcon(material.Icons.list_alt_outlined), findsNothing);

        final settingsDestination =
            find.byIcon(material.Icons.settings_outlined);
        expect(settingsDestination, findsOneWidget);
        await tester.tap(settingsDestination);
        await settleBounded(tester);

        expect(find.byType(SettingsScreen), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}

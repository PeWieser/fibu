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
import 'package:fibu/features/tasks/presentation/tasks_screen.dart';
import 'package:fibu/features/settings/presentation/settings_screen.dart';
import '../helpers/platform_mocks.dart';

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
        await tester.pumpAndSettle();

        // Check initially Dashboard is visible
        expect(find.text(strings.navDashboard), findsWidgets);
        
        // Tap on Tasks Pane Item. Find by icon.
        final tasksItemFinder = find.byIcon(fluent.FluentIcons.task_manager);
        expect(tasksItemFinder, findsOneWidget);
        await tester.tap(tasksItemFinder);
        await tester.pumpAndSettle();

        // Check Tasks screen is loaded
        expect(find.byType(TasksScreen), findsOneWidget);
        expect(find.text(strings.tasksTitle), findsOneWidget);

        // Tap on Settings Pane Item
        final settingsItemFinder = find.byIcon(fluent.FluentIcons.settings);
        expect(settingsItemFinder, findsOneWidget);
        await tester.tap(settingsItemFinder);
        await tester.pumpAndSettle();

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
              rcloneServiceProvider.overrideWithValue(mockRcloneService),
            ],
            child: const material.MaterialApp(
              home: ShellScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check initially Dashboard is visible (find by type to avoid label/appbar text conflicts)
        expect(find.byType(DashboardScreen), findsOneWidget);
        
        // Tap on Tasks navigation destination
        final tasksDestination = find.byIcon(material.Icons.list_alt_outlined);
        expect(tasksDestination, findsOneWidget);
        await tester.tap(tasksDestination);
        await tester.pumpAndSettle();

        expect(find.byType(TasksScreen), findsOneWidget);
        expect(find.text(strings.tasksTitle), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fibu/core/localization/app_strings.dart';
import 'package:fibu/core/localization/locale_provider.dart';
import 'package:fibu/features/tasks/presentation/tasks_screen.dart';
import 'package:fibu/features/tasks/presentation/tasks_controller.dart';
import 'package:fibu/core/services/mock_rclone_service.dart';

void main() {
  group('TasksScreen Widget Tests', () {
    late MockRcloneService mockRcloneService;
    const strings = AppStrings(AppLocale.de);

    setUp(() {
      mockRcloneService = MockRcloneService();
    });

    tearDown(() {
      mockRcloneService.dispose();
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Renders Windows Fluent UI layout successfully', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      try {
        final container = ProviderContainer();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const fluent.FluentApp(
              home: TasksScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check Windows headers are visible
        expect(find.text(strings.tasksTitle), findsOneWidget);
        
        // Assert mock tasks are listed
        expect(find.text('Camera Photos Backup'), findsOneWidget);
        expect(find.text('GoPro Videos Archive'), findsOneWidget);
        expect(find.text('Work Documents Sync'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Renders iOS Cupertino layout successfully', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      try {
        final container = ProviderContainer();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const cupertino.CupertinoApp(
              home: TasksScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check Cupertino section title
        expect(find.text(strings.backupJobsHeader), findsOneWidget);
        
        // Assert mock tasks are listed
        expect(find.text('Camera Photos Backup'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Renders Android Material 3 layout successfully', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      try {
        final container = ProviderContainer();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const material.MaterialApp(
              home: TasksScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check Material AppBar title
        expect(find.text(strings.tasksTitle), findsOneWidget);
        
        // Assert mock tasks are listed
        expect(find.text('Camera Photos Backup'), findsOneWidget);
        expect(find.byType(material.FloatingActionButton), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Toggling task switch updates active state', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      try {
        final container = ProviderContainer();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const material.MaterialApp(
              home: TasksScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // First task is initially active (isActive = true)
        expect(container.read(tasksListProvider)[0].isActive, isTrue);

        // Tap Switch on first ListTile
        final switchFinder = find.byType(material.Switch).first;
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        // First task should now be inactive
        expect(container.read(tasksListProvider)[0].isActive, isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Deleting task triggers confirmation dialog with plain text consequence', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      try {
        final container = ProviderContainer();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const fluent.FluentApp(
              home: TasksScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find and tap delete button for the first task
        final deleteBtn = find.byIcon(fluent.FluentIcons.delete).first;
        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();

        // Confirmation dialog should be visible
        expect(find.text(strings.deleteTaskConfirmTitle), findsOneWidget);
        
        // Verify Rule 6 plain text consequence is present
        expect(find.textContaining(strings.deleteTaskRule6Notice), findsOneWidget);

        // Tap cancel/abbrechen
        final cancelBtn = find.text(strings.cancel);
        expect(cancelBtn, findsOneWidget);
        await tester.tap(cancelBtn);
        await tester.pumpAndSettle();

        // Tasks count remains 3
        expect(container.read(tasksListProvider), hasLength(3));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}

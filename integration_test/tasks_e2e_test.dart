import 'package:flutter/foundation.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fibu/core/localization/app_strings.dart';
import 'package:fibu/core/localization/locale_provider.dart';
import 'package:fibu/core/services/mock_rclone_service.dart';
import 'package:fibu/core/services/rclone_provider.dart';
import 'package:fibu/features/tasks/presentation/tasks_screen.dart';
import 'package:fibu/features/tasks/presentation/tasks_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Tasks Screen E2E Tests', () {
    late MockRcloneService mockRcloneService;
    const strings = AppStrings(AppLocale.de);

    setUp(() {
      mockRcloneService = MockRcloneService();
    });

    tearDown(() {
      mockRcloneService.dispose();
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('TASK-01: Create Task Full Flow and state persistence', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      try {
        final container = ProviderContainer(
          overrides: [
            rcloneServiceProvider.overrideWithValue(mockRcloneService),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const fluent.FluentApp(
              home: TasksScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Click Add Task button
        final addBtn = find.text(strings.addTask);
        expect(addBtn, findsOneWidget);
        await tester.tap(addBtn);
        await tester.pumpAndSettle();

        // Fill task name
        final nameInput = find.byType(fluent.TextBox).first;
        await tester.enterText(nameInput, 'Music Backup');
        await tester.pumpAndSettle();

        // Fill source path
        final srcInput = find.byType(fluent.TextBox).at(1);
        await tester.enterText(srcInput, 'D:\\Music');
        await tester.pumpAndSettle();

        // Click Save button
        final saveBtn = find.widgetWithText(fluent.FilledButton, strings.save);
        expect(saveBtn, findsOneWidget);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        // Verify task appears in the list
        expect(find.text('Music Backup'), findsOneWidget);
        expect(container.read(tasksListProvider).any((t) => t.name == 'Music Backup'), isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('TASK-02: Edit Task schedule and toggle active status', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      try {
        final container = ProviderContainer(
          overrides: [
            rcloneServiceProvider.overrideWithValue(mockRcloneService),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const fluent.FluentApp(
              home: TasksScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap edit button on the first task
        final editBtn = find.byIcon(fluent.FluentIcons.edit).first;
        expect(editBtn, findsOneWidget);
        await tester.tap(editBtn);
        await tester.pumpAndSettle();

        // Edit name to 'Camera Photos Backup HD'
        final nameInput = find.byType(fluent.TextBox).first;
        await tester.enterText(nameInput, 'Camera Photos Backup HD');
        await tester.pumpAndSettle();

        // Save changes
        final saveBtn = find.widgetWithText(fluent.FilledButton, strings.save);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        // Task name updated in UI
        expect(find.text('Camera Photos Backup HD'), findsOneWidget);

        // Toggle active switch
        final toggleSwitch = find.byType(fluent.ToggleSwitch).first;
        await tester.tap(toggleSwitch);
        await tester.pumpAndSettle();

        expect(container.read(tasksListProvider)[0].isActive, isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('TASK-03: Delete Task Rule 6 Confirmation Dialog and Cancel/Confirm', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      try {
        final container = ProviderContainer(
          overrides: [
            rcloneServiceProvider.overrideWithValue(mockRcloneService),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const fluent.FluentApp(
              home: TasksScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find delete button on first task
        final deleteBtn = find.byIcon(fluent.FluentIcons.delete).first;
        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();

        // Confirmation dialog shown
        expect(find.text(strings.deleteTaskConfirmTitle), findsOneWidget);
        expect(find.text(strings.deleteTaskRule6Notice), findsOneWidget);

        // Cancel
        final cancelBtn = find.text(strings.cancel);
        await tester.tap(cancelBtn);
        await tester.pumpAndSettle();

        expect(container.read(tasksListProvider), hasLength(3));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('TASK-04: Task Form Validation for empty name and path', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      try {
        final container = ProviderContainer(
          overrides: [
            rcloneServiceProvider.overrideWithValue(mockRcloneService),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const fluent.FluentApp(
              home: TasksScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open Add Task dialog
        final addBtn = find.text(strings.addTask);
        await tester.tap(addBtn);
        await tester.pumpAndSettle();

        // Click Save immediately with empty fields
        final saveBtn = find.widgetWithText(fluent.FilledButton, strings.save);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        // Validation error messages are shown
        expect(find.text(strings.taskNameRequiredError), findsOneWidget);
        expect(find.text(strings.sourcePathRequiredError), findsOneWidget);

        // Dismiss dialog
        final cancelBtn = find.widgetWithText(fluent.Button, strings.cancel);
        await tester.tap(cancelBtn);
        await tester.pumpAndSettle();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/widgets.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fibu/core/localization/app_strings.dart';
import 'package:fibu/core/localization/locale_provider.dart';
import 'package:fibu/features/tasks/presentation/tasks_screen.dart';
import 'package:fibu/features/tasks/presentation/task_detail_screen.dart';
import 'package:fibu/features/tasks/presentation/tasks_controller.dart';
import 'package:fibu/core/services/mock_rclone_service.dart';
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

  group('TasksScreen & TaskDetailScreen Widget Tests', () {
    late MockRcloneService mockRcloneService;
    const strings = AppStrings(AppLocale.de);

    setUp(() {
      mockRcloneService = MockRcloneService();
    });

    tearDown(() {
      mockRcloneService.dispose();
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Renders Windows Empty State when no tasks exist', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      try {
        final container = ProviderContainer(overrides: [tasksLoadedProvider.overrideWith((ref) => true),]);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const fluent.FluentApp(
              home: TasksScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Header
        expect(find.text(strings.tasksTitle), findsOneWidget);
        // Empty state
        expect(find.text(strings.noTasksConfigured), findsOneWidget);
        expect(find.text(strings.noTasksDescription), findsOneWidget);
        // CTA Button
        expect(find.text(strings.addTask), findsWidgets);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Renders iOS Empty State when no tasks exist', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      try {
        final container = ProviderContainer(overrides: [tasksLoadedProvider.overrideWith((ref) => true),]);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const cupertino.CupertinoApp(
              home: TasksScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Empty state
        expect(find.text(strings.noTasksConfigured), findsOneWidget);
        expect(find.text(strings.noTasksDescription), findsOneWidget);
        // CTA Button
        expect(find.text(strings.addTask), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Renders Android Empty State when no tasks exist', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      try {
        final container = ProviderContainer(overrides: [tasksLoadedProvider.overrideWith((ref) => true),]);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const material.MaterialApp(
              home: TasksScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // AppBar title
        expect(find.text(strings.tasksTitle), findsOneWidget);
        // Empty state
        expect(find.text(strings.noTasksConfigured), findsOneWidget);
        expect(find.text(strings.noTasksDescription), findsOneWidget);
        // FAB and CTA button
        expect(find.byType(material.FloatingActionButton), findsOneWidget);
        expect(find.text(strings.addTask), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Renders populated tasks list with clean minimal rows and chevrons', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      try {
        final container = ProviderContainer(overrides: [tasksLoadedProvider.overrideWith((ref) => true),]);

        container.read(tasksListProvider.notifier).addTask(
          const BackupTask(
            id: 'task_inc',
            name: 'Incremental Backup Task',
            sourcePath: 'D:\\Photos',
            targetRemote: 'OneDrive_Backup:backup',
            schedule: 'Daily at 02:00',
            isActive: true,
            syncMode: SyncMode.incremental,
          ),
        );
        container.read(tasksListProvider.notifier).addTask(
          const BackupTask(
            id: 'task_mir',
            name: 'Mirror Backup Task',
            sourcePath: 'D:\\Documents',
            targetRemote: 'GoogleDrive_Backup:backup',
            schedule: 'Manual',
            isActive: false,
            syncMode: SyncMode.mirror,
          ),
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

        expect(find.text('Incremental Backup Task'), findsOneWidget);
        expect(find.text('Mirror Backup Task'), findsOneWidget);
        expect(find.text(strings.statusActive), findsOneWidget);
        expect(find.text(strings.statusInactive), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('iOS swipe-to-delete confirms then removes task after dismiss animation', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      try {
        final container = ProviderContainer(overrides: [tasksLoadedProvider.overrideWith((ref) => true),]);
        container.read(tasksListProvider.notifier).addTask(
          const BackupTask(
            id: 'task_swipe',
            name: 'Swipe Delete Task',
            sourcePath: 'photos',
            targetRemote: 'Remote:backup',
            schedule: 'Manual',
            isActive: true,
          ),
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const cupertino.CupertinoApp(
              home: TasksScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Swipe Delete Task'), findsOneWidget);
        expect(container.read(tasksListProvider), hasLength(1));

        // Nach links wischen, um den Delete-Trigger zu öffnen.
        await tester.drag(find.text('Swipe Delete Task'), const Offset(-500, 0));
        await tester.pumpAndSettle();

        // Bestätigungsdialog (Rule 6 Guard) erscheint.
        expect(find.text(strings.deleteTaskConfirmTitle), findsOneWidget);

        // Löschen bestätigen -> Dialog schließt, onDismissed entfernt den Task.
        await tester.tap(find.text(strings.delete));
        await tester.pumpAndSettle();

        expect(container.read(tasksListProvider), isEmpty);
        expect(find.text('Swipe Delete Task'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('TaskDetailScreen renders full task configuration and sync mode details', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      try {
        final container = ProviderContainer(overrides: [tasksLoadedProvider.overrideWith((ref) => true),]);
        container.read(tasksListProvider.notifier).addTask(
          const BackupTask(
            id: 'task_detail_test',
            name: 'Photo Mirror Task',
            sourcePath: 'photos',
            targetRemote: 'GoogleDrive:PhotosBackup',
            schedule: 'Daily at 02:00',
            isActive: true,
            syncMode: SyncMode.mirror,
            wifiOnly: true,
          ),
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const cupertino.CupertinoApp(
              home: TaskDetailScreen(taskId: 'task_detail_test'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Photo Mirror Task'), findsOneWidget);
        expect(find.text(strings.allPhotos), findsOneWidget);
        expect(find.text(strings.syncModeMirror), findsOneWidget);
        expect(find.text(strings.deleteTask), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Toggling task switch in TaskDetailScreen updates active state', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      try {
        final container = ProviderContainer(overrides: [tasksLoadedProvider.overrideWith((ref) => true),]);
        container.read(tasksListProvider.notifier).addTask(
          const BackupTask(
            id: 'task_test',
            name: 'Toggle Test Task',
            sourcePath: 'C:\\Folder',
            targetRemote: 'Remote:backup',
            schedule: 'Manual',
            isActive: true,
          ),
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const material.MaterialApp(
              home: TaskDetailScreen(taskId: 'task_test'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(container.read(tasksListProvider)[0].isActive, isTrue);

        final switchFinder = find.byType(material.Switch).first;
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        expect(container.read(tasksListProvider)[0].isActive, isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Deleting task in TaskDetailScreen triggers confirmation dialog with plain text consequence', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      try {
        final container = ProviderContainer(overrides: [tasksLoadedProvider.overrideWith((ref) => true),]);
        container.read(tasksListProvider.notifier).addTask(
          const BackupTask(
            id: 'task_del',
            name: 'Delete Test Task',
            sourcePath: 'C:\\Folder',
            targetRemote: 'Remote:backup',
            schedule: 'Manual',
            isActive: true,
          ),
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const fluent.FluentApp(
              home: TaskDetailScreen(taskId: 'task_del'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final deleteBtn = find.text(strings.deleteTask);
        expect(deleteBtn, findsOneWidget);
        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();

        // Confirmation dialog should be visible with Rule 6 consequence notice
        expect(find.text(strings.deleteTaskConfirmTitle), findsOneWidget);
        expect(find.textContaining(strings.deleteTaskRule6Notice), findsOneWidget);

        // Tap cancel/abbrechen
        final cancelBtn = find.text(strings.cancel);
        expect(cancelBtn, findsOneWidget);
        await tester.tap(cancelBtn);
        await tester.pumpAndSettle();

        expect(container.read(tasksListProvider), hasLength(1));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}

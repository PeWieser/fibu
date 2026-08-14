import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fibu/features/tasks/presentation/tasks_controller.dart';

void main() {
  group('Backup Tasks State Notifier Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('TasksListNotifier is initialized with empty list (no mock tasks)', () {
      final tasks = container.read(tasksListProvider);
      expect(tasks, isEmpty);
    });

    test('addTask appends a new task to the state with default incremental SyncMode', () {
      const newTask = BackupTask(
        id: 'task_1',
        name: 'My Photos Backup',
        sourcePath: 'D:\\Pictures',
        targetRemote: 'OneDrive_Backup:backup',
        schedule: 'Daily at 02:00',
        isActive: true,
      );

      container.read(tasksListProvider.notifier).addTask(newTask);

      final tasks = container.read(tasksListProvider);
      expect(tasks, hasLength(1));
      expect(tasks.first.id, equals('task_1'));
      expect(tasks.first.name, equals('My Photos Backup'));
      expect(tasks.first.syncMode, equals(SyncMode.incremental));
    });

    test('addTask supports mirror (Echo) SyncMode', () {
      const mirrorTask = BackupTask(
        id: 'task_mirror',
        name: 'Work Mirror Archive',
        sourcePath: 'D:\\Work',
        targetRemote: 'GoogleDrive_Backup:backup',
        schedule: 'Manual',
        isActive: true,
        syncMode: SyncMode.mirror,
      );

      container.read(tasksListProvider.notifier).addTask(mirrorTask);

      final tasks = container.read(tasksListProvider);
      expect(tasks.any((t) => t.id == 'task_mirror' && t.syncMode == SyncMode.mirror), isTrue);
    });

    test('updateTask modifies the target task in place', () {
      const task1 = BackupTask(
        id: 'task_1',
        name: 'Initial Name',
        sourcePath: 'C:\\Folder',
        targetRemote: 'Drive:backup',
        schedule: 'Daily at 02:00',
        isActive: true,
      );
      container.read(tasksListProvider.notifier).addTask(task1);

      final updatedTask = task1.copyWith(
        name: 'Updated Photos Backup',
        sourcePath: 'C:\\Updated\\Path',
        syncMode: SyncMode.mirror,
      );

      container.read(tasksListProvider.notifier).updateTask('task_1', updatedTask);

      final tasks = container.read(tasksListProvider);
      expect(tasks.first.name, equals('Updated Photos Backup'));
      expect(tasks.first.sourcePath, equals('C:\\Updated\\Path'));
      expect(tasks.first.syncMode, equals(SyncMode.mirror));
    });

    test('toggleTaskActive flips the active state of the task', () {
      const task1 = BackupTask(
        id: 'task_1',
        name: 'Task 1',
        sourcePath: 'C:\\Folder',
        targetRemote: 'Drive:backup',
        schedule: 'Manual',
        isActive: true,
      );
      container.read(tasksListProvider.notifier).addTask(task1);

      container.read(tasksListProvider.notifier).toggleTaskActive('task_1');
      expect(container.read(tasksListProvider).first.isActive, isFalse);

      container.read(tasksListProvider.notifier).toggleTaskActive('task_1');
      expect(container.read(tasksListProvider).first.isActive, isTrue);
    });

    test('removeTask deletes the selected task', () {
      const task1 = BackupTask(
        id: 'task_1',
        name: 'Task 1',
        sourcePath: 'C:\\Folder',
        targetRemote: 'Drive:backup',
        schedule: 'Manual',
        isActive: true,
      );
      container.read(tasksListProvider.notifier).addTask(task1);
      expect(container.read(tasksListProvider), hasLength(1));

      container.read(tasksListProvider.notifier).removeTask('task_1');
      expect(container.read(tasksListProvider), isEmpty);
    });
  });
}

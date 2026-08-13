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

    test('TasksListNotifier is initialized with 3 default tasks', () {
      final tasks = container.read(tasksListProvider);
      expect(tasks, hasLength(3));
      expect(tasks[0].name, equals('Camera Photos Backup'));
      expect(tasks[1].name, equals('GoPro Videos Archive'));
      expect(tasks[2].name, equals('Work Documents Sync'));
    });

    test('addTask appends a new task to the state', () {
      const newTask = BackupTask(
        id: 'task_new',
        name: 'New Custom Sync',
        sourcePath: 'D:\\MyFolder',
        targetRemote: 'MyDrive:backup',
        schedule: 'Manual',
        isActive: true,
      );

      container.read(tasksListProvider.notifier).addTask(newTask);

      final tasks = container.read(tasksListProvider);
      expect(tasks, hasLength(4));
      expect(tasks.last.id, equals('task_new'));
      expect(tasks.last.name, equals('New Custom Sync'));
    });

    test('updateTask modifies the target task in place', () {
      final initialTasks = container.read(tasksListProvider);
      final firstTask = initialTasks.first;

      final updatedTask = firstTask.copyWith(
        name: 'Updated Photos Backup',
        sourcePath: 'C:\\Updated\\Path',
      );

      container.read(tasksListProvider.notifier).updateTask(firstTask.id, updatedTask);

      final tasks = container.read(tasksListProvider);
      expect(tasks, hasLength(3));
      expect(tasks.first.name, equals('Updated Photos Backup'));
      expect(tasks.first.sourcePath, equals('C:\\Updated\\Path'));
    });

    test('toggleTaskActive flips the active state of the task', () {
      final initialTasks = container.read(tasksListProvider);
      final task = initialTasks.first; // initially true
      expect(task.isActive, isTrue);

      container.read(tasksListProvider.notifier).toggleTaskActive(task.id);

      final tasks = container.read(tasksListProvider);
      expect(tasks.first.isActive, isFalse);

      container.read(tasksListProvider.notifier).toggleTaskActive(task.id);
      expect(container.read(tasksListProvider).first.isActive, isTrue);
    });

    test('removeTask deletes the selected task', () {
      final initialTasks = container.read(tasksListProvider);
      final firstTaskId = initialTasks.first.id;

      container.read(tasksListProvider.notifier).removeTask(firstTaskId);

      final tasks = container.read(tasksListProvider);
      expect(tasks, hasLength(2));
      expect(tasks.any((t) => t.id == firstTaskId), isFalse);
    });
  });
}

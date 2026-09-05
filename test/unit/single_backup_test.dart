import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fibu/features/tasks/presentation/tasks_controller.dart';

/// Modell „eine Cloud, eine Sicherung": Es gibt genau eine Sicherung.
///
/// Treffen mehrere ein — Alt-Installation, oder ein altes Gerät schickt seine
/// Konfiguration — muss die Auswahl deterministisch sein, sonst entscheidet
/// der Zufall, wohin gesichert wird.
void main() {
  // Der Notifier schreibt seine Liste weg; ohne Binding wirft schon der
  // MethodChannel-Aufruf statt der erwarteten MissingPluginException.
  TestWidgetsFlutterBinding.ensureInitialized();

  BackupTask task({
    required String id,
    required String target,
    bool isActive = true,
  }) {
    return BackupTask(
      id: id,
      name: 'Sicherung $id',
      sourcePath: 'files:/daten/$id',
      targetRemotes: [target],
      schedule: 'Täglich um 02:00',
      isActive: isActive,
    );
  }

  group('Eine Sicherung', () {
    test('ohne Einträge bleibt es leer', () {
      expect(TasksListNotifier.reduceToSingle(const []), isEmpty);
    });

    test('ein Eintrag bleibt unverändert', () {
      final one = [task(id: 'a', target: 'mega')];
      expect(TasksListNotifier.reduceToSingle(one), same(one));
    });

    test('die erste aktive Sicherung gewinnt', () {
      final reduced = TasksListNotifier.reduceToSingle([
        task(id: 'alt', target: 'mega', isActive: false),
        task(id: 'aktiv', target: 'b2'),
        task(id: 'noch-eine', target: 'dropbox'),
      ]);
      expect(reduced, hasLength(1));
      expect(reduced.single.id, 'aktiv');
      expect(reduced.single.targetRemote, 'b2');
    });

    test('ist keine aktiv, gewinnt die erste', () {
      final reduced = TasksListNotifier.reduceToSingle([
        task(id: 'erste', target: 'mega', isActive: false),
        task(id: 'zweite', target: 'b2', isActive: false),
      ]);
      expect(reduced.single.id, 'erste');
    });

    test('eine zweite Sicherung ersetzt die erste', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Der Notifier lädt im Konstruktor asynchron nach. Erst warten, bis
      // das erledigt ist — sonst läuft der Ladevorgang in einen Container,
      // den der Test gerade abgeräumt hat.
      final notifier = container.read(tasksListProvider.notifier);
      while (!container.read(tasksLoadedProvider)) {
        await Future<void>.delayed(Duration.zero);
      }
      notifier.addTask(task(id: 'alt', target: 'mega'));
      notifier.addTask(task(id: 'neu', target: 'b2'));

      final tasks = container.read(tasksListProvider);
      expect(tasks, hasLength(1));
      expect(tasks.single.id, 'neu');
    });

    test('die Reihenfolge der Datei entscheidet, nicht die Sortierung', () {
      final reduced = TasksListNotifier.reduceToSingle([
        task(id: 'z', target: 'mega'),
        task(id: 'a', target: 'b2'),
      ]);
      // Beide aktiv → die erste in der Liste, nicht die alphabetisch erste.
      expect(reduced.single.id, 'z');
    });
  });
}

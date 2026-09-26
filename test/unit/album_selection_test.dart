import 'package:flutter_test/flutter_test.dart';

import 'package:fibu/features/tasks/presentation/tasks_controller.dart';

/// Album-Auswahl auf iOS — DIE Kodierung (`copyWithAlbums` /
/// `copyWithAllAlbums`) ist die einzige Wahrheit für „Fotos & Videos".
///
/// Drei Zusagen, die die Oberfläche dem Nutzer macht:
///   1. „Alle Alben" ist eine ausdrückliche Wahl (`all`) — inklusive Alben,
///      die es künftig erst gibt.
///   2. Eine gewählte Menge ist sortiert — die Tipp-Reihenfolge darf nicht
///      eine andere Mirror-Kennung erzeugen.
///   3. Die leere Menge ist eine sichtbare Lücke (`''`), NIEMALS ein stilles
///      „alles sichern". Wer alles sichern will, wählt „Alle Alben".
void main() {
  BackupTask task({String sourcePath = 'all', List<String> albums = const []}) {
    return BackupTask(
      id: 't1',
      name: 'Sicherung',
      sourcePath: sourcePath,
      targetRemotes: const ['mega'],
      schedule: 'Automatisch (iOS-System)',
      scheduleDay: 'iOS System',
      isActive: true,
      selectedAlbums: albums,
    );
  }

  group('copyWithAllAlbums', () {
    test('schreibt genau „all“ — auch künftige Alben sind dabei', () {
      final updated = task(sourcePath: 'all:Urlaub', albums: ['Urlaub'])
          .copyWithAllAlbums();
      expect(updated.sourcePath, 'all');
      expect(updated.selectedAlbums, isEmpty);
      expect(updated.effectiveAlbums, isEmpty);
      expect(TasksListNotifier.isMediaLibrarySource(updated.sourcePath), isTrue);
    });
  });

  group('copyWithAlbums', () {
    test('sortiert alphabetisch — Tipp-Reihenfolge ändert nichts', () {
      final updated = task().copyWithAlbums(['Urlaub', 'arten', 'Kinder']);
      expect(updated.sourcePath, 'all:arten|Kinder|Urlaub');
      expect(updated.selectedAlbums, ['arten', 'Kinder', 'Urlaub']);

      final other = task().copyWithAlbums(['Kinder', 'Urlaub', 'arten']);
      expect(other.sourcePath, updated.sourcePath);
    });

    test('leere Menge ist die sichtbare Lücke, nicht „alle“', () {
      final updated = task(sourcePath: 'all:Urlaub', albums: ['Urlaub'])
          .copyWithAlbums(const <String>[]);
      expect(updated.sourcePath, isEmpty);
      expect(updated.selectedAlbums, isEmpty);
      // Genau die Gegenprobe zu „alle": die Quelle ist KEINE Mediathek-Auswahl
      // mehr — die Oberfläche zeigt „Alben wählen“, der Sync hat eine Lücke.
      expect(TasksListNotifier.isMediaLibrarySource(updated.sourcePath), isFalse);
    });

    test('Doppelte Namen überleben die Reise nicht', () {
      final updated = task().copyWithAlbums(['Urlaub', 'Urlaub', 'Kinder']);
      expect(updated.selectedAlbums, ['Kinder', 'Urlaub']);
      expect(updated.sourcePath, 'all:Kinder|Urlaub');
    });

    test('Die Kodierung liest sich über effectiveAlbums zurück', () {
      final updated = task().copyWithAlbums(['Kinder', 'Urlaub']);
      expect(updated.effectiveAlbums, ['Kinder', 'Urlaub']);
    });
  });
}

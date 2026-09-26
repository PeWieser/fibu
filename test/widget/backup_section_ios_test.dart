import 'dart:io';

import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fibu/core/localization/app_strings.dart';
import 'package:fibu/core/localization/locale_provider.dart';
import 'package:fibu/core/services/active_cloud.dart';
import 'package:fibu/core/services/mock_rclone_service.dart';
import 'package:fibu/core/services/rclone_provider.dart';
import 'package:fibu/features/settings/presentation/backup_section.dart';
import 'package:fibu/features/tasks/presentation/tasks_controller.dart';
import '../helpers/platform_mocks.dart';

/// „Sicherung" auf iOS: Quelle = Fotoalben, Zeitplan = das System.
///
/// Diese Tests sind die Antwort auf einen Rückfall: versehentlich war das
/// Windows-Modell eingezogen (Ordner per FilePicker, Wiederholung + Uhrzeit).
/// Auf iOS darf es dort weder eine Ordnerwahl noch einen Zeit-Wähler geben —
/// und „Sicherung einrichten" startet mit allen Alben und System-Zeitplan.
void main() {
  // path_provider mocken: Die Screens lesen tasks.json / settings.json
  // darüber — ohne Mock gäbe es MissingPluginException.
  late Directory mockDir;
  setUpAll(() async {
    mockDir = await installPathProviderMock();
  });
  tearDownAll(() async {
    await removePathProviderMock(mockDir);
  });

  group('Sicherung auf iOS', () {
    late MockRcloneService mockRcloneService;
    const strings = AppStrings(AppLocale.de);

    setUp(() {
      mockRcloneService = MockRcloneService();
    });

    tearDown(() {
      mockRcloneService.dispose();
      debugDefaultTargetPlatformOverride = null;
    });

    BackupTask iosTask({
      String sourcePath = 'all:Urlaub',
      List<String> albums = const ['Urlaub'],
    }) {
      return BackupTask(
        id: 'task_ios',
        name: 'Sicherung auf Mega',
        sourcePath: sourcePath,
        targetRemote: 'fibu-test-cloud:fibu-backup',
        schedule: 'Automatisch (iOS-System)',
        scheduleDay: 'iOS System',
        scheduleTime: '02:00',
        isActive: true,
        selectedAlbums: albums,
      );
    }

    Future<ProviderContainer> pumpBackupSection(
      WidgetTester tester, {
      required bool hasCloud,
      BackupTask? task,
    }) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      final container = ProviderContainer(overrides: [
        localeProvider.overrideWith((ref) => AppLocale.de),
        rcloneServiceProvider.overrideWithValue(mockRcloneService),
        activeRemoteIdProvider
            .overrideWith((ref) async => hasCloud ? 'fibu-test-cloud' : null),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const cupertino.CupertinoApp(
            home: cupertino.CupertinoPageScaffold(
              child: SingleChildScrollView(child: BackupSection()),
            ),
          ),
        ),
      );

      // Der Notifier startet das Laden von tasks.json im Konstruktor —
      // ausdrücklich anstoßen, dann warten: sonst überschreibt der
      // Ladevorgang die gleich gesetzte Sicherung (dasselbe Muster wie in
      // single_backup_test). Begrenzt pumpen: endlose Indikatoren dürfen
      // pumpAndSettle nicht einfrieren.
      container.read(tasksListProvider);
      for (var i = 0; i < 20 && !container.read(tasksLoadedProvider); i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(container.read(tasksLoadedProvider), isTrue,
          reason: 'tasks.json muss vor dem Setzen geladen sein');

      // Altbestand aus der geteilten Temp-Datei raus — jeder Test sieht
      // genau seinen Zustand.
      final TasksListNotifier notifier =
          container.read(tasksListProvider.notifier);
      for (final BackupTask existing in container.read(tasksListProvider)) {
        notifier.removeTask(existing.id);
      }
      if (task != null) {
        notifier.addTask(task);
      }
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      return container;
    }

    testWidgets('zeigt Fotoalben statt Ordner — und keinen Zeit-Wähler',
        (WidgetTester tester) async {
      await pumpBackupSection(tester, hasCloud: true, task: iosTask());

      // Quelle: die Alben, nicht Ordner.
      expect(find.text(strings.backupAlbums), findsOneWidget);
      expect(find.text('Urlaub'), findsOneWidget);
      expect(find.text(strings.backupAddFolder), findsNothing);
      expect(find.text(strings.backupNoFolder), findsNothing);

      // Zeitplan: eine Zeile, die die Wahrheit sagt — ohne Wiederholung und
      // ohne Uhrzeit. Die Zeile darunter erklärt, warum.
      expect(find.text(strings.scheduleLabel), findsOneWidget);
      expect(
        find.text(strings.scheduleDescriptionFor('iOS System', '02:00')),
        findsOneWidget,
      );
      expect(find.text(strings.scheduleDayLabel), findsNothing);
      expect(find.text(strings.scheduleTimeLabel), findsNothing);
      expect(find.text(strings.schedulePlatformNote), findsOneWidget);

      // Die übrigen Zeilen bleiben.
      expect(find.text(strings.backupSyncMode), findsOneWidget);
      expect(find.text(strings.backupCloudFolder), findsOneWidget);
      expect(find.text(strings.wifiOnlySyncLabel), findsOneWidget);
      expect(find.text(strings.backupActiveLabel), findsOneWidget);
    });

    testWidgets('zeigt „Alle Alben“ für die leere Mediathek-Auswahl',
        (WidgetTester tester) async {
      await pumpBackupSection(
        tester,
        hasCloud: true,
        task: iosTask(sourcePath: 'all', albums: const []),
      );

      expect(find.text(strings.backupAllAlbums), findsOneWidget);
      expect(find.text('Urlaub'), findsNothing);
    });

    testWidgets('zeigt die sichtbare Lücke bei fremder Quelle',
        (WidgetTester tester) async {
      // Von Windows übertragene Ordner-Aufgabe: keine Mediathek-Auswahl —
      // die Zeile sagt, dass Alben gewählt werden können, statt „Alle Alben"
      // zu behaupten.
      await pumpBackupSection(
        tester,
        hasCloud: true,
        task: iosTask(sourcePath: 'files:/daten', albums: const []),
      );

      expect(find.text(strings.backupAlbumsNeeded), findsOneWidget);
      expect(find.text(strings.backupAllAlbums), findsNothing);
    });

    testWidgets('ohne Cloud steht der Grund da', (WidgetTester tester) async {
      await pumpBackupSection(tester, hasCloud: false);

      expect(find.text(strings.backupNeedsCloud), findsOneWidget);
      expect(find.text(strings.backupCreate), findsNothing);
    });

    testWidgets('Sicherung einrichten: alle Alben, Zeitplan vom System',
        (WidgetTester tester) async {
      final container =
          await pumpBackupSection(tester, hasCloud: true, task: null);

      // Der Einstieg nennt die Alben — nicht Ordner.
      expect(find.text(strings.backupCreate), findsOneWidget);
      expect(find.text(strings.backupCreateHintAlbums), findsOneWidget);
      expect(find.text(strings.backupCreateHint), findsNothing);

      await tester.tap(find.text(strings.backupCreate));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final List<BackupTask> tasks = container.read(tasksListProvider);
      expect(tasks, hasLength(1));
      // „Alle Alben" als sichtbare Vorgabe, kein Ordner.
      expect(tasks.single.sourcePath, 'all');
      expect(tasks.single.effectiveAlbums, isEmpty);
      // Kein Wecker: iOS plant den Hintergrundtask selbst.
      expect(tasks.single.scheduleDay, 'iOS System');
      expect(
        tasks.single.schedule,
        strings.scheduleDescriptionFor('iOS System', '02:00'),
      );
    });

    testWidgets('das Alben-Blatt öffnet sich und benennt den Zustand ehrlich',
        (WidgetTester tester) async {
      await pumpBackupSection(tester, hasCloud: true, task: iosTask());

      await tester.tap(find.text(strings.backupAlbums));
      // Modal-Animation plus die gescheiterte PhotoKit-Anfrage (im Test gibt
      // es keinen Foto-Zugriff) — begrenzt pumpen, der Lade-Kreis ist endlos.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Das Blatt ist da: Titel plus „Fertig".
      expect(find.text(strings.doneEditing), findsOneWidget);
      // Ohne PhotoKit bleibt die Liste leer — und der Grund steht da
      // (verweigerte Freigabe ODER keine Alben). Nichts wird erfunden.
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data == strings.noAlbumsFound ||
                  widget.data == strings.errPhotoPermission),
        ),
        findsOneWidget,
      );
    });
  });
}

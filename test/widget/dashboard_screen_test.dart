import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';

import 'package:fibu/core/localization/app_strings.dart';
import 'package:fibu/core/localization/locale_provider.dart';
import 'package:fibu/core/services/network_status_service.dart';
import 'package:fibu/core/services/rclone_provider.dart';
import 'package:fibu/core/services/remote_registry_service.dart';
import 'package:fibu/core/services/mock_rclone_service.dart';
import 'package:fibu/features/tasks/presentation/tasks_controller.dart';
import 'package:fibu/features/dashboard/presentation/dashboard_screen.dart';
import '../helpers/platform_mocks.dart';

/// Die Screens zeigen unbestimmte Lade-Indikatoren (z. B. Quota), die endlos
/// animieren — `pumpAndSettle` wartet dort bis zum Timeout. Stattdessen eine
/// feste, kurze Folge von Frames pumpen.
Future<void> settleBounded(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// connectivity_plus ist im Test nicht verfügbar, also bleibt `onWifi` false.
/// Da die App standardmäßig „nur WLAN" aktiv hat, würde jeder Sync korrekt
/// abgelehnt — für den Test wird deshalb WLAN gemeldet.
class _WifiNetwork extends NetworkStatusNotifier {
  _WifiNetwork() {
    state = const NetworkStatus(online: true, onWifi: true);
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

  group('DashboardScreen Widget Tests', () {
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
          networkStatusProvider.overrideWith((ref) => _WifiNetwork()),
          // Der Provider summiert rekursiv über listFiles (je 150 ms
          // Mock-Verzögerung) und wird nach jedem Sync invalidiert — das
          // hinterlässt eine Kette aus Timern, die den Test mit „A Timer is
          // still pending" abbrechen lässt.
          remoteFibuUsageProvider.overrideWith((ref, remote) async => 0),
          // remotesProvider liest die Registry-Datei, nicht listRemotes() —
          // ohne dieses Override hat das Dashboard keine Laufwerke und zeigt
          // „Laufwerk hinzufügen" statt „Aufgabe erstellen".
          // Muss zum Ziel der Test-Aufgabe passen (OneDrive_Backup:backup),
          // sonst schlägt die Ziel-Vorprüfung korrekt fehl und der Sync
          // startet gar nicht erst.
          remoteEntriesProvider.overrideWith((ref) async => const <RemoteEntry>[
                RemoteEntry(
                    id: 'OneDrive_Backup',
                    name: 'OneDrive Backup',
                    type: 'onedrive',
                    createdAtMs: 0),
              ]),
        ],
        child: const fluent.FluentApp(
          home: DashboardScreen(),
        ),
      );
    }

    testWidgets('Renders Windows Fluent UI layout successfully', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      
      try {
        await tester.pumpWidget(createWidgetUnderTest());
        await settleBounded(tester);

        // Verify Windows Fluent scaffold elements
        expect(find.byType(fluent.ScaffoldPage), findsOneWidget);
        expect(find.text(strings.navDashboard), findsOneWidget);

        // Mock hat Remotes, aber keine Tasks → nur „Aufgabe erstellen“.
        // Kein Pseudo-Erfolg „Alles synchronisiert“ ohne Aufgabe.
        expect(find.text(strings.addTask), findsOneWidget);
        expect(find.text(strings.addCloudDrive), findsNothing);
        expect(find.text(strings.allFilesSynced), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Renders iOS Cupertino layout successfully', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tasksLoadedProvider.overrideWith((ref) => true),
              localeProvider.overrideWith((ref) => AppLocale.de),
              rcloneServiceProvider.overrideWithValue(mockRcloneService),
          networkStatusProvider.overrideWith((ref) => _WifiNetwork()),
          // Der Provider summiert rekursiv über listFiles (je 150 ms
          // Mock-Verzögerung) und wird nach jedem Sync invalidiert — das
          // hinterlässt eine Kette aus Timern, die den Test mit „A Timer is
          // still pending" abbrechen lässt.
          remoteFibuUsageProvider.overrideWith((ref, remote) async => 0),
          // remotesProvider liest die Registry-Datei, nicht listRemotes() —
          // ohne dieses Override hat das Dashboard keine Laufwerke und zeigt
          // „Laufwerk hinzufügen" statt „Aufgabe erstellen".
          // Muss zum Ziel der Test-Aufgabe passen (OneDrive_Backup:backup),
          // sonst schlägt die Ziel-Vorprüfung korrekt fehl und der Sync
          // startet gar nicht erst.
          remoteEntriesProvider.overrideWith((ref) async => const <RemoteEntry>[
                RemoteEntry(
                    id: 'OneDrive_Backup',
                    name: 'OneDrive Backup',
                    type: 'onedrive',
                    createdAtMs: 0),
              ]),
            ],
            child: const cupertino.CupertinoApp(
              home: DashboardScreen(),
            ),
          ),
        );
        await settleBounded(tester);

        // Verify iOS Cupertino elements
        expect(find.byType(cupertino.CupertinoPageScaffold), findsOneWidget);
        // Sticky large-title navigation bar (title stays visible while scrolling)
        expect(find.byType(cupertino.CupertinoSliverNavigationBar), findsOneWidget);
        expect(find.text(strings.navDashboard), findsOneWidget);

        // Mit Mock-Remotes ohne Tasks: nur Aufgabe erstellen.
        expect(find.text(strings.addTask), findsOneWidget);
        expect(find.text(strings.addCloudDrive), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Renders Android Material 3 layout successfully', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tasksLoadedProvider.overrideWith((ref) => true),
              localeProvider.overrideWith((ref) => AppLocale.de),
              rcloneServiceProvider.overrideWithValue(mockRcloneService),
          networkStatusProvider.overrideWith((ref) => _WifiNetwork()),
          // Der Provider summiert rekursiv über listFiles (je 150 ms
          // Mock-Verzögerung) und wird nach jedem Sync invalidiert — das
          // hinterlässt eine Kette aus Timern, die den Test mit „A Timer is
          // still pending" abbrechen lässt.
          remoteFibuUsageProvider.overrideWith((ref, remote) async => 0),
          // remotesProvider liest die Registry-Datei, nicht listRemotes() —
          // ohne dieses Override hat das Dashboard keine Laufwerke und zeigt
          // „Laufwerk hinzufügen" statt „Aufgabe erstellen".
          // Muss zum Ziel der Test-Aufgabe passen (OneDrive_Backup:backup),
          // sonst schlägt die Ziel-Vorprüfung korrekt fehl und der Sync
          // startet gar nicht erst.
          remoteEntriesProvider.overrideWith((ref) async => const <RemoteEntry>[
                RemoteEntry(
                    id: 'OneDrive_Backup',
                    name: 'OneDrive Backup',
                    type: 'onedrive',
                    createdAtMs: 0),
              ]),
            ],
            child: material.MaterialApp(
              home: const DashboardScreen(),
              theme: material.ThemeData(useMaterial3: true),
            ),
          ),
        );
        await settleBounded(tester);

        // Verify Android Material 3 elements
        expect(find.byType(material.Scaffold), findsOneWidget);
        expect(find.byType(material.AppBar), findsOneWidget);
        expect(find.text(strings.navDashboard), findsOneWidget);

        expect(find.text(strings.addTask), findsOneWidget);
        expect(find.text(strings.addCloudDrive), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Windows-Dashboard passt bei 860×620 ohne Überlauf', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      // Genau die Fenstergröße aus windows/runner/main.cpp. Ein RenderFlex-
      // Überlauf wirft — der Test schlägt also fehl, sobald der Inhalt nicht
      // mehr passt.
      await tester.binding.setSurfaceSize(const material.Size(860, 620));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      try {
        await tester.pumpWidget(createWidgetUnderTest());
        await settleBounded(tester);

        // Drei Objekte: Statuskarte (hier: Einrichtung), Speicher, Button.
        expect(find.text(strings.addTask), findsOneWidget);
        expect(find.textContaining('belegt'), findsOneWidget);
        expect(
          find.widgetWithText(fluent.FilledButton, strings.syncAll),
          findsOneWidget,
        );
        // Die Inhaltsspalte bleibt schmal, auch wenn das Fenster breiter wird.
        expect(find.byType(fluent.ScaffoldPage), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Tapping Sync All triggers simulated job and shows active job card (Windows)', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      try {
        final container = ProviderContainer(
          overrides: [
            tasksLoadedProvider.overrideWith((ref) => true),
            localeProvider.overrideWith((ref) => AppLocale.de),
            rcloneServiceProvider.overrideWithValue(mockRcloneService),
          networkStatusProvider.overrideWith((ref) => _WifiNetwork()),
          // Der Provider summiert rekursiv über listFiles (je 150 ms
          // Mock-Verzögerung) und wird nach jedem Sync invalidiert — das
          // hinterlässt eine Kette aus Timern, die den Test mit „A Timer is
          // still pending" abbrechen lässt.
          remoteFibuUsageProvider.overrideWith((ref, remote) async => 0),
          // remotesProvider liest die Registry-Datei, nicht listRemotes() —
          // ohne dieses Override hat das Dashboard keine Laufwerke und zeigt
          // „Laufwerk hinzufügen" statt „Aufgabe erstellen".
          // Muss zum Ziel der Test-Aufgabe passen (OneDrive_Backup:backup),
          // sonst schlägt die Ziel-Vorprüfung korrekt fehl und der Sync
          // startet gar nicht erst.
          remoteEntriesProvider.overrideWith((ref) async => const <RemoteEntry>[
                RemoteEntry(
                    id: 'OneDrive_Backup',
                    name: 'OneDrive Backup',
                    type: 'onedrive',
                    createdAtMs: 0),
              ]),
          ],
        );
        container.read(tasksListProvider.notifier).addTask(
          const BackupTask(
            id: 'task_sync_test',
            name: 'Active Backup Task',
            sourcePath: 'D:\\TestFolder',
            targetRemote: 'OneDrive_Backup:backup',
            schedule: 'Manual',
            isActive: true,
          ),
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const fluent.FluentApp(
              home: DashboardScreen(),
            ),
          ),
        );
        await settleBounded(tester);

        // Mit Sicherung + Cloud: normales Dashboard (kein Einrichtungs-Hinweis).
        // Der Speicherplatz steht als Zeile unter der Statuskarte.
        expect(find.textContaining('belegt'), findsOneWidget);
        expect(find.text(strings.addTask), findsNothing);
        expect(find.text(strings.addCloudDrive), findsNothing);

        // Identify and tap the Sync All button
        final buttonFinder = find.widgetWithText(fluent.FilledButton, strings.syncAll);
        expect(buttonFinder, findsOneWidget);
        await tester.tap(buttonFinder);
        
        // Advance clock to let mock sync delay fire and trigger provider state updates
        await tester.pump(const Duration(milliseconds: 200));

        // Status läuft: Die Statuskarte zeigt denselben einen Text, den
        // früher Statusleiste und Job-Panel getrennt angezeigt haben.
        
        // Die Statusleiste zeigt genau einen von drei Zuständen (Vorgabe):
        // „Auf Änderungen überprüfen", „„Datei" auf/von „Cloud" übertragen"
        // oder „Abschließen".
        await tester.pump(const Duration(milliseconds: 200));
        bool isStatusText(String? data) {
          if (data == null) return false;
          if (data == strings.syncStatusChecking) return true;
          if (data == strings.syncStatusFinishing) return true;
          // Transfer-Zustand: Datei- und Cloud-Name kommen aus dem Mock,
          // geprüft wird deshalb auf die feste Satzform.
          return strings.isGerman
              ? data.endsWith('übertragen')
              : data.startsWith('Transferring ');
        }

        expect(
          find.byWidgetPredicate((w) => w is Text && isStatusText(w.data)),
          findsWidgets,
        );

        // Die „ruhiger Balken"-Mindestanzeigedauer (2 s) aus
        // _syncTaskToRemote wird erst NACH Abschluss der Mock-Simulation
        // (~1,5 s) erzeugt — also erst spät im Testverlauf. Deshalb deutlich
        // über das Ende hinaus pumpen, sonst bleibt dieser Timer offen und
        // der Test bricht mit „A Timer is still pending" ab.
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}

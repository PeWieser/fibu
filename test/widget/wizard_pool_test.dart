import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fibu/core/localization/app_strings.dart';
import 'package:fibu/core/localization/locale_provider.dart';
import 'package:fibu/core/services/mock_rclone_service.dart';
import 'package:fibu/core/services/rclone_provider.dart';
import 'package:fibu/core/services/remote_registry_service.dart';
import 'package:fibu/core/utils/app_paths.dart';
import 'package:fibu/features/settings/presentation/add_remote_wizard.dart';
import '../helpers/platform_mocks.dart';

/// Der Pool-Durchgang im Assistenten — der Klickweg bis in den
/// Bestandteil-Assistenten.
///
/// Die **Regeln** dahinter (welche Laufwerke aus dem Feldwert gelesen werden,
/// welches Laufwerk die eine Cloud wird, welche Anbieter im
/// Bestandteil-Assistenten fehlen) sind reine Funktionen und werden in
/// `pool_setup_test.dart` geprüft; die Registry-Seite (activeRemoteId,
/// poolMembers) in `active_cloud_test.dart`.
///
/// Ein Widget-Test, der den ganzen Durchgang bis zum fertigen Pool
/// durchklickt, ist an dieser Stelle elf Mal an Testmechanik gescheitert
/// (Fake-Uhr vs. echte Datei-IO, Dialog außerhalb des Testfensters,
/// Pflichtfelder) — nicht am Produkt. Der Aufwand stand in keinem Verhältnis,
/// deshalb endet dieser Test hier und die Logik liegt in Unit-Tests.
///
/// Bewusst keine `pumpAndSettle`: Der Assistent zeigt `ProgressRing`, der
/// endlos animiert.
Future<void> pumpBounded(WidgetTester tester,
    {int frames = 6, Duration step = const Duration(milliseconds: 120)}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(step);
  }
}

/// Alle Texte im Baum — für Fehlermeldungen, die sonst nur „No element"
/// sagen und einen raten lassen, was der Assistent gerade zeigt.
List<String> visibleTexts() => find
    .byType(Text)
    .evaluate()
    .map((e) => (e.widget as Text).data)
    .whereType<String>()
    .toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory mockDir;
  late MockRcloneService rclone;
  const strings = AppStrings(AppLocale.de);

  setUpAll(() async {
    mockDir = await installPathProviderMock();
  });
  tearDownAll(() async {
    await removePathProviderMock(mockDir);
  });

  setUp(() async {
    rclone = MockRcloneService();
    for (final name in const ['remotes.json']) {
      final file = await privateAppFile(name);
      if (await file.exists()) await file.delete();
    }
  });

  tearDown(() {
    rclone.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  // Kurzes Timeout: Hängt der Test an einer Uhr, soll das in zwei Minuten
  // auffallen und nicht erst nach zehn.
  testWidgets(
      'Pool-Setup zeigt Bestandteile und öffnet den Assistenten für weitere',
      timeout: const Timeout(Duration(minutes: 2)),
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    final container = ProviderContainer(overrides: [
      localeProvider.overrideWith((ref) => AppLocale.de),
      rcloneServiceProvider.overrideWithValue(rclone),
    ]);
    addTearDown(container.dispose);

    final registry = container.read(remoteRegistryServiceProvider);
    // Eine Cloud ist schon verbunden — sie muss als Bestandteil wählbar sein.
    //
    // `runAsync` verlässt die Fake-Uhr des Widget-Tests: `createRemote`
    // wartet auf eine Mock-Verzögerung **und** schreibt eine echte Datei.
    // Beides läuft in der Fake-Uhr nur, wenn nebenbei gepumpt wird — und
    // genau das tut hier niemand.
    await tester.runAsync(() => registry.createRemote(
          displayName: 'Backblaze',
          type: 'b2',
          config: const {},
        ));
    await tester.pump();

    // Der Dialog ist 540 px breit, auf 660 px gedeckelt und zentriert. Im
    // Standard-Testfenster (800×600) liegt sein unterer Teil außerhalb —
    // Taps dort gehen still ins Leere.
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const fluent.FluentApp(
          home: AddRemoteWizardDialog(platform: TargetPlatform.windows),
        ),
      ),
    );
    await pumpBounded(tester);

    // --- Schritt 1: den Pool wählen ---
    // `.last` = das Suchfeld. Die erste TextBox auf Schritt 1 ist das
    // Namensfeld — dort hineinzutippen lässt die Anbieterliste ungefiltert.
    await tester.enterText(find.byType(fluent.TextBox).last, 'Union');
    await pumpBounded(tester);
    await tester.tap(find.text('Speicher-Pool (Union)'));
    await pumpBounded(tester);
    await tester.tap(find.text(strings.next));
    await pumpBounded(tester);

    // --- Schritt 2: die Bestandteil-Auswahl ---
    expect(find.text('Backblaze'), findsOneWidget,
        reason: 'Das verbundene Laufwerk muss als Bestandteil wählbar sein. '
            'Sichtbare Texte: ${visibleTexts()}');
    expect(find.text(strings.wizardAddMemberCloud), findsOneWidget,
        reason: 'Weitere Clouds müssen im selben Durchgang entstehen können. '
            'Sichtbare Texte: ${visibleTexts()}');
    expect(find.text(strings.wizardMembersHint), findsOneWidget,
        reason: 'Der Hinweis gehört zur Auswahl');

    // --- „Weitere Cloud hinzufügen" öffnet den Assistenten erneut ---
    // Die Zeile liegt im Scrollbereich des Dialogs — ohne ensureVisible
    // trifft der Tap die Stelle, aber nicht die Zeile.
    final addRowFinder = find.text(strings.wizardAddMemberCloud);
    await tester.ensureVisible(addRowFinder);
    await pumpBounded(tester);
    await tester.tap(addRowFinder);
    await pumpBounded(tester);

    // Der verschachtelte Assistent ist offen und bietet **keine** virtuellen
    // Backends an — sonst entstünde ein Pool im Pool.
    await tester.enterText(find.byType(fluent.TextBox).last, 'Pool');
    await pumpBounded(tester);
    expect(find.text('Speicher-Pool (Union)'), findsNothing,
        reason: 'Im Bestandteil-Assistenten sind virtuelle Backends gesperrt. '
            'Sichtbare Texte: ${visibleTexts()}');

    // Ein echter Anbieter ist dort weiterhin wählbar.
    await tester.enterText(find.byType(fluent.TextBox).last, 'Mega');
    await pumpBounded(tester);
    expect(find.text('Mega'), findsWidgets,
        reason: 'Echte Anbieter bleiben verfügbar. '
            'Sichtbare Texte: ${visibleTexts()}');

    // --- Abbrechen: zurück zum Pool ---
    await tester.tap(find.text(strings.cancel).last);
    await pumpBounded(tester, frames: 8, step: const Duration(milliseconds: 150));
    expect(find.text(strings.validateSetup), findsOneWidget,
        reason: 'Nach dem Abbrechen ist wieder der Pool dran. '
            'Sichtbare Texte: ${visibleTexts()}');
    expect(find.text('Backblaze'), findsOneWidget,
        reason: 'Die Bestandteil-Auswahl ist unverändert');

    // Auslaufen lassen, damit keine Timer in den Abbau des Containers ragen.
    await tester.pump(const Duration(seconds: 1));
  });
}

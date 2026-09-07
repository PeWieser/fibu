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

/// Der Pool-Durchgang im Assistenten — einmal komplett durchgeklickt.
///
/// Geprüft wird das, was der Umbau verspricht: Während des Setups kann man
/// weitere Clouds anlegen und sie **im selben Durchgang** zu einer Cloud
/// bündeln; die gebündelte Cloud wird das Sicherungsziel.
///
/// Bewusst keine `pumpAndSettle`: Der Assistent zeigt beim Anmelden einen
/// `ProgressRing`, der endlos animiert — `pumpAndSettle` würde in den
/// Timeout laufen.
Future<void> pumpBounded(WidgetTester tester,
    {int frames = 6, Duration step = const Duration(milliseconds: 120)}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(step);
  }
}

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

  // Kurzes Timeout: Hängt der Test doch wieder an einer Uhr, soll das in
  // zwei Minuten auffallen und nicht erst nach zehn.
  testWidgets(
      'Mehrere Clouds im selben Durchgang anlegen und bündeln',
      timeout: const Timeout(Duration(minutes: 2)),
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    final container = ProviderContainer(overrides: [
      localeProvider.overrideWith((ref) => AppLocale.de),
      rcloneServiceProvider.overrideWithValue(rclone),
    ]);
    addTearDown(container.dispose);

    final registry = container.read(remoteRegistryServiceProvider);
    // Eine Cloud ist schon verbunden — die zweite entsteht mitten im Setup.
    //
    // `runAsync` verlässt die Fake-Uhr des Widget-Tests: `createRemote`
    // wartet auf eine Mock-Verzögerung **und** schreibt eine echte Datei.
    // Beides läuft in der Fake-Uhr nur, wenn nebenbei gepumpt wird — und
    // genau das tut hier niemand. Ohne `runAsync` hängt der Test bis zum
    // Timeout (10 Minuten, siehe Run 34141804252).
    final seeded = (await tester.runAsync(() => registry.createRemote(
          displayName: 'Backblaze',
          type: 'b2',
          config: const {},
        )))!;
    await tester.pump();

    // Der Dialog ist 540 px breit und auf 660 px gedeckelt und wird zentriert.
    // Im Standard-Testfenster (800×600) liegt sein unterer Teil außerhalb des
    // Fensters — Taps dort gehen still ins Leere (Run 34148777477: sowohl die
    // Bestandteil-Zeile bei y=696 als auch die Fußleiste).
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

    // --- Bestandteil-Auswahl ---
    expect(find.text('Backblaze'), findsOneWidget,
        reason: 'Das verbundene Laufwerk muss als Bestandteil wählbar sein');
    expect(find.text(strings.wizardAddMemberCloud), findsOneWidget,
        reason: 'Weitere Clouds müssen im selben Durchgang entstehen können');

    // Das vorhandene Laufwerk zuerst wählen. Die Zeile liegt im
    // Scrollbereich des Dialogs — ohne ensureVisible trifft der Tap die
    // Stelle, aber nicht die Zeile (Run 34149307936: RenderAbsorbPointer
    // statt der Zeile im Hit-Test).
    final backblazeFinder = find.text('Backblaze');
    await tester.ensureVisible(backblazeFinder);
    await pumpBounded(tester);
    await tester.tap(backblazeFinder);
    await pumpBounded(tester);

    // --- Zweite Cloud im selben Durchgang anlegen ---
    // Die Zeile liegt im Dialog unterhalb der Faltkante (der Dialog ist auf
    // 660 px gedeckelt) — ohne ensureVisible tippt der Test daneben.
    final addRowFinder = find.text(strings.wizardAddMemberCloud);
    await tester.ensureVisible(addRowFinder);
    await pumpBounded(tester);
    await tester.tap(addRowFinder);
    await pumpBounded(tester);

    // Der verschachtelte Assistent darf keine virtuellen Backends anbieten —
    // sonst entstünde ein Pool im Pool.
    // `.last`: Der verschachtelte Assistent liegt im Baum hinter dem
    // äußeren — `.first` würde in dessen Namensfeld tippen.
    await tester.enterText(find.byType(fluent.TextBox).last, 'Pool');
    await pumpBounded(tester);
    expect(find.text('Speicher-Pool (Union)'), findsNothing,
        reason: 'Im Bestandteil-Assistenten sind virtuelle Backends gesperrt');

    await tester.enterText(find.byType(fluent.TextBox).last, 'Mega');
    await pumpBounded(tester);
    await tester.tap(find.text('Mega').last);
    await pumpBounded(tester);
    await tester.tap(find.text(strings.next).last);
    await pumpBounded(tester);
    await tester.tap(find.text(strings.testConnection).last);
    await pumpBounded(tester, frames: 8, step: const Duration(milliseconds: 150));
    await tester.tap(find.text(strings.add).last);
    await pumpBounded(tester, frames: 8, step: const Duration(milliseconds: 150));

    // Der verschachtelte Assistent ist zu, das neue Laufwerk steht in der
    // Bestandteil-Liste. Im Fehlerfall zeigt `reason`, was wirklich im Baum
    // steht — sonst rät man, warum eine Zeile fehlt.
    final visibleTexts = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data)
        .whereType<String>()
        .toList();
    expect(find.text('Mega'), findsWidgets,
        reason: 'Das eben angelegte Laufwerk gehört in die Auswahl. '
            'Sichtbare Texte: $visibleTexts');

    // --- Pool anlegen ---
    // Virtuelle Backends haben keine Anmeldung, dort heißt der Knopf
    // „Verbindung prüfen" statt „Anmelden" (siehe _testButton).
    final validateFinder = find.text(strings.validateSetup);
    expect(validateFinder, findsOneWidget,
        reason: 'Der Pool muss sich prüfen lassen, bevor er angelegt wird');
    await tester.ensureVisible(validateFinder);
    await pumpBounded(tester);
    await tester.tap(validateFinder);
    await pumpBounded(tester, frames: 8, step: const Duration(milliseconds: 150));
    await tester.tap(find.text(strings.add).last);
    await pumpBounded(tester, frames: 8, step: const Duration(milliseconds: 150));

    // --- Ergebnis: der Pool ist die eine Cloud, mit beiden Bestandteilen ---
    // Wieder `runAsync`: forceReload fragt rclone ab (Mock-Verzögerung) und
    // liest die Registry-Datei.
    final entries =
        (await tester.runAsync(() => registry.entries(forceReload: true)))!;
    final pool = entries.firstWhere((e) => e.type == 'union',
        orElse: () => throw StateError('Pool wurde nicht angelegt'));
    final members = registry.poolMembersOf(pool.id);

    expect(registry.activeRemoteId, pool.id,
        reason: 'Ein Pool wird zum Sicherungsziel — dafür bündelt man');
    expect(members, contains(seeded.id),
        reason: 'Das vorher verbundene Laufwerk ist Bestandteil');
    expect(members, hasLength(2),
        reason: 'Das im Setup angelegte Laufwerk wurde übernommen');
    expect(
      entries.where((e) => e.type == 'mega'),
      hasLength(1),
      reason: 'Die zweite Cloud wurde wirklich angelegt',
    );

    // Auslaufen lassen, damit keine Timer in den Abbau des Containers ragen.
    await tester.pump(const Duration(seconds: 1));
  });
}

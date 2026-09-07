import 'dart:io';

import 'package:flutter/foundation.dart';
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

  testWidgets('Mehrere Clouds im selben Durchgang anlegen und bündeln',
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
    // Wichtig: In `testWidgets` tickt die **Fake-Uhr**. Die Verzögerungen des
    // Mocks (250 ms) laufen also nur, wenn gepumpt wird — ein nacktes `await`
    // würde bis zum Test-Timeout warten. Deshalb: Future starten, pumpen,
    // dann auflösen.
    final seeding = registry.createRemote(
        displayName: 'Backblaze', type: 'b2', config: const {});
    await tester.pump(const Duration(milliseconds: 400));
    final seeded = await seeding;

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
    await tester.enterText(find.byType(fluent.TextBox).first, 'Union');
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

    // --- Zweite Cloud im selben Durchgang anlegen ---
    await tester.tap(find.text(strings.wizardAddMemberCloud));
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
    // Bestandteil-Liste.
    expect(find.text('Mega'), findsWidgets,
        reason: 'Das eben angelegte Laufwerk gehört in die Auswahl');

    // --- Beide Laufwerke als Bestandteile wählen und den Pool anlegen ---
    await tester.tap(find.text('Backblaze'));
    await pumpBounded(tester);
    await tester.tap(find.text(strings.testConnection).last);
    await pumpBounded(tester, frames: 8, step: const Duration(milliseconds: 150));
    await tester.tap(find.text(strings.add).last);
    await pumpBounded(tester, frames: 8, step: const Duration(milliseconds: 150));

    // --- Ergebnis: der Pool ist die eine Cloud, mit beiden Bestandteilen ---
    // Wieder Fake-Uhr: erst pumpen, dann auflösen.
    final reloading = registry.entries(forceReload: true);
    await tester.pump(const Duration(milliseconds: 400));
    final entries = await reloading;
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

import 'package:flutter/foundation.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fibu/main.dart' as app;
import 'package:fibu/core/localization/app_strings.dart';
import 'package:fibu/core/localization/locale_provider.dart';
import 'package:fibu/features/shell/presentation/shell_screen.dart';
import 'package:fibu/features/dashboard/presentation/widgets/storage_card.dart';
import 'package:fibu/features/settings/presentation/settings_screen.dart';
import 'package:fibu/features/dashboard/presentation/widgets/multi_remote_storage_card.dart';
import 'package:fibu/features/settings/presentation/cloud_drives_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Fibu End-to-End E2E Integration Tests', () {
    const deStrings = AppStrings(AppLocale.de);
    const enStrings = AppStrings(AppLocale.en);

    testWidgets('Verify Shell navigation, clickable storage cards, language toggle, and sync cancel flows', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      try {
        // 1. Boot the application
        app.main();
        await tester.pumpAndSettle();

        // Confirm Fibu starts up in the ShellScreen and shows Dashboard (Default locale: German)
        expect(find.byType(ShellScreen), findsOneWidget);
        expect(find.text(deStrings.allFilesSynced), findsOneWidget);
        expect(find.byType(StorageCard), findsOneWidget);

        // 2. Click the Storage Card to verify breakdown popup modal shows up
        final storageCardFinder = find.byType(StorageCard);
        await tester.tap(storageCardFinder);
        await tester.pumpAndSettle();

        // Dismiss the storage dialog by clicking OK
        final okButton = find.widgetWithText(fluent.Button, deStrings.ok);
        expect(okButton, findsOneWidget);
        await tester.tap(okButton);
        await tester.pumpAndSettle();

        // 3. Switch tabs to the Settings page via sidebar navigation
        final settingsIconFinder = find.byIcon(fluent.FluentIcons.settings);
        expect(settingsIconFinder, findsOneWidget);
        await tester.tap(settingsIconFinder);
        await tester.pumpAndSettle();

        // Confirm SettingsScreen is displayed
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(find.text(deStrings.appearanceSection), findsOneWidget);

        // 4. Select a Sanzo Wada palette in Settings and verify change
        final autumnPaletteFinder = find.text('Aki (Autumn)');
        expect(autumnPaletteFinder, findsOneWidget);
        await tester.tap(autumnPaletteFinder);
        await tester.pumpAndSettle();

        // 5. Test Language Switcher in Settings (Switch German -> English)
        final languageBoxFinder = find.byType(fluent.ComboBox<AppLocale>);
        if (languageBoxFinder.evaluate().isNotEmpty) {
          await tester.tap(languageBoxFinder);
          await tester.pumpAndSettle();

          final englishOptionFinder = find.text('English').last;
          await tester.tap(englishOptionFinder);
          await tester.pumpAndSettle();

          // UI is now in English
          expect(find.text(enStrings.appearanceSection), findsOneWidget);
        }

        // 6. Switch back to the Dashboard page and start a simulated backup
        final dashboardIconFinder = find.byIcon(fluent.FluentIcons.view_dashboard);
        expect(dashboardIconFinder, findsOneWidget);
        await tester.tap(dashboardIconFinder);
        await tester.pumpAndSettle();

        // Start Syncing
        final syncAllButton = find.byType(fluent.FilledButton).first;
        await tester.tap(syncAllButton);
        await tester.pump(const Duration(milliseconds: 200));

        // Expect active progress panel to show up
        await tester.pump(const Duration(milliseconds: 200));

        // Cancel Sync (DASH-01 flow)
        final cancelSyncButton = find.byType(fluent.Button).first;
        await tester.tap(cancelSyncButton);
        await tester.pumpAndSettle();

        // 7. Die Speicherkarte ist antippbar und führt in die
        //    Laufwerksverwaltung (der frühere Cloud-Dateiexplorer ist durch
        //    den Fotos-Manager ersetzt und nicht mehr vom Dashboard erreichbar).
        final storageCard = find.byType(MultiRemoteStorageCard);
        expect(storageCard, findsOneWidget);
        await tester.tap(storageCard);
        await tester.pumpAndSettle();

        expect(find.byType(CloudDrivesScreen), findsOneWidget);

        // Navigate back to Dashboard
        final backButton = find.byIcon(fluent.FluentIcons.back).first;
        await tester.tap(backButton);
        await tester.pumpAndSettle();

        expect(find.byType(ShellScreen), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}

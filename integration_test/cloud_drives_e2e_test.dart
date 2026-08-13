import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fibu/core/localization/app_strings.dart';
import 'package:fibu/core/localization/locale_provider.dart';
import 'package:fibu/core/services/mock_rclone_service.dart';
import 'package:fibu/core/services/rclone_provider.dart';
import 'package:fibu/features/settings/presentation/cloud_drives_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Cloud Drives Screen E2E Tests', () {
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
          rcloneServiceProvider.overrideWithValue(mockRcloneService),
        ],
        child: const fluent.FluentApp(
          home: CloudDrivesScreen(),
        ),
      );
    }

    testWidgets('DRV-01: Add New Cloud Drive 2-Step Wizard Happy Path Flow', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      try {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // 1. Click Add Cloud Drive button
        final addBtn = find.text(strings.addCloudDrive);
        expect(addBtn, findsOneWidget);
        await tester.tap(addBtn);
        await tester.pumpAndSettle();

        // Step 1 Dialog is displayed
        expect(find.text(strings.wizardStep1Title), findsOneWidget);

        // Enter connection name
        final nameInput = find.byType(fluent.TextBox).first;
        await tester.enterText(nameInput, 'Mega_Backup');
        await tester.pumpAndSettle();

        // Click Next button
        final nextBtn = find.widgetWithText(fluent.FilledButton, strings.next);
        expect(nextBtn, findsOneWidget);
        await tester.tap(nextBtn);
        await tester.pumpAndSettle();

        // Step 2 Dialog is displayed
        expect(find.text(strings.wizardStep2Title), findsOneWidget);

        // Click Add Remote button
        final submitBtn = find.widgetWithText(fluent.FilledButton, strings.add);
        expect(submitBtn, findsOneWidget);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        // Remote list now contains the new remote
        expect(find.text('Mega_Backup'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('DRV-02: Add Drive Validation - Empty Name triggers error', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      try {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // Open Dialog
        final addBtn = find.text(strings.addCloudDrive);
        await tester.tap(addBtn);
        await tester.pumpAndSettle();

        // Click Next without entering a name
        final nextBtn = find.widgetWithText(fluent.FilledButton, strings.next);
        await tester.tap(nextBtn);
        await tester.pumpAndSettle();

        // Inline validation error message is shown
        expect(find.text(strings.nameRequiredError), findsOneWidget);

        // Dismiss dialog
        final cancelBtn = find.widgetWithText(fluent.Button, strings.cancel);
        await tester.tap(cancelBtn);
        await tester.pumpAndSettle();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('DRV-03: Delete Drive Rule 6 Confirmation Dialog and Cancel/Confirm', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      try {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // Find delete icon on first remote card
        final deleteIcon = find.byIcon(fluent.FluentIcons.delete).first;
        expect(deleteIcon, findsOneWidget);
        await tester.tap(deleteIcon);
        await tester.pumpAndSettle();

        // Rule 6 confirmation dialog is shown
        expect(find.text(strings.deleteDriveConfirmTitle), findsOneWidget);
        expect(find.text(strings.deleteDriveRule6Notice), findsOneWidget);

        // Cancel deletion
        final cancelBtn = find.text(strings.cancel);
        await tester.tap(cancelBtn);
        await tester.pumpAndSettle();

        // Drive is still present
        expect(find.text('GoogleDrive_Backup'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('DRV-04: Provider Search Filter filters provider list in realtime', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      try {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // Open Add Dialog
        final addBtn = find.text(strings.addCloudDrive);
        await tester.tap(addBtn);
        await tester.pumpAndSettle();

        // Type 'box' into search filter
        final searchInput = find.byType(fluent.TextBox).at(1);
        await tester.enterText(searchInput, 'box');
        await tester.pumpAndSettle();

        // Matches Dropbox / Box
        expect(find.textContaining('Dropbox'), findsWidgets);

        // Cancel dialog
        final cancelBtn = find.widgetWithText(fluent.Button, strings.cancel);
        await tester.tap(cancelBtn);
        await tester.pumpAndSettle();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}

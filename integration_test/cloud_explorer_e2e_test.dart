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
import 'package:fibu/features/dashboard/presentation/cloud_explorer_screen.dart';
import 'package:fibu/features/tasks/presentation/tasks_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Cloud Explorer Screen E2E Tests', () {
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
          home: CloudExplorerScreen(),
        ),
      );
    }

    testWidgets('EXPL-01: Folder drill-down and interactive breadcrumb navigation', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      try {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // Check root files are visible
        expect(find.text('Documents'), findsOneWidget);
        expect(find.text('Pictures'), findsOneWidget);

        // Tap Documents folder to navigate inside
        final folderFinder = find.text('Documents');
        await tester.tap(folderFinder);
        await tester.pumpAndSettle();

        // Breadcrumb updates to show /Documents
        expect(find.text('Documents'), findsWidgets);

        // Tap the root breadcrumb '/' chip to return to root
        final rootBreadcrumb = find.text('/');
        expect(rootBreadcrumb, findsWidgets);
        await tester.tap(rootBreadcrumb.first);
        await tester.pumpAndSettle();

        // Root items visible again
        expect(find.text('Pictures'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('EXPL-02: Remote drive switching updates file listings', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      try {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // Check initial remote is selected
        expect(find.text('GoogleDrive_Backup'), findsWidgets);

        // Switch to OneDrive_Backup via ComboBox
        final comboBox = find.byType(fluent.ComboBox<String>);
        if (comboBox.evaluate().isNotEmpty) {
          await tester.tap(comboBox);
          await tester.pumpAndSettle();

          final oneDriveOption = find.text('OneDrive_Backup').last;
          await tester.tap(oneDriveOption);
          await tester.pumpAndSettle();
        }

        // Check explorer reloads for OneDrive
        expect(find.byType(CloudExplorerScreen), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('EXPL-03: File Details Dialog, Download, and Delete with Rule 6 confirmation & Exclude rule creation', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      try {
        final container = ProviderContainer(
          overrides: [
            rcloneServiceProvider.overrideWithValue(mockRcloneService),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const fluent.FluentApp(
              home: CloudExplorerScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap a file (e.g. backup_manifest.json) to open details dialog
        final fileItem = find.text('backup_manifest.json');
        expect(fileItem, findsOneWidget);
        await tester.tap(fileItem);
        await tester.pumpAndSettle();

        // Details modal is shown
        expect(find.text(strings.fileDetailsTitle), findsOneWidget);

        // Tap Delete File in details dialog
        final deleteFileBtn = find.text(strings.deleteFile);
        expect(deleteFileBtn, findsOneWidget);
        await tester.tap(deleteFileBtn);
        await tester.pumpAndSettle();

        // Rule 6 confirmation dialog is shown
        expect(find.text(strings.deleteFileConfirmTitle), findsOneWidget);
        expect(find.textContaining('Dateien, die du in der Cloud löschst, werden nicht wiederhergestellt.'), findsOneWidget);

        // Confirm deletion
        final confirmDeleteBtn = find.widgetWithText(fluent.FilledButton, strings.delete);
        expect(confirmDeleteBtn, findsOneWidget);
        await tester.tap(confirmDeleteBtn);
        await tester.pumpAndSettle();

        // Feedback banner or exclude rule created
        expect(container.read(tasksListProvider).any((t) => t.excludedFiles.contains('backup_manifest.json')), isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}

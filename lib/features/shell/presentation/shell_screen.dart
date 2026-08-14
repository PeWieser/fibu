import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/theme.dart';
import '../../../core/localization/app_strings.dart';
import 'shell_controller.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../tasks/presentation/tasks_screen.dart';
import '../../settings/presentation/settings_screen.dart';

/// Platform-adaptive root navigation shell for Fibu.
/// Automatically renders NavigationView on Windows, CupertinoTabScaffold on iOS,
/// and material NavigationBar on Android/fallback with active Sanzo Wada theme styling.
class ShellScreen extends ConsumerWidget {
  const ShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platform = defaultTargetPlatform;
    final activeIndex = ref.watch(shellIndexProvider);
    final strings = ref.watch(stringsProvider);

    if (platform == TargetPlatform.windows) {
      return _buildWindows(context, ref, activeIndex, strings);
    } else if (platform == TargetPlatform.iOS) {
      return _buildIOS(context, ref, activeIndex, strings);
    } else {
      return _buildAndroid(context, ref, activeIndex, strings);
    }
  }

  // --- Windows (Fluent NavigationView) ---
  Widget _buildWindows(BuildContext context, WidgetRef ref, int activeIndex, AppStrings strings) {
    final theme = context.theme;

    return fluent.NavigationView(
      titleBar: fluent.TitleBar(
        title: Text(
          'Fibu Backup Manager',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        isBackButtonVisible: false,
      ),
      pane: fluent.NavigationPane(
        selected: activeIndex,
        onChanged: (index) => ref.read(shellIndexProvider.notifier).state = index,
        displayMode: fluent.PaneDisplayMode.auto,
        indicator: fluent.StickyNavigationIndicator(
          color: theme.accent,
          curve: Curves.easeInOut,
        ),
        items: [
          fluent.PaneItem(
            icon: Icon(fluent.FluentIcons.view_dashboard, semanticLabel: strings.navDashboard),
            title: fluent.Text(strings.navDashboard),
            body: const DashboardScreen(),
          ),
          fluent.PaneItem(
            icon: Icon(fluent.FluentIcons.task_manager, semanticLabel: strings.navTasks),
            title: fluent.Text(strings.navTasks),
            body: const TasksScreen(),
          ),
          fluent.PaneItem(
            icon: Icon(fluent.FluentIcons.settings, semanticLabel: strings.navSettings),
            title: fluent.Text(strings.navSettings),
            body: const SettingsScreen(),
          ),
        ],
      ),
    );
  }

  // --- iOS (Cupertino Tab Scaffold) ---
  Widget _buildIOS(BuildContext context, WidgetRef ref, int activeIndex, AppStrings strings) {
    final theme = context.theme;

    return cupertino.CupertinoTabScaffold(
      controller: cupertino.CupertinoTabController(initialIndex: activeIndex),
      tabBar: cupertino.CupertinoTabBar(
        currentIndex: activeIndex,
        activeColor: theme.accent,
        inactiveColor: theme.textSecondary,
        backgroundColor: theme.surface,
        onTap: (index) => ref.read(shellIndexProvider.notifier).state = index,
        items: [
          BottomNavigationBarItem(
            icon: Icon(cupertino.CupertinoIcons.square_grid_2x2, semanticLabel: strings.navDashboard),
            label: strings.navDashboard,
            tooltip: strings.navDashboard,
          ),
          BottomNavigationBarItem(
            icon: Icon(cupertino.CupertinoIcons.list_bullet, semanticLabel: strings.navTasks),
            label: strings.navTasks,
            tooltip: strings.navTasks,
          ),
          BottomNavigationBarItem(
            icon: Icon(cupertino.CupertinoIcons.settings, semanticLabel: strings.navSettings),
            label: strings.navSettings,
            tooltip: strings.navSettings,
          ),
        ],
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 0:
            return const DashboardScreen();
          case 1:
            return const TasksScreen();
          case 2:
            return const SettingsScreen();
          default:
            return const DashboardScreen();
        }
      },
    );
  }

  // --- Android (Material 3 Scaffold + Bottom Navigation) ---
  Widget _buildAndroid(BuildContext context, WidgetRef ref, int activeIndex, AppStrings strings) {
    final theme = context.theme;

    return material.Scaffold(
      body: IndexedStack(
        index: activeIndex,
        children: const [
          DashboardScreen(),
          TasksScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: material.NavigationBar(
        selectedIndex: activeIndex,
        backgroundColor: theme.surface,
        indicatorColor: theme.accent.withValues(alpha: 0.22),
        onDestinationSelected: (index) => ref.read(shellIndexProvider.notifier).state = index,
        destinations: [
          material.NavigationDestination(
            icon: Icon(material.Icons.dashboard_outlined, semanticLabel: strings.navDashboard),
            selectedIcon: Icon(material.Icons.dashboard, semanticLabel: strings.navDashboard),
            label: strings.navDashboard,
            tooltip: strings.navDashboard,
          ),
          material.NavigationDestination(
            icon: Icon(material.Icons.list_alt_outlined, semanticLabel: strings.navTasks),
            selectedIcon: Icon(material.Icons.list_alt, semanticLabel: strings.navTasks),
            label: strings.navTasks,
            tooltip: strings.navTasks,
          ),
          material.NavigationDestination(
            icon: Icon(material.Icons.settings_outlined, semanticLabel: strings.navSettings),
            selectedIcon: Icon(material.Icons.settings, semanticLabel: strings.navSettings),
            label: strings.navSettings,
            tooltip: strings.navSettings,
          ),
        ],
      ),
    );
  }
}

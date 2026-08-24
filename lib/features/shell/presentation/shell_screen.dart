import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/theme.dart';
import '../../../core/utils/ios_haptics.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/widgets/liquid_glass.dart';
import 'shell_controller.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../tasks/presentation/tasks_screen.dart';
import '../../settings/presentation/settings_screen.dart';

/// Platform-adaptive root navigation shell for Fibu.
/// Automatically renders NavigationView on Windows, CupertinoTabScaffold on iOS,
/// and material NavigationBar on Android/fallback with immediate live theme reactivity.
class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  // Der iOS-TabController wird einmal erzeugt und überlebt Rebuilds,
  // damit Tab-Inhalte (Scroll-Position etc.) erhalten bleiben.
  final cupertino.CupertinoTabController _tabController =
      cupertino.CupertinoTabController();

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Explicitly watch appThemeProvider and themeConfigProvider for immediate live theme propagation
    final theme = ref.watch(appThemeProvider);
    ref.watch(themeConfigProvider);
    final platform = defaultTargetPlatform;
    final activeIndex = ref.watch(shellIndexProvider);
    final strings = ref.watch(stringsProvider);

    if (platform == TargetPlatform.windows) {
      return _buildWindows(context, ref, activeIndex, strings, theme);
    } else if (platform == TargetPlatform.iOS) {
      return _buildIOS(context, ref, activeIndex, strings, theme);
    } else {
      return _buildAndroid(context, ref, activeIndex, strings, theme);
    }
  }

  // --- Windows (Fluent NavigationView) ---
  Widget _buildWindows(BuildContext context, WidgetRef ref, int activeIndex, AppStrings strings, AppThemeData theme) {
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

  // --- iOS (Cupertino Tab Scaffold with Symmetrical Vertical Padding) ---
  Widget _buildIOS(BuildContext context, WidgetRef ref, int activeIndex, AppStrings strings, AppThemeData theme) {
    // iOS 26+: Tab-Bar transparent + natives Liquid Glass dahinter.
    // iOS < 26: opakes surface wie bisher.
    final glass = liquidGlassActive(ref);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    const tabBarHeight = 52.0;
    final glassHeight = tabBarHeight + bottomInset;

    final scaffold = cupertino.CupertinoTabScaffold(
      controller: _tabController,
      tabBar: cupertino.CupertinoTabBar(
        currentIndex: activeIndex,
        activeColor: theme.accent,
        inactiveColor: theme.textSecondary,
        // Transparent bei Glass, sonst solid surface — Optik unter iOS 26 unverändert.
        backgroundColor: glass ? const Color(0x00000000) : theme.surface,
        border: glass
            ? const Border(top: BorderSide(color: Color(0x00000000), width: 0))
            : null,
        iconSize: 22.0,
        height: tabBarHeight,
        onTap: (index) {
          IosHaptics.selection();
          ref.read(shellIndexProvider.notifier).state = index;
        },
        items: [
          BottomNavigationBarItem(
            icon: const Padding(
              padding: EdgeInsets.only(top: 5.0, bottom: 2.0),
              child: Icon(cupertino.CupertinoIcons.square_grid_2x2, semanticLabel: 'Dashboard'),
            ),
            activeIcon: const Padding(
              padding: EdgeInsets.only(top: 5.0, bottom: 2.0),
              child: Icon(cupertino.CupertinoIcons.square_grid_2x2_fill, semanticLabel: 'Dashboard Active'),
            ),
            label: strings.navDashboard,
            tooltip: strings.navDashboard,
          ),
          BottomNavigationBarItem(
            icon: const Padding(
              padding: EdgeInsets.only(top: 5.0, bottom: 2.0),
              child: Icon(cupertino.CupertinoIcons.list_bullet, semanticLabel: 'Tasks'),
            ),
            activeIcon: const Padding(
              padding: EdgeInsets.only(top: 5.0, bottom: 2.0),
              child: Icon(cupertino.CupertinoIcons.list_bullet_indent, semanticLabel: 'Tasks Active'),
            ),
            label: strings.navTasks,
            tooltip: strings.navTasks,
          ),
          BottomNavigationBarItem(
            icon: const Padding(
              padding: EdgeInsets.only(top: 5.0, bottom: 2.0),
              child: Icon(cupertino.CupertinoIcons.settings, semanticLabel: 'Settings'),
            ),
            activeIcon: const Padding(
              padding: EdgeInsets.only(top: 5.0, bottom: 2.0),
              child: Icon(cupertino.CupertinoIcons.settings_solid, semanticLabel: 'Settings Active'),
            ),
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

    if (!glass) return scaffold;

    // Glass ZUERST (hinten), Scaffold darüber. Der opake Seiten-Inhalt deckt
    // Glass ab; die transparente Tab-Bar lässt es durchscheinen — Icons bleiben
    // scharf über dem Glass.
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: LiquidGlassTabBarBackdrop(height: glassHeight),
          ),
        ),
        scaffold,
      ],
    );
  }

  // --- Android (Material 3 Scaffold + Bottom Navigation) ---
  Widget _buildAndroid(BuildContext context, WidgetRef ref, int activeIndex, AppStrings strings, AppThemeData theme) {
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

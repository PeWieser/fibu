import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';

import 'theme/theme.dart';
import 'theme/ios_theme.dart';
import 'core/localization/app_strings.dart';
import 'core/services/app_log_service.dart';
import 'core/services/quick_actions_service.dart';
import 'core/services/scheduler_service.dart';
import 'core/services/settings_service.dart';
import 'features/dashboard/presentation/dashboard_controller.dart';
import 'features/shell/presentation/shell_screen.dart';
import 'features/onboarding/presentation/onboarding_controller.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Hintergrund-Scheduling registrieren (iOS BGTaskScheduler / Android WorkManager).
  SchedulerService.initialize();
  runApp(
    const ProviderScope(
      child: FibuApp(),
    ),
  );
}

/// Dynamically derives a balanced Fluent AccentColor swatch from any Sanzo Wada accent color.
fluent.AccentColor _createFluentAccent(Color accent, bool isDark) {
  final hsl = HSLColor.fromColor(accent);
  if (isDark) {
    return fluent.AccentColor.swatch({
      'darkest': hsl.withLightness((hsl.lightness + 0.35).clamp(0.0, 1.0)).toColor(),
      'darker': hsl.withLightness((hsl.lightness + 0.22).clamp(0.0, 1.0)).toColor(),
      'dark': hsl.withLightness((hsl.lightness + 0.10).clamp(0.0, 1.0)).toColor(),
      'normal': accent,
      'light': hsl.withLightness((hsl.lightness - 0.10).clamp(0.0, 1.0)).toColor(),
      'lighter': hsl.withLightness((hsl.lightness - 0.20).clamp(0.0, 1.0)).toColor(),
      'lightest': hsl.withLightness((hsl.lightness - 0.30).clamp(0.0, 1.0)).toColor(),
    });
  } else {
    return fluent.AccentColor.swatch({
      'darkest': hsl.withLightness((hsl.lightness - 0.30).clamp(0.0, 1.0)).toColor(),
      'darker': hsl.withLightness((hsl.lightness - 0.20).clamp(0.0, 1.0)).toColor(),
      'dark': hsl.withLightness((hsl.lightness - 0.10).clamp(0.0, 1.0)).toColor(),
      'normal': accent,
      'light': hsl.withLightness((hsl.lightness + 0.10).clamp(0.0, 1.0)).toColor(),
      'lighter': hsl.withLightness((hsl.lightness + 0.22).clamp(0.0, 1.0)).toColor(),
      'lightest': hsl.withLightness((hsl.lightness + 0.35).clamp(0.0, 1.0)).toColor(),
    });
  }
}

class FibuApp extends ConsumerStatefulWidget {
  const FibuApp({super.key});

  @override
  ConsumerState<FibuApp> createState() => _FibuAppState();
}

class _FibuAppState extends ConsumerState<FibuApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Plattform-Brightness-Änderungen (iOS Light/Dark-Systemwechsel) live in
    // den systemBrightnessProvider spiegeln → appThemeProvider re-evaluiert
    // sofort, kein App-Neustart nötig.
    WidgetsBinding.instance.addObserver(this);

    // Zentrales Diagnose-Protokoll: statische Fassade mit Provider verbinden,
    // damit alle Services (auch ohne Ref) loggen können.
    AppLog.attach(ref);
    AppLog.info('app', 'Fibu gestartet');

    // iOS-Homescreen-Quick-Action „Jetzt synchronisieren“.
    final strings = ref.read(stringsProvider);
    QuickActionsService.instance.setup(
      syncNowLabel: strings.quickActionSyncNow,
      onSyncNow: () async {
        // Beim Kaltstart ist das Onboarding-Flag evtl. noch nicht geladen –
        // deshalb direkt aus den persistierten Settings lesen.
        final settings = await SettingsService.loadSettings();
        final onboardingDone = settings?.onboardingCompleted ?? true;
        if (!onboardingDone) {
          AppLog.warn('quickaction', 'Sync ignoriert: Onboarding nicht abgeschlossen');
          return;
        }
        ref.read(activeJobProvider.notifier).triggerSyncAll();
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    final brightness = PlatformDispatcher.instance.platformBrightness;
    final current = ref.read(systemBrightnessProvider);
    if (current != brightness) {
      ref.read(systemBrightnessProvider.notifier).state = brightness;
    }
    super.didChangePlatformBrightness();
  }

  @override
  Widget build(BuildContext context) {
    final platform = defaultTargetPlatform;
    final themeData = ref.watch(appThemeProvider);
    final onboardingCompleted = ref.watch(onboardingControllerProvider);
    final Widget homeWidget = onboardingCompleted ? const ShellScreen() : const OnboardingScreen();

    // Compute active brightness based on resolved colors
    final isDark = themeData.canvas.computeLuminance() < 0.5;
    final fluentAccent = _createFluentAccent(themeData.accent, isDark);

    // Build platform specific Fluent App
    if (platform == TargetPlatform.windows) {
      final fluentMode = isDark ? fluent.ThemeMode.dark : fluent.ThemeMode.light;

      return fluent.FluentApp(
        title: 'Fibu',
        themeMode: fluentMode,
        theme: fluent.FluentThemeData(
          brightness: fluent.Brightness.light,
          accentColor: fluentAccent,
          scaffoldBackgroundColor: themeData.canvas,
          cardColor: themeData.surface,
          buttonTheme: const fluent.ButtonThemeData(
            filledButtonStyle: fluent.ButtonStyle(
              foregroundColor: fluent.WidgetStatePropertyAll(Color(0xFFFFFFFF)),
            ),
          ),
          navigationPaneTheme: fluent.NavigationPaneThemeData(
            backgroundColor: themeData.canvas,
            selectedIconColor: fluent.WidgetStatePropertyAll(themeData.accent),
            selectedTextStyle: fluent.WidgetStatePropertyAll(
              TextStyle(color: themeData.textPrimary, fontWeight: FontWeight.w600),
            ),
            unselectedTextStyle: fluent.WidgetStatePropertyAll(
              TextStyle(color: themeData.textSecondary),
            ),
            highlightColor: themeData.accent,
          ),
          toggleSwitchTheme: fluent.ToggleSwitchThemeData(
            checkedDecoration: fluent.WidgetStateProperty.resolveWith((states) {
              if (states.isHovered) {
                return BoxDecoration(
                  color: themeData.accent.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                );
              }
              return BoxDecoration(
                color: themeData.accent,
                borderRadius: BorderRadius.circular(20),
              );
            }),
          ),
          sliderTheme: fluent.SliderThemeData(
            activeColor: fluent.WidgetStatePropertyAll(themeData.accent),
            thumbColor: fluent.WidgetStatePropertyAll(themeData.accent),
          ),
        ),
        darkTheme: fluent.FluentThemeData(
          brightness: fluent.Brightness.dark,
          accentColor: fluentAccent,
          scaffoldBackgroundColor: themeData.canvas,
          cardColor: themeData.surface,
          buttonTheme: const fluent.ButtonThemeData(
            filledButtonStyle: fluent.ButtonStyle(
              foregroundColor: fluent.WidgetStatePropertyAll(Color(0xFFFFFFFF)),
            ),
          ),
          navigationPaneTheme: fluent.NavigationPaneThemeData(
            backgroundColor: themeData.canvas,
            selectedIconColor: fluent.WidgetStatePropertyAll(themeData.accent),
            selectedTextStyle: fluent.WidgetStatePropertyAll(
              TextStyle(color: themeData.textPrimary, fontWeight: FontWeight.w600),
            ),
            unselectedTextStyle: fluent.WidgetStatePropertyAll(
              TextStyle(color: themeData.textSecondary),
            ),
            highlightColor: themeData.accent,
          ),
          toggleSwitchTheme: fluent.ToggleSwitchThemeData(
            checkedDecoration: fluent.WidgetStateProperty.resolveWith((states) {
              if (states.isHovered) {
                return BoxDecoration(
                  color: themeData.accent.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                );
              }
              return BoxDecoration(
                color: themeData.accent,
                borderRadius: BorderRadius.circular(20),
              );
            }),
          ),
          sliderTheme: fluent.SliderThemeData(
            activeColor: fluent.WidgetStatePropertyAll(themeData.accent),
            thumbColor: fluent.WidgetStatePropertyAll(themeData.accent),
          ),
        ),
        debugShowCheckedModeBanner: false,
        home: homeWidget,
      );
    } else if (platform == TargetPlatform.iOS) {
      return cupertino.CupertinoApp(
        title: 'Fibu',
        theme: IosTheme.build(themeData),
        debugShowCheckedModeBanner: false,
        home: homeWidget,
      );
    } else {
      // Default to Android/Material 3
      final materialMode = isDark ? material.ThemeMode.dark : material.ThemeMode.light;

      return material.MaterialApp(
        title: 'Fibu',
        themeMode: materialMode,
        theme: material.ThemeData(
          useMaterial3: true,
          brightness: material.Brightness.light,
          colorScheme: material.ColorScheme.fromSeed(
            seedColor: themeData.accent,
            brightness: material.Brightness.light,
            primary: themeData.accent,
            surface: themeData.surface,
            onSurface: themeData.textPrimary,
          ),
          filledButtonTheme: material.FilledButtonThemeData(
            style: material.FilledButton.styleFrom(
              foregroundColor: material.Colors.white,
            ),
          ),
          scaffoldBackgroundColor: themeData.canvas,
          cardColor: themeData.surface,
          switchTheme: material.SwitchThemeData(
            thumbColor: material.WidgetStateProperty.resolveWith((states) {
              if (states.contains(material.WidgetState.selected)) {
                return themeData.accent;
              }
              return null;
            }),
            trackColor: material.WidgetStateProperty.resolveWith((states) {
              if (states.contains(material.WidgetState.selected)) {
                return themeData.accent.withValues(alpha: 0.45);
              }
              return null;
            }),
          ),
          sliderTheme: material.SliderThemeData(
            activeTrackColor: themeData.accent,
            thumbColor: themeData.accent,
            inactiveTrackColor: themeData.accent.withValues(alpha: 0.24),
          ),
          progressIndicatorTheme: material.ProgressIndicatorThemeData(
            color: themeData.accent,
            linearTrackColor: themeData.surface,
            circularTrackColor: themeData.surface,
          ),
          navigationBarTheme: material.NavigationBarThemeData(
            indicatorColor: themeData.accent.withValues(alpha: 0.22),
            iconTheme: material.WidgetStateProperty.resolveWith((states) {
              if (states.contains(material.WidgetState.selected)) {
                return material.IconThemeData(color: themeData.accent);
              }
              return material.IconThemeData(color: themeData.textSecondary);
            }),
            labelTextStyle: material.WidgetStateProperty.resolveWith((states) {
              if (states.contains(material.WidgetState.selected)) {
                return TextStyle(color: themeData.accent, fontWeight: FontWeight.bold, fontSize: 12);
              }
              return TextStyle(color: themeData.textSecondary, fontSize: 12);
            }),
          ),
          tabBarTheme: material.TabBarThemeData(
            indicatorColor: themeData.accent,
            labelColor: themeData.accent,
            unselectedLabelColor: themeData.textSecondary,
          ),
        ),
        darkTheme: material.ThemeData(
          useMaterial3: true,
          brightness: material.Brightness.dark,
          colorScheme: material.ColorScheme.fromSeed(
            seedColor: themeData.accent,
            brightness: material.Brightness.dark,
            primary: themeData.accent,
            surface: themeData.surface,
            onSurface: themeData.textPrimary,
          ),
          filledButtonTheme: material.FilledButtonThemeData(
            style: material.FilledButton.styleFrom(
              foregroundColor: material.Colors.white,
            ),
          ),
          scaffoldBackgroundColor: themeData.canvas,
          cardColor: themeData.surface,
          switchTheme: material.SwitchThemeData(
            thumbColor: material.WidgetStateProperty.resolveWith((states) {
              if (states.contains(material.WidgetState.selected)) {
                return themeData.accent;
              }
              return null;
            }),
            trackColor: material.WidgetStateProperty.resolveWith((states) {
              if (states.contains(material.WidgetState.selected)) {
                return themeData.accent.withValues(alpha: 0.45);
              }
              return null;
            }),
          ),
          sliderTheme: material.SliderThemeData(
            activeTrackColor: themeData.accent,
            thumbColor: themeData.accent,
            inactiveTrackColor: themeData.accent.withValues(alpha: 0.24),
          ),
          progressIndicatorTheme: material.ProgressIndicatorThemeData(
            color: themeData.accent,
            linearTrackColor: themeData.surface,
            circularTrackColor: themeData.surface,
          ),
          navigationBarTheme: material.NavigationBarThemeData(
            indicatorColor: themeData.accent.withValues(alpha: 0.22),
            iconTheme: material.WidgetStateProperty.resolveWith((states) {
              if (states.contains(material.WidgetState.selected)) {
                return material.IconThemeData(color: themeData.accent);
              }
              return material.IconThemeData(color: themeData.textSecondary);
            }),
            labelTextStyle: material.WidgetStateProperty.resolveWith((states) {
              if (states.contains(material.WidgetState.selected)) {
                return TextStyle(color: themeData.accent, fontWeight: FontWeight.bold, fontSize: 12);
              }
              return TextStyle(color: themeData.textSecondary, fontSize: 12);
            }),
          ),
          tabBarTheme: material.TabBarThemeData(
            indicatorColor: themeData.accent,
            labelColor: themeData.accent,
            unselectedLabelColor: themeData.textSecondary,
          ),
        ),
        debugShowCheckedModeBanner: false,
        home: homeWidget,
      );
    }
  }
}

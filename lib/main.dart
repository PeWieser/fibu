import 'dart:async';

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
import 'core/services/auto_refresh_service.dart';
import 'core/services/quick_actions_service.dart';
import 'core/services/scheduler_service.dart';
import 'core/services/widget_status_service.dart';
import 'features/dashboard/presentation/dashboard_controller.dart';
import 'features/shell/presentation/shell_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Rechtliches: librclone (rclone, MIT) und gomobile (BSD-3) sind statisch
  // eingebundene Nicht-Dart-Komponenten — sie erscheinen sonst nicht in der
  // automatischen Lizenzliste (LicenseRegistry sammelt nur pub-Pakete).
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      <String>['rclone / librclone'],
      'MIT License\n\n'
      'Copyright (C) 2012 by Nick Craig-Wood https://www.craig-wood.com/nick/\n\n'
      'Permission is hereby granted, free of charge, to any person obtaining a copy '
      'of this software and associated documentation files (the "Software"), to deal '
      'in the Software without restriction, including without limitation the rights '
      'to use, copy, modify, merge, publish, distribute, sublicense, and/or sell '
      'copies of the Software, and to permit persons to whom the Software is '
      'furnished to do so, subject to the following conditions:\n\n'
      'The above copyright notice and this permission notice shall be included in '
      'all copies or substantial portions of the Software.\n\n'
      'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR '
      'IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, '
      'FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE '
      'AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER '
      'LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING '
      'FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER '
      'DEALINGS IN THE SOFTWARE.',
    );
    yield const LicenseEntryWithLineBreaks(
      <String>['golang.org/x/mobile (gomobile)'],
      'Copyright 2014 The Go Authors.\n\n'
      'Redistribution and use in source and binary forms, with or without '
      'modification, are permitted provided that the following conditions are met:\n\n'
      '  * Redistributions of source code must retain the above copyright notice, '
      'this list of conditions and the following disclaimer.\n'
      '  * Redistributions in binary form must reproduce the above copyright notice, '
      'this list of conditions and the following disclaimer in the documentation '
      'and/or other materials provided with the distribution.\n'
      '  * Neither the name of Google LLC nor the names of its contributors may be '
      'used to endorse or promote products derived from this software without '
      'specific prior written permission.\n\n'
      'THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" '
      'AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE '
      'IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE '
      'ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE '
      'LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR '
      'CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF '
      'SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS '
      'INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN '
      'CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) '
      'ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE '
      'POSSIBILITY OF SUCH DAMAGE.',
    );
  });
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

/// Wischt die Tastatur weg, sobald der Nutzer IRGENDEINEN Nicht-Text-Bereich
/// tippt (sonst bleibt sie nach Wizard/Textfeldern hartnäckig offen).
Widget _dismissKeyboardOnOutsideTap(Widget child) {
  return GestureDetector(
    behavior: HitTestBehavior.translucent,
    onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
    child: child,
  );
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
    // damit alle Services (auch ohne Ref) loggen können; zusätzlich wird jede
    // Zeile in <Dokumente>/fibu.log persistiert (neben der rclone.conf).
    AppLog.attach(ref);
    AppLog.info('app', 'Fibu gestartet');
    unawaited(AppLog.attachFileSink());

    // Widget-Status initial neu bewerten (App-Start / nach Kaltstart) und
    // in die Widget-Extension pushen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(widgetStatusProvider.notifier).recomputeAndPush();
      // Automatische Aktualisierung (ersetzt alle „Aktualisieren“-Buttons):
      // 10 s normal, 20 s im Stromsparmodus — nur im Vordergrund und online.
      ref.read(autoRefreshServiceProvider).start();
    });

    // iOS-Homescreen-Quick-Action „Jetzt synchronisieren“.
    final strings = ref.read(stringsProvider);
    QuickActionsService.instance.setup(
      syncNowLabel: strings.quickActionSyncNow,
      onSyncNow: () async {
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Auto-Refresh nur im Vordergrund laufen lassen (Akku!).
    ref
        .read(autoRefreshServiceProvider)
        .setForeground(state == AppLifecycleState.resumed);
    // App kommt zurück in den Vordergrund → Sync-Bedarf neu bewerten und in
    // die Homescreen-Widgets pushen (hält Banner + Widgets aktuell, auch wenn
    // zwischenzeitlich fotografiert wurde).
    if (state == AppLifecycleState.resumed) {
      ref.read(widgetStatusProvider.notifier).recomputeAndPush();
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    final platform = defaultTargetPlatform;
    final themeData = ref.watch(appThemeProvider);
    // Kein Onboarding mehr: Die App startet direkt in der Shell. Berechtigungen
    // (z. B. Fotozugriff) werden erst „bei Bedarf“ im Task-Wizard angefragt.
    const Widget homeWidget = ShellScreen();

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
        home: _dismissKeyboardOnOutsideTap(homeWidget),
      );
    } else if (platform == TargetPlatform.iOS) {
      return cupertino.CupertinoApp(
        title: 'Fibu',
        theme: IosTheme.build(themeData),
        debugShowCheckedModeBanner: false,
        home: _dismissKeyboardOnOutsideTap(homeWidget),
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
        home: _dismissKeyboardOnOutsideTap(homeWidget),
      );
    }
  }
}

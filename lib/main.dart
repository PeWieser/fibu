import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';

import 'theme/theme.dart';
import 'features/shell/presentation/shell_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: FibuApp(),
    ),
  );
}

class FibuApp extends ConsumerWidget {
  const FibuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platform = defaultTargetPlatform;
    final themeData = ref.watch(appThemeProvider);

    // Compute active brightness based on resolved colors
    final isDark = themeData.canvas.computeLuminance() < 0.5;

    // Build platform specific Fluent App
    if (platform == TargetPlatform.windows) {
      final fluentMode = isDark ? fluent.ThemeMode.dark : fluent.ThemeMode.light;

      return fluent.FluentApp(
        title: 'Fibu',
        themeMode: fluentMode,
        theme: fluent.FluentThemeData(
          brightness: fluent.Brightness.light,
          accentColor: fluent.AccentColor.swatch({
            'normal': themeData.accent,
            'darkest': const fluent.Color(0xff004578),
            'darker': const fluent.Color(0xff005a9e),
            'dark': const fluent.Color(0xff0078d4),
            'light': const fluent.Color(0xffc7e0f4),
            'lighter': const fluent.Color(0xffdeecf9),
            'lightest': const fluent.Color(0xffeff6fc),
          }),
          scaffoldBackgroundColor: themeData.canvas,
          cardColor: themeData.surface,
        ),
        darkTheme: fluent.FluentThemeData(
          brightness: fluent.Brightness.dark,
          accentColor: fluent.AccentColor.swatch({
            'normal': themeData.accent,
            'darkest': const fluent.Color(0xffeff6fc),
            'darker': const fluent.Color(0xffdeecf9),
            'dark': const fluent.Color(0xffc7e0f4),
            'light': const fluent.Color(0xff0078d4),
            'lighter': const fluent.Color(0xff005a9e),
            'lightest': const fluent.Color(0xff004578),
          }),
          scaffoldBackgroundColor: themeData.canvas,
          cardColor: themeData.surface,
        ),
        debugShowCheckedModeBanner: false,
        home: const ShellScreen(),
      );
    } else if (platform == TargetPlatform.iOS) {
      return cupertino.CupertinoApp(
        title: 'Fibu',
        theme: cupertino.CupertinoThemeData(
          brightness: isDark ? cupertino.Brightness.dark : cupertino.Brightness.light,
          primaryColor: themeData.accent,
          scaffoldBackgroundColor: themeData.canvas,
          barBackgroundColor: themeData.surface,
        ),
        debugShowCheckedModeBanner: false,
        home: const ShellScreen(),
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
          ),
          scaffoldBackgroundColor: themeData.canvas,
          cardColor: themeData.surface,
        ),
        darkTheme: material.ThemeData(
          useMaterial3: true,
          brightness: material.Brightness.dark,
          colorScheme: material.ColorScheme.fromSeed(
            seedColor: themeData.accent,
            brightness: material.Brightness.dark,
            primary: themeData.accent,
            surface: themeData.surface,
          ),
          scaffoldBackgroundColor: themeData.canvas,
          cardColor: themeData.surface,
        ),
        debugShowCheckedModeBanner: false,
        home: const ShellScreen(),
      );
    }
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sanzo_wada_palettes.dart';

/// Semantic token-based theme design system for the Fibu application.
/// Strictly enforces the 4pt grid system and specific border-radius guidelines.
class AppThemeData {
  // --- 4pt Grid Spacing Tokens ---
  final double xs = 4.0;
  final double sm = 8.0;
  final double md = 12.0;
  final double lg = 16.0;
  final double xl = 24.0;
  final double xxl = 32.0;

  // --- Border Radius (Fixed sm: 6, lg: 12 rule) ---
  final double radiusSm = 6.0;
  final double radiusLg = 12.0;

  // --- Semantic Color Tokens ---
  final Color canvas;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color success;
  final Color warning;
  final Color error;
  final Color offline;

  const AppThemeData({
    required this.canvas,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.success,
    required this.warning,
    required this.error,
    required this.offline,
  });

  /// Default Light Theme (Material/Cupertino compliant)
  static const light = AppThemeData(
    canvas: Color(0xfffcfbfa),
    surface: Color(0xffffffff),
    textPrimary: Color(0xff1c1a17),
    textSecondary: Color(0xff706c64),
    accent: Color(0xff007aff),
    success: Color(0xff34c759),
    warning: Color(0xffffcc00),
    error: Color(0xffff3b30),
    offline: Color(0xff8e8e93),
  );

  /// Default Dark Theme
  static const dark = AppThemeData(
    canvas: Color(0xff0c0c0e),
    surface: Color(0xff18181b),
    textPrimary: Color(0xfff4f4f5),
    textSecondary: Color(0xffa1a1aa),
    accent: Color(0xff0a84ff),
    success: Color(0xff30d158),
    warning: Color(0xffffd60a),
    error: Color(0xffff453a),
    offline: Color(0xff636366),
  );

  /// Create a theme from a Sanzo Wada palette
  factory AppThemeData.fromWadaPalette(SanzoWadaPalette palette, {bool isDark = false}) {
    return AppThemeData(
      canvas: palette.background,
      surface: palette.surface,
      textPrimary: palette.textPrimary,
      textSecondary: palette.textSecondary,
      accent: palette.accent,
      success: isDark ? const Color(0xff30d158) : const Color(0xff34c759),
      warning: isDark ? const Color(0xffffd60a) : const Color(0xffffcc00),
      error: isDark ? const Color(0xffff453a) : const Color(0xffff3b30),
      offline: isDark ? const Color(0xff636366) : const Color(0xff8e8e93),
    );
  }
}

/// The mode/configuration of the theme.
/// Supports separate selected Wada palettes for light and dark modes, with system synchronization.
class ThemeConfig {
  final bool syncWithSystem;
  final bool forceDarkMode;
  final SanzoWadaPalette? selectedLightPalette;
  final SanzoWadaPalette? selectedDarkPalette;

  const ThemeConfig({
    this.syncWithSystem = true,
    this.forceDarkMode = false,
    this.selectedLightPalette,
    this.selectedDarkPalette,
  });

  ThemeConfig copyWith({
    bool? syncWithSystem,
    bool? forceDarkMode,
    SanzoWadaPalette? selectedLightPalette,
    SanzoWadaPalette? selectedDarkPalette,
    bool clearLightPalette = false,
    bool clearDarkPalette = false,
  }) {
    return ThemeConfig(
      syncWithSystem: syncWithSystem ?? this.syncWithSystem,
      forceDarkMode: forceDarkMode ?? this.forceDarkMode,
      selectedLightPalette: clearLightPalette ? null : (selectedLightPalette ?? this.selectedLightPalette),
      selectedDarkPalette: clearDarkPalette ? null : (selectedDarkPalette ?? this.selectedDarkPalette),
    );
  }
}

/// State notifier to manage user appearance settings with JSON file persistence.
class ThemeNotifier extends StateNotifier<ThemeConfig> {
  ThemeNotifier() : super(const ThemeConfig()) {
    _loadThemeConfig();
  }

  Future<File> _getSettingsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/settings.json');
  }

  Future<void> _loadThemeConfig() async {
    try {
      final file = await _getSettingsFile();
      if (file.existsSync()) {
        final content = await file.readAsString();
        final Map<String, dynamic> data = json.decode(content);
        
        SanzoWadaPalette? lightPal;
        SanzoWadaPalette? darkPal;

        if (data['selectedLightPalette'] != null) {
          try {
            lightPal = SanzoWadaPalette.values.firstWhere(
              (p) => p.name == data['selectedLightPalette'],
            );
          } catch (_) {}
        }

        if (data['selectedDarkPalette'] != null) {
          try {
            darkPal = SanzoWadaPalette.values.firstWhere(
              (p) => p.name == data['selectedDarkPalette'],
            );
          } catch (_) {}
        }

        state = ThemeConfig(
          syncWithSystem: data['syncWithSystem'] as bool? ?? true,
          forceDarkMode: data['forceDarkMode'] as bool? ?? false,
          selectedLightPalette: lightPal,
          selectedDarkPalette: darkPal,
        );
      }
    } catch (_) {}
  }

  Future<void> _persistThemeConfig() async {
    try {
      final file = await _getSettingsFile();
      Map<String, dynamic> data = {};
      if (file.existsSync()) {
        try {
          data = json.decode(await file.readAsString());
        } catch (_) {}
      }
      data['syncWithSystem'] = state.syncWithSystem;
      data['forceDarkMode'] = state.forceDarkMode;
      data['selectedLightPalette'] = state.selectedLightPalette?.name;
      data['selectedDarkPalette'] = state.selectedDarkPalette?.name;
      await file.writeAsString(json.encode(data));
    } catch (_) {}
  }

  void setSyncWithSystem(bool sync) {
    state = state.copyWith(syncWithSystem: sync);
    _persistThemeConfig();
  }

  void setForceDarkMode(bool forceDark) {
    state = state.copyWith(forceDarkMode: forceDark);
    _persistThemeConfig();
  }

  void setLightPalette(SanzoWadaPalette? palette) {
    state = state.copyWith(
      selectedLightPalette: palette,
      clearLightPalette: palette == null,
    );
    _persistThemeConfig();
  }

  void setDarkPalette(SanzoWadaPalette? palette) {
    state = state.copyWith(
      selectedDarkPalette: palette,
      clearDarkPalette: palette == null,
    );
    _persistThemeConfig();
  }
}

/// Riverpod provider to read/write theme configuration.
final themeConfigProvider = StateNotifierProvider<ThemeNotifier, ThemeConfig>((ref) {
  return ThemeNotifier();
});

/// Riverpod provider that returns the resolved [AppThemeData] based on active configuration and system brightness.
final appThemeProvider = Provider<AppThemeData>((ref) {
  final config = ref.watch(themeConfigProvider);
  
  // Detect system brightness for automatic mode
  final systemBrightness = PlatformDispatcher.instance.platformBrightness;
  final isDark = config.syncWithSystem
      ? systemBrightness == Brightness.dark
      : config.forceDarkMode;

  if (isDark) {
    if (config.selectedDarkPalette != null) {
      return AppThemeData.fromWadaPalette(config.selectedDarkPalette!, isDark: true);
    }
    return AppThemeData.dark;
  } else {
    if (config.selectedLightPalette != null) {
      return AppThemeData.fromWadaPalette(config.selectedLightPalette!, isDark: false);
    }
    return AppThemeData.light;
  }
});

/// Extension on [BuildContext] to access design tokens quickly and elegantly.
extension ThemeExtensions on BuildContext {
  AppThemeData get theme {
    // We can use a ProviderContainer if Riverpod isn't initialized, but inside widgets:
    // This allows convenient lookup in widget builds.
    final container = ProviderScope.containerOf(this);
    return container.read(appThemeProvider);
  }
}

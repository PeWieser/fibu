import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/contrast.dart';
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
  /// Hintergrund der „freien Fläche" (Scaffold, Bereich um Listen/Karten).
  ///
  /// Bewusst identisch zu [surface]: Freifläche und Elemente (Aufgaben,
  /// Laufwerke, Karten) teilen sich EINE Theme-Hintergrundfarbe, damit kein
  /// zweiter, abweichender Farbton im Layout auftaucht. Struktur entsteht
  /// über Einzüge und Hairline-Rahmen, nicht über einen Farbversatz.
  final Color canvas;

  /// Fläche eines Elements (Karte, Listen-Sektion, Laufwerks-/Aufgabenzeile).
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color success;
  final Color warning;
  final Color error;
  final Color offline;

  /// Charakterfarben der Palette.
  ///
  /// Beide sind bewusst NICHT text-tauglich (Kontrast teils unter 3:1) und
  /// werden deshalb ausschließlich dekorativ eingesetzt — immer neben einem
  /// zugänglichen Text-Label, nie als alleiniger Informationsträger.
  final Color primary;
  final Color secondary;

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
    this.primary = const Color(0xff007aff),
    this.secondary = const Color(0xff8e8e93),
  });

  /// Hintergrund für Tab- und Navigationsleisten.
  ///
  /// Bewusst von [canvas]/[surface] abgesetzt: Da Freifläche und Karten sich
  /// eine Farbe teilen, braucht die Leiste einen eigenen Ton, sonst verschwimmt
  /// sie mit dem Inhalt und ist nicht mehr als eigene Ebene erkennbar.
  Color get bar {
    final bool dark = surface.computeLuminance() < 0.25;
    return Color.lerp(
      surface,
      dark ? const Color(0xffffffff) : const Color(0xff000000),
      dark ? 0.10 : 0.07,
    )!;
  }

  /// Haarlinie zur Abtrennung der Leisten vom Inhalt.
  Color get hairline => textSecondary.withValues(alpha: 0.28);

  /// Text-/Icon-Farbe auf [accent]-Flächen (Buttons, Chips, Badges).
  ///
  /// Wird aus dem Akzent abgeleitet (Weiß oder Schwarz, je nach Kontrast),
  /// damit Beschriftungen auf Akzentflächen immer WCAG AA erfüllen — auch
  /// bei hellen Akzenten im Dark Mode, wo Weiß nur ~2:1 hätte.
  Color get accentText => ColorContrast.bestOn(accent);

  /// Default Light Theme (Material/Cupertino compliant)
  static const light = AppThemeData(
    canvas: Color(0xffffffff),
    surface: Color(0xffffffff),
    textPrimary: Color(0xff1c1a17),
    textSecondary: Color(0xff706c64),
    // Abgedunkeltes Systemblau: #007aff hätte nur 3.9:1 auf Weiß (AA-Fail).
    accent: Color(0xff0062e6),
    success: Color(0xff34c759),
    warning: Color(0xffffcc00),
    error: Color(0xffff3b30),
    offline: Color(0xff8e8e93),
    primary: Color(0xff0a84ff),
    secondary: Color(0xff5e5ce6),
  );

  /// Default Dark Theme
  static const dark = AppThemeData(
    canvas: Color(0xff18181b),
    surface: Color(0xff18181b),
    textPrimary: Color(0xfff4f4f5),
    textSecondary: Color(0xffa1a1aa),
    accent: Color(0xff0a84ff),
    success: Color(0xff30d158),
    warning: Color(0xffffd60a),
    error: Color(0xffff453a),
    offline: Color(0xff636366),
    primary: Color(0xff64d2ff),
    secondary: Color(0xffbf5af2),
  );

  /// Create a theme from a Sanzo Wada palette
  ///
  /// Jede Palette hat ein eigenes Hell- und Dunkel-Set, damit der Canvas
  /// (Hintergrund zwischen den Karten) in beiden Modi sichtbar im
  /// Paletten-Farbton liegt statt „fast weiß" bzw. „grau/schwarz".
  factory AppThemeData.fromWadaPalette(SanzoWadaPalette palette, {bool isDark = false}) {
    // Freifläche und Elementfläche teilen sich dieselbe Farbe — der
    // Hintergrund „drumherum" ist damit identisch zum Hintergrund der
    // Aufgaben-/Laufwerks-Elemente (kein zweiter Farbton im Layout).
    final Color background = isDark ? palette.darkSurface : palette.lightSurface;
    return AppThemeData(
      canvas: background,
      surface: background,
      textPrimary: isDark ? palette.darkTextPrimary : palette.lightTextPrimary,
      textSecondary: isDark ? palette.darkTextSecondary : palette.lightTextSecondary,
      accent: palette.accentFor(isDark),
      success: isDark ? const Color(0xff30d158) : const Color(0xff34c759),
      warning: isDark ? const Color(0xffffd60a) : const Color(0xffffcc00),
      error: isDark ? const Color(0xffff453a) : const Color(0xffff3b30),
      offline: isDark ? const Color(0xff636366) : const Color(0xff8e8e93),
      primary: palette.primary,
      secondary: palette.secondary,
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

/// Live-Provider für die System-Helligkeit (Light/Dark).
///
/// Der Initialwert stammt aus [PlatformDispatcher]; der App-Root (WidgetsApp
/// tree in main.dart) beobachtet `didChangePlatformBrightness` und setzt hier
/// den neuen Wert, sobald iOS/Android/Windows zwischen Light und Dark
/// umschalten – so re-evaluiert [appThemeProvider] sofort, ohne Neustart.
final systemBrightnessProvider = StateProvider<Brightness>((ref) {
  return PlatformDispatcher.instance.platformBrightness;
});

/// Riverpod provider that returns the resolved [AppThemeData] based on active configuration and system brightness.
final appThemeProvider = Provider<AppThemeData>((ref) {
  final config = ref.watch(themeConfigProvider);

  // Systemhelligkeit live verfolgen (Systemwechsel Light/Dark zur Laufzeit).
  final systemBrightness = ref.watch(systemBrightnessProvider);
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

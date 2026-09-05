import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/contrast.dart';
import 'sanzo_wada_palettes.dart';

/// Wie die Paletten-Charakterfarbe [AppThemeData.primary] eingesetzt wird.
///
/// In den Einstellungen umschaltbar. `primary` erreicht roh in keiner
/// Palette 3:1 gegen den Hintergrund (schlechtester Wert 1,21:1) und darf
/// deshalb nur so verwendet werden, wie es hier gewählt wurde.
enum PrimaryUsage {
  /// Nur Identitätsfarbe: erscheint ausschließlich in der Paletten-Vorschau.
  identity,

  /// Dekorative Waschung: `primary` mit niedriger Alpha als Hintergrund-
  /// Tönung. Trägt selbst keine Information, der Text darüber bleibt
  /// ungeändert zugänglich.
  wash,

  /// Abgesicherte Variante: `primary` wird Richtung Schwarz bzw. Weiß
  /// verschoben, bis es 3:1 gegen `canvas` und `surface` erreicht, und
  /// färbt dann die Section-Header.
  accessible,
}

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

  /// Gewählter Einsatz von [primary] (Einstellung).
  final PrimaryUsage primaryUsage;

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
    this.primaryUsage = PrimaryUsage.identity,
  });

  /// Kopie mit anderem [PrimaryUsage] — alle übrigen Tokens bleiben gleich.
  AppThemeData copyWith({PrimaryUsage? primaryUsage}) => AppThemeData(
        canvas: canvas,
        surface: surface,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        accent: accent,
        success: success,
        warning: warning,
        error: error,
        offline: offline,
        primary: primary,
        secondary: secondary,
        primaryUsage: primaryUsage ?? this.primaryUsage,
      );

  /// [primary], Richtung Schwarz (hell) bzw. Weiß (dunkel) verschoben, bis es
  /// 3:1 gegen [canvas] und [surface] erreicht — dieselbe Technik, die
  /// `accent` WCAG-tauglich macht.
  Color primaryFor(bool isDark) {
    final Color target =
        isDark ? const Color(0xffffffff) : const Color(0xff000000);
    Color candidate = primary;
    for (int i = 0; i <= 20; i++) {
      candidate = Color.lerp(primary, target, i / 20)!;
      if (ColorContrast.ratio(candidate, canvas) >= 3.0 &&
          ColorContrast.ratio(candidate, surface) >= 3.0) {
        return candidate;
      }
    }
    return candidate;
  }

  /// Hintergrund-Waschung aus [primary] für den Modus [PrimaryUsage.wash].
  Color get primaryWash => primary.withValues(alpha: 0.10);

  /// Apples Systemblau — die Farbe des Sync-Fortschrittsbalkens.
  ///
  /// Bewusst **nicht** [accent]: Der Fortschritt ist eine systemische
  /// Betriebssystem-Rückmeldung und soll auf jedem Paletten-Hintergrund
  /// identisch aussehen. Die Werte sind exakt `CupertinoColors.systemBlue`
  /// (#007AFF hell, #0A84FF dunkel) und gegen [canvas]/[surface] in allen
  /// Paletten ≥ 3:1 — der Balken ist ein großes Flächenelement, dafür gilt
  /// die WCAG-Grenze für Nicht-Text.
  Color syncProgressFor(bool isDark) =>
      isDark ? const Color(0xff0a84ff) : const Color(0xff007aff);

  /// Passendes Track-Grau hinter dem Fortschrittsbalken.
  Color get syncTrack => textSecondary.withValues(alpha: 0.22);

  /// Haarlinie zur Abtrennung transluzenter Leisten vom Inhalt.
  ///
  /// Nur unter iOS 26 sinnvoll: Dort ist die Leiste natives, transluzentes
  /// Glass und braucht eine Kante. Darunter trennt bereits der eigene
  /// Farbton von [bar], eine Linie wäre dort zu viel.
  Color get hairline => textSecondary.withValues(alpha: 0.28);

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

/// Erscheinungsbild-Konfiguration: **eine** Palette, keine Modus-Wahl.
///
/// Früher gab es hier fünf Stellgrößen: System-Übernahme an/aus, Dunkelmodus
/// erzwingen an/aus, Hell-Palette, Dunkel-Palette — also 8 Paletten × 2 Modi
/// = 16 Farbwähler plus zwei Schalter. Für eine Backup-App sind das 18
/// Entscheidungen, die man einmal trifft und danach nie wieder anfasst.
///
/// Jetzt: eine Palette für beide Modi. Jede Palette bringt ihr Hell- und ihr
/// Dunkel-Set mit; welcher Modus aktiv ist, entscheidet das System
/// (siehe [appThemeProvider]). Der Nutzer wählt einen Farbklang — nicht
/// zweimal denselben Farbklang in zwei Helligkeiten.
class ThemeConfig {
  /// Die gewählte Palette. `null` = Standard (neutrales [AppThemeData.light]
  /// bzw. [AppThemeData.dark]).
  final SanzoWadaPalette? selectedPalette;
  final PrimaryUsage primaryUsage;

  const ThemeConfig({
    this.selectedPalette,
    this.primaryUsage = PrimaryUsage.identity,
  });

  ThemeConfig copyWith({
    SanzoWadaPalette? selectedPalette,
    PrimaryUsage? primaryUsage,
    bool clearPalette = false,
  }) {
    return ThemeConfig(
      selectedPalette: clearPalette ? null : (selectedPalette ?? this.selectedPalette),
      primaryUsage: primaryUsage ?? this.primaryUsage,
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

        state = ThemeConfig(
          selectedPalette: paletteFromSettings(data),
          primaryUsage: PrimaryUsage.values.firstWhere(
            (PrimaryUsage u) => u.name == data['primaryUsage'],
            orElse: () => PrimaryUsage.identity,
          ),
        );
      }
    } catch (_) {}
  }

  /// Liest die Paletten-Wahl aus einem Einstellungs-`Map` — und wandert
  /// alte Schlüssel mit.
  ///
  /// Ältere Versionen haben Hell- und Dunkel-Palette getrennt gespeichert
  /// (`selectedLightPalette` / `selectedDarkPalette`). Wer die App
  /// aktualisiert, soll seine Wahl behalten, nicht auf Standard
  /// zurückfallen: die Hell-Palette gewinnt, sonst die Dunkel-Palette.
  /// Dieselbe Regel gilt für die Konfig-Übertragung zwischen Geräten
  /// (`AppSettingsData.fromJson` in settings_service.dart).
  static SanzoWadaPalette? paletteFromSettings(Map<String, dynamic> data) {
    SanzoWadaPalette? byName(Object? name) {
      if (name == null) return null;
      for (final p in SanzoWadaPalette.values) {
        if (p.name == name) return p;
      }
      return null;
    }

    return byName(data['selectedPalette']) ??
        byName(data['selectedLightPalette']) ??
        byName(data['selectedDarkPalette']);
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
      data['selectedPalette'] = state.selectedPalette?.name;
      // Alte Schlüssel ausräumen, sonst steht nach dem Update eine zweite,
      // widersprüchliche Wahrheit in der Datei.
      data.remove('selectedLightPalette');
      data.remove('selectedDarkPalette');
      data.remove('syncWithSystem');
      data.remove('forceDarkMode');
      data['primaryUsage'] = state.primaryUsage.name;
      await file.writeAsString(json.encode(data));
    } catch (_) {}
  }

  /// Setzt die eine Palette für beide Modi. `null` = Standard.
  void setPalette(SanzoWadaPalette? palette) {
    state = state.copyWith(
      selectedPalette: palette,
      clearPalette: palette == null,
    );
    _persistThemeConfig();
  }

  void setPrimaryUsage(PrimaryUsage usage) {
    state = state.copyWith(primaryUsage: usage);
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
///
/// Hell/Dunkel ist keine Einstellung, sondern eine Folge: Das System sagt,
/// welcher Modus gilt, die eine gewählte Palette liefert das passende
/// Farbset dazu. Schaltet das System um, schaltet die App mit — ohne dass
/// der Nutzer irgendwo einen Modus gewählt hätte.
final appThemeProvider = Provider<AppThemeData>((ref) {
  final config = ref.watch(themeConfigProvider);

  // Systemhelligkeit live verfolgen (Systemwechsel Light/Dark zur Laufzeit).
  final systemBrightness = ref.watch(systemBrightnessProvider);
  final isDark = systemBrightness == Brightness.dark;

  final palette = config.selectedPalette;
  final AppThemeData base;
  if (palette != null) {
    base = AppThemeData.fromWadaPalette(palette, isDark: isDark);
  } else {
    base = isDark ? AppThemeData.dark : AppThemeData.light;
  }
  return base.copyWith(primaryUsage: config.primaryUsage);
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

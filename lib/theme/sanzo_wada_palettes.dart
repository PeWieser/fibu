import 'package:flutter/widgets.dart';

/// Sanzo Wada curated color combinations from "A Dictionary of Color Combinations".
///
/// Jede Palette besitzt sowohl ein Hell- als auch ein Dunkel-Farbset, damit
/// sie in beiden Modi mit sichtbar eingefärbtem Canvas (Hintergrund zwischen
/// den Karten) verwendet werden kann — nicht mehr „fast weiß" (Hell) bzw.
/// „fast grau/schwarz" (Dunkel), sondern klar im Farbton der Palette.
class SanzoWadaPalette {
  final String name;

  /// Charakter-Farben der Palette (identisch in Hell/Dunkel).
  final Color primary;
  final Color secondary;
  final Color accent;

  // --- Light-Mode-Set ---
  final Color lightBackground;
  final Color lightSurface;
  final Color lightTextPrimary;
  final Color lightTextSecondary;

  // --- Dark-Mode-Set ---
  final Color darkBackground;
  final Color darkSurface;
  final Color darkTextPrimary;
  final Color darkTextSecondary;

  const SanzoWadaPalette({
    required this.name,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.lightBackground,
    required this.lightSurface,
    required this.lightTextPrimary,
    required this.lightTextSecondary,
    required this.darkBackground,
    required this.darkSurface,
    required this.darkTextPrimary,
    required this.darkTextSecondary,
  });

  /// Hintergrund (Canvas) für den angegebenen Modus.
  Color backgroundFor(bool isDark) =>
      isDark ? darkBackground : lightBackground;

  /// Karten-/Listen-Fläche (Surface) für den angegebenen Modus.
  Color surfaceFor(bool isDark) => isDark ? darkSurface : lightSurface;

  // ===================== PALETTEN (je Hell- + Dunkel-Set) =====================

  /// Wada Palette No. 154 - Autumnal Elegance
  static const SanzoWadaPalette autumnAki = SanzoWadaPalette(
    name: 'Aki (Autumn)',
    primary: Color(0xff8a3324),      // Deep Rust Red
    secondary: Color(0xffc59b27),    // Mustard Yellow
    accent: Color(0xff395c47),       // Sage Green
    lightBackground: Color(0xfff2ecdf), // Warmer Sand Canvas
    lightSurface: Color(0xffe5dac2),    // Pale Sand Card
    lightTextPrimary: Color(0xff2b2a27),
    lightTextSecondary: Color(0xff58564f),
    darkBackground: Color(0xff241a10), // Ember Brown
    darkSurface: Color(0xff3a2c1a),    // Umber Card
    darkTextPrimary: Color(0xfff6ede0),
    darkTextSecondary: Color(0xffc9b59b),
  );

  /// Wada Palette No. 81 - Spring Whisper
  static const SanzoWadaPalette springHaru = SanzoWadaPalette(
    name: 'Haru (Spring)',
    primary: Color(0xffe5989b),      // Sakura Pink
    secondary: Color(0xffb5c99a),    // Pale Sprout Green
    accent: Color(0xffffb5a7),       // Soft Peach
    lightBackground: Color(0xfff1f6ec), // Light Sage Canvas
    lightSurface: Color(0xffe2ecda),    // Sage Mint Card
    lightTextPrimary: Color(0xff2c302e),
    lightTextSecondary: Color(0xff5d6663),
    darkBackground: Color(0xff1a2018), // Deep Sage Night
    darkSurface: Color(0xff2c372a),    // Moss Night Card
    darkTextPrimary: Color(0xfff2f5ee),
    darkTextSecondary: Color(0xffa9b6a3),
  );

  /// Wada Palette No. 25 - Summer Breeze
  static const SanzoWadaPalette summerNatsu = SanzoWadaPalette(
    name: 'Natsu (Summer)',
    primary: Color(0xff008080),      // Teal
    secondary: Color(0xff2ec4b6),    // Emerald Mint
    accent: Color(0xffe29578),       // Coral
    lightBackground: Color(0xffe6f3f0), // Ice Mint Canvas
    lightSurface: Color(0xffd3e9e3),    // Mint Card
    lightTextPrimary: Color(0xff122321),
    lightTextSecondary: Color(0xff425956),
    darkBackground: Color(0xff0d2421), // Deep Teal Night
    darkSurface: Color(0xff1b3e37),    // Seaweed Card
    darkTextPrimary: Color(0xffe0f4f0),
    darkTextSecondary: Color(0xff9cc4bc),
  );

  /// Wada Palette No. 63 - Ocean Coastal Walk
  static const SanzoWadaPalette oceanUmi = SanzoWadaPalette(
    name: 'Umi (Ocean)',
    primary: Color(0xff0e5f76),      // Deep Teal
    secondary: Color(0xffd4a373),    // Sand Gold
    accent: Color(0xff138a8a),       // Aquamarine
    lightBackground: Color(0xffe8eff6), // Soft Blue Canvas
    lightSurface: Color(0xffd6e2ec),    // Light Grey Blue Card
    lightTextPrimary: Color(0xff0b2545),
    lightTextSecondary: Color(0xff475569),
    darkBackground: Color(0xff0d1b2e), // Deep Navy Night
    darkSurface: Color(0xff1c3249),    // Slate Blue Card
    darkTextPrimary: Color(0xffe8f0f7),
    darkTextSecondary: Color(0xffa9bfd1),
  );

  /// Wada Palette No. 223 - Winter Nocturne
  static const SanzoWadaPalette winterFuyu = SanzoWadaPalette(
    name: 'Fuyu (Winter)',
    primary: Color(0xff8da9c4),      // Frost Blue
    secondary: Color(0xff556b2f),    // Dark Olive
    accent: Color(0xff48cae4),       // Ice Cyan
    lightBackground: Color(0xffedf2f8), // Ice Blue Canvas
    lightSurface: Color(0xffdbe6f1),    // Frost Card
    lightTextPrimary: Color(0xff1a2735),
    lightTextSecondary: Color(0xff5a6b7c),
    darkBackground: Color(0xff0b1b33), // Midnight Blue
    darkSurface: Color(0xff1e3152),    // Slate Grey Blue Card
    darkTextPrimary: Color(0xffffffff),
    darkTextSecondary: Color(0xffcbd5e1),
  );

  /// Wada Palette No. 295 - Midnight Neon
  static const SanzoWadaPalette midnightYoru = SanzoWadaPalette(
    name: 'Yoru (Midnight)',
    primary: Color(0xff9d4edd),      // Medium Purple
    secondary: Color(0xff48cae4),    // Ice Cyan
    accent: Color(0xff06d6a0),       // Mint Green
    lightBackground: Color(0xfff0ebf7), // Soft Lavender Canvas
    lightSurface: Color(0xffe0d6ee),    // Violet Card
    lightTextPrimary: Color(0xff241b33),
    lightTextSecondary: Color(0xff5f5470),
    darkBackground: Color(0xff150f26), // Deep Purple Night
    darkSurface: Color(0xff2b2152),    // Deep Violet Card
    darkTextPrimary: Color(0xfff3e8ff),
    darkTextSecondary: Color(0xffc084fc),
  );

  /// Wada Palette No. 112 - Ancient Forest
  static const SanzoWadaPalette forestMori = SanzoWadaPalette(
    name: 'Mori (Forest)',
    primary: Color(0xff40916c),      // Green
    secondary: Color(0xff8d5b4c),    // Bark Brown
    accent: Color(0xff52b788),       // Light Green
    lightBackground: Color(0xffe9f2ea), // Soft Forest Canvas (sichtbar grün)
    lightSurface: Color(0xffd6e6da),    // Pale Moss Card
    lightTextPrimary: Color(0xff1c2b22),
    lightTextSecondary: Color(0xff55685c),
    darkBackground: Color(0xff0f2b1d), // Deep Forest Green (klar grün)
    darkSurface: Color(0xff204737),    // Moss Card
    darkTextPrimary: Color(0xffe8f5e9),
    darkTextSecondary: Color(0xffa3c1ad),
  );

  /// Wada Palette No. 182 - Magma Ash
  static const SanzoWadaPalette volcanoKazan = SanzoWadaPalette(
    name: 'Kazan (Volcano)',
    primary: Color(0xffe63946),      // Volcano Red
    secondary: Color(0xffa2a2d0),    // Lilac Grey
    accent: Color(0xffff4d6d),       // Hot Pink
    lightBackground: Color(0xfff7ecee), // Soft Rose Canvas
    lightSurface: Color(0xffecd8dd),    // Ash Rose Card
    lightTextPrimary: Color(0xff2e2023),
    lightTextSecondary: Color(0xff6b565b),
    darkBackground: Color(0xff261216), // Deep Ember Night
    darkSurface: Color(0xff3d2530),    // Ash Card
    darkTextPrimary: Color(0xfffae0e4),
    darkTextSecondary: Color(0xffcca3a8),
  );

  /// Alle Paletten (jede mit Hell- und Dunkel-Set, damit in beiden Modus-
  /// Reihen jede Farbe wählbar ist).
  static List<SanzoWadaPalette> get values => [
        autumnAki,
        springHaru,
        summerNatsu,
        oceanUmi,
        winterFuyu,
        midnightYoru,
        forestMori,
        volcanoKazan,
      ];

  /// Alle Paletten für die Hell-Reihe (Auswahl zeigt das Light-Set).
  static List<SanzoWadaPalette> get lightPalettes => values;

  /// Alle Paletten für die Dunkel-Reihe (Auswahl zeigt das Dark-Set).
  static List<SanzoWadaPalette> get darkPalettes => values;
}

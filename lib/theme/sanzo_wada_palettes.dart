import 'package:flutter/widgets.dart';

/// Sanzo Wada curated color combinations from "A Dictionary of Color Combinations".
///
/// Jede Palette besitzt sowohl ein Hell- als auch ein Dunkel-Farbset, damit
/// sie in beiden Modi mit sichtbar eingefärbtem Hintergrund verwendet werden
/// kann — nicht mehr „fast weiß" (Hell) bzw. „fast grau/schwarz" (Dunkel),
/// sondern klar im Farbton der Palette.
///
/// Accessibility: Die Akzentfarbe ist bewusst MODUS-abhängig. Eine einzige
/// Akzentfarbe für Hell und Dunkel kann WCAG AA nie erfüllen — ein heller
/// Akzent (z. B. Pfirsich) hat auf hellem Grund nur ~1.5:1 Kontrast. Deshalb
/// gibt es je Modus eine eigene, geprüfte Akzentfarbe (≥ 4.5:1 auf Canvas und
/// Surface, plus ≥ 4.5:1 für Text auf der Akzentfläche).
class SanzoWadaPalette {
  final String name;

  /// Charakter-Farben der Palette (identisch in Hell/Dunkel) — für Vorschauen.
  final Color primary;
  final Color secondary;

  // --- Light-Mode-Set ---
  final Color lightBackground;
  final Color lightSurface;
  final Color lightTextPrimary;
  final Color lightTextSecondary;
  final Color lightAccent;

  // --- Dark-Mode-Set ---
  final Color darkBackground;
  final Color darkSurface;
  final Color darkTextPrimary;
  final Color darkTextSecondary;
  final Color darkAccent;

  const SanzoWadaPalette({
    required this.name,
    required this.primary,
    required this.secondary,
    required this.lightBackground,
    required this.lightSurface,
    required this.lightTextPrimary,
    required this.lightTextSecondary,
    required this.lightAccent,
    required this.darkBackground,
    required this.darkSurface,
    required this.darkTextPrimary,
    required this.darkTextSecondary,
    required this.darkAccent,
  });

  /// Hintergrund (Canvas) für den angegebenen Modus.
  Color backgroundFor(bool isDark) => isDark ? darkBackground : lightBackground;

  /// Karten-/Listen-Fläche (Surface) für den angegebenen Modus.
  Color surfaceFor(bool isDark) => isDark ? darkSurface : lightSurface;

  /// Geprüfte Akzentfarbe für den angegebenen Modus.
  Color accentFor(bool isDark) => isDark ? darkAccent : lightAccent;

  /// Akzentfarbe für Vorschau-Swatches (Modus-unabhängiger Charakterton).
  Color get accent => primary;

  // ===================== PALETTEN (je Hell- + Dunkel-Set) =====================

  /// Wada Palette No. 154 - Autumnal Elegance
  static const SanzoWadaPalette autumnAki = SanzoWadaPalette(
    name: 'Aki (Autumn)',
    primary: Color(0xff8a3324), // Deep Rust Red
    secondary: Color(0xffc59b27), // Mustard Yellow
    lightBackground: Color(0xfff2ecdf), // Warmer Sand Canvas
    lightSurface: Color(0xffe5dac2), // Pale Sand Card
    lightTextPrimary: Color(0xff2b2a27),
    lightTextSecondary: Color(0xff58564f),
    lightAccent: Color(0xff395c47), // Sage Green (6.4:1 / 5.4:1)
    darkBackground: Color(0xff241a10), // Ember Brown
    darkSurface: Color(0xff3a2c1a), // Umber Card
    darkTextPrimary: Color(0xfff6ede0),
    darkTextSecondary: Color(0xffc9b59b),
    darkAccent: Color(0xff74b78f), // Hellerer Salbei (7.2:1 / 5.7:1)
  );

  /// Wada Palette No. 81 - Spring Whisper
  static const SanzoWadaPalette springHaru = SanzoWadaPalette(
    name: 'Haru (Spring)',
    primary: Color(0xffe5989b), // Sakura Pink
    secondary: Color(0xffb5c99a), // Pale Sprout Green
    lightBackground: Color(0xfff1f6ec), // Light Sage Canvas
    lightSurface: Color(0xffe2ecda), // Sage Mint Card
    lightTextPrimary: Color(0xff2c302e),
    lightTextSecondary: Color(0xff5d6663),
    lightAccent: Color(0xffb3261e), // Tiefes Sakura-Rot (6.0:1 / 5.4:1)
    darkBackground: Color(0xff1a2018), // Deep Sage Night
    darkSurface: Color(0xff2c372a), // Moss Night Card
    darkTextPrimary: Color(0xfff2f5ee),
    darkTextSecondary: Color(0xffa9b6a3),
    darkAccent: Color(0xffffb5a7), // Soft Peach (9.8:1 / 7.4:1)
  );

  /// Wada Palette No. 25 - Summer Breeze
  static const SanzoWadaPalette summerNatsu = SanzoWadaPalette(
    name: 'Natsu (Summer)',
    primary: Color(0xff008080), // Teal
    secondary: Color(0xff2ec4b6), // Emerald Mint
    lightBackground: Color(0xffe6f3f0), // Ice Mint Canvas
    lightSurface: Color(0xffd3e9e3), // Mint Card
    lightTextPrimary: Color(0xff122321),
    lightTextSecondary: Color(0xff425956),
    lightAccent: Color(0xffa8442a), // Terrakotta (5.2:1 / 4.7:1)
    darkBackground: Color(0xff0d2421), // Deep Teal Night
    darkSurface: Color(0xff1b3e37), // Seaweed Card
    darkTextPrimary: Color(0xffd8f0ea),
    darkTextSecondary: Color(0xff9cc4bc),
    darkAccent: Color(0xffe29578), // Coral (6.8:1 / 4.9:1)
  );

  /// Wada Palette No. 63 - Ocean Coastal Walk
  static const SanzoWadaPalette oceanUmi = SanzoWadaPalette(
    name: 'Umi (Ocean)',
    primary: Color(0xff0e5f76), // Deep Teal
    secondary: Color(0xffd4a373), // Sand Gold
    lightBackground: Color(0xffe8eff6), // Soft Blue Canvas
    lightSurface: Color(0xffd6e2ec), // Light Grey Blue Card
    lightTextPrimary: Color(0xff0b2545),
    lightTextSecondary: Color(0xff475569),
    lightAccent: Color(0xff0f6d6d), // Aquamarin, abgedunkelt (5.3:1 / 4.7:1)
    darkBackground: Color(0xff0d1b2e), // Deep Navy Night
    darkSurface: Color(0xff1c3249), // Slate Blue Card
    darkTextPrimary: Color(0xffe8f0f7),
    darkTextSecondary: Color(0xffa9bfd1),
    darkAccent: Color(0xff2ec4c4), // Helles Aquamarin (6.9:1 / 5.2:1)
  );

  /// Wada Palette No. 223 - Winter Nocturne
  static const SanzoWadaPalette winterFuyu = SanzoWadaPalette(
    name: 'Fuyu (Winter)',
    primary: Color(0xff8da9c4), // Frost Blue
    secondary: Color(0xff556b2f), // Dark Olive
    lightBackground: Color(0xffedf2f8), // Ice Blue Canvas
    lightSurface: Color(0xffdbe6f1), // Frost Card
    lightTextPrimary: Color(0xff1a2735),
    lightTextSecondary: Color(0xff4a5b6c), // abgedunkelt: 5.5:1 auf Surface
    lightAccent: Color(0xff156d8d), // Eisblau, abgedunkelt (5.2:1 / 4.6:1)
    darkBackground: Color(0xff0b1b33), // Midnight Blue
    darkSurface: Color(0xff1e3152), // Slate Grey Blue Card
    darkTextPrimary: Color(0xffffffff),
    darkTextSecondary: Color(0xffcbd5e1),
    darkAccent: Color(0xff6fd3ef), // Ice Cyan, aufgehellt (8.9:1 / 6.7:1)
  );

  /// Wada Palette No. 295 - Midnight Neon
  static const SanzoWadaPalette midnightYoru = SanzoWadaPalette(
    name: 'Yoru (Midnight)',
    primary: Color(0xff9d4edd), // Medium Purple
    secondary: Color(0xff48cae4), // Ice Cyan
    lightBackground: Color(0xfff0ebf7), // Soft Lavender Canvas
    lightSurface: Color(0xffe0d6ee), // Violet Card
    lightTextPrimary: Color(0xff241b33),
    lightTextSecondary: Color(0xff5f5470),
    lightAccent: Color(0xff036b50), // Tiefes Mintgrün (5.6:1 / 4.7:1)
    darkBackground: Color(0xff150f26), // Deep Purple Night
    darkSurface: Color(0xff2b2152), // Deep Violet Card
    darkTextPrimary: Color(0xfff3e8ff),
    darkTextSecondary: Color(0xffc084fc),
    darkAccent: Color(0xff2ee6b0), // Mint Green (10.6:1 / 8.3:1)
  );

  /// Wada Palette No. 112 - Ancient Forest
  static const SanzoWadaPalette forestMori = SanzoWadaPalette(
    name: 'Mori (Forest)',
    primary: Color(0xff40916c), // Green
    secondary: Color(0xff8d5b4c), // Bark Brown
    lightBackground: Color(0xffe9f2ea), // Soft Forest Canvas (sichtbar grün)
    lightSurface: Color(0xffd6e6da), // Pale Moss Card
    lightTextPrimary: Color(0xff1c2b22),
    lightTextSecondary: Color(0xff55685c),
    lightAccent: Color(0xff14713f), // Waldgrün, abgedunkelt (5.3:1 / 4.7:1)
    darkBackground: Color(0xff0f2b1d), // Deep Forest Green (klar grün)
    darkSurface: Color(0xff204737), // Moss Card
    darkTextPrimary: Color(0xffe8f5e9),
    darkTextSecondary: Color(0xffa3c1ad),
    darkAccent: Color(0xff46c389), // Helles Moosgrün (6.8:1 / 4.7:1)
  );

  /// Wada Palette No. 182 - Magma Ash
  static const SanzoWadaPalette volcanoKazan = SanzoWadaPalette(
    name: 'Kazan (Volcano)',
    primary: Color(0xffe63946), // Volcano Red
    secondary: Color(0xffa2a2d0), // Lilac Grey
    lightBackground: Color(0xfff7ecee), // Soft Rose Canvas
    lightSurface: Color(0xffecd8dd), // Ash Rose Card
    lightTextPrimary: Color(0xff2e2023),
    lightTextSecondary: Color(0xff6b565b),
    lightAccent: Color(0xffc20527), // Vulkanrot, abgedunkelt (5.4:1 / 4.6:1)
    darkBackground: Color(0xff261216), // Deep Ember Night
    darkSurface: Color(0xff3d2530), // Ash Card
    darkTextPrimary: Color(0xfffae0e4),
    darkTextSecondary: Color(0xffcca3a8),
    darkAccent: Color(0xffff6b81), // Hot Pink, aufgehellt (6.2:1 / 4.7:1)
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

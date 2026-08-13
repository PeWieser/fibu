import 'package:flutter/widgets.dart';

/// Sanzo Wada curated color combinations from "A Dictionary of Color Combinations".
/// Expanded to support 4 Light-mode and 4 Dark-mode specific Japanese color schemes.
class SanzoWadaPalette {
  final String name;
  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;

  const SanzoWadaPalette({
    required this.name,
    required this.primary,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
  });

  // ================= LIGHT MODE PALETTES =================

  /// Wada Palette No. 154 - Autumnal Elegance
  static const SanzoWadaPalette autumnAki = SanzoWadaPalette(
    name: 'Aki (Autumn)',
    primary: Color(0xff8a3324),      // Deep Rust Red
    secondary: Color(0xffc59b27),    // Mustard Yellow
    background: Color(0xfff7f5f0),   // Warm Alabaster Off-white
    surface: Color(0xffe8e4d9),      // Pale Sand
    textPrimary: Color(0xff2b2a27),  // Charcoal
    textSecondary: Color(0xff58564f),// Muted Earth Grey
    accent: Color(0xff395c47),       // Sage Green
  );

  /// Wada Palette No. 81 - Spring Whisper
  static const SanzoWadaPalette springHaru = SanzoWadaPalette(
    name: 'Haru (Spring)',
    primary: Color(0xffe5989b),      // Sakura Pink
    secondary: Color(0xffb5c99a),    // Pale Sprout Green
    background: Color(0xfffafcf6),   // Soft Cream White
    surface: Color(0xfff0f4e8),      // Soft Sage Mint
    textPrimary: Color(0xff2c302e),  // Deep Forest Charcoal
    textSecondary: Color(0xff5d6663),// Muted Sage Grey
    accent: Color(0xffffb5a7),       // Soft Peach
  );

  /// Wada Palette No. 25 - Summer Breeze
  static const SanzoWadaPalette summerNatsu = SanzoWadaPalette(
    name: 'Natsu (Summer)',
    primary: Color(0xff008080),      // Teal
    secondary: Color(0xff2ec4b6),    // Emerald Mint
    background: Color(0xfff4faf8),   // Ice Mint Canvas
    surface: Color(0xffe6f4f1),      // Mint Card
    textPrimary: Color(0xff122321),  // Very Dark Teal
    textSecondary: Color(0xff425956),// Muted Slate Teal
    accent: Color(0xffe29578),       // Coral
  );

  /// Wada Palette No. 63 - Ocean Coastal Walk
  static const SanzoWadaPalette oceanUmi = SanzoWadaPalette(
    name: 'Umi (Ocean)',
    primary: Color(0xff0e5f76),      // Deep Teal
    secondary: Color(0xffd4a373),    // Sand Gold
    background: Color(0xfff8f9fa),   // Soft White
    surface: Color(0xffe9ecef),      // Light Grey Blue
    textPrimary: Color(0xff0b2545),  // Navy Dark
    textSecondary: Color(0xff475569),// Slate Grey
    accent: Color(0xff138a8a),       // Aquamarine
  );

  // ================= DARK MODE PALETTES =================

  /// Wada Palette No. 223 - Winter Nocturne
  static const SanzoWadaPalette winterFuyu = SanzoWadaPalette(
    name: 'Fuyu (Winter)',
    primary: Color(0xff8da9c4),      // Frost Blue
    secondary: Color(0xff556b2f),    // Dark Olive
    background: Color(0xff0b132b),   // Deep Ocean/Midnight Blue
    surface: Color(0xff1c2541),      // Slate Grey Blue
    textPrimary: Color(0xffffffff),  // Crisp White
    textSecondary: Color(0xffcbd5e1),// Light Slate Grey
    accent: Color(0xff48cae4),       // Ice Cyan
  );

  /// Wada Palette No. 295 - Midnight Neon
  static const SanzoWadaPalette midnightYoru = SanzoWadaPalette(
    name: 'Yoru (Midnight)',
    primary: Color(0xff9d4edd),      // Medium Purple
    secondary: Color(0xff48cae4),    // Ice Cyan
    background: Color(0xff100c1a),   // Deep Purple Black
    surface: Color(0xff241d3b),      // Deep Violet Card
    textPrimary: Color(0xfff3e8ff),  // Light Violet White
    textSecondary: Color(0xffc084fc),// Light Purple
    accent: Color(0xff06d6a0),       // Mint Green
  );

  /// Wada Palette No. 112 - Ancient Forest
  static const SanzoWadaPalette forestMori = SanzoWadaPalette(
    name: 'Mori (Forest)',
    primary: Color(0xff40916c),      // Green
    secondary: Color(0xff8d5b4c),    // Bark Brown
    background: Color(0xff0c1a14),   // Deep Forest Floor
    surface: Color(0xff1c352d),      // Moss Card
    textPrimary: Color(0xffe8f5e9),  // Mint Tint White
    textSecondary: Color(0xffa3c1ad),// Moss Grey
    accent: Color(0xff52b788),       // Light Green
  );

  /// Wada Palette No. 182 - Magma Ash
  static const SanzoWadaPalette volcanoKazan = SanzoWadaPalette(
    name: 'Kazan (Volcano)',
    primary: Color(0xffe63946),      // Volcano Red
    secondary: Color(0xffa2a2d0),    // Lilac Grey
    background: Color(0xff1a1216),   // Magma Dark Ash
    surface: Color(0xff30212a),      // Ash Card
    textPrimary: Color(0xfffae0e4),  // Magma White
    textSecondary: Color(0xffcca3a8),// Rose Ash
    accent: Color(0xffff4d6d),       // Hot Pink
  );

  /// Returns light-mode Wada palettes.
  static List<SanzoWadaPalette> get lightPalettes => [
        autumnAki,
        springHaru,
        summerNatsu,
        oceanUmi,
      ];

  /// Returns dark-mode Wada palettes.
  static List<SanzoWadaPalette> get darkPalettes => [
        winterFuyu,
        midnightYoru,
        forestMori,
        volcanoKazan,
      ];
}

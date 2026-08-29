import 'package:fibu/core/utils/contrast.dart';
import 'package:fibu/theme/sanzo_wada_palettes.dart';
import 'package:fibu/theme/theme.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dauerhafter Accessibility-Wächter für das Theme-System.
///
/// AGENTS.md fordert WCAG AA (≥ 4.5:1) für alle Text-auf-Hintergrund-
/// Kombinationen. Die Sanzo-Wada-Paletten waren ursprünglich nur auf
/// Ästhetik geprüft: Eine einzige Akzentfarbe pro Palette kann AA nie
/// erfüllen, weil sie in einem der beiden Modi zu hell bzw. zu dunkel ist
/// (z. B. Pfirsich auf hellem Grund: ~1.5:1). Diese Tests stellen sicher,
/// dass keine künftige Farbänderung unbemerkt darunter fällt.
void main() {
  const double aa = 4.5;

  /// Alle Kombinationen, die in der App tatsächlich als Text/Hintergrund
  /// auftreten können.
  List<(String, Color, Color)> combinations(AppThemeData theme) => [
        ('textPrimary auf canvas', theme.textPrimary, theme.canvas),
        ('textPrimary auf surface', theme.textPrimary, theme.surface),
        ('textSecondary auf canvas', theme.textSecondary, theme.canvas),
        ('textSecondary auf surface', theme.textSecondary, theme.surface),
        ('accent auf canvas', theme.accent, theme.canvas),
        ('accent auf surface', theme.accent, theme.surface),
        ('accentText auf accent', theme.accentText, theme.accent),
      ];

  void expectAccessible(String label, AppThemeData theme) {
    for (final (name, foreground, background) in combinations(theme)) {
      final double ratio = ColorContrast.ratio(foreground, background);
      expect(ratio, greaterThanOrEqualTo(aa),
          reason: '$label — $name ist $ratio:1 (gefordert ≥ $aa:1)');
    }
  }

  group('WCAG AA Kontraste', () {
    test('Standard-Themes erfüllen AA in Hell und Dunkel', () {
      expectAccessible('Standard Hell', AppThemeData.light);
      expectAccessible('Standard Dunkel', AppThemeData.dark);
    });

    test('jede Wada-Palette erfüllt AA in Hell und Dunkel', () {
      for (final SanzoWadaPalette palette in SanzoWadaPalette.values) {
        expectAccessible('${palette.name} (hell)',
            AppThemeData.fromWadaPalette(palette, isDark: false));
        expectAccessible('${palette.name} (dunkel)',
            AppThemeData.fromWadaPalette(palette, isDark: true));
      }
    });

    test('accentText ist stets die kontraststärkere Farbe', () {
      for (final SanzoWadaPalette palette in SanzoWadaPalette.values) {
        for (final bool isDark in [false, true]) {
          final AppThemeData theme =
              AppThemeData.fromWadaPalette(palette, isDark: isDark);
          final double white =
              ColorContrast.ratio(const Color(0xffffffff), theme.accent);
          final double black =
              ColorContrast.ratio(const Color(0xff000000), theme.accent);
          expect(theme.accentText,
              white >= black ? const Color(0xffffffff) : const Color(0xff000000),
              reason: '${palette.name} isDark=$isDark wählt die falsche Textfarbe');
        }
      }
    });
  });

  group('Einheitlicher Hintergrund', () {
    // Die freie Fläche um Listen/Karten herum soll dieselbe Theme-Farbe
    // haben wie die Elemente selbst (Aufgaben, Laufwerke) — kein zweiter,
    // abweichender Farbton im Layout.
    test('canvas entspricht surface in allen Themes', () {
      expect(AppThemeData.light.canvas, AppThemeData.light.surface);
      expect(AppThemeData.dark.canvas, AppThemeData.dark.surface);
      for (final SanzoWadaPalette palette in SanzoWadaPalette.values) {
        for (final bool isDark in [false, true]) {
          final AppThemeData theme =
              AppThemeData.fromWadaPalette(palette, isDark: isDark);
          expect(theme.canvas, theme.surface,
              reason: '${palette.name} isDark=$isDark: Freifläche weicht ab');
        }
      }
    });

    test('Akzentfarbe ist modusabhängig (Hell ≠ Dunkel bei hellen Tönen)', () {
      // Mindestens die Paletten mit hellen Charaktertönen brauchen zwingend
      // einen eigenen, dunkleren Hell-Akzent.
      for (final SanzoWadaPalette palette in SanzoWadaPalette.values) {
        final double lightLuminance =
            ColorContrast.relativeLuminance(palette.lightAccent);
        final double darkLuminance =
            ColorContrast.relativeLuminance(palette.darkAccent);
        expect(lightLuminance, isNot(darkLuminance),
            reason: '${palette.name}: identische Akzente können AA nicht '
                'in beiden Modi erfüllen');
        expect(lightLuminance, lessThan(darkLuminance),
            reason: '${palette.name}: Hell-Akzent muss dunkler sein als der '
                'Dunkel-Akzent');
      }
    });
  });

  group('Farbtokens werden tatsächlich genutzt', () {
    List<AppThemeData> allThemes() => [
          AppThemeData.light,
          AppThemeData.dark,
          for (final SanzoWadaPalette p in SanzoWadaPalette.values)
            AppThemeData.fromWadaPalette(p, isDark: false),
          for (final SanzoWadaPalette p in SanzoWadaPalette.values)
            AppThemeData.fromWadaPalette(p, isDark: true),
        ];

    test('Tab-/Navigationsleisten heben sich vom Inhalt ab', () {
      // Freifläche und Karten teilen sich eine Farbe; die Leiste braucht
      // deshalb einen eigenen Ton, sonst ist sie keine erkennbare Ebene.
      for (final AppThemeData t in allThemes()) {
        expect(t.bar, isNot(t.canvas),
            reason: 'bar muss sich von canvas unterscheiden');
        expect(t.bar, isNot(t.surface),
            reason: 'bar muss sich von surface unterscheiden');
      }
    });

    test('Haarlinie ist sichtbar, aber dezent', () {
      for (final AppThemeData t in allThemes()) {
        expect(t.hairline.a, greaterThan(0.1));
        expect(t.hairline.a, lessThan(0.5));
      }
    });

    test('Charakterfarben primary/secondary sind je Palette gesetzt', () {
      for (final SanzoWadaPalette p in SanzoWadaPalette.values) {
        for (final bool isDark in [false, true]) {
          final AppThemeData t = AppThemeData.fromWadaPalette(p, isDark: isDark);
          expect(t.primary, p.primary);
          expect(t.secondary, p.secondary);
        }
      }
    });
  });


  group('Einstellung „Charakterfarbe“', () {
    List<AppThemeData> allThemes() => [
          AppThemeData.light,
          AppThemeData.dark,
          for (final SanzoWadaPalette p in SanzoWadaPalette.values)
            AppThemeData.fromWadaPalette(p, isDark: false),
          for (final SanzoWadaPalette p in SanzoWadaPalette.values)
            AppThemeData.fromWadaPalette(p, isDark: true),
        ];

    test('Modus „Abgesichert“: primaryFor erreicht 3:1', () {
      for (final AppThemeData t in allThemes()) {
        final bool isDark = t.surface.computeLuminance() < 0.25;
        final Color c = t.primaryFor(isDark);
        expect(ColorContrast.ratio(c, t.canvas), greaterThanOrEqualTo(3.0),
            reason: 'primaryFor muss 3:1 gegen canvas erreichen');
        expect(ColorContrast.ratio(c, t.surface), greaterThanOrEqualTo(3.0),
            reason: 'primaryFor muss 3:1 gegen surface erreichen');
      }
    });

    test('Modus „Farbwaschung“: Text bleibt über der Waschung lesbar', () {
      // Die Waschung ist dekorativ, der Text darüber muss trotzdem 4.5:1
      // gegen die GEMISCHTE Fläche halten. Im wash-Modus wird deshalb
      // textPrimary verwendet: textSecondary fiele in drei Paletten unter
      // 4.5:1 (Fuyu 4.09, Mori 4.18, Kazan 4.41).
      for (final AppThemeData t in allThemes()) {
        final Color blended = Color.alphaBlend(t.primaryWash, t.surface);
        expect(ColorContrast.ratio(t.textPrimary, blended),
            greaterThanOrEqualTo(4.5),
            reason: 'textPrimary kippt über der Waschung unter 4.5:1');
      }
    });

    test('Modus „Farbwaschung“: textSecondary wäre zu schwach', () {
      // Dokumentiert, warum der wash-Modus textPrimary braucht.
      var tooWeak = 0;
      for (final AppThemeData t in allThemes()) {
        final Color blended = Color.alphaBlend(t.primaryWash, t.surface);
        if (ColorContrast.ratio(t.textSecondary, blended) < 4.5) tooWeak++;
      }
      expect(tooWeak, greaterThan(0),
          reason: 'Fällt keine Kombination ab, wäre textPrimary unnötig');
    });

    test('alle drei Modi sind auswählbar und persistent', () {
      expect(PrimaryUsage.values, hasLength(3));
      for (final PrimaryUsage usage in PrimaryUsage.values) {
        final AppThemeData t =
            AppThemeData.light.copyWith(primaryUsage: usage);
        expect(t.primaryUsage, usage);
        expect(t.canvas, AppThemeData.light.canvas,
            reason: 'copyWith darf keine anderen Tokens ändern');
      }
    });
  });

}

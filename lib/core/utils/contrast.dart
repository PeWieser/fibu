import 'package:flutter/widgets.dart';

/// WCAG-2.1-Kontrast-Hilfsfunktionen.
///
/// Wird vom Theme-System genutzt, damit Text-/Icon-Farben auf Akzentflächen
/// automatisch lesbar sind, und von den Theme-Tests, die die in AGENTS.md
/// geforderten Mindestkontraste (WCAG AA ≥ 4.5:1) dauerhaft absichern.
///
/// Die Leuchtdichte kommt aus [Color.computeLuminance] — Flutter rechnet dort
/// exakt die WCAG-Formel, und wir vermeiden damit die veralteten
/// Kanal-Accessoren (`color.red` & Co.), die im Rest des Projekts ebenfalls
/// nicht mehr verwendet werden.
abstract final class ColorContrast {
  /// Relative Leuchtdichte nach WCAG (0 = schwarz, 1 = weiß).
  static double relativeLuminance(Color color) => color.computeLuminance();

  /// Kontrastverhältnis zweier Farben (1.0 … 21.0).
  static double ratio(Color a, Color b) {
    final double l1 = relativeLuminance(a);
    final double l2 = relativeLuminance(b);
    final double lighter = l1 > l2 ? l1 : l2;
    final double darker = l1 > l2 ? l2 : l1;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Erfüllt die Kombination den WCAG-AA-Mindestkontrast für Fließtext?
  static bool meetsAA(Color foreground, Color background) =>
      ratio(foreground, background) >= 4.5;

  /// Erfüllt die Kombination den WCAG-AA-Mindestkontrast für große Schrift
  /// bzw. grafische Elemente (3.0:1)?
  static bool meetsAALargeText(Color foreground, Color background) =>
      ratio(foreground, background) >= 3.0;

  /// Liefert Weiß oder Schwarz — je nachdem, was auf [background] den höheren
  /// Kontrast erzielt. Damit ist Text auf Akzentflächen immer lesbar, ohne
  /// dass jede Aufrufstelle die Farbwahl selbst treffen muss.
  static Color bestOn(Color background) {
    return ratio(const Color(0xffffffff), background) >=
            ratio(const Color(0xff000000), background)
        ? const Color(0xffffffff)
        : const Color(0xff000000);
  }
}

import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/widgets.dart';

import 'theme.dart';

/// Central factory for the iOS (Cupertino) theme.
///
/// Everything on iOS should derive its colors from the active Sanzo Wada
/// [AppThemeData] (the user-visible color variants are preserved) while the
/// typography uses the system SF Pro font and native iOS layout metrics.
class IosTheme {
  const IosTheme._();

  /// Builds a [cupertino.CupertinoThemeData] from the resolved app theme.
  static cupertino.CupertinoThemeData build(AppThemeData theme) {
    final isDark = theme.canvas.computeLuminance() < 0.5;

    final textTheme = cupertino.CupertinoTextThemeData(
      textStyle: TextStyle(
        color: theme.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w400,
      ),
      actionTextStyle: TextStyle(
        color: theme.accent,
        fontSize: 17,
        fontWeight: FontWeight.w400,
      ),
      tabLabelTextStyle: TextStyle(
        color: theme.textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.w500,
      ),
      navTitleTextStyle: TextStyle(
        color: theme.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      navLargeTitleTextStyle: TextStyle(
        color: theme.textPrimary,
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      primaryColor: theme.accent,
    );

    return cupertino.CupertinoThemeData(
      brightness: isDark ? cupertino.Brightness.dark : cupertino.Brightness.light,
      primaryColor: theme.accent,
      primaryContrastingColor: cupertino.CupertinoColors.white,
      scaffoldBackgroundColor: theme.canvas,
      // Nav-Bars: pro Screen via iosBarBackground() transparent bei Liquid Glass
      // (iOS 26+); Default bleibt surface für iOS < 26 und System-Fallbacks.
      barBackgroundColor: theme.surface,
      textTheme: textTheme,
    );
  }

  /// Standard navigation bar background with iOS blur behaviour.
  static cupertino.CupertinoNavigationBar buildNavigationBar({
    required Widget title,
    Widget? leading,
    Widget? trailing,
  }) {
    return cupertino.CupertinoNavigationBar(
      // CupertinoNavigationBar applies its own translucent/blur background.
      middle: title,
      leading: leading,
      trailing: trailing,
    );
  }

  /// Gruppierter Section-Header (Apple-HIG): klein, sekundär, mit leichtem
  /// Tracking — bewusst NICHT in Versalien (Steve-Jobs-Regel: kein Schrei-Text).
  static Widget sectionHeader(String title, AppThemeData theme) {
    // `primaryFor` braucht die Modi-Information; abgeleitet aus der
    // Leuchtdichte von surface, damit kein zusätzlicher Parameter nötig ist.
    final bool isDark = theme.surface.computeLuminance() < 0.25;

    final bool wash = theme.primaryUsage == PrimaryUsage.wash;
    final bool accessible = theme.primaryUsage == PrimaryUsage.accessible;

    // Textton je Modus:
    //  - accessible: Charakterfarbe, Richtung Schwarz/Weiß verschoben bis 3:1.
    //  - wash: textPrimary. Über der Waschung fällt textSecondary in drei
    //    Paletten unter 4.5:1 (Fuyu 4.09, Mori 4.18, Kazan 4.41);
    //    textPrimary hält überall (Minimum 8.34).
    //  - identity: der geprüfte Standardton.
    final Color labelColor = accessible
        ? theme.primaryFor(isDark)
        : (wash ? theme.textPrimary : theme.textSecondary);

    final Widget label = Text(
      title,
      style: TextStyle(
        color: labelColor,
        fontSize: 13,
        fontWeight:
            (accessible || wash) ? FontWeight.w600 : FontWeight.w500,
        letterSpacing: 0.3,
      ),
    );

    // Modus `wash`: dezente Hintergrund-Tönung in der Charakterfarbe.
    // Rein dekorativ — der Text behält seinen zugänglichen Ton.
    if (wash) {
      return Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 6),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: theme.primaryWash,
            borderRadius: BorderRadius.circular(theme.radiusSm),
          ),
          child: label,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 6),
      child: label,
    );
  }

  /// A native large-title style header used inside a scroll view.
  ///
  /// iOS apps commonly present a 34 pt title above the grouped list content.
  static Widget largeTitle(String title, AppThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

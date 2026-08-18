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
      actionColor: theme.textSecondary,
    );

    return cupertino.CupertinoThemeData(
      brightness: isDark ? cupertino.Brightness.dark : cupertino.Brightness.light,
      primaryColor: theme.accent,
      primaryContrastingColor: cupertino.CupertinoColors.white,
      scaffoldBackgroundColor: theme.canvas,
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

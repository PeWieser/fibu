import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:fluent_ui/fluent_ui.dart' as fluent;

import '../utils/ios_haptics.dart';

/// Ein Weg, einen Bildschirm zu öffnen — auf allen drei Plattformen.
///
/// Bisher baute jede Navigation ihre Plattform-Weiche selbst:
/// `defaultTargetPlatform` prüfen, dann `FluentPageRoute`,
/// `CupertinoPageRoute` oder `MaterialPageRoute`. Dieselben fünf Zeilen
/// standen elf Mal im Projekt, und wer eine Navigation ergänzt hat, musste
/// sie neu schreiben — und hat dabei leicht eine Plattform vergessen.
///
/// Das Aussehen bleibt plattformeigen (Fluent-Übergang auf Windows,
/// Cupertino-Slide auf iOS, Material auf Android). Nur die **Entscheidung**
/// dafür steht jetzt an einer Stelle. Das ist derselbe Schnitt, den die
/// Bausteine in `core/widgets/windows_controls.dart` schon machen: geteilte
/// Logik, plattformeigene Darstellung.
class AppNav {
  const AppNav._();

  /// Route mit dem zur Plattform passenden Übergang.
  static Route<T> _route<T>(Widget screen) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return fluent.FluentPageRoute<T>(builder: (_) => screen);
      case TargetPlatform.iOS:
        return cupertino.CupertinoPageRoute<T>(builder: (_) => screen);
      default:
        return material.MaterialPageRoute<T>(builder: (_) => screen);
    }
  }

  /// Öffnet [screen] über dem aktuellen Bildschirm.
  ///
  /// Auf iOS mit Auswahl-Haptik, wie sie die Cupertino-Komponenten der App
  /// überall sonst auch auslösen.
  static Future<T?> push<T>(BuildContext context, Widget screen) {
    if (defaultTargetPlatform == TargetPlatform.iOS) IosHaptics.selection();
    return Navigator.of(context).push<T>(_route<T>(screen));
  }
}

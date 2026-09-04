import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;

import '../../theme/theme.dart';

/// Gemeinsame Fluent-Bausteine für die Windows-Ansichten.
///
/// **Warum diese Datei existiert.** Die Windows-Ansichten waren über weite
/// Strecken mit `GestureDetector` + `MouseRegion` + `ConstrainedBox` von Hand
/// gebaut. Das sieht nicht nur nach Fremdplattform aus, es ist auch nicht
/// barrierefrei:
///
///  * kein Tastaturfokus — mit Tab kommt man nicht hin, Aktivieren unmöglich
///  * keine Semantik — ein Screenreader meldet „Gruppe", nicht „Schaltfläche"
///  * keine sichtbare Fokus-Anzeige
///
/// `fluent.ListTile` bringt Fokus, Semantik und Fokus-Ring selbst mit. Diese
/// Bausteine kapseln es, damit alle fünf Ansichten gleich aussehen und gleich
/// bedienbar sind — und damit die Barrierefreiheit an einer Stelle stimmt
/// statt an fünf.
///
/// Nur für `TargetPlatform.windows`. iOS und Android bleiben unberührt.
class Win {
  Win._();

  /// Mindestgröße eines interaktiven Ziels. WCAG 2.5.8 verlangt 24 px,
  /// Apple und Microsoft empfehlen 44 bzw. 40. Wir nehmen 40.
  static const double minTarget = 40;

  /// Abschnitts-Überschrift im Stil der Windows-Einstellungen.
  static Widget sectionHeader(String text, AppThemeData theme) => Padding(
        padding: EdgeInsets.only(top: theme.lg, bottom: theme.sm),
        child: Semantics(
          header: true,
          child: Text(
            text,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );

  /// Eine Zeile in einer Kartengruppe.
  ///
  /// [onPressed] macht die Zeile zur Schaltfläche — mit Fokus, Semantik und
  /// Fokus-Ring. Ohne [onPressed] ist sie reine Anzeige.
  static Widget tile({
    required AppThemeData theme,
    required String title,
    String? subtitle,
    IconData? leading,
    Widget? trailing,
    VoidCallback? onPressed,
    String? semanticLabel,
    bool first = false,
    bool last = false,
  }) {
    return fluent.ListTile(
      leading: leading == null
          ? null
          : Icon(leading, size: 20, color: theme.accent),
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: TextStyle(color: theme.textSecondary, fontSize: 12, height: 1.4),
            ),
      trailing: trailing,
      onPressed: onPressed,
      shape: _groupBorder(theme, first: first, last: last),
    );
  }

  /// Kartengruppe um eine Folge von [tile]-Zeilen.
  static Widget group({
    required AppThemeData theme,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(theme.radiusSm),
        border: Border.all(color: theme.textSecondary.withValues(alpha: 0.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  /// Wert-Zeile ohne Interaktion — Beschriftung links, Wert rechts.
  static Widget infoRow({
    required AppThemeData theme,
    required String label,
    required String value,
    IconData? leading,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.md, vertical: theme.sm),
      child: Row(
        children: [
          if (leading != null) ...[
            Icon(leading, size: 20, color: theme.accent),
            SizedBox(width: theme.md),
          ],
          Expanded(
            child: Text(label,
                style: TextStyle(color: theme.textPrimary, fontSize: 14)),
          ),
          SizedBox(width: theme.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(color: theme.textSecondary, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  /// Schalter-Zeile mit Beschriftung.
  static Widget toggle({
    required AppThemeData theme,
    required String title,
    required String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool first = false,
    bool last = false,
  }) {
    return tile(
      theme: theme,
      title: title,
      subtitle: subtitle,
      // Der Schalter bekommt die Beschriftung als Semantik mit, sonst meldet
      // ein Screenreader nur „Schalter, ein/aus" ohne Bezug zur Zeile.
      trailing: Semantics(
        label: title,
        toggled: value,
        child: fluent.ToggleSwitch(
          checked: value,
          onChanged: onChanged,
        ),
      ),
      first: first,
      last: last,
    );
  }

  /// Ausklappbarer Bereich — das Fluent-Äquivalent zu „weitere Optionen".
  static Widget expander({
    required AppThemeData theme,
    required String header,
    String? subtitle,
    IconData? leading,
    required Widget content,
    bool initiallyExpanded = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: theme.sm),
      child: fluent.Expander(
        leading: leading == null ? null : Icon(leading, size: 20, color: theme.accent),
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(header, style: const TextStyle(fontSize: 14)),
            if (subtitle != null)
              Text(
                subtitle,
                style: TextStyle(color: theme.textSecondary, fontSize: 12),
              ),
          ],
        ),
        content: content,
        initiallyExpanded: initiallyExpanded,
      ),
    );
  }

  /// Statusmeldung — ersetzt die handgebauten Banner.
  static Widget infoBar({
    required String title,
    String? message,
    fluent.InfoBarSeverity severity = fluent.InfoBarSeverity.informational,
    VoidCallback? onClose,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: fluent.InfoBar(
        title: Text(title),
        content: message == null ? null : Text(message),
        severity: severity,
        onClose: onClose,
      ),
    );
  }

  static RoundedRectangleBorder _groupBorder(
    AppThemeData theme, {
    required bool first,
    required bool last,
  }) {
    final color = theme.textSecondary.withValues(alpha: 0.18);
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(first ? theme.radiusSm : 0),
        bottom: Radius.circular(last ? theme.radiusSm : 0),
      ),
      side: BorderSide(color: first || last ? color : color.withValues(alpha: 0)),
    );
  }

  /// Trennlinie zwischen Gruppen.
  static Widget divider(AppThemeData theme) => Padding(
        padding: EdgeInsets.symmetric(vertical: theme.sm),
        child: const fluent.Divider(),
      );
}

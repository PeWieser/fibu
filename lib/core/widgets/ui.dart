import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;

import '../../theme/theme.dart';
import 'windows_controls.dart';

/// Plattformneutrale Bausteine für Einstellungen.
///
/// **Warum es das gibt.** Dieselben Abschnitte (Cloud, Sicherung, System)
/// existierten dreimal — einmal pro Plattform. Jede Änderung musste dreimal
/// gemacht werden, und eine Plattform wurde dabei leicht vergessen.
///
/// Geteilt ist die **Struktur**: eine Zeile hat Titel, Untertitel, Symbol,
/// rechtes Element und Aktion. Plattformabhängig bleibt die **Darstellung**:
/// Windows bekommt `fluent.ListTile` über [Win] (Tastaturfokus, Semantik,
/// Fokus-Ring), iOS `CupertinoListTile`, Android `material.ListTile`.
///
/// Wer einen Abschnitt baut, schreibt ihn einmal.
class Ui {
  const Ui._();

  // --- Symbole -------------------------------------------------------------
  // Ein Satz semantischer Symbole, je Plattform das native.

  static TargetPlatform get _p => defaultTargetPlatform;

  static IconData get chevron => _p == TargetPlatform.windows
      ? fluent.FluentIcons.chevron_right
      : (_p == TargetPlatform.iOS
          ? cupertino.CupertinoIcons.chevron_forward
          : material.Icons.chevron_right);

  static IconData get cloud => _p == TargetPlatform.windows
      ? fluent.FluentIcons.cloud
      : (_p == TargetPlatform.iOS
          ? cupertino.CupertinoIcons.cloud
          : material.Icons.cloud_outlined);

  static IconData get cloudAdd => _p == TargetPlatform.windows
      ? fluent.FluentIcons.cloud_add
      : (_p == TargetPlatform.iOS
          ? cupertino.CupertinoIcons.cloud_upload
          : material.Icons.cloud_upload_outlined);

  static IconData get add => _p == TargetPlatform.windows
      ? fluent.FluentIcons.add
      : (_p == TargetPlatform.iOS
          ? cupertino.CupertinoIcons.add_circled
          : material.Icons.add_circle_outline);

  static IconData get folder => _p == TargetPlatform.windows
      ? fluent.FluentIcons.folder
      : (_p == TargetPlatform.iOS
          ? cupertino.CupertinoIcons.folder
          : material.Icons.folder_outlined);

  static IconData get sync => _p == TargetPlatform.windows
      ? fluent.FluentIcons.sync
      : (_p == TargetPlatform.iOS
          ? cupertino.CupertinoIcons.arrow_2_squarepath
          : material.Icons.sync);

  static IconData get document => _p == TargetPlatform.windows
      ? fluent.FluentIcons.document
      : (_p == TargetPlatform.iOS
          ? cupertino.CupertinoIcons.doc_text
          : material.Icons.description_outlined);

  static IconData get lock => _p == TargetPlatform.windows
      ? fluent.FluentIcons.lock
      : (_p == TargetPlatform.iOS
          ? cupertino.CupertinoIcons.lock
          : material.Icons.lock_outline);

  static IconData get calendar => _p == TargetPlatform.windows
      ? fluent.FluentIcons.calendar
      : (_p == TargetPlatform.iOS
          ? cupertino.CupertinoIcons.calendar
          : material.Icons.calendar_today_outlined);

  static IconData get clock => _p == TargetPlatform.windows
      ? fluent.FluentIcons.clock
      : (_p == TargetPlatform.iOS
          ? cupertino.CupertinoIcons.clock
          : material.Icons.schedule_outlined);

  static IconData get delete => _p == TargetPlatform.windows
      ? fluent.FluentIcons.delete
      : (_p == TargetPlatform.iOS
          ? cupertino.CupertinoIcons.trash
          : material.Icons.delete_outline);

  static IconData get settings => _p == TargetPlatform.windows
      ? fluent.FluentIcons.settings
      : (_p == TargetPlatform.iOS
          ? cupertino.CupertinoIcons.settings
          : material.Icons.settings_outlined);

  // --- Bausteine -----------------------------------------------------------

  /// Überschrift eines Abschnitts.
  static Widget sectionHeader(String text, AppThemeData theme) {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return Win.sectionHeader(text, theme);
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(theme.lg, theme.lg, theme.lg, theme.xs),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: theme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  /// Karte um eine Gruppe von Zeilen.
  ///
  /// [first]/[last] brauchen nur Windows (dort zeichnen die Zeilen ihre
  /// Ränder selbst); iOS und Android übernimmt die Liste.
  static Widget group({
    required AppThemeData theme,
    required List<Widget> children,
  }) {
    final platform = defaultTargetPlatform;
    if (platform == TargetPlatform.windows) {
      return Win.group(theme: theme, children: children);
    }
    if (platform == TargetPlatform.iOS) {
      return cupertino.CupertinoListSection.insetGrouped(
        backgroundColor: theme.surface,
        children: children,
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.md),
      child: material.Card(
        elevation: 0,
        color: theme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(theme.radiusLg),
          side: BorderSide(color: theme.textSecondary.withValues(alpha: 0.15)),
        ),
        child: Column(children: children),
      ),
    );
  }

  /// Eine Zeile: Titel, optional Untertitel, Symbol links, Element rechts.
  ///
  /// Ohne [onTap] ist sie reine Anzeige.
  static Widget tile({
    required AppThemeData theme,
    required String title,
    String? subtitle,
    IconData? leading,
    Widget? trailing,
    VoidCallback? onTap,
    String? semanticLabel,
    bool first = false,
    bool last = false,
  }) {
    final platform = defaultTargetPlatform;
    if (platform == TargetPlatform.windows) {
      return Win.tile(
        theme: theme,
        title: title,
        subtitle: subtitle,
        leading: leading,
        trailing: trailing,
        onPressed: onTap,
        semanticLabel: semanticLabel,
        first: first,
        last: last,
      );
    }
    if (platform == TargetPlatform.iOS) {
      return cupertino.CupertinoListTile(
        leading: leading == null
            ? null
            : Icon(leading, color: theme.accent, size: 22, semanticLabel: semanticLabel),
        title: Text(title, style: const TextStyle(fontSize: 16)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle,
                style: TextStyle(color: theme.textSecondary, fontSize: 12)),
        trailing: trailing ??
            (onTap == null
                ? null
                : Icon(chevron,
                    size: 18, color: cupertino.CupertinoColors.inactiveGray)),
        onTap: onTap,
      );
    }
    return material.ListTile(
      leading: leading == null
          ? null
          : Icon(leading, color: theme.accent, semanticLabel: semanticLabel),
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(subtitle,
              style: TextStyle(color: theme.textSecondary, fontSize: 12)),
      trailing: trailing ??
          (onTap == null ? null : Icon(chevron, color: theme.textSecondary)),
      onTap: onTap,
    );
  }

  /// Kleine Symbolschaltfläche — auf Windows mit Tastaturfokus.
  static Widget iconButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? semanticLabel,
  }) {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return fluent.IconButton(
        icon: Icon(icon, semanticLabel: semanticLabel),
        onPressed: onPressed,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Icon(icon,
            size: 20,
            color: cupertino.CupertinoColors.systemRed,
            semanticLabel: semanticLabel),
      );
    }
    return material.IconButton(
      icon: Icon(icon, semanticLabel: semanticLabel),
      onPressed: onPressed,
    );
  }

  /// Auswahlfeld — ComboBox auf Windows, Dropdown auf Android, Blatt auf iOS.
  ///
  /// [items] ist eine Map statt einer Liste, damit die Reihenfolge fest ist
  /// und der Anzeigetext pro Plattform übersetzt werden kann.
  static Widget picker<T>({
    required BuildContext context,
    required AppThemeData theme,
    required T value,
    required Map<T, String> items,
    required ValueChanged<T?> onChanged,
  }) {
    final platform = defaultTargetPlatform;
    if (platform == TargetPlatform.windows) {
      return fluent.ComboBox<T>(
        value: value,
        items: [
          for (final entry in items.entries)
            fluent.ComboBoxItem<T>(value: entry.key, child: Text(entry.value)),
        ],
        onChanged: onChanged,
      );
    }
    if (platform == TargetPlatform.iOS) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          final picked = await cupertino.showCupertinoModalPopup<T>(
            context: context,
            builder: (ctx) => cupertino.CupertinoActionSheet(
              actions: [
                for (final entry in items.entries)
                  cupertino.CupertinoActionSheetAction(
                    isDefaultAction: entry.key == value,
                    onPressed: () => Navigator.of(ctx).pop(entry.key),
                    child: Text(entry.value),
                  ),
              ],
              cancelButton: cupertino.CupertinoActionSheetAction(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(material.MaterialLocalizations.of(ctx).cancelButtonLabel),
              ),
            ),
          );
          if (picked != null) onChanged(picked);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(items[value] ?? '',
                style: TextStyle(color: theme.accent, fontSize: 15)),
            const SizedBox(width: 4),
            Icon(chevron, size: 14, color: cupertino.CupertinoColors.inactiveGray),
          ],
        ),
      );
    }
    return material.DropdownButton<T>(
      value: value,
      underline: const SizedBox.shrink(),
      items: [
        for (final entry in items.entries)
          material.DropdownMenuItem<T>(value: entry.key, child: Text(entry.value)),
      ],
      onChanged: onChanged,
    );
  }

  /// Einzeiliges Textfeld.
  static Widget textField({
    required AppThemeData theme,
    required TextEditingController controller,
    required ValueChanged<String> onSubmitted,
    String placeholder = '',
    double width = 220,
  }) {
    final platform = defaultTargetPlatform;
    if (platform == TargetPlatform.windows) {
      return SizedBox(
        width: width,
        child: fluent.TextBox(
          controller: controller,
          placeholder: placeholder,
          onSubmitted: onSubmitted,
        ),
      );
    }
    if (platform == TargetPlatform.iOS) {
      return SizedBox(
        width: width,
        child: cupertino.CupertinoTextField(
          controller: controller,
          placeholder: placeholder,
          onSubmitted: onSubmitted,
        ),
      );
    }
    return SizedBox(
      width: width,
      child: material.TextField(
        controller: controller,
        onSubmitted: onSubmitted,
        decoration: material.InputDecoration(
          hintText: placeholder,
          isDense: true,
          border: const material.OutlineInputBorder(),
        ),
      ),
    );
  }

  /// Zeile mit Schalter.
  static Widget toggle({
    required AppThemeData theme,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    bool first = false,
    bool last = false,
  }) {
    final platform = defaultTargetPlatform;
    if (platform == TargetPlatform.windows) {
      return Win.toggle(
        theme: theme,
        title: title,
        subtitle: subtitle,
        value: value,
        onChanged: onChanged,
        first: first,
        last: last,
      );
    }
    if (platform == TargetPlatform.iOS) {
      return cupertino.CupertinoListTile(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle,
                style: TextStyle(color: theme.textSecondary, fontSize: 12)),
        trailing: cupertino.CupertinoSwitch(value: value, onChanged: onChanged),
      );
    }
    return material.SwitchListTile(
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(subtitle,
              style: TextStyle(color: theme.textSecondary, fontSize: 12)),
      value: value,
      onChanged: onChanged,
    );
  }
}

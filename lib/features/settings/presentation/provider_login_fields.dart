import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/services/provider_auth.dart';
import '../../../core/services/rclone_provider_registry.dart';
import '../../../core/services/remote_registry_service.dart';
import '../../../theme/theme.dart';

/// Gemeinsame Anmeldefelder für einen rclone-Provider.
///
/// Kein eigener „gespeicherte Zugänge“-Button. Apple-Schlüsselbund /
/// System-Autofill füllt Benutzer/Passwort, weil die Felder korrekte
/// AutofillHints + Associated Domain haben.
///
/// Für virtuelle Backends (Union, Crypt, Alias, …) erscheint statt
/// Freitext eine Multiple-Choice-Auswahl der bereits verbundenen
/// Cloud-Laufwerke.
class ProviderLoginFields extends ConsumerStatefulWidget {
  const ProviderLoginFields({
    super.key,
    required this.platform,
    required this.theme,
    required this.strings,
    required this.descriptor,
    required this.controllers,
    required this.obscure,
    required this.onChanged,
    required this.onToggleObscure,
    required this.showAdvanced,
    required this.onToggleAdvanced,
  });

  final TargetPlatform platform;
  final AppThemeData theme;
  final AppStrings strings;
  final RcloneProviderDescriptor? descriptor;
  final Map<String, TextEditingController> controllers;
  final Set<String> obscure;
  final VoidCallback onChanged;
  final void Function(String key) onToggleObscure;
  final bool showAdvanced;
  final VoidCallback onToggleAdvanced;

  @override
  ConsumerState<ProviderLoginFields> createState() =>
      _ProviderLoginFieldsState();
}

class _ProviderLoginFieldsState extends ConsumerState<ProviderLoginFields> {
  TargetPlatform get platform => widget.platform;
  AppThemeData get theme => widget.theme;
  AppStrings get strings => widget.strings;
  RcloneProviderDescriptor? get descriptor => widget.descriptor;
  Map<String, TextEditingController> get controllers => widget.controllers;
  Set<String> get obscure => widget.obscure;
  VoidCallback get onChanged => widget.onChanged;
  void Function(String key) get onToggleObscure => widget.onToggleObscure;
  bool get showAdvanced => widget.showAdvanced;
  VoidCallback get onToggleAdvanced => widget.onToggleAdvanced;

  /// Fokus-Knoten pro Feld — nötig, um Schlüsselbund-Autofill zu erkennen.
  final Map<String, FocusNode> _focusNodes = {};

  /// Felder, deren Controller bereits einen Autofill-Listener haben.
  final Set<String> _autofillHooked = {};
  bool _dismissScheduled = false;

  FocusNode _nodeFor(String key) =>
      _focusNodes.putIfAbsent(key, () => FocusNode());

  /// Befüllt der Apple-Schlüsselbund das Passwortfeld, während der Fokus
  /// woanders liegt (typisch: E-Mail-Feld), ist die Eingabe komplett —
  /// Tastatur automatisch einklappen statt „Weiter/Fertig“-Getippe.
  void _hookAutofillDismiss(String key, TextEditingController controller) {
    if (!_autofillHooked.add(key)) return;
    controller.addListener(() {
      if (controller.text.isEmpty || _dismissScheduled) return;
      final node = _focusNodes[key];
      if (node != null && node.hasFocus) return; // Nutzer tippt selbst.
      _dismissScheduled = true;
      // Kleiner Aufschub, damit AutoFill beide Felder fertig schreiben kann.
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        _dismissScheduled = false;
        if (!mounted) return;
        final n = _focusNodes[key];
        if (n != null && n.hasFocus) return;
        FocusManager.instance.primaryFocus?.unfocus();
      });
    });
  }

  @override
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fields = ProviderAuth.visibleFields(
      descriptor,
      includeAdvanced: showAdvanced,
    );
    final hasAdvanced =
        descriptor?.fields.any((f) => f.isAdvanced) ?? false;

    final visible = fields.isEmpty && !ProviderAuth.isOAuth(descriptor)
        ? _fallbackFields()
        : fields;

    // WICHTIG: Kein verstecktes 0×0-URL-Feld mehr in der AutofillGroup.
    // iOS klassifiziert die Maske anhand der sichtbaren Felder (username +
    // password); ein unsichtbares URL-Feld hat die Erkennung als
    // Login-Formular gestört, sodass weder E-Mail- noch Passwort-Vorschläge
    // erschienen. Die Domain-Zuordnung übernimmt das Associated-Domains-
    // Entitlement (webcredentials), nicht ein Textfeld.
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < visible.length; i++)
            ..._fieldBlock(context, visible[i], isLast: i == visible.length - 1),
          if (hasAdvanced) ...[
            SizedBox(height: theme.sm),
            _advancedToggle(),
          ],
        ],
      ),
    );
  }

  List<ConfigFieldDefinition> _fallbackFields() => [
        ConfigFieldDefinition(
          key: 'user',
          label: strings.emailOrUserLabel,
        ),
        ConfigFieldDefinition(
          key: 'pass',
          label: strings.passwordFieldLabel,
          isSecret: true,
        ),
      ];

  List<Widget> _fieldBlock(
    BuildContext context,
    ConfigFieldDefinition field, {
    required bool isLast,
  }) {
    // Labels und Hinweise werden in der aktiven Sprache angezeigt.
    final label = field.localizedLabel(strings.locale);
    final hint = field.localizedHint(strings.locale);
    return [
      SizedBox(height: theme.md),
      Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      if (hint.isNotEmpty) ...[
        const SizedBox(height: 2),
        Text(
          hint,
          style: TextStyle(color: theme.textSecondary, fontSize: 12),
        ),
      ],
      SizedBox(height: theme.xs),
      if (field.remotePicker != RemotePickerMode.none)
        _remotePicker(context, field)
      else if (field.dropdownOptions != null && field.dropdownOptions!.isNotEmpty)
        _dropdown(context, field)
      else
        _textField(field, isLast: isLast),
    ];
  }

  Widget _advancedToggle() {
    final label =
        showAdvanced ? strings.hideAdvancedSettings : strings.advancedSettings;
    if (platform == TargetPlatform.iOS) {
      return cupertino.CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onToggleAdvanced,
        child: Text(
          showAdvanced ? label : label,
          style: TextStyle(color: theme.accent, fontSize: 14),
        ),
      );
    }
    if (platform == TargetPlatform.windows) {
      return fluent.HyperlinkButton(
        onPressed: onToggleAdvanced,
        child: Text(label),
      );
    }
    return material.TextButton(
      onPressed: onToggleAdvanced,
      child: Text(label),
    );
  }

  /// Multiple-Choice über die bereits verbundenen Cloud-Laufwerke.
  /// Single: ein Laufwerk; Multi: beliebig viele (Union/Combine).
  Widget _remotePicker(BuildContext context, ConfigFieldDefinition field) {
    final entriesAsync = ref.watch(remoteEntriesProvider);
    final entries = entriesAsync.valueOrNull ?? const <RemoteEntry>[];
    final controller =
        controllers[field.key] ?? TextEditingController();
    controllers[field.key] = controller;

    if (entriesAsync.isLoading && entries.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: theme.sm),
        child: platform == TargetPlatform.iOS
            ? const cupertino.CupertinoActivityIndicator()
            : platform == TargetPlatform.windows
                ? const SizedBox(
                    width: 16, height: 16, child: fluent.ProgressRing(strokeWidth: 2))
                : const SizedBox(
                    width: 16,
                    height: 16,
                    child: material.CircularProgressIndicator(strokeWidth: 2),
                  ),
      );
    }

    if (entries.isEmpty) {
      return Container(
        padding: EdgeInsets.all(theme.md),
        decoration: BoxDecoration(
          color: theme.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(theme.radiusSm),
          border: Border.all(color: theme.warning.withValues(alpha: 0.35)),
        ),
        child: Text(
          strings.noBaseDrivesForVirtual,
          style: TextStyle(color: theme.textPrimary, fontSize: 13, height: 1.35),
        ),
      );
    }

    final multi = field.remotePicker == RemotePickerMode.multi;
    final selectedIds = _parseSelectedRemoteIds(controller.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in entries)
          _remoteChoiceRow(
            entry: entry,
            selected: selectedIds.contains(entry.id),
            multi: multi,
            onTap: () {
              final next = Set<String>.from(selectedIds);
              if (multi) {
                if (next.contains(entry.id)) {
                  next.remove(entry.id);
                } else {
                  next.add(entry.id);
                }
              } else {
                next
                  ..clear()
                  ..add(entry.id);
              }
              // Gespeichert als rclone-IDs mit abschließendem „:“
              // (rclone erwartet „remote:“ bzw. „r1: r2:“).
              controller.text = next.map((id) => '$id:').join(' ');
              setState(() {});
              onChanged();
            },
          ),
      ],
    );
  }

  /// Liest die im Controller gespeicherten Remote-IDs (Format „id:“ oder „id:path“).
  Set<String> _parseSelectedRemoteIds(String raw) {
    final result = <String>{};
    for (final token in raw.split(RegExp(r'\s+'))) {
      final t = token.trim();
      if (t.isEmpty) continue;
      // Combine speichert „name=id:“ — hier nur die ID extrahieren.
      final eq = t.indexOf('=');
      final body = eq >= 0 ? t.substring(eq + 1) : t;
      final colon = body.indexOf(':');
      final id = colon >= 0 ? body.substring(0, colon) : body;
      if (id.isNotEmpty) result.add(id);
    }
    return result;
  }

  Widget _remoteChoiceRow({
    required RemoteEntry entry,
    required bool selected,
    required bool multi,
    required VoidCallback onTap,
  }) {
    final typeLabel = RemoteEntry.prettyType(entry.type);
    final subtitle = typeLabel.isNotEmpty && typeLabel != entry.name
        ? typeLabel
        : null;

    final leading = Icon(
      selected
          ? (multi
              ? cupertino.CupertinoIcons.checkmark_square_fill
              : cupertino.CupertinoIcons.checkmark_circle_fill)
          : (multi
              ? cupertino.CupertinoIcons.square
              : cupertino.CupertinoIcons.circle),
      color: selected ? theme.accent : theme.textSecondary,
      size: 22,
      semanticLabel: selected
          ? '${entry.name} ${strings.selectedLabel}'
          : entry.name,
    );

    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.sm, vertical: theme.sm),
        child: Row(
          children: [
            leading,
            SizedBox(width: theme.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 15,
                      color: theme.textPrimary,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: theme.xs),
        decoration: BoxDecoration(
          color: selected
              ? theme.accent.withValues(alpha: 0.10)
              : theme.surface,
          borderRadius: BorderRadius.circular(theme.radiusSm),
          border: Border.all(
            color: selected
                ? theme.accent.withValues(alpha: 0.40)
                : theme.textSecondary.withValues(alpha: 0.18),
          ),
        ),
        child: content,
      ),
    );
  }

  Widget _dropdown(BuildContext context, ConfigFieldDefinition field) {
    final options = field.dropdownOptions!;
    final current = controllers[field.key]?.text;
    final value = (current != null && options.contains(current))
        ? current
        : options.first;
    if (platform == TargetPlatform.iOS) {
      return cupertino.CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        color: theme.surface,
        onPressed: () async {
          final picked = await _pickCupertino(options, value);
          if (picked != null) {
            controllers[field.key]?.text = picked;
            onChanged();
          }
        },
        child: Row(
          children: [
            Expanded(
              child: Text(value, style: TextStyle(color: theme.textPrimary)),
            ),
            Icon(cupertino.CupertinoIcons.chevron_down,
                size: 14, color: theme.textSecondary),
          ],
        ),
      );
    }
    if (platform == TargetPlatform.windows) {
      return fluent.ComboBox<String>(
        value: value,
        items: options
            .map((o) => fluent.ComboBoxItem(value: o, child: Text(o)))
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          controllers[field.key]?.text = v;
          onChanged();
        },
      );
    }
    return material.DropdownButton<String>(
      isExpanded: true,
      value: value,
      items: options
          .map((o) => material.DropdownMenuItem(value: o, child: Text(o)))
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        controllers[field.key]?.text = v;
        onChanged();
      },
    );
  }

  Future<String?> _pickCupertino(List<String> options, String current) {
    var index = options.indexOf(current);
    if (index < 0) index = 0;
    return cupertino.showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => Container(
        height: 240,
        color: theme.surface,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: cupertino.CupertinoButton(
                onPressed: () => Navigator.pop(ctx, options[index]),
                child: Text(strings.save),
              ),
            ),
            Expanded(
              child: cupertino.CupertinoPicker(
                itemExtent: 36,
                scrollController:
                    cupertino.FixedExtentScrollController(initialItem: index),
                onSelectedItemChanged: (i) => index = i,
                children: [
                  for (final o in options) Center(child: Text(o)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textField(ConfigFieldDefinition field, {required bool isLast}) {
    final controller =
        controllers[field.key] ?? TextEditingController();
    controllers[field.key] = controller;
    final secret = field.isSecret;
    final hidden = secret && !obscure.contains(field.key);
    final hints = ProviderAuth.autofillHintsFor(field).toList();
    final keyboard = ProviderAuth.keyboardFor(field);
    final action = ProviderAuth.actionFor(field, isLast);
    final focusNode = _nodeFor(field.key);
    final hint = field.localizedHint(strings.locale);
    // Passwortfelder: Autofill-Erkennung → Tastatur automatisch einklappen.
    if (secret) _hookAutofillDismiss(field.key, controller);

    if (platform == TargetPlatform.iOS) {
      return cupertino.CupertinoTextField(
        controller: controller,
        focusNode: focusNode,
        placeholder: hint.isNotEmpty ? hint : null,
        padding: const EdgeInsets.all(12),
        obscureText: hidden,
        autofillHints: hints,
        keyboardType: keyboard,
        textInputAction: action,
        autocorrect: false,
        enableSuggestions: !secret,
        textCapitalization: TextCapitalization.none,
        onChanged: (_) => onChanged(),
        suffix: secret
            ? cupertino.CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                onPressed: () => onToggleObscure(field.key),
                child: Icon(
                  hidden
                      ? cupertino.CupertinoIcons.eye
                      : cupertino.CupertinoIcons.eye_slash,
                  size: 20,
                  semanticLabel:
                      hidden ? strings.showPassword : strings.hidePassword,
                ),
              )
            : null,
      );
    }
    if (platform == TargetPlatform.windows) {
      return fluent.TextBox(
        controller: controller,
        focusNode: focusNode,
        placeholder: hint.isNotEmpty ? hint : null,
        obscureText: hidden,
        keyboardType: keyboard,
        textInputAction: action,
        onChanged: (_) => onChanged(),
        suffix: secret
            ? fluent.IconButton(
                icon: Icon(
                  hidden ? fluent.FluentIcons.view : fluent.FluentIcons.hide,
                  size: 16,
                ),
                onPressed: () => onToggleObscure(field.key),
              )
            : null,
      );
    }
    return material.TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: hidden,
      autofillHints: hints,
      keyboardType: keyboard,
      textInputAction: action,
      autocorrect: false,
      enableSuggestions: !secret,
      textCapitalization: TextCapitalization.none,
      onChanged: (_) => onChanged(),
      decoration: material.InputDecoration(
        hintText: hint.isNotEmpty ? hint : null,
        border: const material.OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        suffixIcon: secret
            ? material.IconButton(
                icon: Icon(
                  hidden
                      ? material.Icons.visibility
                      : material.Icons.visibility_off,
                  size: 20,
                ),
                tooltip:
                    hidden ? strings.showPassword : strings.hidePassword,
                onPressed: () => onToggleObscure(field.key),
              )
            : null,
      ),
    );
  }
}

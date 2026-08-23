import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;

import '../../../core/localization/app_strings.dart';
import '../../../core/services/provider_auth.dart';
import '../../../core/services/rclone_provider_registry.dart';
import '../../../theme/theme.dart';

/// Gemeinsame Anmeldefelder für einen rclone-Provider.
///
/// Kein eigener „gespeicherte Zugänge“-Button. Apple-Schlüsselbund /
/// System-Autofill füllt Benutzer/Passwort, weil die Felder korrekte
/// AutofillHints + Associated Domain haben.
class ProviderLoginFields extends StatefulWidget {
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
  State<ProviderLoginFields> createState() => _ProviderLoginFieldsState();
}

class _ProviderLoginFieldsState extends State<ProviderLoginFields> {
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
    return [
      SizedBox(height: theme.md),
      Text(
        field.label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      if (field.hint.isNotEmpty) ...[
        const SizedBox(height: 2),
        Text(
          field.hint,
          style: TextStyle(color: theme.textSecondary, fontSize: 12),
        ),
      ],
      SizedBox(height: theme.xs),
      if (field.dropdownOptions != null && field.dropdownOptions!.isNotEmpty)
        _dropdown(context, field)
      else
        _textField(field, isLast: isLast),
    ];
  }

  Widget _advancedToggle() {
    final label = showAdvanced
        ? strings.advancedSettings
        : strings.advancedSettings;
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
    // Passwortfelder: Autofill-Erkennung → Tastatur automatisch einklappen.
    if (secret) _hookAutofillDismiss(field.key, controller);

    if (platform == TargetPlatform.iOS) {
      return cupertino.CupertinoTextField(
        controller: controller,
        focusNode: focusNode,
        placeholder: field.hint.isNotEmpty ? field.hint : null,
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
        placeholder: field.hint.isNotEmpty ? field.hint : null,
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
        hintText: field.hint.isNotEmpty ? field.hint : null,
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

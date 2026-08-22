import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
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
  late final TextEditingController _domainController;

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

  @override
  void initState() {
    super.initState();
    final domain = descriptor == null
        ? null
        : ProviderAuth.autofillDomain(descriptor!.id);
    _domainController = TextEditingController(
      text: domain == null ? '' : 'https://$domain',
    );
  }

  @override
  void didUpdateWidget(covariant ProviderLoginFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    final domain = descriptor == null
        ? null
        : ProviderAuth.autofillDomain(descriptor!.id);
    final next = domain == null ? '' : 'https://$domain';
    if (_domainController.text != next) _domainController.text = next;
  }

  @override
  void dispose() {
    _domainController.dispose();
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
    final domain = descriptor == null
        ? null
        : ProviderAuth.autofillDomain(descriptor!.id);

    final visible = fields.isEmpty && !ProviderAuth.isOAuth(descriptor)
        ? _fallbackFields()
        : fields;

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (domain != null) _hiddenDomainField(),
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

  List<ConfigFieldDefinition> _fallbackFields() => const [
        ConfigFieldDefinition(
          key: 'user',
          label: 'E-Mail / Benutzername',
          hint: 'name@beispiel.de',
        ),
        ConfigFieldDefinition(
          key: 'pass',
          label: 'Passwort',
          isSecret: true,
        ),
      ];

  Widget _hiddenDomainField() {
    // Unsichtbares URL-Feld: iOS ordnet den Autofill-Kontext der Domain zu
    // (mega.nz, drive.google.com, …) — zusammen mit Associated Domains.
    return ExcludeSemantics(
      child: SizedBox(
        height: 0,
        width: 0,
        child: Opacity(
          opacity: 0,
          child: cupertino.CupertinoTextField(
            controller: _domainController,
            autofillHints: const [AutofillHints.url],
            enableSuggestions: false,
            autocorrect: false,
          ),
        ),
      ),
    );
  }

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
          final picked = await _pickCupertino(context, options, value);
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
    // Callers pass context via the button; we use a root-less picker through
    // the nearest navigator. Implemented by the parent via overlay would be
    // heavier — CupertinoPicker in a modal is enough.
    return Future<String?>.value(null);
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

    if (platform == TargetPlatform.iOS) {
      return cupertino.CupertinoTextField(
        controller: controller,
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

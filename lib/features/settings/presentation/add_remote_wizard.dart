import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/services/app_log_service.dart';
import '../../../core/services/ios_rclone_service.dart';
import '../../../core/services/oauth_service.dart';
import '../../../core/services/provider_auth.dart';
import '../../../core/services/rclone_provider.dart';
import '../../../core/services/rclone_provider_registry.dart';
import '../../../core/services/remote_registry_service.dart';
import '../../../theme/theme.dart';
import 'provider_login_fields.dart';

/// 2-Schritt-Wizard: Anbieter wählen → passende Anmeldemaske.
///
/// Keine eigenen „gespeicherte Zugänge“-Buttons. Der Apple-Schlüsselbund
/// füllt Benutzer/Passwort über Autofill + Associated Domains.
class AddRemoteWizardDialog extends ConsumerStatefulWidget {
  const AddRemoteWizardDialog({super.key, required this.platform});

  final TargetPlatform platform;

  @override
  ConsumerState<AddRemoteWizardDialog> createState() =>
      _AddRemoteWizardDialogState();
}

class _AddRemoteWizardDialogState extends ConsumerState<AddRemoteWizardDialog> {
  int _currentStep = 0;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final Map<String, TextEditingController> _fieldControllers = {};
  final Set<String> _revealedSecrets = {};
  bool _showAdvanced = false;
  bool _nameWasAutoFilled = false;

  String _selectedProviderId = '';
  String _selectedProviderName = '';
  String _searchQuery = '';

  String? _nameError;
  String? _providerError;
  String? _step2Error;

  bool _isTesting = false;
  String? _testStatus;
  String? _testMessage;

  bool _isAdding = false;
  String? _addError;
  bool _isOAuthAuthorized = false;
  bool _isOAuthWorking = false;
  String? _oauthError;
  bool _step2Verified = false;

  bool get _canAdd => _step2Verified;

  RcloneProviderDescriptor? get _selectedDescriptor =>
      _selectedProviderId.isEmpty
          ? null
          : RcloneProviderRegistry.findById(_selectedProviderId);

  String get _selectedRcloneType => ProviderAuth.rcloneType(_selectedProviderId);

  bool get _isOAuthProvider => ProviderAuth.isOAuth(_selectedDescriptor);

  String get _selectedProviderDisplay => _selectedProviderName.isNotEmpty
      ? _selectedProviderName
      : _selectedProviderId;

  Map<String, String> get _fieldValues => {
        for (final e in _fieldControllers.entries) e.key: e.value.text,
      };

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    for (final c in _fieldControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _markCredentialsDirty() {
    if (_step2Verified) setState(() => _step2Verified = false);
  }

  void _ensureFieldControllers() {
    final fields =
        _selectedDescriptor?.fields ?? const <ConfigFieldDefinition>[];
    final keys = fields.isEmpty
        ? const ['user', 'pass', 'host', 'port']
        : fields.map((f) => f.key);
    for (final key in keys) {
      if (_fieldControllers.containsKey(key)) continue;
      String initial = '';
      for (final f in fields) {
        if (f.key == key && f.defaultValue != null) {
          initial = f.defaultValue!;
          break;
        }
      }
      _fieldControllers[key] = TextEditingController(text: initial);
    }
  }

  void _selectProvider(RcloneProviderDescriptor provider) {
    final strings = context.strings;
    final displayName = provider.localizedName(strings.locale);
    setState(() {
      _selectedProviderId = provider.id;
      _selectedProviderName = displayName;
      _providerError = null;
      _step2Verified = false;
      _showAdvanced = false;
      _revealedSecrets.clear();
      if (_nameController.text.trim().isEmpty || _nameWasAutoFilled) {
        _nameController.text = displayName;
        _nameWasAutoFilled = true;
        _nameError = null;
      }
    });
    _ensureFieldControllers();
  }

  List<RcloneProviderDescriptor> _filteredProviders() {
    final query = _searchQuery.toLowerCase().trim();
    final all = RcloneProviderRegistry.providers;
    if (query.isEmpty) {
      final popular = all.where((p) => p.isPopular).toList();
      final rest = all.where((p) => !p.isPopular).toList();
      return [...popular, ...rest];
    }
    // Suche berücksichtigt deutsche UND englische Bezeichnungen sowie die
    // interne Kennung, damit die Liste in beiden Sprachen durchsuchbar ist.
    return all
        .where((p) =>
            p.name.toLowerCase().contains(query) ||
            p.nameEn.toLowerCase().contains(query) ||
            p.description.toLowerCase().contains(query) ||
            p.descriptionEn.toLowerCase().contains(query) ||
            p.id.toLowerCase().contains(query))
        .toList();
  }

  void _goToStep2() {
    final strings = context.strings;
    final name = _nameController.text.trim();
    var hasError = false;
    setState(() {
      _nameError = name.isEmpty ? strings.nameRequiredError : null;
      _providerError =
          _selectedProviderId.isEmpty ? strings.providerRequiredError : null;
      hasError = _nameError != null || _providerError != null;
    });
    if (hasError) return;
    setState(() {
      _currentStep = 1;
      _step2Error = null;
      _testStatus = null;
      _testMessage = null;
      _addError = null;
      _isOAuthAuthorized = false;
      _oauthError = null;
      _step2Verified = false;
      _showAdvanced = false;
    });
    _ensureFieldControllers();
  }

  Future<void> _handleOAuthAuthorize() async {
    final strings = context.strings;
    final remoteName = _nameController.text.trim();
    if (remoteName.isEmpty) {
      setState(() => _oauthError = strings.nameRequiredError);
      return;
    }

    setState(() {
      _isOAuthWorking = true;
      _oauthError = null;
      _isOAuthAuthorized = false;
    });

    final providerId = _selectedRcloneType;
    final rclone = ref.read(rcloneServiceProvider);
    Map<String, String> creds = const {'client_id': '', 'client_secret': ''};
    if (rclone is IosRcloneService) {
      creds = await rclone.getProviderClientCredentials(providerId);
    }
    final clientId = creds['client_id'] ?? '';
    if (clientId.isEmpty) {
      if (mounted) {
        setState(() {
          _isOAuthWorking = false;
          _oauthError = strings.oauthMissingClientHint;
        });
      }
      return;
    }

    final result = await ref.read(oauthServiceProvider).authorize(
          providerId: providerId,
          remoteName: remoteName,
          authUrl: _buildOAuthUrl(providerId, remoteName, creds),
        );

    if (mounted) {
      setState(() {
        _isOAuthWorking = false;
        if (result.success) {
          _isOAuthAuthorized = true;
          _step2Verified = true;
          _oauthError = null;
        } else {
          _oauthError = result.error;
        }
      });
    }
  }

  Uri _buildOAuthUrl(
    String providerId,
    String remoteName,
    Map<String, String> creds,
  ) {
    final state = Uri.encodeQueryComponent(remoteName);
    final clientId = creds['client_id'] ?? '';
    final redirect =
        Uri.encodeComponent('${OAuthService.callbackScheme}://callback');
    if (clientId.isEmpty) {
      return Uri.parse(
          'https://rclone.org/oauth/?provider=$providerId&state=$state&redirect_uri=$redirect');
    }
    switch (providerId) {
      case 'drive':
      case 'google_photos':
      case 'google photos':
        return Uri.parse(
            'https://accounts.google.com/o/oauth2/v2/auth?scope=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fdrive&state=$state&redirect_uri=$redirect&response_type=code&client_id=$clientId');
      case 'onedrive':
        return Uri.parse(
            'https://login.microsoftonline.com/common/oauth2/v2.0/authorize?scope=offline_access%20files.readwrite.all&state=$state&redirect_uri=$redirect&response_type=code&client_id=$clientId');
      case 'dropbox':
        return Uri.parse(
            'https://www.dropbox.com/oauth2/authorize?response_type=code&state=$state&client_id=$clientId&redirect_uri=$redirect');
      default:
        return Uri.parse(
            'https://rclone.org/oauth/?provider=$providerId&state=$state&redirect_uri=$redirect');
    }
  }

  String _friendlyConfigError(AppStrings strings, Object e) {
    final raw = e.toString().replaceAll('Exception: ', '').trim();
    final lower = raw.toLowerCase();
    String? providerError;
    final m = RegExp(r'"error"\s*:\s*"([^"]+)"').firstMatch(raw);
    if (m != null) providerError = m.group(1);

    if (lower.contains("couldn't login") ||
        lower.contains('unauthorized') ||
        lower.contains('forbidden') ||
        lower.contains('access denied') ||
        lower.contains('invalid') ||
        lower.contains('401') ||
        lower.contains('403')) {
      return providerError != null
          ? '${strings.invalidCredentialsHint}\n$providerError'
          : strings.invalidCredentialsHint;
    }
    if (lower.contains('timeout') ||
        lower.contains('timed out') ||
        lower.contains('socket') ||
        lower.contains('no such host') ||
        lower.contains('network') ||
        lower.contains('unreachable')) {
      return providerError != null
          ? '${strings.networkUnavailableError}\n$providerError'
          : strings.networkUnavailableError;
    }
    return providerError ?? raw;
  }

  Future<Map<String, String>> _buildProviderConfig() async {
    String? token;
    if (_isOAuthProvider) {
      token = await ref
          .read(oauthServiceProvider)
          .getToken(_nameController.text.trim());
    }
    return ProviderAuth.buildConfig(
      providerId: _selectedProviderId,
      descriptor: _selectedDescriptor,
      values: _fieldValues,
      obscure: (plain) =>
          ref.read(rcloneServiceProvider).obscurePassword(plain),
      oauthToken: token,
    );
  }

  void _validateStep2Fields(AppStrings strings) {
    final missing =
        ProviderAuth.missingRequired(_selectedDescriptor, _fieldValues);
    if (missing != null) {
      throw Exception(strings.credentialsRequiredError);
    }
  }

  Future<void> _handleTestConnection() async {
    final strings = context.strings;
    setState(() {
      _isTesting = true;
      _testStatus = null;
      _testMessage = null;
      _step2Error = null;
    });

    try {
      _validateStep2Fields(strings);
      if (_isOAuthProvider) {
        final token = await ref
            .read(oauthServiceProvider)
            .getToken(_nameController.text.trim());
        if (token == null || token.isEmpty) {
          throw Exception(strings.oauthAuthorizeFirstHint);
        }
        _isOAuthAuthorized = true;
      } else {
        final config = await _buildProviderConfig();
        await ref.read(rcloneServiceProvider).testConnection(
              type: _selectedRcloneType,
              config: config,
            );
      }
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testStatus = 'success';
          _testMessage = strings.connectionSuccess;
          _step2Verified = true;
        });
      }
    } catch (e) {
      AppLog.warn('remote', 'Verbindungstest fehlgeschlagen: $e');
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testStatus = 'error';
          _testMessage = _friendlyConfigError(strings, e);
        });
      }
    }
  }

  Future<void> _handleAddRemote() async {
    final strings = context.strings;
    final name = _nameController.text.trim();
    if (!_canAdd) {
      setState(() => _step2Error = strings.testRequiredBeforeAddHint);
      return;
    }
    try {
      _validateStep2Fields(strings);
    } catch (_) {
      setState(() => _step2Error = strings.credentialsRequiredError);
      return;
    }

    setState(() {
      _isAdding = true;
      _addError = null;
      _step2Error = null;
    });

    try {
      final config = await _buildProviderConfig();
      // createRemote liefert den Eintrag mit der stabilen internen Kennung.
      // Zurückgegeben wird diese Kennung (nicht der Anzeigename!), sonst
      // fänden rclone-Aufrufe wie „catFile(name)“ die Sektion nicht
      // („didn't find section in config file“) und die Erkennung vorhandener
      // Tasks schlüge fehl.
      final entry = await ref.read(remoteRegistryServiceProvider).createRemote(
            displayName: name,
            type: _selectedRcloneType,
            config: config,
          );
      if (widget.platform == TargetPlatform.iOS && !_isOAuthProvider) {
        TextInput.finishAutofillContext();
      }
      ref.invalidate(remoteEntriesProvider);
      ref.invalidate(remotesProvider);
      ref.invalidate(primaryQuotaProvider);
      if (mounted) Navigator.pop(context, entry.id);
    } catch (e) {
      AppLog.warn('remote', 'Remote-Anlage fehlgeschlagen: $e');
      if (mounted) {
        setState(() {
          _isAdding = false;
          _addError = _friendlyConfigError(strings, e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    // Theme live verfolgen, damit der Wizard bei Dark-/Light-/Palettenwechsel
    // sofort neu einfärbt (Text- und Objektfarben).
    ref.watch(appThemeProvider);
    final theme = context.theme;
    final strings = context.strings;
    if (widget.platform == TargetPlatform.iOS) {
      return _buildIOS(theme, strings);
    }
    if (widget.platform == TargetPlatform.android) {
      return _buildAndroid(theme, strings);
    }
    return _buildWindows(theme, strings);
  }

  Widget _providerList(AppThemeData theme, AppStrings strings) {
    final filtered = _filteredProviders();
    if (filtered.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(theme.xl),
        child: Center(
          child: Text(strings.noMatchingProviders,
              style: TextStyle(color: theme.textSecondary)),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: widget.platform == TargetPlatform.iOS,
      physics: widget.platform == TargetPlatform.iOS
          ? const NeverScrollableScrollPhysics()
          : null,
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final provider = filtered[index];
        final selected = _selectedProviderId == provider.id;
        final title = provider.localizedName(strings.locale);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _selectProvider(provider),
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: theme.md, vertical: theme.sm + 2),
            color: selected ? theme.accent.withValues(alpha: 0.12) : null,
            child: Row(
              children: [
                Icon(
                  selected
                      ? cupertino.CupertinoIcons.checkmark_circle_fill
                      : cupertino.CupertinoIcons.circle,
                  color: selected ? theme.accent : theme.textSecondary,
                  size: 22,
                ),
                SizedBox(width: theme.md),
                // Nur der Anbietername — die Beschreibungszeile
                // („bekannter Cloud-Speicherdienst“ etc.) ist Rauschen.
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 15,
                      )),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _loginFields(AppThemeData theme, AppStrings strings) {
    return ProviderLoginFields(
      platform: widget.platform,
      theme: theme,
      strings: strings,
      descriptor: _selectedDescriptor,
      controllers: _fieldControllers,
      obscure: _revealedSecrets,
      onChanged: _markCredentialsDirty,
      onToggleObscure: (key) => setState(() {
        if (_revealedSecrets.contains(key)) {
          _revealedSecrets.remove(key);
        } else {
          _revealedSecrets.add(key);
        }
      }),
      showAdvanced: _showAdvanced,
      onToggleAdvanced: () => setState(() => _showAdvanced = !_showAdvanced),
    );
  }

  /// Erklärbox für Anbieter mit komplexerer Einrichtung (Union, Crypt, S3 …):
  /// Was man braucht, was passiert und wie es funktioniert.
  Widget _setupGuide(AppThemeData theme, AppStrings strings) {
    final descriptor = _selectedDescriptor;
    if (descriptor == null) return const SizedBox.shrink();
    final guide = strings.providerSetupGuide(descriptor.id);
    if (guide == null || guide.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: theme.lg),
      padding: EdgeInsets.all(theme.md),
      decoration: BoxDecoration(
        color: theme.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(theme.radiusSm),
        border: Border.all(color: theme.accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(cupertino.CupertinoIcons.info_circle,
                  size: 16, color: theme.accent),
              SizedBox(width: theme.xs),
              Expanded(
                child: Text(
                  strings.providerGuideHeader,
                  style: TextStyle(
                    color: theme.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: theme.xs),
          Text(
            guide,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _step2Body(AppThemeData theme, AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _selectedProviderDisplay,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        const SizedBox(height: 4),
        Text(
          _nameController.text.trim(),
          style: TextStyle(color: theme.textSecondary, fontSize: 13),
        ),
        SizedBox(height: theme.lg),
        _setupGuide(theme, strings),
        if (_isOAuthProvider) ...[
          Text(strings.oauthInfoNotice,
              style: TextStyle(color: theme.textSecondary, fontSize: 15, height: 1.4)),
          SizedBox(height: theme.md),
          _oauthButton(theme, strings),
          if (_isOAuthAuthorized) ...[
            SizedBox(height: theme.sm),
            Text(strings.authorizedSuccess,
                style: TextStyle(
                    color: theme.success, fontWeight: FontWeight.w600)),
          ],
          if (_oauthError != null) ...[
            SizedBox(height: theme.sm),
            Text(_oauthError!,
                style: TextStyle(color: theme.error, fontSize: 14)),
          ],
        ] else
          _loginFields(theme, strings),
        if (_step2Error != null) ...[
          SizedBox(height: theme.md),
          Text(_step2Error!, style: TextStyle(color: theme.error, fontSize: 14)),
        ],
        SizedBox(height: theme.lg),
        _testButton(theme, strings),
        if (_testStatus != null) ...[
          SizedBox(height: theme.sm),
          Text(
            _testMessage ?? '',
            style: TextStyle(
              color: _testStatus == 'success' ? theme.success : theme.error,
              fontSize: 14,
            ),
          ),
        ],
        if (!_canAdd) ...[
          SizedBox(height: theme.sm),
          Text(
            strings.testRequiredBeforeAddHint,
            style: TextStyle(color: theme.textSecondary, fontSize: 13, height: 1.35),
          ),
        ],
        if (_addError != null) ...[
          SizedBox(height: theme.md),
          Text(_addError!,
              style: TextStyle(color: theme.error, fontSize: 14)),
        ],
      ],
    );
  }

  Widget _oauthButton(AppThemeData theme, AppStrings strings) {
    final label = _isOAuthWorking ? '…' : strings.authorizeInBrowser;
    if (widget.platform == TargetPlatform.iOS) {
      return cupertino.CupertinoButton.filled(
        onPressed: _isOAuthWorking ? null : _handleOAuthAuthorize,
        child: _isOAuthWorking
            ? const cupertino.CupertinoActivityIndicator(
                color: cupertino.CupertinoColors.white)
            : Text(label),
      );
    }
    if (widget.platform == TargetPlatform.windows) {
      return fluent.FilledButton(
        onPressed: _isOAuthWorking ? null : _handleOAuthAuthorize,
        child: Text(label, style: TextStyle(color: theme.accentText)),
      );
    }
    return material.FilledButton.icon(
      icon: const Icon(material.Icons.open_in_browser, size: 18),
      label: Text(label),
      onPressed: _isOAuthWorking ? null : _handleOAuthAuthorize,
    );
  }

  Widget _testButton(AppThemeData theme, AppStrings strings) {
    // Virtuelle Backends (Crypt, Union, …) haben keine klassische Anmeldung —
    // dort heißt die Aktion neutral „Verbindung prüfen“.
    final label = _selectedDescriptor?.authType == AuthType.none
        ? strings.validateSetup
        : strings.testConnection;
    if (widget.platform == TargetPlatform.iOS) {
      return cupertino.CupertinoButton(
        color: theme.accent,
        onPressed: _isTesting || _isAdding ? null : _handleTestConnection,
        child: _isTesting
            ? const cupertino.CupertinoActivityIndicator()
            : Text(label,
                style: const TextStyle(color: Color(0xFFFFFFFF))),
      );
    }
    if (widget.platform == TargetPlatform.windows) {
      return fluent.FilledButton(
        onPressed: _isTesting || _isAdding ? null : _handleTestConnection,
        child: _isTesting
            ? const SizedBox(
                width: 16, height: 16, child: fluent.ProgressRing(strokeWidth: 2))
            : Text(label,
                style: TextStyle(color: theme.accentText)),
      );
    }
    return material.FilledButton(
      onPressed: _isTesting || _isAdding ? null : _handleTestConnection,
      // Kein `const`: theme.accentText ist zur Laufzeit aufgelöst.
      child: _isTesting
          ? SizedBox(
              width: 16,
              height: 16,
              child: material.CircularProgressIndicator(
                  strokeWidth: 2, color: theme.accentText))
          : Text(label),
    );
  }

  Widget _step1Body(AppThemeData theme, AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(strings.connectionNameLabel,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        SizedBox(height: theme.xs),
        _nameField(strings),
        if (_nameError != null) ...[
          SizedBox(height: theme.xs),
          Text(_nameError!, style: TextStyle(color: theme.error, fontSize: 13)),
        ],
        SizedBox(height: theme.lg),
        Text(strings.searchProviderHint,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        SizedBox(height: theme.xs),
        _searchField(theme, strings),
        SizedBox(height: theme.md),
        if (widget.platform == TargetPlatform.iOS)
          _providerList(theme, strings)
        else
          SizedBox(height: 220, child: _providerList(theme, strings)),
        if (_providerError != null) ...[
          SizedBox(height: theme.xs),
          Text(_providerError!,
              style: TextStyle(color: theme.error, fontSize: 13)),
        ],
      ],
    );
  }

  Widget _nameField(AppStrings strings) {
    if (widget.platform == TargetPlatform.iOS) {
      return cupertino.CupertinoTextField(
        controller: _nameController,
        placeholder: strings.connectionNameHint,
        padding: const EdgeInsets.all(12),
        autocorrect: false,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) {
          _nameWasAutoFilled = false;
          if (_nameError != null) setState(() => _nameError = null);
        },
      );
    }
    if (widget.platform == TargetPlatform.windows) {
      return fluent.TextBox(
        controller: _nameController,
        placeholder: strings.connectionNameHint,
        onChanged: (_) {
          _nameWasAutoFilled = false;
          if (_nameError != null) setState(() => _nameError = null);
        },
      );
    }
    return material.TextField(
      controller: _nameController,
      decoration: material.InputDecoration(
        hintText: strings.connectionNameHint,
        border: const material.OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      onChanged: (_) {
        _nameWasAutoFilled = false;
        if (_nameError != null) setState(() => _nameError = null);
      },
    );
  }

  Widget _searchField(AppThemeData theme, AppStrings strings) {
    if (widget.platform == TargetPlatform.iOS) {
      return cupertino.CupertinoSearchTextField(
        controller: _searchController,
        placeholder: strings.searchProviderHint,
        onChanged: (val) => setState(() => _searchQuery = val),
      );
    }
    if (widget.platform == TargetPlatform.windows) {
      return fluent.TextBox(
        controller: _searchController,
        placeholder: strings.searchProviderHint,
        prefix: Padding(
          padding: EdgeInsets.only(left: theme.sm),
          child: Icon(fluent.FluentIcons.search,
              size: 14, color: theme.textSecondary),
        ),
        onChanged: (val) => setState(() => _searchQuery = val),
      );
    }
    return material.TextField(
      controller: _searchController,
      decoration: const material.InputDecoration(
        hintText: '',
        prefixIcon: Icon(material.Icons.search, size: 20),
        border: material.OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      onChanged: (val) => setState(() => _searchQuery = val),
    );
  }

  Widget _buildIOS(AppThemeData theme, AppStrings strings) {
    return cupertino.CupertinoPageScaffold(
      backgroundColor: theme.canvas,
      navigationBar: cupertino.CupertinoNavigationBar(
        backgroundColor: theme.surface,
        middle: Text(_currentStep == 0
            ? strings.wizardStep1Title
            : strings.wizardStep2Title),
        trailing: _isAdding
            ? const cupertino.CupertinoActivityIndicator()
            : cupertino.CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(context),
                child: Text(strings.close),
              ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(theme.lg),
                child: _currentStep == 0
                    ? _step1Body(theme, strings)
                    : _step2Body(theme, strings),
              ),
            ),
            _footer(theme, strings),
          ],
        ),
      ),
    );
  }

  Widget _buildAndroid(AppThemeData theme, AppStrings strings) {
    return material.Scaffold(
      backgroundColor: theme.canvas,
      appBar: material.AppBar(
        backgroundColor: theme.surface,
        elevation: 0,
        title: Text(
          _currentStep == 0
              ? strings.wizardStep1Title
              : strings.wizardStep2Title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: material.IconButton(
          icon: const Icon(material.Icons.close),
          onPressed: _isAdding ? null : () => Navigator.pop(context),
          tooltip: strings.close,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(theme.lg),
                child: _currentStep == 0
                    ? _step1Body(theme, strings)
                    : _step2Body(theme, strings),
              ),
            ),
            const material.Divider(height: 1),
            _footer(theme, strings),
          ],
        ),
      ),
    );
  }

  Widget _buildWindows(AppThemeData theme, AppStrings strings) {
    return fluent.FluentTheme(
      data: fluent.FluentThemeData(
        scaffoldBackgroundColor: theme.canvas,
        cardColor: theme.surface,
      ),
      child: Center(
        child: material.Material(
          color: material.Colors.transparent,
          child: Container(
            width: 540,
            constraints: const BoxConstraints(maxHeight: 660),
            margin: EdgeInsets.all(theme.lg),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(theme.radiusLg),
              border: Border.all(
                  color: theme.textSecondary.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: theme.xl, vertical: theme.lg),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _currentStep == 0
                              ? strings.wizardStep1Title
                              : strings.wizardStep2Title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      fluent.IconButton(
                        icon: Icon(fluent.FluentIcons.chrome_close,
                            size: 14, color: theme.textSecondary),
                        onPressed:
                            _isAdding ? null : () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const material.Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(theme.xl),
                    child: _currentStep == 0
                        ? _step1Body(theme, strings)
                        : _step2Body(theme, strings),
                  ),
                ),
                const material.Divider(height: 1),
                _footer(theme, strings),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _footer(AppThemeData theme, AppStrings strings) {
    final isStep1 = _currentStep == 0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.xl, vertical: theme.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isStep1) ...[
            _secondary(strings.cancel, () => Navigator.pop(context)),
            SizedBox(width: theme.md),
            _primary(strings.next, _goToStep2),
          ] else ...[
            _secondary(
                strings.back,
                _isAdding
                    ? null
                    : () => setState(() => _currentStep = 0)),
            SizedBox(width: theme.md),
            _primary(
              strings.add,
              _isAdding || !_canAdd ? null : _handleAddRemote,
              busy: _isAdding,
            ),
          ],
        ],
      ),
    );
  }

  Widget _secondary(String label, VoidCallback? onPressed) {
    if (widget.platform == TargetPlatform.iOS) {
      return cupertino.CupertinoButton(
          onPressed: onPressed, child: Text(label));
    }
    if (widget.platform == TargetPlatform.windows) {
      return fluent.Button(onPressed: onPressed, child: Text(label));
    }
    return material.TextButton(onPressed: onPressed, child: Text(label));
  }

  Widget _primary(String label, VoidCallback? onPressed, {bool busy = false}) {
    final child = busy
        ? const SizedBox(
            width: 16,
            height: 16,
            child: cupertino.CupertinoActivityIndicator())
        : Text(label);
    if (widget.platform == TargetPlatform.iOS) {
      return cupertino.CupertinoButton.filled(
          onPressed: onPressed, child: child);
    }
    if (widget.platform == TargetPlatform.windows) {
      return fluent.FilledButton(
        onPressed: onPressed,
        child: busy
            ? const SizedBox(
                width: 14, height: 14, child: fluent.ProgressRing(strokeWidth: 2))
            : Text(label,
                style: TextStyle(color: context.theme.accentText)),
      );
    }
    return material.FilledButton(onPressed: onPressed, child: child);
  }
}

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'rclone_provider_registry.dart';

/// Auth-Helfer: echte Provider-Metadaten statt Namens-Heuristik.
///
/// Entscheidet Backend-Typ, Associated-Domain für den Apple-Schlüsselbund,
/// Tastatur/Autofill und die rclone-Config-Map. Niemals den Anzeigenamen
/// erraten — immer [RcloneProviderDescriptor.id].
class ProviderAuth {
  ProviderAuth._();

  /// rclone `config/create` type. Convenience-IDs (`s3-wasabi`) werden
  /// auf das echte Backend (`s3`) gemappt.
  static String rcloneType(String providerId) {
    final id = providerId.trim().toLowerCase();
    if (id.startsWith('s3-')) return 's3';
    if (id == 'gcs') return 'google cloud storage';
    if (id == '1fichier') return 'fichier';
    return id;
  }

  /// Zusätzliche rclone-Keys, die nicht im Formular stehen (S3-Provider-Name).
  static Map<String, String> staticConfig(String providerId) {
    switch (providerId.trim().toLowerCase()) {
      case 's3':
        return const {'provider': 'AWS'};
      case 's3-wasabi':
        return const {'provider': 'Wasabi'};
      case 's3-b2':
        return const {'provider': 'Other'};
      case 's3-r2':
        return const {'provider': 'Cloudflare'};
      case 's3-minio':
        return const {'provider': 'Minio'};
      case 's3-digitalocean':
        return const {'provider': 'DigitalOcean'};
      case 's3-idrive':
        return const {'provider': 'IDrive'};
      case 's3-synology':
        return const {'provider': 'Other'};
      case 's3-ceph':
        return const {'provider': 'Ceph'};
      case 's3-generic':
        return const {'provider': 'Other'};
      default:
        return const {};
    }
  }

  /// Primäre Website-Domain für den Apple-Schlüsselbund / Autofill.
  /// Genau diese Hosts werden als `webcredentials:` gemeldet.
  static String? autofillDomain(String providerId) {
    switch (providerId.trim().toLowerCase()) {
      case 'mega':
        return 'mega.nz';
      case 'drive':
      case 'google photos':
      case 'google_photos':
        return 'drive.google.com';
      case 'gcs':
        return 'accounts.google.com';
      case 'dropbox':
        return 'www.dropbox.com';
      case 'onedrive':
      case 'sharepoint':
        return 'login.live.com';
      case 'box':
        return 'account.box.com';
      case 'pcloud':
        return 'my.pcloud.com';
      case 'yandex':
        return 'passport.yandex.com';
      case 'protondrive':
        return 'proton.me';
      case 'hidrive':
        return 'my.hidrive.com';
      case 'zoho':
        return 'accounts.zoho.com';
      case 'jottacloud':
        return 'id.jottacloud.com';
      case 'koofr':
        return 'app.koofr.net';
      case 'mailru':
        return 'cloud.mail.ru';
      case 'pikpak':
        return 'mypikpak.com';
      case 'opendrive':
        return 'www.opendrive.com';
      case 'sugarsync':
        return 'www.sugarsync.com';
      case 'putio':
        return 'app.put.io';
      case '1fichier':
        return '1fichier.com';
      case 's3':
        return 'console.aws.amazon.com';
      case 's3-wasabi':
        return 'console.wasabisys.com';
      case 's3-b2':
      case 'b2':
        return 'secure.backblaze.com';
      case 's3-r2':
        return 'dash.cloudflare.com';
      case 's3-digitalocean':
        return 'cloud.digitalocean.com';
      case 'azureblob':
      case 'azurefiles':
        return 'portal.azure.com';
      case 'storj':
        return 'www.storj.io';
      default:
        return null;
    }
  }

  /// Alle Associated-Domains, die ins Entitlement gehören (Apex + die
  /// konkreten Login-Hosts, die der Nutzer genannt hat).
  static const List<String> associatedWebcredentialHosts = [
    'mega.nz',
    '*.mega.nz',
    'drive.google.com',
    'accounts.google.com',
    'google.com',
    '*.google.com',
    'www.dropbox.com',
    'dropbox.com',
    '*.dropbox.com',
    'login.live.com',
    'live.com',
    '*.live.com',
    'login.microsoftonline.com',
    'microsoftonline.com',
    '*.microsoftonline.com',
    'my.pcloud.com',
    'pcloud.com',
    '*.pcloud.com',
    'account.box.com',
    'box.com',
    '*.box.com',
    'passport.yandex.com',
    'yandex.com',
    '*.yandex.com',
    'yandex.ru',
    '*.yandex.ru',
    'proton.me',
    '*.proton.me',
    'secure.backblaze.com',
    'backblaze.com',
    '*.backblaze.com',
    'console.wasabisys.com',
    'wasabisys.com',
    '*.wasabisys.com',
    'dash.cloudflare.com',
    'cloudflare.com',
    '*.cloudflare.com',
    'my.hidrive.com',
    'hidrive.com',
    '*.hidrive.com',
    'id.jottacloud.com',
    'jottacloud.com',
    '*.jottacloud.com',
    'app.koofr.net',
    'koofr.net',
    '*.koofr.net',
  ];

  static Iterable<String> autofillHintsFor(ConfigFieldDefinition field) {
    final key = field.key.toLowerCase();
    if (field.isSecret) {
      if (key.contains('2fa') || key == 'otp' || key.contains('code')) {
        return const [AutofillHints.oneTimeCode];
      }
      if (key.contains('key') || key.contains('token') || key.contains('secret')) {
        // API-Schlüssel/Token: kein „neues Passwort“-Angebot, nur ausfüllen.
        return const [AutofillHints.password];
      }
      // Echtes Passwort (pass/password/passphrase): iOS damit einlädt, den
      // Zugang im Schlüsselbund zu SICHERN (finishAutofillContext).
      return const [AutofillHints.newPassword];
    }
    if (key == 'user' ||
        key == 'username' ||
        key == 'email' ||
        key.contains('user')) {
      return const [AutofillHints.username, AutofillHints.email];
    }
    if (key == 'url' || key == 'endpoint' || key == 'auth') {
      return const [AutofillHints.url];
    }
    if (key == 'host' || key == 'namenode') {
      return const [AutofillHints.url];
    }
    if (key == 'port') {
      return const [];
    }
    return const [];
  }

  static TextInputType keyboardFor(ConfigFieldDefinition field) {
    final key = field.key.toLowerCase();
    if (field.isSecret) return TextInputType.visiblePassword;
    if (key == 'port') return TextInputType.number;
    if (key == 'url' || key == 'endpoint' || key == 'auth' || key == 'host') {
      return TextInputType.url;
    }
    if (key.contains('user') || key.contains('email') || key.contains('mail')) {
      return TextInputType.emailAddress;
    }
    return TextInputType.text;
  }

  static TextInputAction actionFor(
    ConfigFieldDefinition field,
    bool isLastVisible,
  ) =>
      isLastVisible ? TextInputAction.done : TextInputAction.next;

  static bool isOAuth(RcloneProviderDescriptor? d) =>
      d != null && d.authType == AuthType.oauth;

  /// Pflichtfelder, die sichtbar und nicht optional sind.
  static List<ConfigFieldDefinition> requiredFields(
    RcloneProviderDescriptor? d,
  ) {
    if (d == null) return const [];
    return d.fields.where((f) => !f.isOptional && !f.isAdvanced).toList();
  }

  static List<ConfigFieldDefinition> visibleFields(
    RcloneProviderDescriptor? d, {
    required bool includeAdvanced,
  }) {
    if (d == null) return const [];
    return d.fields
        .where((f) => includeAdvanced || !f.isAdvanced)
        .toList(growable: false);
  }

  /// Baut die rclone-Config. Geheimnisse werden über [obscure] verdunkelt.
  static Future<Map<String, String>> buildConfig({
    required String providerId,
    required RcloneProviderDescriptor? descriptor,
    required Map<String, String> values,
    required Future<String> Function(String plain) obscure,
    String? oauthToken,
  }) async {
    final config = <String, String>{...staticConfig(providerId)};
    final fields = descriptor?.fields ?? const <ConfigFieldDefinition>[];

    if (fields.isEmpty && !isOAuth(descriptor)) {
      // Fallback für unbekannte Typen: user/pass/host/port.
      final user = values['user']?.trim() ?? '';
      final pass = values['pass'] ?? '';
      final host = values['host']?.trim() ?? '';
      final port = values['port']?.trim() ?? '';
      if (user.isNotEmpty) config['user'] = user;
      if (pass.isNotEmpty) config['pass'] = await obscure(pass);
      if (host.isNotEmpty) config['host'] = host;
      if (port.isNotEmpty) config['port'] = port;
    } else {
      for (final field in fields) {
        final raw = values[field.key] ?? field.defaultValue ?? '';
        final value = raw.trim();
        if (value.isEmpty) continue;
        config[field.key] = field.isSecret ? await obscure(value) : value;
      }
    }

    if (oauthToken != null && oauthToken.isNotEmpty) {
      config['token'] =
          '{"access_token":"$oauthToken","token_type":"Bearer","expiry":"0001-01-01T00:00:00Z"}';
    }
    return config;
  }

  /// null wenn gültig, sonst ein kurzer Hinweis (kein Jargon).
  static String? missingRequired(
    RcloneProviderDescriptor? descriptor,
    Map<String, String> values,
  ) {
    if (isOAuth(descriptor)) return null;
    for (final field in requiredFields(descriptor)) {
      final v = (values[field.key] ?? '').trim();
      if (v.isEmpty) return field.label;
    }
    if (descriptor == null) {
      final user = (values['user'] ?? '').trim();
      final pass = values['pass'] ?? '';
      if (user.isEmpty && pass.isEmpty) return 'user';
    }
    return null;
  }
}

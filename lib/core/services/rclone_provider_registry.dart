import '../localization/locale_provider.dart';
import 'rclone_service.dart';

/// Categories for organizing 70+ rclone providers in a clean, Apple-like UI.
enum ProviderCategory {
  popular,
  cloudStorage,
  s3Compatible,
  enterpriseAndNative,
  protocols,
  virtualAndWrappers,
}

/// Type of authentication required by a provider.
enum AuthType {
  oauth,
  credentials,
  s3,
  protocol,
  keyBased,
  none,
}

/// Wie ein Formularfeld bestehende Cloud-Laufwerke auswählt.
///
/// Statt Freitext „drive1:pfad drive2:pfad“ bekommt der Nutzer eine
/// Multiple-Choice-Liste der bereits verbundenen Laufwerke — der Prozess
/// bleibt so einfach wie möglich.
enum RemotePickerMode {
  /// Kein Remote-Picker (normales Text-/Dropdown-Feld).
  none,

  /// Genau ein verbundenes Laufwerk wählen (Crypt, Alias, Chunker, …).
  single,

  /// Mehrere verbundene Laufwerke wählen (Union, Combine).
  multi,
}

/// Dynamic form field definition for configuring an rclone remote.
///
/// Labels and hints are maintained in German (base) with optional English
/// counterparts; [localizedLabel] / [localizedHint] resolve per locale.
class ConfigFieldDefinition {
  final String key;
  final String label;
  final String labelEn;
  final String hint;
  final String hintEn;
  final bool isSecret;
  final bool isOptional;
  final bool isAdvanced;
  final String? defaultValue;
  final List<String>? dropdownOptions;

  /// Wenn gesetzt: statt Texteingabe eine Auswahl der verbundenen Laufwerke.
  final RemotePickerMode remotePicker;

  const ConfigFieldDefinition({
    required this.key,
    required this.label,
    this.labelEn = '',
    this.hint = '',
    this.hintEn = '',
    this.isSecret = false,
    this.isOptional = false,
    this.isAdvanced = false,
    this.defaultValue,
    this.dropdownOptions,
    this.remotePicker = RemotePickerMode.none,
  });

  /// Field label in the active UI language.
  String localizedLabel(AppLocale locale) =>
      locale == AppLocale.en && labelEn.isNotEmpty ? labelEn : label;

  /// Placeholder/example hint in the active UI language.
  String localizedHint(AppLocale locale) =>
      locale == AppLocale.en && hintEn.isNotEmpty ? hintEn : hint;
}

/// Descriptor providing complete metadata and form fields for an rclone backend.
///
/// [name] / [description] are the German base strings; [nameEn] /
/// [descriptionEn] provide the English UI. Brand names stay identical in
/// both languages unless overridden.
class RcloneProviderDescriptor {
  final String id;
  final String name;
  final String nameEn;
  final String description;
  final String descriptionEn;
  final ProviderCategory category;
  final AuthType authType;
  final bool isPopular;
  final List<ConfigFieldDefinition> fields;

  const RcloneProviderDescriptor({
    required this.id,
    required this.name,
    this.nameEn = '',
    required this.description,
    this.descriptionEn = '',
    required this.category,
    required this.authType,
    this.isPopular = false,
    this.fields = const [],
  });

  /// Provider name in the active UI language.
  String localizedName(AppLocale locale) =>
      locale == AppLocale.en && nameEn.isNotEmpty ? nameEn : name;

  /// Provider description in the active UI language.
  String localizedDescription(AppLocale locale) =>
      locale == AppLocale.en && descriptionEn.isNotEmpty
          ? descriptionEn
          : description;

  RcloneProviderInfo toProviderInfo() => RcloneProviderInfo(
        id: id,
        name: name,
        description: description,
      );
}

/// Central registry of all 70+ rclone storage providers.
class RcloneProviderRegistry {
  static const List<RcloneProviderDescriptor> providers = [
    // --- POPULAR / CONSUMER CLOUD STORAGE ---
    RcloneProviderDescriptor(
      id: 'drive',
      name: 'Google Drive',
      description:
          'Cloud-Speicher von Google. Die Anmeldung erfolgt direkt über Ihr Google-Konto im Browser (OAuth).',
      descriptionEn:
          'Google cloud storage. You sign in with your Google account in the browser (OAuth).',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.oauth,
      isPopular: true,
      fields: [
        ConfigFieldDefinition(
          key: 'client_id',
          label: 'Client ID (optional)',
          labelEn: 'Client ID (optional)',
          hint: 'Eigene Client-ID aus der Google Cloud Console',
          hintEn: 'Your own client ID from the Google Cloud Console',
          isOptional: true,
          isAdvanced: true,
        ),
        ConfigFieldDefinition(
          key: 'client_secret',
          label: 'Client Secret (optional)',
          labelEn: 'Client Secret (optional)',
          hint: 'Passendes Client Secret aus der Google Cloud Console',
          hintEn: 'Matching client secret from the Google Cloud Console',
          isSecret: true,
          isOptional: true,
          isAdvanced: true,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'google photos',
      name: 'Google Photos',
      nameEn: 'Google Photos',
      description:
          'Sicherung Ihrer Google-Fotos-Mediathek. Die Anmeldung erfolgt über Ihr Google-Konto im Browser (OAuth).',
      descriptionEn:
          'Back up your Google Photos library. Sign-in happens with your Google account in the browser (OAuth).',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.oauth,
      isPopular: true,
    ),
    RcloneProviderDescriptor(
      id: 'onedrive',
      name: 'Microsoft OneDrive',
      description:
          'OneDrive und SharePoint von Microsoft. Die Anmeldung erfolgt über Ihr Microsoft-Konto im Browser (OAuth).',
      descriptionEn:
          'Microsoft OneDrive and SharePoint. You sign in with your Microsoft account in the browser (OAuth).',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.oauth,
      isPopular: true,
      fields: [
        ConfigFieldDefinition(
          key: 'drive_type',
          label: 'Laufwerk-Typ',
          labelEn: 'Drive type',
          defaultValue: 'personal',
          dropdownOptions: ['personal', 'business', 'sharepoint'],
          isAdvanced: true,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'dropbox',
      name: 'Dropbox',
      description:
          'Dropbox Cloud-Speicher. Die Anmeldung erfolgt direkt bei Dropbox im Browser (OAuth).',
      descriptionEn:
          'Dropbox cloud storage. You sign in with Dropbox in the browser (OAuth).',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.oauth,
      isPopular: true,
    ),
    RcloneProviderDescriptor(
      id: 'box',
      name: 'Box',
      description:
          'Box.com Cloud-Speicher für Teams und Unternehmen. Anmeldung über Box im Browser (OAuth).',
      descriptionEn:
          'Box.com cloud storage for teams and enterprises. Sign in with Box in the browser (OAuth).',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.oauth,
      isPopular: true,
    ),
    RcloneProviderDescriptor(
      id: 'pcloud',
      name: 'pCloud',
      description:
          'pCloud Cloud-Speicher mit Sitz in der Schweiz/EU. Anmeldung über pCloud im Browser (OAuth).',
      descriptionEn:
          'pCloud cloud storage based in Switzerland/EU. Sign in with pCloud in the browser (OAuth).',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.oauth,
      isPopular: true,
    ),
    RcloneProviderDescriptor(
      id: 'mega',
      name: 'Mega',
      description:
          'MEGA Cloud-Speicher mit Ende-zu-Ende-Verschlüsselung. Anmeldung mit E-Mail-Adresse und Passwort.',
      descriptionEn:
          'MEGA cloud storage with end-to-end encryption. Sign in with email address and password.',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.credentials,
      isPopular: true,
      fields: [
        ConfigFieldDefinition(
          key: 'user',
          label: 'E-Mail-Adresse',
          labelEn: 'Email address',
        ),
        ConfigFieldDefinition(
          key: 'pass',
          label: 'Passwort',
          labelEn: 'Password',
          isSecret: true,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'yandex',
      name: 'Yandex Disk',
      description:
          'Yandex Disk Cloud-Speicher. Anmeldung über Ihr Yandex-Konto im Browser (OAuth).',
      descriptionEn:
          'Yandex Disk cloud storage. Sign in with your Yandex account in the browser (OAuth).',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.oauth,
    ),
    RcloneProviderDescriptor(
      id: 'hidrive',
      name: 'STRATO HiDrive',
      description:
          'STRATO HiDrive Cloud-Speicher aus Deutschland. Anmeldung über STRATO im Browser (OAuth).',
      descriptionEn:
          'STRATO HiDrive cloud storage from Germany. Sign in with STRATO in the browser (OAuth).',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.oauth,
    ),
    RcloneProviderDescriptor(
      id: 'zoho',
      name: 'Zoho WorkDrive',
      description:
          'Zoho WorkDrive Team-Speicher. Anmeldung über Ihr Zoho-Konto im Browser (OAuth).',
      descriptionEn:
          'Zoho WorkDrive team storage. Sign in with your Zoho account in the browser (OAuth).',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.oauth,
    ),
    RcloneProviderDescriptor(
      id: 'protondrive',
      name: 'Proton Drive',
      description:
          'Proton Drive mit Ende-zu-Ende-Verschlüsselung. Anmeldung mit Benutzername und Passwort.',
      descriptionEn:
          'Proton Drive with end-to-end encryption. Sign in with username and password.',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(
          key: 'username',
          label: 'Benutzername / E-Mail',
          labelEn: 'Username / email',
        ),
        ConfigFieldDefinition(
          key: 'password',
          label: 'Passwort',
          labelEn: 'Password',
          isSecret: true,
        ),
        ConfigFieldDefinition(
          key: '2fa',
          label: '2FA-Code (falls aktiv)',
          labelEn: '2FA code (if enabled)',
          isOptional: true,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'pikpak',
      name: 'PikPak',
      description:
          'PikPak Cloud-Drive. Anmeldung mit E-Mail-Adresse oder Telefonnummer und Passwort.',
      descriptionEn:
          'PikPak cloud drive. Sign in with email address or phone number and password.',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(
          key: 'user',
          label: 'E-Mail / Telefonnummer',
          labelEn: 'Email / phone number',
        ),
        ConfigFieldDefinition(
          key: 'pass',
          label: 'Passwort',
          labelEn: 'Password',
          isSecret: true,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'putio',
      name: 'Put.io',
      description:
          'Put.io Cloud-Speicher und Downloader. Anmeldung über Put.io im Browser (OAuth).',
      descriptionEn:
          'Put.io cloud storage and downloader. Sign in with Put.io in the browser (OAuth).',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.oauth,
    ),
    RcloneProviderDescriptor(
      id: 'mailru',
      name: 'Mail.ru Cloud',
      description:
          'Mail.ru Cloud-Speicher. Anmeldung mit E-Mail-Adresse und App-Passwort.',
      descriptionEn:
          'Mail.ru cloud storage. Sign in with email address and app password.',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(
          key: 'user',
          label: 'E-Mail-Adresse',
          labelEn: 'Email address',
        ),
        ConfigFieldDefinition(
          key: 'pass',
          label: 'App-Passwort',
          labelEn: 'App password',
          isSecret: true,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'jottacloud',
      name: 'Jottacloud',
      description:
          'Jottacloud Backup-Speicher aus Norwegen. Anmeldung über Jottacloud im Browser (OAuth).',
      descriptionEn:
          'Jottacloud backup storage from Norway. Sign in with Jottacloud in the browser (OAuth).',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.oauth,
    ),
    RcloneProviderDescriptor(
      id: 'koofr',
      name: 'Koofr',
      description:
          'Koofr EU-Cloud-Speicher. Anmeldung mit E-Mail-Adresse und App-Passwort.',
      descriptionEn:
          'Koofr EU cloud storage. Sign in with email address and app password.',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(
          key: 'user',
          label: 'E-Mail-Adresse',
          labelEn: 'Email address',
        ),
        ConfigFieldDefinition(
          key: 'password',
          label: 'App-Passwort',
          labelEn: 'App password',
          isSecret: true,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'opendrive',
      name: 'OpenDrive',
      description:
          'OpenDrive Cloud-Speicher. Anmeldung mit E-Mail-Adresse und Passwort.',
      descriptionEn:
          'OpenDrive cloud storage. Sign in with email address and password.',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(
          key: 'username',
          label: 'E-Mail-Adresse',
          labelEn: 'Email address',
        ),
        ConfigFieldDefinition(
          key: 'password',
          label: 'Passwort',
          labelEn: 'Password',
          isSecret: true,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'sugarsync',
      name: 'SugarSync',
      description:
          'SugarSync Cloud-Backup. Die Anmeldung erfolgt mit Entwickler-Zugangsdaten (App-ID und Access Key).',
      descriptionEn:
          'SugarSync cloud backup. Sign-in uses developer credentials (App ID and access key).',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(
          key: 'app_id',
          label: 'App ID',
          hint: 'Von SugarSync unter „Developer“ anfordern',
          hintEn: 'Request from SugarSync under “Developer”',
        ),
        ConfigFieldDefinition(
          key: 'access_key_id',
          label: 'Access Key ID',
          labelEn: 'Access Key ID',
          hint: 'Zusammen mit der App ID ausgestellt',
          hintEn: 'Issued together with the App ID',
        ),
        ConfigFieldDefinition(
          key: 'refresh_token',
          label: 'Refresh Token (optional)',
          labelEn: 'Refresh token (optional)',
          isOptional: true,
          isAdvanced: true,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: '1fichier',
      name: '1Fichier',
      description:
          '1Fichier Cloud-Speicher. Anmeldung mit einem persönlichen API-Schlüssel.',
      descriptionEn:
          '1Fichier cloud storage. Sign in with a personal API key.',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(
          key: 'api_key',
          label: 'API-Schlüssel',
          labelEn: 'API key',
          isSecret: true,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'uptobox',
      name: 'Uptobox',
      description:
          'Uptobox Cloud-Speicher. Anmeldung mit Ihrem persönlichen Benutzer-Token.',
      descriptionEn:
          'Uptobox cloud storage. Sign in with your personal user token.',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(
          key: 'access_token',
          label: 'Benutzer-Token',
          labelEn: 'User token',
          isSecret: true,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'quatrix',
      name: 'Quatrix',
      description:
          'Quatrix Enterprise-Cloud. Anmeldung mit API-Schlüssel und Instanz-Hostname.',
      descriptionEn:
          'Quatrix enterprise cloud. Sign in with API key and instance hostname.',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(
          key: 'api_key',
          label: 'API-Schlüssel',
          labelEn: 'API key',
          isSecret: true,
        ),
        ConfigFieldDefinition(
          key: 'host',
          label: 'Quatrix-Hostname',
          labelEn: 'Quatrix hostname',
          hint: 'firma.quatrix.it',
          hintEn: 'company.quatrix.it',
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'seafile',
      name: 'Seafile',
      description:
          'Seafile Private-Cloud-Server. Anmeldung mit Server-URL und Ihren Zugangsdaten.',
      descriptionEn:
          'Seafile private cloud server. Sign in with the server URL and your credentials.',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(
          key: 'url',
          label: 'Server-URL',
          labelEn: 'Server URL',
          hint: 'https://seafile.example.com',
        ),
        ConfigFieldDefinition(
          key: 'user',
          label: 'Benutzername / E-Mail',
          labelEn: 'Username / email',
        ),
        ConfigFieldDefinition(
          key: 'pass',
          label: 'Passwort / API-Token',
          labelEn: 'Password / API token',
          isSecret: true,
        ),
      ],
    ),

    // --- S3-COMPATIBLE SERVICES & OBJECT STORAGE ---
    RcloneProviderDescriptor(
      id: 's3',
      name: 'Amazon S3',
      description:
          'Amazon Simple Storage Service (S3). Anmeldung mit Access Key ID und Secret Access Key aus AWS IAM.',
      descriptionEn:
          'Amazon Simple Storage Service (S3). Sign in with Access Key ID and Secret Access Key from AWS IAM.',
      category: ProviderCategory.s3Compatible,
      authType: AuthType.s3,
      isPopular: true,
      fields: [
        ConfigFieldDefinition(
          key: 'access_key_id',
          label: 'AWS Access Key ID',
          labelEn: 'AWS Access Key ID',
        ),
        ConfigFieldDefinition(
          key: 'secret_access_key',
          label: 'AWS Secret Access Key',
          labelEn: 'AWS Secret Access Key',
          isSecret: true,
        ),
        ConfigFieldDefinition(
          key: 'region',
          label: 'Region',
          labelEn: 'Region',
          hint: 'eu-central-1',
          defaultValue: 'eu-central-1',
        ),
        ConfigFieldDefinition(
          key: 'endpoint',
          label: 'Benutzerdefinierter Endpoint (optional)',
          labelEn: 'Custom endpoint (optional)',
          isOptional: true,
          isAdvanced: true,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 's3-wasabi',
      name: 'Wasabi Hot Cloud Storage',
      description:
          'Wasabi Objektspeicher (S3-kompatibel). Anmeldung mit Wasabi Access Key und Secret Key.',
      descriptionEn:
          'Wasabi object storage (S3-compatible). Sign in with Wasabi access key and secret key.',
      category: ProviderCategory.s3Compatible,
      authType: AuthType.s3,
      isPopular: true,
      fields: [
        ConfigFieldDefinition(
          key: 'access_key_id',
          label: 'Wasabi Access Key',
          labelEn: 'Wasabi access key',
        ),
        ConfigFieldDefinition(
          key: 'secret_access_key',
          label: 'Wasabi Secret Key',
          labelEn: 'Wasabi secret key',
          isSecret: true,
        ),
        ConfigFieldDefinition(
          key: 'endpoint',
          label: 'Endpoint',
          labelEn: 'Endpoint',
          defaultValue: 's3.eu-central-1.wasabisys.com',
        ),
        ConfigFieldDefinition(
          key: 'region',
          label: 'Region',
          labelEn: 'Region',
          defaultValue: 'eu-central-1',
          isAdvanced: true,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 's3-b2',
      name: 'Backblaze B2 (S3 API)',
      nameEn: 'Backblaze B2 (S3 API)',
      description:
          'Backblaze B2 über die S3-Schnittstelle. Anmeldung mit Application Key ID und Application Key.',
      descriptionEn:
          'Backblaze B2 via the S3 interface. Sign in with Application Key ID and Application Key.',
      category: ProviderCategory.s3Compatible,
      authType: AuthType.s3,
      isPopular: true,
      fields: [
        ConfigFieldDefinition(
          key: 'access_key_id',
          label: 'Key ID',
          labelEn: 'Key ID',
        ),
        ConfigFieldDefinition(
          key: 'secret_access_key',
          label: 'Application Key',
          labelEn: 'Application Key',
          isSecret: true,
        ),
        ConfigFieldDefinition(
          key: 'endpoint',
          label: 'S3-Endpoint',
          labelEn: 'S3 endpoint',
          hint: 's3.eu-central-003.backblazeb2.com',
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 's3-r2',
      name: 'Cloudflare R2',
      description:
          'Cloudflare R2 Objektspeicher ohne Egress-Gebühren. Anmeldung mit R2 Access Key ID und Secret.',
      descriptionEn:
          'Cloudflare R2 object storage with zero egress fees. Sign in with R2 Access Key ID and secret.',
      category: ProviderCategory.s3Compatible,
      authType: AuthType.s3,
      isPopular: true,
      fields: [
        ConfigFieldDefinition(
          key: 'access_key_id',
          label: 'R2 Access Key ID',
          labelEn: 'R2 Access Key ID',
        ),
        ConfigFieldDefinition(
          key: 'secret_access_key',
          label: 'R2 Secret Access Key',
          labelEn: 'R2 Secret Access Key',
          isSecret: true,
        ),
        ConfigFieldDefinition(
          key: 'endpoint',
          label: 'R2 S3-API-Endpoint',
          labelEn: 'R2 S3 API endpoint',
          hint: 'https://<ACCOUNT_ID>.r2.cloudflarestorage.com',
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 's3-minio',
      name: 'MinIO',
      description:
          'MinIO Self-Hosted S3-Objektspeicher. Anmeldung mit Server-URL und MinIO-Zugangsdaten.',
      descriptionEn:
          'MinIO self-hosted S3 object storage. Sign in with server URL and MinIO credentials.',
      category: ProviderCategory.s3Compatible,
      authType: AuthType.s3,
      fields: [
        ConfigFieldDefinition(
          key: 'endpoint',
          label: 'MinIO Server-URL',
          labelEn: 'MinIO server URL',
          hint: 'https://minio.lan:9000',
        ),
        ConfigFieldDefinition(
          key: 'access_key_id',
          label: 'MinIO Access Key',
          labelEn: 'MinIO access key',
        ),
        ConfigFieldDefinition(
          key: 'secret_access_key',
          label: 'MinIO Secret Key',
          labelEn: 'MinIO secret key',
          isSecret: true,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 's3-digitalocean',
      name: 'DigitalOcean Spaces',
      description:
          'DigitalOcean Spaces Objektspeicher. Anmeldung mit Spaces Access Key und Secret Key.',
      descriptionEn:
          'DigitalOcean Spaces object storage. Sign in with Spaces access key and secret key.',
      category: ProviderCategory.s3Compatible,
      authType: AuthType.s3,
      fields: [
        ConfigFieldDefinition(
          key: 'access_key_id',
          label: 'Spaces Access Key',
          labelEn: 'Spaces access key',
        ),
        ConfigFieldDefinition(
          key: 'secret_access_key',
          label: 'Spaces Secret Key',
          labelEn: 'Spaces secret key',
          isSecret: true,
        ),
        ConfigFieldDefinition(
          key: 'endpoint',
          label: 'Endpoint',
          labelEn: 'Endpoint',
          hint: 'fra1.digitaloceanspaces.com',
          defaultValue: 'fra1.digitaloceanspaces.com',
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 's3-idrive',
      name: 'IDrive e2',
      description:
          'IDrive e2 S3-kompatibler Cloud-Speicher. Anmeldung mit Access Key ID und Secret Access Key.',
      descriptionEn:
          'IDrive e2 S3-compatible cloud storage. Sign in with Access Key ID and Secret Access Key.',
      category: ProviderCategory.s3Compatible,
      authType: AuthType.s3,
      fields: [
        ConfigFieldDefinition(
          key: 'access_key_id',
          label: 'Access Key ID',
          labelEn: 'Access Key ID',
        ),
        ConfigFieldDefinition(
          key: 'secret_access_key',
          label: 'Secret Access Key',
          labelEn: 'Secret Access Key',
          isSecret: true,
        ),
        ConfigFieldDefinition(
          key: 'endpoint',
          label: 'S3-Endpoint-URL',
          labelEn: 'S3 endpoint URL',
          hint: 'https://xxx.fra.idrivee2-XX.com',
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 's3-synology',
      name: 'Synology C2 Storage',
      description:
          'Synology C2 Objektspeicher (S3-API). Anmeldung mit C2 Access Key ID und Secret Key.',
      descriptionEn:
          'Synology C2 object storage (S3 API). Sign in with C2 Access Key ID and secret key.',
      category: ProviderCategory.s3Compatible,
      authType: AuthType.s3,
      fields: [
        ConfigFieldDefinition(
          key: 'access_key_id',
          label: 'C2 Access Key ID',
          labelEn: 'C2 Access Key ID',
        ),
        ConfigFieldDefinition(
          key: 'secret_access_key',
          label: 'C2 Secret Key',
          labelEn: 'C2 secret key',
          isSecret: true,
        ),
        ConfigFieldDefinition(
          key: 'endpoint',
          label: 'C2 S3-Endpoint',
          labelEn: 'C2 S3 endpoint',
          hint: 'https://eu-002.s3.synologyc2.net',
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 's3-ceph',
      name: 'Ceph Object Gateway',
      nameEn: 'Ceph Object Gateway',
      description:
          'Ceph RADOS Gateway (S3-kompatibel). Anmeldung mit Endpoint sowie Access Key und Secret Key.',
      descriptionEn:
          'Ceph RADOS Gateway (S3-compatible). Sign in with endpoint plus access key and secret key.',
      category: ProviderCategory.s3Compatible,
      authType: AuthType.s3,
      fields: [
        ConfigFieldDefinition(
          key: 'endpoint',
          label: 'Ceph S3-Endpoint',
          labelEn: 'Ceph S3 endpoint',
        ),
        ConfigFieldDefinition(
          key: 'access_key_id',
          label: 'Access Key',
          labelEn: 'Access key',
        ),
        ConfigFieldDefinition(
          key: 'secret_access_key',
          label: 'Secret Key',
          labelEn: 'Secret key',
          isSecret: true,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 's3-generic',
      name: 'Generischer S3-Speicher',
      nameEn: 'Generic S3 Storage',
      description:
          'Beliebiger S3-kompatibler Objektspeicher. Anmeldung mit Endpoint, Access Key ID und Secret Access Key.',
      descriptionEn:
          'Any S3-compatible object storage. Sign in with endpoint, Access Key ID and Secret Access Key.',
      category: ProviderCategory.s3Compatible,
      authType: AuthType.s3,
      fields: [
        ConfigFieldDefinition(
          key: 'endpoint',
          label: 'S3-Endpoint-URL',
          labelEn: 'S3 endpoint URL',
          hint: 'https://s3.example.com',
        ),
        ConfigFieldDefinition(
          key: 'access_key_id',
          label: 'Access Key ID',
          labelEn: 'Access Key ID',
        ),
        ConfigFieldDefinition(
          key: 'secret_access_key',
          label: 'Secret Access Key',
          labelEn: 'Secret Access Key',
          isSecret: true,
        ),
        ConfigFieldDefinition(
          key: 'region',
          label: 'Region (optional)',
          labelEn: 'Region (optional)',
          isOptional: true,
          isAdvanced: true,
        ),
      ],
    ),

    // --- NATIVE ENTERPRISE & CLOUD APIS ---
    RcloneProviderDescriptor(
      id: 'b2',
      name: 'Backblaze B2 (Nativ)',
      nameEn: 'Backblaze B2 (Native)',
      description:
          'Backblaze B2 über die native API. Anmeldung mit Account-ID und Application Key.',
      descriptionEn:
          'Backblaze B2 via the native API. Sign in with account ID and application key.',
      category: ProviderCategory.enterpriseAndNative,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(
          key: 'account',
          label: 'Account ID / Key ID',
          labelEn: 'Account ID / Key ID',
        ),
        ConfigFieldDefinition(
          key: 'key',
          label: 'Application Key',
          labelEn: 'Application Key',
          isSecret: true,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'gcs',
      name: 'Google Cloud Storage (GCS)',
      description:
          'Google Cloud Storage Buckets. Anmeldung über Ihr Google-Konto im Browser (OAuth).',
      descriptionEn:
          'Google Cloud Storage buckets. Sign in with your Google account in the browser (OAuth).',
      category: ProviderCategory.enterpriseAndNative,
      authType: AuthType.oauth,
      fields: [
        ConfigFieldDefinition(
          key: 'project_number',
          label: 'GCP-Projektnummer (optional)',
          labelEn: 'GCP project number (optional)',
          isOptional: true,
        ),
        ConfigFieldDefinition(
          key: 'service_account_file',
          label: 'Service-Account-JSON-Pfad (optional)',
          labelEn: 'Service account JSON path (optional)',
          isOptional: true,
          isAdvanced: true,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'azureblob',
      name: 'Microsoft Azure Blob Storage',
      description:
          'Azure Blob Storage. Anmeldung mit Storage-Account-Name und Account Key (oder SAS-Token).',
      descriptionEn:
          'Azure Blob Storage. Sign in with storage account name and account key (or SAS token).',
      category: ProviderCategory.enterpriseAndNative,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(
          key: 'account',
          label: 'Storage Account Name',
          labelEn: 'Storage account name',
        ),
        ConfigFieldDefinition(
          key: 'key',
          label: 'Account Key oder SAS-Token',
          labelEn: 'Account key or SAS token',
          isSecret: true,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'azurefiles',
      name: 'Microsoft Azure Files',
      description:
          'Azure Managed File Shares. Anmeldung mit Storage-Account-Name und Account Key.',
      descriptionEn:
          'Azure managed file shares. Sign in with storage account name and account key.',
      category: ProviderCategory.enterpriseAndNative,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(
          key: 'account',
          label: 'Storage Account Name',
          labelEn: 'Storage account name',
        ),
        ConfigFieldDefinition(
          key: 'key',
          label: 'Account Key',
          labelEn: 'Account key',
          isSecret: true,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'storj',
      name: 'Storj DCS',
      description:
          'Storj dezentraler Cloud-Speicher. Anmeldung mit API-Key und Verschlüsselungs-Passphrase.',
      descriptionEn:
          'Storj decentralized cloud storage. Sign in with API key and encryption passphrase.',
      category: ProviderCategory.enterpriseAndNative,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(
          key: 'api_key',
          label: 'Storj API-Key',
          labelEn: 'Storj API key',
          isSecret: true,
        ),
        ConfigFieldDefinition(
          key: 'passphrase',
          label: 'Verschlüsselungs-Passphrase',
          labelEn: 'Encryption passphrase',
          isSecret: true,
        ),
        ConfigFieldDefinition(
          key: 'satellite_address',
          label: 'Satellite-Adresse (optional)',
          labelEn: 'Satellite address (optional)',
          defaultValue: 'us1.storj.io:7777',
          isAdvanced: true,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'swift',
      name: 'OpenStack Swift',
      description:
          'OpenStack Swift Objektspeicher. Anmeldung mit Auth-URL, Benutzername und API-Key.',
      descriptionEn:
          'OpenStack Swift object storage. Sign in with auth URL, username and API key.',
      category: ProviderCategory.enterpriseAndNative,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(
          key: 'user',
          label: 'Benutzername',
          labelEn: 'Username',
        ),
        ConfigFieldDefinition(
          key: 'key',
          label: 'API-Key / Passwort',
          labelEn: 'API key / password',
          isSecret: true,
        ),
        ConfigFieldDefinition(
          key: 'auth',
          label: 'Auth-URL',
          labelEn: 'Auth URL',
          hint: 'https://identity.example.com/v3',
        ),
        ConfigFieldDefinition(
          key: 'tenant',
          label: 'Tenant-Name (optional)',
          labelEn: 'Tenant name (optional)',
          isOptional: true,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'qingstor',
      name: 'QingStor',
      description:
          'QingStor Objektspeicher. Anmeldung mit Access Key ID, Secret Access Key und Zone.',
      descriptionEn:
          'QingStor object storage. Sign in with Access Key ID, Secret Access Key and zone.',
      category: ProviderCategory.enterpriseAndNative,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(
          key: 'access_key_id',
          label: 'Access Key ID',
          labelEn: 'Access Key ID',
        ),
        ConfigFieldDefinition(
          key: 'secret_access_key',
          label: 'Secret Access Key',
          labelEn: 'Secret Access Key',
          isSecret: true,
        ),
        ConfigFieldDefinition(
          key: 'zone',
          label: 'Zone',
          labelEn: 'Zone',
          defaultValue: 'pek3a',
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'internetarchive',
      name: 'Internet Archive',
      description:
          'Internet Archive über das S3-Gateway. Anmeldung mit Ihren S3-Zugangsdaten von archive.org.',
      descriptionEn:
          'Internet Archive via its S3 gateway. Sign in with your S3 credentials from archive.org.',
      category: ProviderCategory.enterpriseAndNative,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(
          key: 'access_key_id',
          label: 'IA S3 Access Key',
          labelEn: 'IA S3 access key',
        ),
        ConfigFieldDefinition(
          key: 'secret_access_key',
          label: 'IA S3 Secret Key',
          labelEn: 'IA S3 secret key',
          isSecret: true,
        ),
      ],
    ),

    // --- STANDARD PROTOCOLS & SERVERS ---
    RcloneProviderDescriptor(
      id: 'webdav',
      name: 'WebDAV (Nextcloud / ownCloud / NAS)',
      description:
          'WebDAV-Server: Nextcloud, ownCloud, Synology u. a. Anmeldung mit Server-URL und Zugangsdaten.',
      descriptionEn:
          'WebDAV servers: Nextcloud, ownCloud, Synology and more. Sign in with server URL and credentials.',
      category: ProviderCategory.protocols,
      authType: AuthType.protocol,
      isPopular: true,
      fields: [
        ConfigFieldDefinition(
          key: 'url',
          label: 'WebDAV-URL',
          labelEn: 'WebDAV URL',
          hint: 'https://cloud.example.com/remote.php/dav/files/user/',
        ),
        ConfigFieldDefinition(
          key: 'vendor',
          label: 'Server-Typ',
          labelEn: 'Server type',
          defaultValue: 'nextcloud',
          dropdownOptions: ['nextcloud', 'owncloud', 'synology', 'fastmail', 'other'],
        ),
        ConfigFieldDefinition(
          key: 'user',
          label: 'Benutzername',
          labelEn: 'Username',
        ),
        ConfigFieldDefinition(
          key: 'pass',
          label: 'Passwort / App-Token',
          labelEn: 'Password / app token',
          isSecret: true,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'sftp',
      name: 'SFTP (SSH File Transfer)',
      description:
          'Sichere Dateiübertragung per SSH – für Linux-Server und NAS-Systeme. Anmeldung mit Passwort oder SSH-Schlüssel.',
      descriptionEn:
          'Secure file transfer over SSH – for Linux servers and NAS systems. Sign in with password or SSH key.',
      category: ProviderCategory.protocols,
      authType: AuthType.protocol,
      isPopular: true,
      fields: [
        ConfigFieldDefinition(
          key: 'host',
          label: 'Server-Host / IP',
          labelEn: 'Server host / IP',
          hint: 'server.example.com',
        ),
        ConfigFieldDefinition(
          key: 'port',
          label: 'SSH-Port',
          labelEn: 'SSH port',
          defaultValue: '22',
        ),
        ConfigFieldDefinition(
          key: 'user',
          label: 'SSH-Benutzername',
          labelEn: 'SSH username',
        ),
        ConfigFieldDefinition(
          key: 'pass',
          label: 'SSH-Passwort (optional bei Schlüssel)',
          labelEn: 'SSH password (optional when using a key)',
          isSecret: true,
          isOptional: true,
        ),
        ConfigFieldDefinition(
          key: 'key_file',
          label: 'Pfad zum privaten SSH-Key (optional)',
          labelEn: 'Path to private SSH key (optional)',
          isOptional: true,
          isAdvanced: true,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'ftp',
      name: 'FTP / FTPS',
      description:
          'Klassisches File Transfer Protocol, auf Wunsch verschlüsselt (FTPS/TLS).',
      descriptionEn:
          'Classic File Transfer Protocol, optionally encrypted (FTPS/TLS).',
      category: ProviderCategory.protocols,
      authType: AuthType.protocol,
      fields: [
        ConfigFieldDefinition(
          key: 'host',
          label: 'FTP-Hostname / IP',
          labelEn: 'FTP hostname / IP',
        ),
        ConfigFieldDefinition(
          key: 'port',
          label: 'Port',
          labelEn: 'Port',
          defaultValue: '21',
        ),
        ConfigFieldDefinition(
          key: 'user',
          label: 'Benutzername',
          labelEn: 'Username',
        ),
        ConfigFieldDefinition(
          key: 'pass',
          label: 'Passwort',
          labelEn: 'Password',
          isSecret: true,
        ),
        ConfigFieldDefinition(
          // rclone-Key für explizites FTPS ist `explicit_tls` (nicht `tls`,
          // das wäre implizites FTPS) — passende Konfiguration zur Beschriftung.
          key: 'explicit_tls',
          label: 'Explizites FTPS (TLS) verwenden',
          labelEn: 'Use explicit FTPS (TLS)',
          defaultValue: 'true',
          dropdownOptions: ['true', 'false'],
          isAdvanced: true,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'smb',
      name: 'SMB / CIFS (Windows-Freigabe)',
      nameEn: 'SMB / CIFS (Windows Share)',
      description:
          'Windows-Netzwerkfreigaben und Samba-NAS. Anmeldung mit Host, Benutzername und Passwort.',
      descriptionEn:
          'Windows network shares and Samba NAS. Sign in with host, username and password.',
      category: ProviderCategory.protocols,
      authType: AuthType.protocol,
      fields: [
        ConfigFieldDefinition(
          key: 'host',
          label: 'Server-Host / IP',
          labelEn: 'Server host / IP',
        ),
        ConfigFieldDefinition(
          key: 'user',
          label: 'Benutzername',
          labelEn: 'Username',
        ),
        ConfigFieldDefinition(
          key: 'pass',
          label: 'Passwort',
          labelEn: 'Password',
          isSecret: true,
        ),
        ConfigFieldDefinition(
          key: 'domain',
          label: 'Windows-Domäne (optional)',
          labelEn: 'Windows domain (optional)',
          isOptional: true,
          isAdvanced: true,
        ),
        ConfigFieldDefinition(
          key: 'port',
          label: 'Port',
          labelEn: 'Port',
          defaultValue: '445',
          isAdvanced: true,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'http',
      name: 'HTTP / HTTPS (Nur Lesen)',
      nameEn: 'HTTP / HTTPS (Read-Only)',
      description:
          'Öffentlicher Web-Ordner, schreibgeschützt. Ideal zum Durchsuchen und Herunterladen.',
      descriptionEn:
          'Public web folder, read-only. Ideal for browsing and downloading.',
      category: ProviderCategory.protocols,
      authType: AuthType.protocol,
      fields: [
        ConfigFieldDefinition(
          key: 'url',
          label: 'HTTP-Ordner-URL',
          labelEn: 'HTTP folder URL',
          hint: 'https://files.example.com/data/',
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'hdfs',
      name: 'Hadoop HDFS',
      description:
          'Hadoop Distributed File System. Anmeldung mit NameNode-Adresse und Hadoop-Benutzer.',
      descriptionEn:
          'Hadoop Distributed File System. Sign in with NameNode address and Hadoop user.',
      category: ProviderCategory.protocols,
      authType: AuthType.protocol,
      fields: [
        ConfigFieldDefinition(
          key: 'namenode',
          label: 'NameNode Host:Port',
          labelEn: 'NameNode host:port',
          hint: 'hdfs.cluster.lan:8020',
        ),
        ConfigFieldDefinition(
          key: 'username',
          label: 'Hadoop-Benutzer',
          labelEn: 'Hadoop user',
        ),
      ],
    ),

    // --- VIRTUAL BACKENDS & ENCRYPTION WRAPPERS ---
    RcloneProviderDescriptor(
      id: 'crypt',
      name: 'Verschlüsselter Tresor (Crypt)',
      nameEn: 'Encrypted Vault (Crypt)',
      description:
          'Transparente Ende-zu-Ende-Verschlüsselung über einem beliebigen Cloud-Laufwerk.',
      descriptionEn:
          'Transparent end-to-end encryption on top of any cloud drive.',
      category: ProviderCategory.virtualAndWrappers,
      authType: AuthType.none,
      isPopular: true,
      fields: [
        ConfigFieldDefinition(
          key: 'remote',
          label: 'Basis-Laufwerk',
          labelEn: 'Base drive',
          hint: 'Bereits verbundenes Cloud-Laufwerk wählen',
          hintEn: 'Pick an already connected cloud drive',
          remotePicker: RemotePickerMode.single,
        ),
        ConfigFieldDefinition(
          key: 'password',
          label: 'Hauptpasswort für Verschlüsselung',
          labelEn: 'Master encryption password',
          isSecret: true,
        ),
        ConfigFieldDefinition(
          key: 'password2',
          label: 'Dateinamen-Salt (optional)',
          labelEn: 'Filename salt (optional)',
          isSecret: true,
          isOptional: true,
          isAdvanced: true,
        ),
        ConfigFieldDefinition(
          key: 'filename_encryption',
          label: 'Dateinamen-Verschlüsselung',
          labelEn: 'Filename encryption',
          defaultValue: 'standard',
          dropdownOptions: ['standard', 'obfuscate', 'off'],
          isAdvanced: true,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'chunker',
      name: 'Große Dateien aufteilen (Chunker)',
      nameEn: 'Split Large Files (Chunker)',
      description:
          'Teilt große Dateien automatisch in Blöcke auf – sinnvoll bei Clouds mit Größenlimit.',
      descriptionEn:
          'Automatically splits large files into chunks – useful for clouds with size limits.',
      category: ProviderCategory.virtualAndWrappers,
      authType: AuthType.none,
      fields: [
        ConfigFieldDefinition(
          key: 'remote',
          label: 'Basis-Laufwerk',
          labelEn: 'Base drive',
          hint: 'Bereits verbundenes Cloud-Laufwerk wählen',
          hintEn: 'Pick an already connected cloud drive',
          remotePicker: RemotePickerMode.single,
        ),
        ConfigFieldDefinition(
          key: 'chunk_size',
          label: 'Chunk-Größe',
          labelEn: 'Chunk size',
          defaultValue: '2G',
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'union',
      name: 'Speicher-Pool (Union)',
      nameEn: 'Storage Pool (Union)',
      description:
          'Fasst mehrere Cloud-Laufwerke zu einem gemeinsamen virtuellen Speicher zusammen.',
      descriptionEn:
          'Pools multiple cloud drives into one combined virtual storage.',
      category: ProviderCategory.virtualAndWrappers,
      authType: AuthType.none,
      fields: [
        ConfigFieldDefinition(
          key: 'remotes',
          label: 'Verknüpfte Laufwerke',
          labelEn: 'Linked drives',
          hint: 'Mindestens zwei bereits verbundene Laufwerke auswählen',
          hintEn: 'Select at least two already connected drives',
          remotePicker: RemotePickerMode.multi,
        ),
        ConfigFieldDefinition(
          key: 'action_policy',
          label: 'Schreib-Strategie',
          labelEn: 'Write policy',
          defaultValue: 'epall',
          dropdownOptions: ['epall', 'lfs', 'rand'],
          isAdvanced: true,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'combine',
      name: 'Ordner bündeln (Combine)',
      nameEn: 'Combine Folders (Combine)',
      description:
          'Blendet Ordner verschiedener Cloud-Laufwerke als Unterordner eines virtuellen Laufwerks ein.',
      descriptionEn:
          'Merges folders from different cloud drives as subfolders of one virtual drive.',
      category: ProviderCategory.virtualAndWrappers,
      authType: AuthType.none,
      fields: [
        ConfigFieldDefinition(
          key: 'upstreams',
          label: 'Verknüpfte Laufwerke',
          labelEn: 'Linked drives',
          hint: 'Bereits verbundene Laufwerke auswählen',
          hintEn: 'Select already connected drives',
          remotePicker: RemotePickerMode.multi,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'alias',
      name: 'Laufwerk-Verknüpfung (Alias)',
      nameEn: 'Drive Shortcut (Alias)',
      description:
          'Erstellt eine Verknüpfung auf ein vorhandenes Laufwerk oder einen Unterordner.',
      descriptionEn:
          'Creates a shortcut to an existing drive or subfolder.',
      category: ProviderCategory.virtualAndWrappers,
      authType: AuthType.none,
      fields: [
        ConfigFieldDefinition(
          key: 'remote',
          label: 'Ziel-Laufwerk',
          labelEn: 'Target drive',
          hint: 'Bereits verbundenes Cloud-Laufwerk wählen',
          hintEn: 'Pick an already connected cloud drive',
          remotePicker: RemotePickerMode.single,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'compress',
      name: 'Kompression (Gzip)',
      nameEn: 'Compression (Gzip)',
      description:
          'Komprimiert Dateien transparent vor dem Upload und entpackt sie beim Zugriff.',
      descriptionEn:
          'Transparently compresses files before upload and unpacks them on access.',
      category: ProviderCategory.virtualAndWrappers,
      authType: AuthType.none,
      fields: [
        ConfigFieldDefinition(
          key: 'remote',
          label: 'Basis-Laufwerk',
          labelEn: 'Base drive',
          hint: 'Bereits verbundenes Cloud-Laufwerk wählen',
          hintEn: 'Pick an already connected cloud drive',
          remotePicker: RemotePickerMode.single,
        ),
      ],
    ),
  ];

  /// Returns all providers matching a category.
  static List<RcloneProviderDescriptor> getByCategory(ProviderCategory category) {
    return providers.where((p) => p.category == category).toList();
  }

  /// Returns popular providers for high-priority display.
  static List<RcloneProviderDescriptor> getPopular() {
    return providers.where((p) => p.isPopular).toList();
  }

  /// Finds a provider descriptor by its type/id or (localized) name.
  static RcloneProviderDescriptor? findById(String idOrName) {
    final clean = idOrName.trim().toLowerCase();
    for (final p in providers) {
      if (p.id.toLowerCase() == clean ||
          p.name.toLowerCase() == clean ||
          (p.nameEn.isNotEmpty && p.nameEn.toLowerCase() == clean)) {
        return p;
      }
    }
    // Partial match fallback
    for (final p in providers) {
      if (clean.contains(p.id.toLowerCase()) ||
          p.name.toLowerCase().contains(clean) ||
          (p.nameEn.isNotEmpty && p.nameEn.toLowerCase().contains(clean))) {
        return p;
      }
    }
    return null;
  }
}

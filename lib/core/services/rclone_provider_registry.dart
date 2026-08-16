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

/// Dynamic form field definition for configuring an rclone remote.
class ConfigFieldDefinition {
  final String key;
  final String label;
  final String hint;
  final bool isSecret;
  final bool isOptional;
  final bool isAdvanced;
  final String? defaultValue;
  final List<String>? dropdownOptions;

  const ConfigFieldDefinition({
    required this.key,
    required this.label,
    this.hint = '',
    this.isSecret = false,
    this.isOptional = false,
    this.isAdvanced = false,
    this.defaultValue,
    this.dropdownOptions,
  });
}

/// Descriptor providing complete metadata and form fields for an rclone backend.
class RcloneProviderDescriptor {
  final String id;
  final String name;
  final String description;
  final ProviderCategory category;
  final AuthType authType;
  final bool isPopular;
  final List<ConfigFieldDefinition> fields;

  const RcloneProviderDescriptor({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.authType,
    this.isPopular = false,
    this.fields = const [],
  });

  RcloneProviderInfo toProviderInfo() => RcloneProviderInfo(
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
      description: 'Google Drive Cloud-Speicher (OAuth Web-Login)',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.oauth,
      isPopular: true,
      fields: [
        ConfigFieldDefinition(
          key: 'client_id',
          label: 'Client ID (optional)',
          hint: 'Eigene Google Cloud Console Client-ID',
          isOptional: true,
          isAdvanced: true,
        ),
        ConfigFieldDefinition(
          key: 'client_secret',
          label: 'Client Secret (optional)',
          hint: 'Google Client Secret',
          isSecret: true,
          isOptional: true,
          isAdvanced: true,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'google photos',
      name: 'Google Photos',
      description: 'Google Fotos Mediathek-Sicherung (OAuth)',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.oauth,
      isPopular: true,
    ),
    RcloneProviderDescriptor(
      id: 'onedrive',
      name: 'Microsoft OneDrive',
      description: 'Microsoft OneDrive & SharePoint (OAuth)',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.oauth,
      isPopular: true,
      fields: [
        ConfigFieldDefinition(
          key: 'drive_type',
          label: 'Laufwerk-Typ',
          defaultValue: 'personal',
          dropdownOptions: ['personal', 'business', 'sharepoint'],
          isAdvanced: true,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'dropbox',
      name: 'Dropbox',
      description: 'Dropbox Cloud-Speicher (OAuth)',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.oauth,
      isPopular: true,
    ),
    RcloneProviderDescriptor(
      id: 'box',
      name: 'Box',
      description: 'Box.com Cloud-Speicher (OAuth)',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.oauth,
      isPopular: true,
    ),
    RcloneProviderDescriptor(
      id: 'pcloud',
      name: 'pCloud',
      description: 'pCloud sicherer Cloud-Speicher (OAuth)',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.oauth,
      isPopular: true,
    ),
    RcloneProviderDescriptor(
      id: 'mega',
      name: 'Mega',
      description: 'MEGA verschlüsselter Cloud-Speicher',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.credentials,
      isPopular: true,
      fields: [
        ConfigFieldDefinition(
          key: 'user',
          label: 'E-Mail-Adresse',
          hint: 'dein.name@beispiel.de',
        ),
        ConfigFieldDefinition(
          key: 'pass',
          label: 'Passwort',
          isSecret: true,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'yandex',
      name: 'Yandex Disk',
      description: 'Yandex Disk Speicher (OAuth)',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.oauth,
    ),
    RcloneProviderDescriptor(
      id: 'hidrive',
      name: 'STRATO HiDrive',
      description: 'STRATO HiDrive Cloud-Speicher',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.oauth,
    ),
    RcloneProviderDescriptor(
      id: 'zoho',
      name: 'Zoho WorkDrive',
      description: 'Zoho WorkDrive Cloud (OAuth)',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.oauth,
    ),
    RcloneProviderDescriptor(
      id: 'protondrive',
      name: 'Proton Drive',
      description: 'Proton Drive Ende-zu-Ende verschlüsselt',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(key: 'username', label: 'Benutzername / E-Mail'),
        ConfigFieldDefinition(key: 'password', label: 'Passwort', isSecret: true),
        ConfigFieldDefinition(key: '2fa', label: '2FA Code (falls aktiv)', isOptional: true),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'pikpak',
      name: 'PikPak',
      description: 'PikPak Cloud-Drive',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(key: 'user', label: 'E-Mail / Telefonnummer'),
        ConfigFieldDefinition(key: 'pass', label: 'Passwort', isSecret: true),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'putio',
      name: 'Put.io',
      description: 'Put.io Cloud Storage (OAuth)',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.oauth,
    ),
    RcloneProviderDescriptor(
      id: 'mailru',
      name: 'Mail.ru Cloud',
      description: 'Mail.ru Cloud-Speicher',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(key: 'user', label: 'E-Mail-Adresse'),
        ConfigFieldDefinition(key: 'pass', label: 'App-Passwort', isSecret: true),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'jottacloud',
      name: 'Jottacloud',
      description: 'Jottacloud Unbegrenzter Speicher (OAuth)',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.oauth,
    ),
    RcloneProviderDescriptor(
      id: 'koofr',
      name: 'Koofr',
      description: 'Koofr EU Cloud-Speicher',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(key: 'user', label: 'E-Mail-Adresse'),
        ConfigFieldDefinition(key: 'password', label: 'App-Passwort', isSecret: true),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'opendrive',
      name: 'OpenDrive',
      description: 'OpenDrive Cloud Drive',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(key: 'username', label: 'E-Mail-Adresse'),
        ConfigFieldDefinition(key: 'password', label: 'Passwort', isSecret: true),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'sugarsync',
      name: 'SugarSync',
      description: 'SugarSync Cloud-Backup',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(key: 'user', label: 'E-Mail'),
        ConfigFieldDefinition(key: 'pass', label: 'Passwort', isSecret: true),
        ConfigFieldDefinition(key: 'app_id', label: 'App ID', isAdvanced: true),
        ConfigFieldDefinition(key: 'access_key_id', label: 'Access Key ID', isAdvanced: true),
      ],
    ),
    RcloneProviderDescriptor(
      id: '1fichier',
      name: '1Fichier',
      description: '1Fichier Cloud Storage',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(key: 'api_key', label: 'API-Schlüssel', isSecret: true),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'uptobox',
      name: 'Uptobox',
      description: 'Uptobox Cloud Storage',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(key: 'access_token', label: 'Benutzer-Token', isSecret: true),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'quatrix',
      name: 'Quatrix',
      description: 'Quatrix Enterprise Cloud',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(key: 'api_key', label: 'API-Schlüssel', isSecret: true),
        ConfigFieldDefinition(key: 'host', label: 'Quatrix Hostname', hint: 'firma.quatrix.it'),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'seafile',
      name: 'Seafile',
      description: 'Seafile Private Cloud Server',
      category: ProviderCategory.cloudStorage,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(key: 'url', label: 'Server-URL', hint: 'https://seafile.meine-domain.de'),
        ConfigFieldDefinition(key: 'user', label: 'Benutzername / E-Mail'),
        ConfigFieldDefinition(key: 'pass', label: 'Passwort / API-Token', isSecret: true),
      ],
    ),

    // --- S3-KOMPATIBLE DIENSTE & OBJECT STORAGE ---
    RcloneProviderDescriptor(
      id: 's3',
      name: 'Amazon S3',
      description: 'Amazon Web Services Simple Storage Service',
      category: ProviderCategory.s3Compatible,
      authType: AuthType.s3,
      isPopular: true,
      fields: [
        ConfigFieldDefinition(key: 'access_key_id', label: 'AWS Access Key ID'),
        ConfigFieldDefinition(key: 'secret_access_key', label: 'AWS Secret Access Key', isSecret: true),
        ConfigFieldDefinition(key: 'region', label: 'Region', hint: 'eu-central-1', defaultValue: 'eu-central-1'),
        ConfigFieldDefinition(key: 'endpoint', label: 'Benutzerdefinierter Endpoint (optional)', isOptional: true, isAdvanced: true),
      ],
    ),
    RcloneProviderDescriptor(
      id: 's3-wasabi',
      name: 'Wasabi Hot Cloud Storage',
      description: 'Wasabi S3-kompatibler Objektspeicher',
      category: ProviderCategory.s3Compatible,
      authType: AuthType.s3,
      isPopular: true,
      fields: [
        ConfigFieldDefinition(key: 'access_key_id', label: 'Wasabi Access Key'),
        ConfigFieldDefinition(key: 'secret_access_key', label: 'Wasabi Secret Key', isSecret: true),
        ConfigFieldDefinition(key: 'endpoint', label: 'Endpoint', defaultValue: 's3.eu-central-1.wasabisys.com'),
        ConfigFieldDefinition(key: 'region', label: 'Region', defaultValue: 'eu-central-1', isAdvanced: true),
      ],
    ),
    RcloneProviderDescriptor(
      id: 's3-b2',
      name: 'Backblaze B2 (S3 API)',
      description: 'Backblaze B2 Cloud Storage via S3 API',
      category: ProviderCategory.s3Compatible,
      authType: AuthType.s3,
      isPopular: true,
      fields: [
        ConfigFieldDefinition(key: 'access_key_id', label: 'Key ID'),
        ConfigFieldDefinition(key: 'secret_access_key', label: 'Application Key', isSecret: true),
        ConfigFieldDefinition(key: 'endpoint', label: 'S3 Endpoint', hint: 's3.eu-central-003.backblazeb2.com'),
      ],
    ),
    RcloneProviderDescriptor(
      id: 's3-r2',
      name: 'Cloudflare R2',
      description: 'Cloudflare R2 Object Storage (Null Egress-Gebühren)',
      category: ProviderCategory.s3Compatible,
      authType: AuthType.s3,
      isPopular: true,
      fields: [
        ConfigFieldDefinition(key: 'access_key_id', label: 'R2 Access Key ID'),
        ConfigFieldDefinition(key: 'secret_access_key', label: 'R2 Secret Access Key', isSecret: true),
        ConfigFieldDefinition(key: 'endpoint', label: 'R2 S3 API Endpoint', hint: 'https://<ACCOUNT_ID>.r2.cloudflarestorage.com'),
      ],
    ),
    RcloneProviderDescriptor(
      id: 's3-minio',
      name: 'MinIO',
      description: 'MinIO Self-Hosted S3 Object Storage',
      category: ProviderCategory.s3Compatible,
      authType: AuthType.s3,
      fields: [
        ConfigFieldDefinition(key: 'endpoint', label: 'MinIO Server URL', hint: 'https://minio.lan:9000'),
        ConfigFieldDefinition(key: 'access_key_id', label: 'MinIO Access Key'),
        ConfigFieldDefinition(key: 'secret_access_key', label: 'MinIO Secret Key', isSecret: true),
      ],
    ),
    RcloneProviderDescriptor(
      id: 's3-digitalocean',
      name: 'DigitalOcean Spaces',
      description: 'DigitalOcean Spaces Object Storage',
      category: ProviderCategory.s3Compatible,
      authType: AuthType.s3,
      fields: [
        ConfigFieldDefinition(key: 'access_key_id', label: 'Spaces Access Key'),
        ConfigFieldDefinition(key: 'secret_access_key', label: 'Spaces Secret Key', isSecret: true),
        ConfigFieldDefinition(key: 'endpoint', label: 'Endpoint', hint: 'fra1.digitaloceanspaces.com', defaultValue: 'fra1.digitaloceanspaces.com'),
      ],
    ),
    RcloneProviderDescriptor(
      id: 's3-idrive',
      name: 'IDrive e2',
      description: 'IDrive e2 S3-kompatibler Cloud-Speicher',
      category: ProviderCategory.s3Compatible,
      authType: AuthType.s3,
      fields: [
        ConfigFieldDefinition(key: 'access_key_id', label: 'Access Key ID'),
        ConfigFieldDefinition(key: 'secret_access_key', label: 'Secret Access Key', isSecret: true),
        ConfigFieldDefinition(key: 'endpoint', label: 'S3 Endpoint URL', hint: 'https://xxx.fra.idrivee2-XX.com'),
      ],
    ),
    RcloneProviderDescriptor(
      id: 's3-synology',
      name: 'Synology C2 Storage',
      description: 'Synology C2 Object Storage (S3 API)',
      category: ProviderCategory.s3Compatible,
      authType: AuthType.s3,
      fields: [
        ConfigFieldDefinition(key: 'access_key_id', label: 'C2 Access Key ID'),
        ConfigFieldDefinition(key: 'secret_access_key', label: 'C2 Secret Key', isSecret: true),
        ConfigFieldDefinition(key: 'endpoint', label: 'C2 S3 Endpoint', hint: 'https://eu-002.s3.synologyc2.net'),
      ],
    ),
    RcloneProviderDescriptor(
      id: 's3-ceph',
      name: 'Ceph Object Gateway',
      description: 'Ceph RADOS Gateway S3',
      category: ProviderCategory.s3Compatible,
      authType: AuthType.s3,
      fields: [
        ConfigFieldDefinition(key: 'endpoint', label: 'Ceph S3 Endpoint'),
        ConfigFieldDefinition(key: 'access_key_id', label: 'Access Key'),
        ConfigFieldDefinition(key: 'secret_access_key', label: 'Secret Key', isSecret: true),
      ],
    ),
    RcloneProviderDescriptor(
      id: 's3-generic',
      name: 'Generischer S3 Speicher',
      description: 'Jeder beliebige S3-kompatible Objektspeicher',
      category: ProviderCategory.s3Compatible,
      authType: AuthType.s3,
      fields: [
        ConfigFieldDefinition(key: 'endpoint', label: 'S3 Endpoint URL', hint: 'https://s3.meine-domain.de'),
        ConfigFieldDefinition(key: 'access_key_id', label: 'Access Key ID'),
        ConfigFieldDefinition(key: 'secret_access_key', label: 'Secret Access Key', isSecret: true),
        ConfigFieldDefinition(key: 'region', label: 'Region (optional)', isOptional: true, isAdvanced: true),
      ],
    ),

    // --- NATIVE ENTERPRISE & CLOUD APIS ---
    RcloneProviderDescriptor(
      id: 'b2',
      name: 'Backblaze B2 (Nativ)',
      description: 'Backblaze B2 native API',
      category: ProviderCategory.enterpriseAndNative,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(key: 'account', label: 'Account ID / Key ID'),
        ConfigFieldDefinition(key: 'key', label: 'Application Key', isSecret: true),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'gcs',
      name: 'Google Cloud Storage (GCS)',
      description: 'Google Cloud Platform Storage Buckets',
      category: ProviderCategory.enterpriseAndNative,
      authType: AuthType.oauth,
      fields: [
        ConfigFieldDefinition(key: 'project_number', label: 'GCP Projektnummer (optional)', isOptional: true),
        ConfigFieldDefinition(key: 'service_account_file', label: 'Service Account JSON Pfad (optional)', isOptional: true, isAdvanced: true),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'azureblob',
      name: 'Microsoft Azure Blob Storage',
      description: 'Azure Cloud Blob Container',
      category: ProviderCategory.enterpriseAndNative,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(key: 'account', label: 'Storage Account Name'),
        ConfigFieldDefinition(key: 'key', label: 'Account Key oder SAS-Token', isSecret: true),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'azurefiles',
      name: 'Microsoft Azure Files',
      description: 'Azure Managed File Shares',
      category: ProviderCategory.enterpriseAndNative,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(key: 'account', label: 'Storage Account Name'),
        ConfigFieldDefinition(key: 'key', label: 'Account Key', isSecret: true),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'storj',
      name: 'Storj DCS',
      description: 'Storj Dezentraler Cloud-Speicher',
      category: ProviderCategory.enterpriseAndNative,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(key: 'api_key', label: 'Storj API Key', isSecret: true),
        ConfigFieldDefinition(key: 'passphrase', label: 'Verschlüsselungs-Passphrase', isSecret: true),
        ConfigFieldDefinition(key: 'satellite_address', label: 'Satellite Adresse (optional)', defaultValue: 'us1.storj.io:7777', isAdvanced: true),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'swift',
      name: 'OpenStack Swift',
      description: 'OpenStack Swift Object Storage',
      category: ProviderCategory.enterpriseAndNative,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(key: 'user', label: 'Benutzername'),
        ConfigFieldDefinition(key: 'key', label: 'API-Key / Passwort', isSecret: true),
        ConfigFieldDefinition(key: 'auth', label: 'Auth URL', hint: 'https://identity.domain.com/v3'),
        ConfigFieldDefinition(key: 'tenant', label: 'Tenant Name (optional)', isOptional: true),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'qingstor',
      name: 'QingStor',
      description: 'QingStor Object Storage',
      category: ProviderCategory.enterpriseAndNative,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(key: 'access_key_id', label: 'Access Key ID'),
        ConfigFieldDefinition(key: 'secret_access_key', label: 'Secret Access Key', isSecret: true),
        ConfigFieldDefinition(key: 'zone', label: 'Zone', defaultValue: 'pek3a'),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'internetarchive',
      name: 'Internet Archive',
      description: 'Internet Archive S3 Gateway',
      category: ProviderCategory.enterpriseAndNative,
      authType: AuthType.credentials,
      fields: [
        ConfigFieldDefinition(key: 'access_key_id', label: 'IA S3 Access Key'),
        ConfigFieldDefinition(key: 'secret_access_key', label: 'IA S3 Secret Key', isSecret: true),
      ],
    ),

    // --- STANDARD-PROTOKOLLE & SERVER ---
    RcloneProviderDescriptor(
      id: 'webdav',
      name: 'WebDAV (Nextcloud / ownCloud / NAS)',
      description: 'WebDAV Server, Nextcloud, ownCloud, Synology',
      category: ProviderCategory.protocols,
      authType: AuthType.protocol,
      isPopular: true,
      fields: [
        ConfigFieldDefinition(
          key: 'url',
          label: 'WebDAV URL',
          hint: 'https://cloud.beispiel.de/remote.php/dav/files/user/',
        ),
        ConfigFieldDefinition(
          key: 'vendor',
          label: 'Server-Typ',
          defaultValue: 'nextcloud',
          dropdownOptions: ['nextcloud', 'owncloud', 'synology', 'fastmail', 'other'],
        ),
        ConfigFieldDefinition(
          key: 'user',
          label: 'Benutzername',
        ),
        ConfigFieldDefinition(
          key: 'pass',
          label: 'Passwort / App-Token',
          isSecret: true,
        ),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'sftp',
      name: 'SFTP (SSH File Transfer)',
      description: 'Sicherer Datei-Transfer via SSH / Linux Server / NAS',
      category: ProviderCategory.protocols,
      authType: AuthType.protocol,
      isPopular: true,
      fields: [
        ConfigFieldDefinition(key: 'host', label: 'Server Host / IP', hint: 'server.meine-domain.de'),
        ConfigFieldDefinition(key: 'port', label: 'SSH Port', defaultValue: '22'),
        ConfigFieldDefinition(key: 'user', label: 'SSH Benutzername'),
        ConfigFieldDefinition(key: 'pass', label: 'SSH Passwort (optional falls Key genutzt)', isSecret: true, isOptional: true),
        ConfigFieldDefinition(key: 'key_file', label: 'Pfad zum privaten SSH-Key (optional)', isOptional: true, isAdvanced: true),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'ftp',
      name: 'FTP / FTPS',
      description: 'Standard File Transfer Protocol',
      category: ProviderCategory.protocols,
      authType: AuthType.protocol,
      fields: [
        ConfigFieldDefinition(key: 'host', label: 'FTP Hostname / IP'),
        ConfigFieldDefinition(key: 'port', label: 'Port', defaultValue: '21'),
        ConfigFieldDefinition(key: 'user', label: 'Benutzername'),
        ConfigFieldDefinition(key: 'pass', label: 'Passwort', isSecret: true),
        ConfigFieldDefinition(key: 'tls', label: 'Explizites FTPS (TLS) verwenden', defaultValue: 'true', dropdownOptions: ['true', 'false'], isAdvanced: true),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'smb',
      name: 'SMB / CIFS (Windows Freigabe)',
      description: 'Windows Netzwerkfreigabe / Samba NAS',
      category: ProviderCategory.protocols,
      authType: AuthType.protocol,
      fields: [
        ConfigFieldDefinition(key: 'host', label: 'Server Host / IP'),
        ConfigFieldDefinition(key: 'user', label: 'Benutzername'),
        ConfigFieldDefinition(key: 'pass', label: 'Passwort', isSecret: true),
        ConfigFieldDefinition(key: 'domain', label: 'Windows Domain (optional)', isOptional: true, isAdvanced: true),
        ConfigFieldDefinition(key: 'port', label: 'Port', defaultValue: '445', isAdvanced: true),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'http',
      name: 'HTTP / HTTPS (Nur Lesen)',
      description: 'Öffentlicher Web-Ordner (Read-Only)',
      category: ProviderCategory.protocols,
      authType: AuthType.protocol,
      fields: [
        ConfigFieldDefinition(key: 'url', label: 'HTTP Ordner URL', hint: 'https://files.domain.com/data/'),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'hdfs',
      name: 'Hadoop HDFS',
      description: 'Hadoop Distributed File System',
      category: ProviderCategory.protocols,
      authType: AuthType.protocol,
      fields: [
        ConfigFieldDefinition(key: 'namenode', label: 'NameNode Host:Port', hint: 'hdfs.cluster.lan:8020'),
        ConfigFieldDefinition(key: 'username', label: 'Hadoop Benutzer'),
      ],
    ),

    // --- VIRTUELLE BACKENDS & VERSCHLÜSSELUNGS-WRAPPER ---
    RcloneProviderDescriptor(
      id: 'crypt',
      name: 'Verschlüsselter Tresor (Crypt)',
      description: 'Transparente Ende-zu-Ende-Verschlüsselung auf beliebigem Cloud-Speicher',
      category: ProviderCategory.virtualAndWrappers,
      authType: AuthType.none,
      isPopular: true,
      fields: [
        ConfigFieldDefinition(key: 'remote', label: 'Basis-Remote & Pfad', hint: 'meinDrive:tresor'),
        ConfigFieldDefinition(key: 'password', label: 'Hauptpasswort für Verschlüsselung', isSecret: true),
        ConfigFieldDefinition(key: 'password2', label: 'Dateinamen-Passwort (Salt / optional)', isSecret: true, isOptional: true, isAdvanced: true),
        ConfigFieldDefinition(key: 'filename_encryption', label: 'Dateinamen-Verschlüsselung', defaultValue: 'standard', dropdownOptions: ['standard', 'obfuscate', 'off'], isAdvanced: true),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'chunker',
      name: 'Große Dateien Aufteilen (Chunker)',
      description: 'Teilt Dateien automatisch in Blöcke auf (z.B. für Clouds mit Größenlimit)',
      category: ProviderCategory.virtualAndWrappers,
      authType: AuthType.none,
      fields: [
        ConfigFieldDefinition(key: 'remote', label: 'Basis-Remote & Pfad', hint: 'meinRemote:chunks'),
        ConfigFieldDefinition(key: 'chunk_size', label: 'Chunk-Größe', defaultValue: '2G'),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'union',
      name: 'Speicher-Zusammenführung (Union)',
      description: 'Führt mehrere Cloud-Laufwerke zu einem gemeinsamen virtuellen Speicher zusammen',
      category: ProviderCategory.virtualAndWrappers,
      authType: AuthType.none,
      fields: [
        ConfigFieldDefinition(key: 'remotes', label: 'Verknüpfte Remotes (getrennt durch Leerzeichen)', hint: 'drive1:pfad drive2:pfad'),
        ConfigFieldDefinition(key: 'action_policy', label: 'Schreib-Strategie', defaultValue: 'epall', dropdownOptions: ['epall', 'lfs', 'rand'], isAdvanced: true),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'combine',
      name: 'Verzeichnis-Kombination (Combine)',
      description: 'Kombiniert verschiedene Cloud-Ordner in ein virtuelles Wurzelverzeichnis',
      category: ProviderCategory.virtualAndWrappers,
      authType: AuthType.none,
      fields: [
        ConfigFieldDefinition(key: 'upstreams', label: 'Upstreams (z.B. ordner1=drive:a ordner2=b2:b)', hint: 'fotos=drive:fotos dokus=onedrive:dokus'),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'alias',
      name: 'Remote-Alias',
      description: 'Erstellt eine Verknüpfung / Alias für ein vorhandenes Remote',
      category: ProviderCategory.virtualAndWrappers,
      authType: AuthType.none,
      fields: [
        ConfigFieldDefinition(key: 'remote', label: 'Ziel-Remote & Pfad', hint: 'hauptDrive:unterordner'),
      ],
    ),
    RcloneProviderDescriptor(
      id: 'compress',
      name: 'Kompression (Gzip Wrapper)',
      description: 'Komprimiert Dateien transparent vor dem Upload',
      category: ProviderCategory.virtualAndWrappers,
      authType: AuthType.none,
      fields: [
        ConfigFieldDefinition(key: 'remote', label: 'Basis-Remote & Pfad', hint: 'meinDrive:archiv'),
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

  /// Finds a provider descriptor by its type/id or name.
  static RcloneProviderDescriptor? findById(String idOrName) {
    final clean = idOrName.trim().toLowerCase();
    for (final p in providers) {
      if (p.id.toLowerCase() == clean || p.name.toLowerCase() == clean) {
        return p;
      }
    }
    // Partial match fallback
    for (final p in providers) {
      if (clean.contains(p.id.toLowerCase()) || p.name.toLowerCase().contains(clean)) {
        return p;
      }
    }
    return null;
  }
}

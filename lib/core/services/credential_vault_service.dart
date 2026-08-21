import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_log_service.dart';

/// Ein gespeicherter Zugang für einen Cloud-Provider (Benutzername, Passwort,
/// optional Host/Port).
class SavedCredential {
  final String user;
  final String pass;
  final String host;
  final String port;

  const SavedCredential({
    required this.user,
    this.pass = '',
    this.host = '',
    this.port = '',
  });

  Map<String, dynamic> toJson() => {
        'user': user,
        'pass': pass,
        'host': host,
        'port': port,
      };

  factory SavedCredential.fromJson(Map<String, dynamic> json) {
    return SavedCredential(
      user: json['user'] as String? ?? '',
      pass: json['pass'] as String? ?? '',
      host: json['host'] as String? ?? '',
      port: json['port'] as String? ?? '',
    );
  }

  /// Kurzlabel für Vorschlags-Chips, z. B. „me@mail.de @ mega“.
  String get label => host.isNotEmpty ? '$user @ $host' : user;
}

/// Speichert Credentials pro rclone-Backend-Typ in der sicheren
/// Plattform-Ablage (iOS: Keychain, Android: Keystore, Windows: DPAPI).
///
/// Hintergrund: iOSs systemseitige Schlüsselbund-Autofill kann Einträge nur
/// pro App und per Associated Domain matchen – für Dritt-Service-Logins wie
/// MEGA, S3, WebDAV oder SFTP kann die App keine Web-Assoziation liefern.
/// Darum verwaltet Fibu eine eigene, je Provider gefilterte Vorschlagsliste:
/// Nach einem erfolgreichen Remote-Setup wird der Zugang abgelegt und beim
/// nächsten Hinzufügen desselben Provider-Typs direkt wieder angeboten.
///
/// Sicherheit: Inhalte liegen im Secure Storage (Keychain), nicht in
/// Klartext-Dateien, und werden niemals ins Protokoll geschrieben.
class CredentialVaultService {
  CredentialVaultService._();

  static final CredentialVaultService instance = CredentialVaultService._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const int maxEntriesPerProvider = 5;

  static String _keyFor(String rcloneType) =>
      'fibu_credentials_${rcloneType.trim().toLowerCase()}';

  /// Liest die gespeicherten Zugänge für [rcloneType] (z. B. `mega`, `s3`).
  Future<List<SavedCredential>> listFor(String rcloneType) async {
    try {
      final raw = await _storage.read(key: _keyFor(rcloneType));
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(SavedCredential.fromJson)
          .where((c) => c.user.isNotEmpty)
          .toList();
    } catch (e) {
      AppLog.warn('vault', 'Zugänge für „$rcloneType“ konnten nicht gelesen werden: $e');
      return const [];
    }
  }

  /// Legt [cred] für [rcloneType] ab bzw. ersetzt einen Eintrag mit
  /// identischem Benutzer+Host. Maximal [maxEntriesPerProvider] je Provider.
  Future<void> save(String rcloneType, SavedCredential cred) async {
    if (cred.user.isEmpty) return;
    try {
      final existing = await listFor(rcloneType);
      // WICHTIG: listFor kann „const []" liefern (unveränderbar) – erst eine
      // neue, veränderbare Liste aufbauen, bevor gefiltert wird.
      final filtered = existing
          .where((c) => !(c.user == cred.user && c.host == cred.host))
          .toList();
      final updated = [cred, ...filtered];
      final capped = updated.length > maxEntriesPerProvider
          ? updated.sublist(0, maxEntriesPerProvider)
          : updated;
      await _storage.write(
        key: _keyFor(rcloneType),
        value: jsonEncode(capped.map((c) => c.toJson()).toList()),
      );
      AppLog.info('vault',
          'Zugang für Provider „$rcloneType“ gespeichert (Benutzer: ${cred.user})');
    } catch (e) {
      AppLog.warn('vault', 'Zugang für „$rcloneType“ konnte nicht gespeichert werden: $e');
    }
  }
}

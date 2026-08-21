import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/app_paths.dart';
import 'app_log_service.dart';

/// Minimaler Schlüsselbund-Zugriff – bewusst OHNE Dritt-Plugin
/// (flutter_secure_storage wurde entfernt).
///
/// iOS/macOS: nativer Apple-Schlüsselbund (Security.framework,
/// kSecClassGenericPassword) über den MethodChannel „fibu/keychain", der in
/// AppDelegate.swift implementiert ist. Zugriffsklasse:
/// AfterFirstUnlockThisDeviceOnly – lesbar auch im Hintergrund (nötig für
/// geplante Syncs), niemals in ein Backup/anderes Gerät exportiert.
///
/// Andere Plattformen (Windows/Android): JSON-Datei im privaten
/// App-Support-Ordner. Das ist dasselbe Schutzniveau wie die ohnehin
/// vorhandene rclone.conf (Passwörter dort sind lediglich verschleiert).
///
/// Wertinhalte werden niemals protokolliert.
class SecureStore {
  SecureStore._();

  static const MethodChannel _channel = MethodChannel('fibu/keychain');

  static bool get _useNativeKeychain =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static Future<String?> read(String key) async {
    if (_useNativeKeychain) {
      try {
        final value = await _channel.invokeMethod<String>('read', {'key': key});
        return (value != null && value.isEmpty) ? null : value;
      } on MissingPluginException {
        // Kanal nicht registriert (z. B. alter App-Stand) → Datei-Fallback.
      } catch (e) {
        AppLog.warn('vault', 'Schlüsselbund-Lesefehler (Schlüssel „$key“): $e');
        return null;
      }
    }
    try {
      final all = await _readAllFromFile();
      return all[key];
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String key, String value) async {
    if (_useNativeKeychain) {
      try {
        await _channel.invokeMethod<void>('write', {'key': key, 'value': value});
        return;
      } on MissingPluginException {
        // Fallback unten.
      } catch (e) {
        AppLog.warn('vault', 'Schlüsselbund-Schreibfehler (Schlüssel „$key“): $e');
        return;
      }
    }
    try {
      final all = await _readAllFromFile();
      all[key] = value;
      await _writeAllToFile(all);
    } catch (e) {
      AppLog.warn('vault', 'Ablage-Schreibfehler (Schlüssel „$key“): $e');
    }
  }

  static Future<void> delete(String key) async {
    if (_useNativeKeychain) {
      try {
        await _channel.invokeMethod<void>('delete', {'key': key});
        return;
      } on MissingPluginException {
        // Fallback unten.
      } catch (e) {
        AppLog.warn('vault', 'Schlüsselbund-Löschfehler (Schlüssel „$key“): $e');
        return;
      }
    }
    try {
      final all = await _readAllFromFile();
      if (all.remove(key) != null) {
        await _writeAllToFile(all);
      }
    } catch (_) {}
  }

  // ----------------------------------------------------------------------
  // Datei-Fallback (Windows/Android): privater App-Support-Ordner
  // ----------------------------------------------------------------------

  static Future<Map<String, String>> _readAllFromFile() async {
    try {
      final file = await privateAppFile('fibu_vault.json');
      if (!await file.exists()) return {};
      final raw = (await file.readAsString()).trim();
      if (raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> _writeAllToFile(Map<String, String> values) async {
    final file = await privateAppFile('fibu_vault.json');
    await file.writeAsString(jsonEncode(values));
  }
}

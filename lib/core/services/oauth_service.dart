import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Result of an OAuth authorization attempt.
class OAuthResult {
  final bool success;
  final String? token;
  final String? error;

  const OAuthResult.success(String token)
      : success = true,
        token = token,
        error = null;

  const OAuthResult.failure(String error)
      : success = false,
        token = null,
        error = error;
}

/// Wires the native in-app browser OAuth flow (flutter_web_auth_2) to the
/// Fibu remote creation flow.
///
/// Flow:
///  1. The wizard builds a provider authorization URL (client_id/client_secret
///     come from the rclone config / app settings).
///  2. [authorize] opens it via `ASWebAuthenticationSession` (iOS) / a Chrome
///     Custom Tab (Android) using the `fibuoauth://` callback scheme.
///  3. The returned token/code is stored securely (Keychain on iOS).
///
/// Note: real OAuth needs a registered client_id/client_secret per provider.
/// Those must be configured in the app settings before a login can complete.
class OAuthService {
  OAuthService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  /// Callback URL scheme registered in Info.plist (CFBundleURLTypes).
  static const callbackScheme = 'fibuoauth';
  static const _keyPrefix = 'fibu_oauth_token_';

  Future<String?> getToken(String remoteName) =>
      _storage.read(key: '$_keyPrefix$remoteName');

  Future<void> clearToken(String remoteName) =>
      _storage.delete(key: '$_keyPrefix$remoteName');

  /// Opens the provider authorization page in an in-app browser and stores the
  /// resulting token securely. Returns [OAuthResult.success] when authorized.
  Future<OAuthResult> authorize({
    required String providerId,
    required String remoteName,
    required Uri authUrl,
  }) async {
    try {
      final callback = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: callbackScheme,
      );

      final uri = Uri.parse(callback);
      String? token = uri.queryParameters['code'] ??
          uri.queryParameters['token'] ??
          uri.queryParameters['access_token'];
      // Fallback: tokens may arrive as a fragment (#access_token=...).
      if (token == null && uri.fragment.contains('access_token=')) {
        for (final part in uri.fragment.split('&')) {
          if (part.startsWith('access_token=')) {
            token = Uri.decodeComponent(part.substring('access_token='.length));
            break;
          }
        }
      }

      if (token == null || token.isEmpty) {
        return const OAuthResult.failure(
            'Kein Autorisierungscode im Callback gefunden.');
      }

      await _storage.write(key: '$_keyPrefix$remoteName', value: token);
      return OAuthResult.success(token);
    } catch (e) {
      return OAuthResult.failure(
          'OAuth abgebrochen oder fehlgeschlagen: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }
}

/// Riverpod provider for [OAuthService].
final oauthServiceProvider = Provider<OAuthService>((ref) => OAuthService());

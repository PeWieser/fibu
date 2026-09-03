import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../utils/app_paths.dart';
import 'app_log_service.dart';

/// Was bei der Kopplung von einem Gerät zum anderen wandert.
///
/// Enthält die Cloud-Zugangsdaten — deshalb wird das Bundle verschlüsselt,
/// bevor es das Gerät verlässt.
class PairingBundle {
  final String deviceName;
  final String platform;

  /// Rohe `rclone.conf` — enthält die Zugangsdaten aller Laufwerke.
  final String rcloneConf;

  /// Registry (`remotes.json`): Kennung → Anzeigename/Typ.
  final List<Map<String, dynamic>> remotes;

  /// Aufgaben (`tasks.json`).
  final List<Map<String, dynamic>> tasks;

  /// Einstellungen (`settings.json`), falls vorhanden.
  final Map<String, dynamic>? settings;

  const PairingBundle({
    required this.deviceName,
    required this.platform,
    required this.rcloneConf,
    required this.remotes,
    required this.tasks,
    this.settings,
  });

  Map<String, dynamic> toJson() => {
        'version': 1,
        'deviceName': deviceName,
        'platform': platform,
        'rcloneConf': rcloneConf,
        'remotes': remotes,
        'tasks': tasks,
        if (settings != null) 'settings': settings,
      };

  factory PairingBundle.fromJson(Map<String, dynamic> json) => PairingBundle(
        deviceName: json['deviceName'] as String? ?? '',
        platform: json['platform'] as String? ?? '',
        rcloneConf: json['rcloneConf'] as String? ?? '',
        remotes: (json['remotes'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
        tasks: (json['tasks'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
        settings: json['settings'] is Map
            ? Map<String, dynamic>.from(json['settings'] as Map)
            : null,
      );
}

/// Adressdaten einer laufenden Kopplungs-Sitzung auf der Empfängerseite.
class PairingSession {
  final String host;
  final int port;

  /// 256-Bit-Schlüssel, Base64URL. Wandert nur über den QR-Code, nie über
  /// eine Netzwerkanfrage — ein URL-Fragment wird von HTTP-Clients nicht
  /// mitgesendet.
  final String secret;

  const PairingSession({
    required this.host,
    required this.port,
    required this.secret,
  });

  /// Was im QR-Code steht.
  Uri get uri => Uri.parse('http://$host:$port/#$secret');

  /// Kurzform zum Abtippen, falls kein Scanner zur Hand ist.
  String get shortCode => secret.substring(0, 8).toUpperCase();
}

/// Gerät-zu-Gerät-Übertragung der Konfiguration im lokalen Netz.
///
/// **Ablauf.** Der Empfänger (Desktop) startet einen HTTP-Server und zeigt
/// einen QR-Code mit Adresse und Schlüssel. Das sendende Gerät (Mobil) liest
/// den Code, verschlüsselt sein Konfigurations-Bundle mit dem Schlüssel und
/// lädt es hoch. Danach wird der Server sofort beendet.
///
/// **Kein Server dazwischen.** Die Daten gehen direkt von Gerät zu Gerät über
/// das lokale Netz. Es gibt keinen Relay, keine Cloud und kein Konto.
///
/// **Verschlüsselung.** AES-256-GCM mit dem Pairing-Schlüssel als Key. Der
/// Schlüssel ist 32 zufällige Bytes aus [Random.secure], also bereits hoch
/// entropisch — ein KDF wäre hier Dekoration. GCM liefert Integrität gleich
/// mit, ein manipuliertes Bundle fällt beim Entschlüsseln auf.
class DevicePairingService {
  DevicePairingService._();

  static const Duration defaultTimeout = Duration(minutes: 3);

  static const int _maxBundleBytes = 4 * 1024 * 1024;

  // ---------------------------------------------------------------------------
  // Empfänger (Desktop)
  // ---------------------------------------------------------------------------

  static HttpServer? _server;
  static String? _expectedSecret;
  static Completer<PairingBundle>? _incoming;
  static Timer? _timeoutTimer;

  static bool get isListening => _server != null;

  /// Startet die Sitzung. Liefert null, wenn kein Server gebunden werden
  /// konnte oder keine lokale Adresse gefunden wurde.
  static Future<PairingSession?> startReceiver() async {
    await stopReceiver();

    final secret = _generateSecret();
    final host = await _localAddress();
    if (host == null) {
      AppLog.warn('pairing',
          'Keine lokale Netzadresse gefunden — Kopplung nicht möglich');
      return null;
    }

    try {
      final server = await HttpServer.bind(host, 0);
      _server = server;
      _expectedSecret = secret;
      _incoming = Completer<PairingBundle>();
      _listen(server);
      _timeoutTimer = Timer(defaultTimeout, () {
        AppLog.info('pairing', 'Kopplungs-Sitzung nach Zeitablauf beendet');
        stopReceiver();
      });
      AppLog.info('pairing',
          'Kopplung bereit auf ${server.address.host}:${server.port}');
      return PairingSession(
          host: server.address.host, port: server.port, secret: secret);
    } catch (e) {
      AppLog.warn('pairing', 'Server konnte nicht gestartet werden: $e');
      await stopReceiver();
      return null;
    }
  }

  static void _listen(HttpServer server) {
    server.listen((request) async {
      try {
        if (request.method == 'POST' && request.uri.path == '/upload') {
          await _handleUpload(request);
        } else {
          // Absichtlich keine Auskunft über offene Endpunkte.
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        }
      } catch (e) {
        AppLog.warn('pairing', 'Anfrage fehlgeschlagen: $e');
        try {
          request.response.statusCode = HttpStatus.internalServerError;
          await request.response.close();
        } catch (_) {}
      }
    }, onError: (Object e) {
      AppLog.warn('pairing', 'Server-Fehler: $e');
    });
  }

  static Future<void> _handleUpload(HttpRequest request) async {
    final completer = _incoming;
    final response = request.response;

    if (completer == null || completer.isCompleted) {
      response.statusCode = HttpStatus.gone;
      await response.close();
      return;
    }

    // Grobe Obergrenze, damit niemand den Speicher füllt.
    // `contentLength` ist nicht nullable — bei unbekannter Länge liefert es -1,
    // dann greift die Prüfung unten beim Mitschreiben.
    if (request.contentLength > _maxBundleBytes) {
      response.statusCode = HttpStatus.requestEntityTooLarge;
      await response.close();
      return;
    }

    final bytes = <int>[];
    await for (final chunk in request) {
      bytes.addAll(chunk);
      if (bytes.length > _maxBundleBytes) {
        response.statusCode = HttpStatus.requestEntityTooLarge;
        await response.close();
        return;
      }
    }

    try {
      final bundle =
          await _decryptBundle(Uint8List.fromList(bytes), _expectedSecret ?? '');
      completer.complete(bundle);
      response.statusCode = HttpStatus.ok;
      response.write('ok');
      await response.close();
      AppLog.info('pairing',
          'Konfiguration empfangen von „${bundle.deviceName}" '
          '(${bundle.remotes.length} Laufwerke, ${bundle.tasks.length} Aufgaben)');
      await stopReceiver();
    } catch (e) {
      // Falscher Schlüssel oder manipuliertes Bundle — GCM merkt das.
      response.statusCode = HttpStatus.forbidden;
      await response.close();
      AppLog.warn('pairing', 'Bundle konnte nicht entschlüsselt werden: $e');
    }
  }

  /// Wartet auf ein eintreffendes Bundle. Null bei Zeitablauf oder Abbruch.
  static Future<PairingBundle?> waitForBundle() async {
    final completer = _incoming;
    if (completer == null) return null;
    return completer.future.timeout(
      defaultTimeout,
      onTimeout: () => throw TimeoutException('pairing'),
    ).catchError((Object _) => throw _NoBundle());
  }

  static Future<void> stopReceiver() async {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    final server = _server;
    _server = null;
    _expectedSecret = null;
    final pending = _incoming;
    _incoming = null;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(_NoBundle());
    }
    await server?.close(force: true);
  }

  // ---------------------------------------------------------------------------
  // Sender (Mobil)
  // ---------------------------------------------------------------------------

  /// Lädt ein Bundle zu einer laufenden Empfänger-Sitzung.
  static Future<bool> send({
    required String url,
    required PairingBundle bundle,
  }) async {
    final parsed = Uri.tryParse(url.trim());
    if (parsed == null || parsed.host.isEmpty) {
      AppLog.warn('pairing', 'Ungültige Kopplungs-Adresse: $url');
      return false;
    }
    final secret = parsed.fragment;
    if (secret.isEmpty) {
      AppLog.warn('pairing', 'Adresse enthält keinen Schlüssel');
      return false;
    }
    // Das Fragment darf nicht mitgesendet werden.
    final target = parsed.replace(fragment: '');

    try {
      final payload = await _encryptBundle(bundle, secret);
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      try {
        final request = await client.postUrl(
            target.replace(path: '/upload'));
        request.headers.contentType = ContentType.binary;
        request.add(payload);
        final response = await request.close().timeout(const Duration(seconds: 30));
        await response.drain<void>();
        final ok = response.statusCode == HttpStatus.ok;
        AppLog.info('pairing',
            ok ? 'Konfiguration übertragen' : 'Übertragung abgelehnt (${response.statusCode})');
        return ok;
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      AppLog.warn('pairing', 'Übertragung fehlgeschlagen: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Verschlüsselung
  // ---------------------------------------------------------------------------

  static AesGcm get _algorithm => AesGcm.with256bits();

  /// Schlüssel aus dem Base64URL-Text des QR-Codes.
  static Future<SecretKey> _keyFrom(String secret) async {
    final raw = base64Url.decode(secret);
    if (raw.length != 32) {
      throw const FormatException('Pairing-Schlüssel hat nicht 32 Bytes');
    }
    return SecretKey(raw);
  }

  static Future<Uint8List> _encryptBundle(
      PairingBundle bundle, String secret) async {
    final key = await _keyFrom(secret);
    final plaintext = utf8.encode(jsonEncode(bundle.toJson()));
    final box = await _algorithm.encrypt(plaintext, secretKey: key);
    // Aufbau: [1 Byte Nonce-Länge][Nonce][CipherText][MAC]
    final out = BytesBuilder();
    out.addByte(box.nonce.length);
    out.add(box.nonce);
    out.add(box.cipherText);
    out.add(box.mac.bytes);
    return out.toBytes();
  }

  static Future<PairingBundle> _decryptBundle(
      Uint8List bytes, String secret) async {
    if (bytes.isEmpty) throw const FormatException('Leeres Bundle');
    final key = await _keyFrom(secret);
    final nonceLength = bytes[0];
    if (bytes.length < 1 + nonceLength + 16) {
      throw const FormatException('Bundle zu kurz');
    }
    final nonce = bytes.sublist(1, 1 + nonceLength);
    final mac = bytes.sublist(bytes.length - 16);
    final cipherText = bytes.sublist(1 + nonceLength, bytes.length - 16);
    final plaintext = await _algorithm.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
      secretKey: key,
    );
    final decoded = jsonDecode(utf8.decode(plaintext));
    if (decoded is! Map) throw const FormatException('Bundle ist kein Objekt');
    return PairingBundle.fromJson(Map<String, dynamic>.from(decoded));
  }

  // ---------------------------------------------------------------------------
  // Bundle aus dem eigenen Gerät zusammenstellen
  // ---------------------------------------------------------------------------

  static Future<PairingBundle> collectBundle(String platformName) async {
    // Alle vier Dateien liegen im privaten App-Support-Ordner.
    final conf = await _readOrEmpty('rclone.conf');
    final remotes = await _readJsonList('remotes.json');
    final tasks = await _readJsonList('tasks.json');
    final settings = await _readJsonMap('settings.json');

    return PairingBundle(
      deviceName: Platform.localHostname,
      platform: platformName,
      rcloneConf: conf,
      remotes: remotes,
      tasks: tasks,
      settings: settings,
    );
  }

  static Future<String> _readOrEmpty(String name) async {
    try {
      final f = await privateAppFile(name);
      return await f.exists() ? await f.readAsString() : '';
    } catch (_) {
      return '';
    }
  }

  static Future<List<Map<String, dynamic>>> _readJsonList(String name) async {
    final raw = await _readOrEmpty(name);
    if (raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  static Future<Map<String, dynamic>?> _readJsonMap(String name) async {
    final raw = await _readOrEmpty(name);
    if (raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  // ---------------------------------------------------------------------------
  // Helfer
  // ---------------------------------------------------------------------------

  static String _generateSecret() {
    final rand = Random.secure();
    final bytes = List<int>.generate(32, (_) => rand.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Erste nicht-Loopback-IPv4-Adresse — die, unter der das Gerät im lokalen
  /// Netz erreichbar ist.
  static Future<String?> _localAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (e) {
      AppLog.warn('pairing', 'Netzadapter nicht lesbar: $e');
    }
    return null;
  }
}

/// Interner Marker: „Es kam kein Bundle" (Zeitablauf, Abbruch).
class _NoBundle implements Exception {}

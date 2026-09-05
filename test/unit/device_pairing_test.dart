import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fibu/core/services/device_pairing_service.dart';

/// Konfig-Übertragung zwischen Geräten: Erkennung → ein Tipp → Bestätigung.
///
/// Die Erkennung ist der **einzige** Weg zur Übertragung (kein QR-Code, keine
/// Adresseingabe mehr). Diese Tests decken deshalb die Kette ab, an der ein
/// Fehler sofort das ganze Feature lahmlegt:
///
///   Fund im Netz → Zieladresse **mit Schlüssel** → verschlüsselter Upload →
///   entschlüsseltes Bundle.
///
/// Genau hier lag der Fehler, den die Tests jetzt festnageln: Der Beacon
/// enthielt nur Name, IP und Port — `send` verlangt aber den Schlüssel aus dem
/// URL-Fragment. Ein Tipp auf ein gefundenes Gerät schlug damit immer fehl.
///
/// Die Kette ist bewusst in einzelne Glieder zerlegt (Schlüssel → Krypto →
/// Transport → `send` end-to-end): Scheitert eines, sagt der Test welches,
/// statt nur „Übertragung fehlgeschlagen" zu melden.
void main() {
  group('Kopplung über automatische Erkennung', () {
    // Bewusst zuerst: Solange noch kein Empfänger gestartet wurde, funkt
    // auch nichts im Netz — der Test kann nicht über einen Beacon der
    // folgenden Tests stolpern.
    test('Findet sich kein Empfänger, kommt null — kein Absturz', () async {
      // Kurzer Timeout: Der Test soll nicht die vollen sechs Sekunden warten.
      final found = await DevicePairingService.discover(
          timeout: const Duration(milliseconds: 500));
      expect(found, isNull);
    });

    test('Ein gefundenes Gerät ergibt eine Zieladresse mit Schlüssel', () {
      const device = DiscoveredDevice(
        name: 'DESKTOP-TEST',
        host: '192.168.1.20',
        port: 53124,
        secret: 'schluessel-aus-dem-beacon',
      );

      final url = DevicePairingService.targetUrlFor(device);

      expect(url, 'http://192.168.1.20:53124/#schluessel-aus-dem-beacon');

      final parsed = Uri.parse(url);
      expect(parsed.host, '192.168.1.20');
      expect(parsed.port, 53124);
      // Ohne Fragment lehnt send() ab — das war der Fehler.
      expect(parsed.fragment, isNotEmpty);
      expect(parsed.fragment, device.secret);
      // Das Fragment selbst geht nie über die Leitung: send() schickt
      // `parsed.replace(fragment: '')`. (Uri hängt ein leeres `#` an — das
      // ist kein Inhalt, nur Schreibweise.)
      expect(parsed.replace(fragment: '').fragment, isEmpty);
    });

    test('Bundle überlebt Verschlüsseln und Entschlüsseln unverändert',
        () async {
      const bundle = _testBundle;
      // 32 Bytes, Base64URL ohne Padding — genau das Format aus
      // _generateSecret, damit die Längenprüfung nicht greift.
      final secret = base64Url.encode(List<int>.generate(32, (i) => i + 1))
          .replaceAll('=', '');

      final bytes = await DevicePairingService.encryptBundle(bundle, secret);
      final back = await DevicePairingService.decryptBundle(bytes, secret);

      expect(back.deviceName, bundle.deviceName);
      expect(back.platform, bundle.platform);
      expect(back.rcloneConf, bundle.rcloneConf);
      expect(back.remotes.single['name'], 'Google Drive');
      expect(back.tasks.single['syncMode'], 'mirror');
    });

    test('Ein Bundle mit falschem Schlüssel lässt sich nicht öffnen', () async {
      final secret = base64Url.encode(List<int>.generate(32, (i) => i + 1))
          .replaceAll('=', '');
      final other = base64Url.encode(List<int>.filled(32, 7))
          .replaceAll('=', '');

      final bytes =
          await DevicePairingService.encryptBundle(_testBundle, secret);

      // AES-GCM merkt den falschen Schlüssel — das Bundle ist wertlos.
      await expectLater(
        DevicePairingService.decryptBundle(bytes, other),
        throwsA(anything),
      );
    });

    test('Empfänger nimmt ein Bundle an und reicht es unverändert weiter',
        () async {
      // Loopback: Der Test soll an Verschlüsselung und Protokoll scheitern
      // können, nicht an einer Firewall oder am Routing des CI-Runners.
      final session =
          await DevicePairingService.startReceiver(bindHost: '127.0.0.1');
      expect(session, isNotNull, reason: 'Empfänger konnte nicht starten');
      addTearDown(DevicePairingService.stopReceiver);

      // Erst zuhören, dann senden — sonst ist das Bundle vor dem Await da.
      final waiting = DevicePairingService.waitForBundle();

      final payload = await DevicePairingService.encryptBundle(
          _testBundle, session!.secret);

      // Der HTTP-Status steht hier ausdrücklich im Assert: Er trennt
      // „Schlüssel passt nicht" (403) von „Endpunkt nicht gefunden" (404)
      // von „Sitzung schon zu" (410) — die App selbst meldet in allen drei
      // Fällen nur „Übertragung fehlgeschlagen".
      final client = HttpClient();
      addTearDown(client.close);
      final request = await client
          .postUrl(Uri.parse('http://${session.host}:${session.port}/upload'));
      request.add(payload);
      final response = await request.close();
      final status = response.statusCode;
      await response.drain<void>();
      expect(status, HttpStatus.ok);

      final received = await waiting;
      expect(received, isNotNull);
      expect(received!.deviceName, _testBundle.deviceName);
      expect(received.rcloneConf, _testBundle.rcloneConf);
      expect(received.remotes, hasLength(1));
      expect(received.tasks.single['syncMode'], 'mirror');
    });

    test('send() überträgt an ein gefundenes Gerät — der Weg der App',
        () async {
      final session =
          await DevicePairingService.startReceiver(bindHost: '127.0.0.1');
      expect(session, isNotNull, reason: 'Empfänger konnte nicht starten');
      addTearDown(DevicePairingService.stopReceiver);

      final waiting = DevicePairingService.waitForBundle();

      // Exakt der Weg, den die App geht: Fund im Netz → targetUrlFor → send.
      final ok = await DevicePairingService.send(
        url: DevicePairingService.targetUrlFor(DiscoveredDevice(
          name: 'Empfänger',
          host: session!.host,
          port: session.port,
          secret: session.secret,
        )),
        bundle: _testBundle,
      );
      expect(ok, isTrue,
          reason: DevicePairingService.isListening
              ? 'Der Server lief noch — die Übertragung selbst ist '
                  'fehlgeschlagen (Schlüssel, Pfad oder HTTP-Antwort).'
              : 'Der Server war schon weg, bevor das Bundle ankam.');

      final received = await waiting;
      expect(received, isNotNull);
      expect(received!.deviceName, _testBundle.deviceName);
    });

    test('Ein Fremdgerät ohne Sitzungsschlüssel wird abgewiesen', () async {
      final session =
          await DevicePairingService.startReceiver(bindHost: '127.0.0.1');
      expect(session, isNotNull);
      addTearDown(DevicePairingService.stopReceiver);

      // Gültige Länge (32 Bytes Base64URL), aber ein anderer Schlüssel:
      // Hier muss AES-GCM selbst ablehnen, nicht die Längenprüfung.
      final wrongSecret =
          base64Url.encode(List<int>.filled(32, 7)).replaceAll('=', '');
      final ok = await DevicePairingService.send(
        url: 'http://${session!.host}:${session.port}/#$wrongSecret',
        bundle: _testBundle,
      );
      expect(ok, isFalse);
      expect(DevicePairingService.isListening, isTrue,
          reason: 'Eine abgelehnte Übertragung darf die Sitzung nicht beenden');
    });
  });
}

/// Ein Bundle, wie es ein Mobilgerät schicken würde — mit Zugangsdaten,
/// weil genau die der Grund für die Verschlüsselung sind.
const PairingBundle _testBundle = PairingBundle(
  deviceName: 'iPhone von Test',
  platform: 'iOS',
  rcloneConf: '[gdrive]\ntype = drive\ntoken = {"access_token":"geheim"}\n',
  remotes: [
    {'id': 'gdrive', 'name': 'Google Drive', 'type': 'drive'}
  ],
  tasks: [
    {'id': 't1', 'name': 'Fotos', 'syncMode': 'mirror'}
  ],
);

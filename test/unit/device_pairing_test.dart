import 'dart:convert';

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
      // Das Fragment selbst geht nie über die Leitung.
      expect(parsed.replace(fragment: '').toString(),
          'http://192.168.1.20:53124/');
    });

    test('Bundle kommt verschlüsselt an und ist danach dasselbe', () async {
      final session = await DevicePairingService.startReceiver();
      expect(session, isNotNull,
          reason: 'Empfänger konnte nicht starten — hat der Test-Rechner '
              'eine Netzadresse (nicht Loopback)?');
      addTearDown(DevicePairingService.stopReceiver);

      const bundle = PairingBundle(
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

      // Erst zuhören, dann senden — sonst ist das Bundle vor dem Await da.
      final waiting = DevicePairingService.waitForBundle();

      // Exakt der Weg, den die App geht: Fund im Netz → targetUrlFor → send.
      final ok = await DevicePairingService.send(
        url: DevicePairingService.targetUrlFor(DiscoveredDevice(
          name: 'Empfänger',
          host: session!.host,
          port: session.port,
          secret: session.secret,
        )),
        bundle: bundle,
      );
      expect(ok, isTrue);

      final received = await waiting;
      expect(received, isNotNull);
      expect(received!.deviceName, bundle.deviceName);
      expect(received.platform, bundle.platform);
      expect(received.rcloneConf, bundle.rcloneConf);
      expect(received.remotes, hasLength(1));
      expect(received.remotes.single['name'], 'Google Drive');
      expect(received.tasks.single['syncMode'], 'mirror');
    });

    test('Ein Bundle mit falschem Schlüssel wird abgelehnt', () async {
      final session = await DevicePairingService.startReceiver();
      expect(session, isNotNull);
      addTearDown(DevicePairingService.stopReceiver);

      const bundle = PairingBundle(
        deviceName: 'Angreifer im selben Netz',
        platform: 'linux',
        rcloneConf: 'böse',
        remotes: [],
        tasks: [],
      );

      // Gültige Länge (32 Bytes Base64URL), aber ein anderer Schlüssel:
      // Hier muss AES-GCM selbst ablehnen, nicht die Längenprüfung.
      final wrongSecret = base64Url.encode(List<int>.filled(32, 7));
      final ok = await DevicePairingService.send(
        url: 'http://${session!.host}:${session.port}/#$wrongSecret',
        bundle: bundle,
      );
      // AES-GCM merkt den falschen Schlüssel — nichts wird übergeben.
      expect(ok, isFalse);
      expect(DevicePairingService.isListening, isTrue,
          reason: 'Eine abgelehnte Übertragung darf die Sitzung nicht beenden');
    });

  });
}
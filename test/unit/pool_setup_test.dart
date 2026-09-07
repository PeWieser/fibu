import 'package:flutter_test/flutter_test.dart';

import 'package:fibu/core/services/active_cloud.dart';
import 'package:fibu/core/services/rclone_provider_registry.dart';

/// Die Regeln hinter „mehrere Clouds im selben Setup anlegen und bündeln".
///
/// Bewusst als reine Funktionen und nicht als Widget-Durchklick-Test: Die
/// Logik ist der Teil, der kaputtgehen kann, und sie lässt sich hier
/// deterministisch prüfen. Der Klickweg selbst ist im Widget-Test
/// (`wizard_pool_test.dart`) bis zum Öffnen des Bestandteil-Assistenten
/// abgedeckt.
void main() {
  group('Auswahl der Bestandteile', () {
    test('liest ein einzelnes Laufwerk (Crypt, Chunker, Alias)', () {
      expect(ActiveCloud.parseRemoteIds('fibu-1a2b3c4d:'), ['fibu-1a2b3c4d']);
    });

    test('liest mehrere Laufwerke (Union, Combine)', () {
      expect(ActiveCloud.parseRemoteIds('fibu-1a2b3c4d: fibu-5e6f7a8b:'),
          ['fibu-1a2b3c4d', 'fibu-5e6f7a8b']);
    });

    test('liest das Combine-Format name=id:', () {
      expect(
        ActiveCloud.parseRemoteIds('erste=fibu-1a2b3c4d: zweite=fibu-5e6f7a8b:'),
        ['fibu-1a2b3c4d', 'fibu-5e6f7a8b'],
      );
    });

    test('ein Pfad hinter der Kennung gehört nicht zur Kennung', () {
      expect(ActiveCloud.parseRemoteIds('fibu-1a2b3c4d:backup/2026'),
          ['fibu-1a2b3c4d']);
    });

    test('leere und whitespace-only Werte ergeben keine Bestandteile', () {
      expect(ActiveCloud.parseRemoteIds(''), isEmpty);
      expect(ActiveCloud.parseRemoteIds('   '), isEmpty);
    });
  });

  group('Welches Laufwerk die eine Cloud wird', () {
    test('ein Pool wird es immer — auch gegen eine schon aktive Cloud', () {
      expect(
        ActiveCloud.shouldBecomeActive(isPool: true, hasActiveCloud: true),
        isTrue,
        reason: 'Genau dafür bündelt man Laufwerke',
      );
      expect(
        ActiveCloud.shouldBecomeActive(isPool: true, hasActiveCloud: false),
        isTrue,
      );
    });

    test('ein einzelnes Laufwerk verdrängt keine aktive Cloud', () {
      expect(
        ActiveCloud.shouldBecomeActive(isPool: false, hasActiveCloud: true),
        isFalse,
        reason: 'Ein nachträglich verbundenes Laufwerk darf das Ziel nicht '
            'still ändern',
      );
      expect(
        ActiveCloud.shouldBecomeActive(isPool: false, hasActiveCloud: false),
        isTrue,
        reason: 'Das erste Laufwerk wird das Ziel',
      );
    });
  });

  group('Bestandteil-Assistent ohne virtuelle Backends', () {
    final ids =
        RcloneProviderRegistry.nonVirtualProviders.map((p) => p.id).toSet();

    test('kein Pool im Pool', () {
      for (final virtual in const [
        'union',
        'combine',
        'crypt',
        'chunker',
        'alias',
        'compress',
      ]) {
        expect(ids, isNot(contains(virtual)),
            reason: '$virtual ist selbst virtuell und darf kein '
                'Bestandteil-Assistent sein');
      }
    });

    test('echte Anbieter bleiben wählbar', () {
      expect(ids, contains('mega'));
      expect(ids, contains('dropbox'));
      expect(ids.length, greaterThan(40),
          reason: 'Die allermeisten Anbieter sind echte Clouds');
      expect(ids.length, lessThan(RcloneProviderRegistry.providers.length),
          reason: 'Die virtuellen müssen tatsächlich fehlen');
    });
  });
}

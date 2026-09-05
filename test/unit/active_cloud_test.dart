import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fibu/core/services/active_cloud.dart';
import 'package:fibu/core/services/mock_rclone_service.dart';
import 'package:fibu/core/services/rclone_provider.dart';
import 'package:fibu/core/services/remote_registry_service.dart';
import 'package:fibu/core/utils/app_paths.dart';
import '../helpers/platform_mocks.dart';

/// „Eine Cloud, eine Sicherung" — welche Cloud das ist, und wie groß sie ist.
///
/// Der Mock liefert drei Laufwerke mit fester Quota:
///   Google Drive (Mock)  15 GB gesamt /  9 GB belegt
///   OneDrive (Mock)     100 GB gesamt / 15 GB belegt
///   alles andere          2 GB gesamt /  0,5 GB belegt
void main() {
  const gb = 1024 * 1024 * 1024;
  const google = 'Google Drive (Mock)';
  const onedrive = 'OneDrive (Mock)';
  const dropbox = 'Dropbox (Mock)';

  late Directory mockDir;
  late MockRcloneService rclone;

  setUpAll(() async {
    mockDir = await installPathProviderMock();
  });
  tearDownAll(() async {
    await removePathProviderMock(mockDir);
  });

  setUp(() async {
    rclone = MockRcloneService();
    // Jeder Test beginnt mit leerer Registry und ohne Sicherung.
    for (final name in const ['remotes.json', 'tasks.json']) {
      final file = await privateAppFile(name);
      if (await file.exists()) await file.delete();
    }
  });

  tearDown(() => rclone.dispose());

  Future<void> writeTasks(List<Map<String, dynamic>> tasks) async {
    final file = await privateAppFile('tasks.json');
    await file.writeAsString(jsonEncode(tasks));
  }

  group('Aktive Cloud', () {
    test('die gespeicherte Wahl gewinnt und überlebt einen Neustart', () async {
      final registry = RemoteRegistryService(rclone);
      expect(await registry.entries(), hasLength(3));

      await registry.setActiveRemote(onedrive);

      // Neue Instanz = simulierter App-Neustart: dieselbe Datei.
      final restarted = RemoteRegistryService(rclone);
      await restarted.entries();
      expect(restarted.activeRemoteId, onedrive);
      expect(await ActiveCloud.resolve(restarted), onedrive);
    });

    test('ohne Wahl gewinnt das erste Laufwerk, das kein Bestandteil ist',
        () async {
      await rclone.addRemote(name: 'Tresor', type: 'crypt', config: const {});

      final registry = RemoteRegistryService(rclone);
      expect(await registry.entries(), hasLength(4));
      await registry.setActiveRemote('Tresor', members: const [google, onedrive]);
      await registry.clearActiveRemote();

      final fresh = RemoteRegistryService(rclone);
      await fresh.entries();
      expect(fresh.poolMembersOf('Tresor'), const [google, onedrive]);
      expect(fresh.activeRemoteId, isEmpty);

      // Google und OneDrive sind Bestandteile des Tresors — ein Bestandteil
      // allein ist kein Sicherungsziel. Dropbox ist das erste freie Laufwerk.
      expect(await ActiveCloud.resolve(fresh, persist: false), dropbox);
    });

    test('das Ziel der vorhandenen Sicherung gewinnt', () async {
      final registry = RemoteRegistryService(rclone);
      await registry.entries();

      await writeTasks([
        {
          'id': 'alt',
          'name': 'Alt',
          'sourcePath': 'files:/daten',
          'targetRemote': dropbox,
          'isActive': false,
        },
        {
          'id': 'aktiv',
          'name': 'Aktiv',
          'sourcePath': 'files:/bilder',
          'targetRemote': onedrive,
          'isActive': true,
        },
      ]);

      expect(await ActiveCloud.resolve(registry, persist: false), onedrive);
    });

    test('gibt es keine Sicherung und keine Wahl, gewinnt das erste Laufwerk',
        () async {
      final registry = RemoteRegistryService(rclone);
      await registry.entries();
      expect(await ActiveCloud.resolve(registry), google);
      // resolve schreibt die Wahl fest — danach steht sie in der Datei.
      expect(registry.activeRemoteId, google);
    });

    test('ohne Laufwerke gibt es keine aktive Cloud', () async {
      // Mock ohne Laufwerke: Registry bleibt leer.
      final empty = _NoRemotesRclone();
      final registry = RemoteRegistryService(empty);
      expect(await registry.entries(), isEmpty);
      expect(await ActiveCloud.resolve(registry), isNull);
      empty.dispose();
    });

    test('ein getrenntes Laufwerk verschwindet aus der Wahl und dem Pool',
        () async {
      await rclone.addRemote(name: 'Tresor', type: 'crypt', config: const {});
      final registry = RemoteRegistryService(rclone);
      await registry.entries();
      await registry.setActiveRemote('Tresor', members: const [google, onedrive]);

      await registry.unregister(onedrive);
      expect(registry.poolMembersOf('Tresor'), const [google]);
      expect(registry.activeRemoteId, 'Tresor');

      await registry.unregister('Tresor');
      expect(registry.activeRemoteId, isEmpty);
      expect(registry.poolMembersOf('Tresor'), isEmpty);
    });
  });

  group('Speicherplatz', () {
    test('einer gewöhnlichen Cloud gilt ihre eigene Angabe', () async {
      final registry = RemoteRegistryService(rclone);
      await registry.entries();

      final quota = await ActiveCloud.quota(rclone, registry, google);
      expect(quota, isNotNull);
      expect(quota!.totalBytes, 15 * gb);
      expect(quota.usedBytes, 9 * gb);
    });

    test('eines Pools ist die Summe der Bestandteile', () async {
      await rclone.addRemote(name: 'Tresor', type: 'crypt', config: const {});
      final registry = RemoteRegistryService(rclone);
      await registry.entries();
      await registry.setActiveRemote('Tresor', members: const [google, onedrive]);

      final quota = await ActiveCloud.quota(rclone, registry, 'Tresor');
      expect(quota, isNotNull);
      // 15 + 100 = 115 GB gesamt, 9 + 15 = 24 GB belegt, 6 + 85 = 91 GB frei.
      expect(quota!.totalBytes, 115 * gb);
      expect(quota.usedBytes, 24 * gb);
      expect(quota.freeBytes, 91 * gb);
    });

    test('ein Pool mit einem Bestandteil zeigt dessen Angabe', () async {
      await rclone.addRemote(name: 'Tresor', type: 'crypt', config: const {});
      final registry = RemoteRegistryService(rclone);
      await registry.entries();
      await registry.setActiveRemote('Tresor', members: const [onedrive]);

      final quota = await ActiveCloud.quota(rclone, registry, 'Tresor');
      expect(quota!.totalBytes, 100 * gb);
    });

    test('der Provider liefert den Platz der einen Cloud', () async {
      final registry = RemoteRegistryService(rclone);
      await registry.entries();
      await registry.setActiveRemote(google);

      final container = ProviderContainer(overrides: [
        rcloneServiceProvider.overrideWithValue(rclone),
        remoteRegistryServiceProvider.overrideWithValue(registry),
      ]);
      addTearDown(container.dispose);

      final quota = await container.read(activeCloudQuotaProvider.future);
      expect(quota, isNotNull);
      expect(quota!.totalBytes, 15 * gb);

      final id = await container.read(activeRemoteIdProvider.future);
      expect(id, google);
    });
  });
}

/// Rclone-Dienst ohne ein einziges Laufwerk — für den Fall „nichts verbunden".
class _NoRemotesRclone extends MockRcloneService {
  @override
  Future<List<String>> listRemotes() async => const [];
}

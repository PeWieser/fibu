import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'rclone_service.dart';
import 'mock_rclone_service.dart';
import 'rclone_service_impl.dart';
import 'ios_rclone_service.dart';
import 'remote_registry_service.dart';

/// Wählt die zur Plattform passende Engine — **ohne** Riverpod.
///
/// Brauchen alle Stellen, die keinen `Ref` haben: der Hintergrund-Planer und
/// der Workmanager-Callback laufen außerhalb des Widget-Baums.
///
/// Vorher baute der Planer hardcoded `IosRcloneService()`. Der spricht den
/// MethodChannel `fibu/rclone` an, den es nur auf iOS und Android gibt — auf
/// Windows lief jeder geplante Sync in eine `MissingPluginException` und
/// scheiterte still. Genau die Sorte Fehler, die niemand sieht, weil der
/// Zeitplan in der UI trotzdem korrekt aussieht.
RcloneService createRcloneServiceForPlatform() {
  const useMock = bool.fromEnvironment('USE_MOCK_RCLONE', defaultValue: false);
  if (useMock) return MockRcloneService();

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    return WindowsRcloneService();
  }
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android)) {
    return IosRcloneService();
  }
  return MockRcloneService();
}

/// Riverpod provider for the [RcloneService].
/// Automatically swaps implementations depending on runtime platform or debug config.
final rcloneServiceProvider =
    Provider<RcloneService>((ref) => createRcloneServiceForPlatform());

/// Riverpod provider to load all remotes asynchronously.
///
/// Liefert die stabilen Remote-IDs (= rclone-Sektionsnamen) aus der
/// App-Registry – NICHT mehr roh aus rclone. Die Registry adoptiert
/// Alt-Sektionen und trennt Identität (ID) vom Anzeigenamen; Umbenennen
/// eines Remote bricht dadurch keine Aufgaben mehr.
/// Für UI-Anzeige bitte immer [remoteDisplayNameProvider] verwenden.
final remotesProvider = FutureProvider<List<String>>((ref) async {
  final entries = await ref.watch(remoteEntriesProvider.future);
  return entries.map((e) => e.id).toList();
});

/// Riverpod provider to load quota for the first available remote.
final primaryQuotaProvider = FutureProvider<QuotaInfo?>((ref) async {
  final remotes = await ref.watch(remotesProvider.future);
  if (remotes.isNotEmpty) {
    return ref.watch(rcloneServiceProvider).getQuota(remotes.first);
  }
  return null;
});

/// Riverpod provider to load all supported providers asynchronously.
final providersProvider = FutureProvider<List<RcloneProviderInfo>>((ref) {
  return ref.watch(rcloneServiceProvider).listProviders();
});

/// Quota für ein einzelnes Remote.
///
/// Liefert null (statt Fehler), wenn der Provider kein `about` unterstützt
/// oder die Abfrage scheitert – die UI zeigt dann „n. v.“ statt 0 an.
final remoteQuotaProvider =
    FutureProvider.family<QuotaInfo?, String>((ref, remote) async {
  try {
    return await ref.watch(rcloneServiceProvider).getQuota(remote);
  } catch (_) {
    return null;
  }
});

/// Rekursive Byte-Summe des Fibu-Backup-Zielordners („fibu-backup“) im
/// Remote – also der von Fibu in der Cloud belegte Platz, NICHT der lokale
/// FibuMirror-Spiegel. 0, wenn der Ordner (noch) nicht existiert.
final remoteFibuUsageProvider =
    FutureProvider.family<int, String>((ref, remote) async {
  final service = ref.watch(rcloneServiceProvider);

  Future<int> sum(String path) async {
    var total = 0;
    final List<RcloneFileInfo> items;
    try {
      items = await service.listFiles(remote, path);
    } catch (_) {
      return 0;
    }
    for (final item in items) {
      if (item.isDir) {
        total += await sum(path.isEmpty ? item.name : '$path/${item.name}');
      } else {
        total += item.size;
      }
    }
    return total;
  }

  return sum('fibu-backup');
});

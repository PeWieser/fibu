import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'rclone_service.dart';
import 'mock_rclone_service.dart';
import 'rclone_service_impl.dart';
import 'ios_rclone_service.dart';

/// Riverpod provider for the [RcloneService].
/// Automatically swaps implementations depending on runtime platform or debug config.
final rcloneServiceProvider = Provider<RcloneService>((ref) {
  const useMock = bool.fromEnvironment('USE_MOCK_RCLONE', defaultValue: false);
  if (useMock) {
    return MockRcloneService();
  }

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    return WindowsRcloneService();
  }

  // iOS and Android are backed by the real gomobile `librclone` engine.
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android)) {
    return IosRcloneService();
  }

  return MockRcloneService();
});

/// Riverpod provider to load all remotes asynchronously.
final remotesProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(rcloneServiceProvider).listRemotes();
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

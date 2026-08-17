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

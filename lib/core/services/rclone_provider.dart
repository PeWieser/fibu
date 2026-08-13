import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'rclone_service.dart';
import 'mock_rclone_service.dart';
import 'rclone_service_impl.dart';

/// Riverpod provider for the [RcloneService].
/// Automatically swaps implementations depending on runtime platform or debug config.
final rcloneServiceProvider = Provider<RcloneService>((ref) {
  // During desktop execution on Windows, return the real process-based service.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    // Note: To toggle Mock vs. Process in developer builds, you can customize this.
    // We return MockRcloneService by default for safe local development without rclone.exe dependencies,
    // but WindowsRcloneService when fully deployed.
    const useMock = bool.fromEnvironment('USE_MOCK_RCLONE', defaultValue: false);
    if (useMock) {
      return MockRcloneService();
    }
    return WindowsRcloneService();
  }

  // Fallback to MockRcloneService for iOS, Android (mobile stub phase) and Web
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

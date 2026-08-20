import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Live-Netzwerkstatus der App.
///
/// Wird einmalig per `Connectivity.checkConnectivity()` initialisiert und
/// danach live über den Stream `Connectivity.onConnectivityChanged`
/// aktualisiert – Offline wird sofort erkannt, das Zurückkehren der
/// Verbindung ebenfalls sofort.
class NetworkStatus {
  /// Mindestens eine Verbindung ist aktiv (WLAN, Mobilfunk, Ethernet, ...).
  final bool online;

  /// Eine der aktiven Verbindungen ist WLAN (für die globale WLAN-only-Regel).
  final bool onWifi;

  const NetworkStatus({this.online = true, this.onWifi = false});

  NetworkStatus copyWith({bool? online, bool? onWifi}) => NetworkStatus(
        online: online ?? this.online,
        onWifi: onWifi ?? this.onWifi,
      );
}

/// StateNotifier hinter [networkStatusProvider].
class NetworkStatusNotifier extends StateNotifier<NetworkStatus> {
  NetworkStatusNotifier() : super(const NetworkStatus()) {
    _init();
  }

  StreamSubscription<List<ConnectivityResult>>? _sub;

  Future<void> _init() async {
    try {
      _apply(await Connectivity().checkConnectivity());
    } catch (_) {
      // Plugin nicht verfügbar (z. B. Tests): optimistisch online bleiben.
    }
    try {
      _sub = Connectivity().onConnectivityChanged.listen(
        _apply,
        onError: (_) {},
      );
    } catch (_) {}
  }

  void _apply(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    final onWifi = results.contains(ConnectivityResult.wifi);
    if (!mounted) return;
    if (online != state.online || onWifi != state.onWifi) {
      state = NetworkStatus(online: online, onWifi: onWifi);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Zentraler Provider für den aktuellen Netzwerkstatus.
/// Dashboard, Cloud-Explorer und die Sync-Steuerung hören auf ihn.
final networkStatusProvider =
    StateNotifierProvider<NetworkStatusNotifier, NetworkStatus>((ref) {
  return NetworkStatusNotifier();
});

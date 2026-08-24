import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/dashboard/presentation/dashboard_controller.dart';
import 'rclone_provider.dart';
import 'rclone_service.dart';
import 'network_status_service.dart';
import 'remote_registry_service.dart';
import 'widget_status_service.dart';

/// Automatische Hintergrund-Aktualisierung der Live-Daten (Quota, Remotes,
/// Sync-Bedarf) — ersetzt sämtliche manuellen „Aktualisieren“-Buttons.
///
/// Regeln (bewusst zurückhaltend, Akku zuerst):
///  * Intervall 10 s; im Stromsparmodus 20 s (iOS `lowPowerModeEnabled`
///    über den `fibu/system`-Channel, sonst immer 10 s).
///  * Nur solange die App im Vordergrund ist ([setForeground]).
///  * Nur online — offline gibt es nichts zu aktualisieren.
///  * Nie während eines laufenden Syncs (keine konkurrierenden Calls).
class AutoRefreshService {
  AutoRefreshService(this._ref);

  final Ref _ref;
  static const _channel = MethodChannel('fibu/system');

  Timer? _timer;
  bool _foreground = true;
  bool _busy = false;
  int _cycle = 0;
  DateTime _lastRun = DateTime.fromMillisecondsSinceEpoch(0);

  void start() {
    // Feiner Takt, das effektive Intervall entscheidet _tick (10 s / 20 s).
    _timer ??= Timer.periodic(const Duration(seconds: 5), (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  // App-Lifecycle: nur im Vordergrund aktualisieren.
  // ignore: avoid_positional_boolean_parameters
  void setForeground(bool value) => _foreground = value;

  Future<bool> _lowPowerMode() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return false;
    try {
      return await _channel.invokeMethod<bool>('lowPowerMode') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _tick() async {
    if (_busy || !_foreground) return;
    if (!_ref.read(networkStatusProvider).online) return;

    final jobStatus = _ref.read(activeJobProvider).status;
    if (jobStatus == RcloneJobStatus.syncing ||
        jobStatus == RcloneJobStatus.pending) {
      return;
    }

    final interval = await _lowPowerMode()
        ? const Duration(seconds: 20)
        : const Duration(seconds: 10);
    if (DateTime.now().difference(_lastRun) < interval) return;

    _busy = true;
    _lastRun = DateTime.now();
    _cycle++;
    try {
      // Cloud-Seite: Remotes + Quota frisch laden (billige Calls).
      _ref.invalidate(remoteEntriesProvider);
      _ref.invalidate(remotesProvider);
      _ref.invalidate(primaryQuotaProvider);
      _ref.invalidate(remoteQuotaProvider);
      // Fibu-Beleg = rekursive Ordner-Listung → bewusst seltener
      // (jeder 6. Zyklus ≈ alle 60 s / 120 s im Stromsparmodus).
      final heavy = _cycle % 6 == 1;
      if (heavy) {
        _ref.invalidate(remoteFibuUsageProvider);
      }
      // Sync-Bedarf: lokal (Task-Alben) jeden Takt; Remote-Alben-Abgleich
      // nur im heavy-Zyklus (billige flache Listen, kein Tree-Walk).
      await _ref
          .read(widgetStatusProvider.notifier)
          .recomputeAndPush(includeRemote: heavy);
    } catch (_) {
      // Auto-Refresh ist best-effort und darf nie stören.
    } finally {
      _busy = false;
    }
  }
}

/// Singleton-Provider; [start]/[setForeground] steuert die App-Shell (main).
final autoRefreshServiceProvider = Provider<AutoRefreshService>((ref) {
  final service = AutoRefreshService(ref);
  ref.onDispose(service.stop);
  return service;
});

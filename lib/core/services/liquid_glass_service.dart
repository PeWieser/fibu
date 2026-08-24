import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Erkennung und Konstanten für natives iOS-26-Liquid-Glass.
///
/// Unter iOS < 26 (und allen anderen Plattformen) ist [isAvailable] false —
/// die UI bleibt unverändert. Das echte Glass rendert UIKit
/// ([UIGlassEffect]) in einer Platform-View (`fibu/liquid_glass_view`).
class LiquidGlassService {
  LiquidGlassService();

  static const MethodChannel _channel = MethodChannel('fibu/liquid_glass');

  /// viewType für [UiKitView].
  static const String viewType = 'fibu/liquid_glass_view';

  bool? _cached;

  /// true nur auf echtem iOS 26+ mit UIGlassEffect-Klasse.
  Future<bool> isAvailable() async {
    if (_cached != null) return _cached!;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      _cached = false;
      return false;
    }
    // PathProvider/Channel nur auf Gerät/Simulator — in Tests oft stub.
    try {
      if (!Platform.isIOS) {
        _cached = false;
        return false;
      }
    } catch (_) {
      _cached = false;
      return false;
    }
    try {
      final v = await _channel.invokeMethod<bool>('isAvailable');
      _cached = v ?? false;
    } catch (_) {
      _cached = false;
    }
    return _cached!;
  }

  /// Synchroner Cache (null = noch nicht abgefragt).
  bool? get cached => _cached;
}

final liquidGlassServiceProvider = Provider<LiquidGlassService>((ref) {
  return LiquidGlassService();
});

/// Async: Liquid Glass auf diesem Gerät verfügbar?
final liquidGlassAvailableProvider = FutureProvider<bool>((ref) async {
  return ref.watch(liquidGlassServiceProvider).isAvailable();
});

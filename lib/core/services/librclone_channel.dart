import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import 'app_log_service.dart';

/// Thin Dart wrapper around the native librclone bridge.
///
/// The native side (iOS `RcloneBridge.swift`, Android `RcloneBridge.kt`) links the
/// gomobile-compiled `librclone` framework and exposes two operations over a
/// [MethodChannel]:
///
///  * `initialize` — starts the librclone engine and points it at a writable
///    config file path (usually inside the app documents directory).
///  * `rpc` — forwards a single rclone remote-control call
///    (`RcloneRPC(method, input)`) and returns the JSON string output.
///
/// All rclone functionality (config, sync, listing, stats, quota) is expressed as
/// remote-control methods, so this bridge stays tiny and stable.
class LibrcloneChannel {
  LibrcloneChannel._();

  static final LibrcloneChannel instance = LibrcloneChannel._();

  static const MethodChannel _channel = MethodChannel('fibu/rclone');

  bool _initialized = false;
  Completer<void>? _initializing;

  /// Boots the native librclone engine exactly once and configures the
  /// location of the rclone config file so remotes persist between launches.
  Future<void> ensureInitialized(String configPath) async {
    if (_initialized) return;
    if (_initializing != null) return _initializing!.future;

    final completer = Completer<void>();
    _initializing = completer;
    try {
      AppLog.info('engine', 'librclone engine initialisiere (config: $configPath)');
      await _channel.invokeMethod<void>('initialize', {'configPath': configPath});
      // Make sure librclone writes/reads the same config file we manage.
      await rpc('config/setpath', {'path': configPath});
      _initialized = true;
      completer.complete();
      AppLog.info('engine', 'librclone engine bereit');
    } catch (e, st) {
      completer.completeError(e, st);
      _initializing = null;
      AppLog.error('engine', 'Engine-Initialisierung fehlgeschlagen: $e');
      rethrow;
    }
  }

  /// Performs a single rclone remote-control call and decodes the JSON response.
  ///
  /// Jeder Aufruf hat ein [timeout] (Default 60 s); überschreitet ihn rclone,
  /// wird eine [RcloneRpcException] mit klarer Timeout-Meldung geworfen, statt
  /// endlos zu laden. Polling-Calls (`core/stats`, `job/status`) werden aus
  /// Lärm-Gründen nicht pro Aufruf geloggt.
  ///
  /// Throws [RcloneRpcException] when librclone reports a non-2xx status so callers
  /// can surface real, native error text instead of silent no-ops.
  Future<Map<String, dynamic>> rpc(
    String method, [
    Map<String, dynamic> input = const {},
    Duration timeout = const Duration(seconds: 60),
  ]) async {
    final poll = method == 'core/stats' || method == 'job/status';
    final started = DateTime.now();
    if (!poll) AppLog.info('rclone', '→ $method');
    final String output;
    try {
      output = await _channel
          .invokeMethod<String>('rpc', {
            'method': method,
            'input': jsonEncode(input),
          })
          .timeout(timeout) ??
          '{}';
    } on TimeoutException {
      AppLog.error(
          'rclone', 'Timeout nach ${timeout.inSeconds}s bei $method (Netzwerk/Provider?)');
      throw RcloneRpcException(
        method: method,
        message: 'timeout after ${timeout.inSeconds}s – Timeout/Netzwerkproblem bei $method',
      );
    } on PlatformException catch (e) {
      if (!poll) AppLog.error('rclone', '$method fehlgeschlagen: ${e.message}');
      throw RcloneRpcException(
        method: method,
        message: e.message ?? 'librclone call failed',
        details: e.details?.toString(),
      );
    }

    if (!poll) {
      final ms = DateTime.now().difference(started).inMilliseconds;
      AppLog.info('rclone', '← $method OK (${ms}ms)');
    }
    if (output.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(output);
    if (decoded is Map<String, dynamic>) return decoded;
    return {'result': decoded};
  }
}

/// Error raised when a librclone remote-control call fails.
class RcloneRpcException implements Exception {
  final String method;
  final String message;
  final String? details;

  const RcloneRpcException({
    required this.method,
    required this.message,
    this.details,
  });

  @override
  String toString() {
    // Die Bridge-Nachricht enthält bereits "rclone <method> …" → nichts
    // doppelt präfixen.
    final base = message.startsWith('rclone ') ? message : 'rclone $method: $message';
    return details != null && details!.isNotEmpty ? '$base ($details)' : base;
  }
}

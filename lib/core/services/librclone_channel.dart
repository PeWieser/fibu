import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

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
      await _channel.invokeMethod<void>('initialize', {'configPath': configPath});
      // Make sure librclone writes/reads the same config file we manage.
      await rpc('config/setpath', {'path': configPath});
      _initialized = true;
      completer.complete();
    } catch (e, st) {
      completer.completeError(e, st);
      _initializing = null;
      rethrow;
    }
  }

  /// Performs a single rclone remote-control call and decodes the JSON response.
  ///
  /// Throws [RcloneRpcException] when librclone reports a non-2xx status so callers
  /// can surface real, native error text instead of silent no-ops.
  Future<Map<String, dynamic>> rpc(
    String method, [
    Map<String, dynamic> input = const {},
  ]) async {
    final String output;
    try {
      output = await _channel.invokeMethod<String>('rpc', {
            'method': method,
            'input': jsonEncode(input),
          }) ??
          '{}';
    } on PlatformException catch (e) {
      throw RcloneRpcException(
        method: method,
        message: e.message ?? 'librclone call failed',
        details: e.details?.toString(),
      );
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
  String toString() => 'rclone $method: $message${details != null ? ' ($details)' : ''}';
}

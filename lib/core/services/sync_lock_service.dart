import 'dart:convert';
import 'dart:io';

import 'app_log_service.dart';
import 'device_identity_service.dart';
import 'rclone_service.dart';

/// Geräteübergreifende Sperre für einen Sync-Zielordner.
///
/// **Warum.** Jedes Gerät hat eine eigene Sperre (`isSyncRunning`), aber keine
/// kennt die anderen. Zwei Geräte können gleichzeitig auf denselben Zielordner
/// schreiben — bei einem Spiegel-Lauf mit Löschrecht bedeutet das, dass der
/// eine Lauf dem anderen die Dateien unter den Füßen wegzieht
/// (docs/TESTMATRIX_IOS_WINDOWS.md, B14).
///
/// **Wie.** Eine kleine Datei im Zielordner: `.fibu/lock.json`. Wer syncen
/// will, liest sie zuerst. Hält ein anderes Gerät eine frische Sperre, wird
/// übersprungen. Der Herzschlag wird während des Laufs erneuert, damit eine
/// abgestürzte App die Sperre nicht für immer blockiert.
///
/// **Bewusst fail-open.** Ist die Sperre nicht les- oder schreibbar (Provider
/// ohne Schreibrecht, Netzwerkflackern), wird trotzdem gesynct. Eine Sperre
/// ist eine Koordination, keine Sicherheitsgarantie — sie still zu verlieren
/// wäre schlechter als ohne sie zu laufen. Jeder Fall wird geloggt.
class SyncLock {
  SyncLock._();

  static const String _fileName = '.fibu/lock.json';

  /// Ab diesem Alter gilt eine Sperre als verwaist und wird übernommen.
  /// Kurz genug, dass ein Absturz nicht lange blockiert; lang genug, dass ein
  /// langsamer Lauf auf einem großen Bestand nicht unterbrochen wirkt.
  static const Duration staleAfter = Duration(minutes: 5);

  /// Wie oft der Herzschlag erneuert wird.
  static const Duration heartbeatEvery = Duration(seconds: 60);

  static Timer? _heartbeat;
  static String? _heldPath;

  static String _lockPath(String remotePath) => remotePath.isEmpty
      ? _fileName
      : '${remotePath.replaceAll(RegExp(r'/$'), '')}/$_fileName';

  /// Versucht, die Sperre für [remotePath] zu bekommen.
  ///
  /// Liefert null bei Erfolg, sonst eine menschenlesbare Begründung, wer die
  /// Sperre hält.
  static Future<String?> acquire(
    RcloneService rclone,
    String remoteName,
    String remotePath,
  ) async {
    final path = _lockPath(remotePath);
    final myId = await DeviceIdentity.id();
    final now = DateTime.now();

    Map<String, dynamic>? existing;
    try {
      final content = await rclone.catFile(remoteName, path);
      if (content != null && content.trim().isNotEmpty) {
        final decoded = jsonDecode(content);
        if (decoded is Map) existing = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Nicht lesbar → fail-open, aber nicht still.
      AppLog.info('sync',
          'Sync-Sperre nicht lesbar ($remoteName:$path) — Lauf wird nicht blockiert');
    }

    if (existing != null) {
      final holderId = existing['deviceId'] as String? ?? '';
      final holderName = existing['hostname'] as String? ?? holderId;
      final heartbeat =
          DateTime.tryParse(existing['heartbeatAt'] as String? ?? '');

      final isMine = holderId == myId;
      final isStale = heartbeat == null || now.difference(heartbeat) > staleAfter;

      if (!isMine && !isStale) {
        final reason = '$holderName';
        AppLog.info('sync',
            'Sync übersprungen: $reason hält die Sperre für $remoteName:$remotePath');
        return reason;
      }
      if (!isMine && isStale) {
        AppLog.info('sync',
            'Verwaiste Sperre von $holderName übernommen (älter als ${staleAfter.inMinutes} Minuten)');
      }
    }

    await _write(rclone, remoteName, path, myId, now);
    _heldPath = '$remoteName:$path';
    _startHeartbeat(rclone, remoteName, path, myId);
    return null;
  }

  /// Gibt die Sperre frei und stoppt den Herzschlag.
  static Future<void> release(
    RcloneService rclone,
    String remoteName,
    String remotePath,
  ) async {
    _heartbeat?.cancel();
    _heartbeat = null;
    final held = _heldPath;
    _heldPath = null;
    if (held != '$remoteName:${_lockPath(remotePath)}') return;

    final myId = await DeviceIdentity.id();
    try {
      // Nur freigeben, wenn sie wirklich uns gehört — sonst würden wir die
      // Sperre eines Geräts löschen, das sie inzwischen übernommen hat.
      final content = await rclone.catFile(remoteName, _lockPath(remotePath));
      if (content != null) {
        final decoded = jsonDecode(content);
        if (decoded is Map && decoded['deviceId'] != myId) return;
      }
    } catch (_) {
      return;
    }
    try {
      final empty = File('${Directory.systemTemp.path}/fibu_lock_release.json');
      await empty.writeAsString('');
      await rclone.copyFileToRemote(empty.path, remoteName, _lockPath(remotePath));
    } catch (_) {
      // Eine liegengebliebene Sperre verfällt nach staleAfter von selbst.
    }
  }

  static void _startHeartbeat(
      RcloneService rclone, String remoteName, String path, String myId) {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(heartbeatEvery, (_) async {
      await _write(rclone, remoteName, path, myId, DateTime.now());
    });
  }

  static Future<void> _write(RcloneService rclone, String remoteName,
      String path, String myId, DateTime at) async {
    try {
      final tmp = File('${Directory.systemTemp.path}/fibu_lock.json');
      await tmp.writeAsString(jsonEncode({
        'deviceId': myId,
        'hostname': await DeviceIdentity.displayName(),
        'acquiredAt': at.toIso8601String(),
        'heartbeatAt': at.toIso8601String(),
      }));
      await rclone.copyFileToRemote(tmp.path, remoteName, path);
    } catch (e) {
      AppLog.info('sync', 'Sync-Sperre nicht schreibbar: $e — fail-open');
    }
  }
}

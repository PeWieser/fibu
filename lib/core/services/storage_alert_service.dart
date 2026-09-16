import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../localization/app_strings.dart';
import 'app_log_service.dart';

/// System-Benachrichtigungen für Zustände, die der Nutzer auch dann sehen
/// muss, wenn er gerade nicht auf die App schaut — insbesondere bei
/// Hintergrund-/Planer-Läufen.
///
/// Bewusst KEIN neues Pub-Paket: iOS läuft über den bestehenden
/// MethodChannel-Muster (`fibu/*`, siehe `AppDelegate.swift` →
/// UNUserNotificationCenter), Windows über einen systemeigenen
/// NotifyIcon-Balloon via PowerShell. Beides ohne neue Abhängigkeiten.
///
/// Grundregel: Benachrichtigungen sind reine Kür — sie dürfen NIEMALS einen
/// Lauf stören. Jeder Fehler wird protokolliert und geschluckt.
class StorageAlertService {
  StorageAlertService._();

  static const MethodChannel _channel = MethodChannel('fibu/notifications');

  /// Zeigt eine lokale System-Benachrichtigung.
  static Future<void> show(String title, String body) async {
    try {
      if (kIsWeb) return;
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _channel.invokeMethod<void>(
            'show', <String, dynamic>{'title': title, 'body': body});
        return;
      }
      if (defaultTargetPlatform == TargetPlatform.windows) {
        // Fire-and-forget: Der Balloon-Prozess hält das Icon ~10 s sichtbar
        // und darf den Lauf nicht aufhalten (der sonst 10 s länger „läuft").
        unawaited(_showWindowsBalloon(title, body));
        return;
      }
      AppLog.info('notify', 'Benachrichtigung (nicht unterstützt): $title — $body');
    } catch (e) {
      AppLog.warn('notify', 'Benachrichtigung konnte nicht gezeigt werden: $e');
    }
  }

  /// Zielspeicher (Cloud) voll — Uploads wurden übersprungen.
  static Future<void> cloudFull() {
    final s = AppStrings.current;
    AppLog.warn('notify', 'Push: Cloud-Speicher voll');
    return show(s.notifStorageFullTitle, s.notifCloudFullBody);
  }

  /// Lokaler Gerätespeicher voll — Downloads wurden übersprungen.
  static Future<void> localFull() {
    final s = AppStrings.current;
    AppLog.warn('notify', 'Push: Lokaler Speicher voll');
    return show(s.notifStorageFullTitle, s.notifLocalFullBody);
  }

  /// Windows-Balloon über Bordmittel (System.Windows.Forms.NotifyIcon) —
  /// ohne Zusatzpakete. Die kurze Wartezeit hält das Icon sichtbar, bis der
  /// Balloon abgeklungen ist.
  static Future<void> _showWindowsBalloon(String title, String body) async {
    try {
      String esc(String v) =>
          v.replaceAll("'", "''").replaceAll('\n', ' ').trim();
      final script = 'Add-Type -AssemblyName System.Windows.Forms; '
          '\$n = New-Object System.Windows.Forms.NotifyIcon; '
          '\$n.Icon = [System.Drawing.SystemIcons]::Information; '
          '\$n.Visible = \$true; '
          "\$n.BalloonTipTitle = '${esc(title)}'; "
          "\$n.BalloonTipText = '${esc(body)}'; "
          '\$n.ShowBalloonTip(10000); '
          'Start-Sleep -Seconds 11; '
          '\$n.Dispose()';
      await Process.start('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-WindowStyle',
        'Hidden',
        '-Command',
        script,
      ]);
    } catch (e) {
      AppLog.warn('notify', 'Windows-Balloon konnte nicht gestartet werden: $e');
    }
  }
}

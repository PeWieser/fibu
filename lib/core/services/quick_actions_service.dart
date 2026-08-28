import 'package:flutter/foundation.dart';
import 'package:quick_actions/quick_actions.dart';

import 'app_log_service.dart';

/// iOS-Homescreen-Kontextmenü (langes Drücken aufs App-Icon):
/// Quick Action „Jetzt synchronisieren“.
///
/// Läuft nur auf iOS (dort nativ; dynamische Shortcuts brauchen keinerlei
/// Info.plist-Einträge). [onSyncNow] wird beim Tippen aufgerufen – auch beim
/// Kaltstart: `initialize` liefert den Action-Type nach, mit dem die App
/// gestartet wurde.
class QuickActionsService {
  QuickActionsService._();

  static final QuickActionsService instance = QuickActionsService._();

  static const String syncNowType = 'fibu.sync_now';

  bool _registered = false;

  void setup({required String syncNowLabel, required void Function() onSyncNow}) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    if (_registered) return;
    _registered = true;

    const actions = QuickActions();
    actions.initialize((String type) {
      if (type == syncNowType) {
        AppLog.info('quickaction', 'Homescreen-Aktion „Jetzt synchronisieren“ getippt');
        onSyncNow();
      }
    });
    actions.setShortcutItems(<ShortcutItem>[
      ShortcutItem(
        type: syncNowType,
        localizedTitle: syncNowLabel,
        // SF Symbol auf iOS (quick_actions_ios unterstützt Symbolnamen).
        icon: 'arrow.triangle.2.circlepath',
      ),
    ]);
    AppLog.info('quickaction', 'Quick Actions registriert');
  }
}

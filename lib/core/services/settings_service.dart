import 'dart:convert';
import 'dart:io';
import '../utils/app_paths.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/theme.dart';
import '../../theme/sanzo_wada_palettes.dart';
import '../localization/locale_provider.dart';

/// Persistent data transfer object for application settings.
class AppSettingsData {
  final ThemeConfig themeConfig;
  final AppLocale locale;
  final bool wifiOnlySync;

  const AppSettingsData({
    required this.themeConfig,
    required this.locale,
    this.wifiOnlySync = true,
  });

  Map<String, dynamic> toJson() => {
    'syncWithSystem': themeConfig.syncWithSystem,
    'forceDarkMode': themeConfig.forceDarkMode,
    'selectedLightPalette': themeConfig.selectedLightPalette?.name,
    'selectedDarkPalette': themeConfig.selectedDarkPalette?.name,
    'locale': locale.name,
    'wifiOnlySync': wifiOnlySync,
  };

  factory AppSettingsData.fromJson(Map<String, dynamic> json) {
    SanzoWadaPalette? lightPal;
    SanzoWadaPalette? darkPal;

    if (json['selectedLightPalette'] != null) {
      try {
        lightPal = SanzoWadaPalette.values.firstWhere(
          (p) => p.name == json['selectedLightPalette'],
        );
      } catch (_) {}
    }

    if (json['selectedDarkPalette'] != null) {
      try {
        darkPal = SanzoWadaPalette.values.firstWhere(
          (p) => p.name == json['selectedDarkPalette'],
        );
      } catch (_) {}
    }

    AppLocale loc = AppLocale.de;
    if (json['locale'] != null) {
      try {
        loc = AppLocale.values.firstWhere((l) => l.name == json['locale']);
      } catch (_) {}
    }

    return AppSettingsData(
      themeConfig: ThemeConfig(
        syncWithSystem: json['syncWithSystem'] as bool? ?? true,
        forceDarkMode: json['forceDarkMode'] as bool? ?? false,
        selectedLightPalette: lightPal,
        selectedDarkPalette: darkPal,
      ),
      locale: loc,
      wifiOnlySync: json['wifiOnlySync'] as bool? ?? true,
    );
  }
}

/// Service to persist and load application settings (Theme, Wada Palettes, Locale).
class SettingsService {
  static Future<File> _getFile() async {
    // Privat (App-Support): Nutzer sehen settings.json nicht in der Dateien-App.
    return privateAppFile('settings.json');
  }

  static Future<AppSettingsData?> loadSettings() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> map = json.decode(content);
        return AppSettingsData.fromJson(map);
      }
    } catch (_) {
      // Return null on read error / test environments
    }
    return null;
  }

  static Future<void> saveSettings(
    ThemeConfig themeConfig,
    AppLocale locale, {
    bool? wifiOnlySync,
  }) async {
    try {
      final file = await _getFile();
      bool wifiOnly = wifiOnlySync ?? true;
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          final Map<String, dynamic> map = json.decode(content);
          if (wifiOnlySync == null && map['wifiOnlySync'] != null) {
            wifiOnly = map['wifiOnlySync'] as bool? ?? true;
          }
        } catch (_) {}
      }

      final data = AppSettingsData(
        themeConfig: themeConfig,
        locale: locale,
        wifiOnlySync: wifiOnlySync ?? wifiOnly,
      );
      await file.writeAsString(json.encode(data.toJson()));
    } catch (_) {
      // Ignore write errors in test environments
    }
  }

  static Future<void> setWifiOnlySync(bool wifiOnly) async {
    try {
      final current = await loadSettings();
      if (current != null) {
        await saveSettings(
          current.themeConfig,
          current.locale,
          wifiOnlySync: wifiOnly,
        );
      } else {
        await saveSettings(
          const ThemeConfig(),
          AppLocale.de,
          wifiOnlySync: wifiOnly,
        );
      }
    } catch (_) {}
  }
}

/// StateNotifier for WiFi-Only Sync setting.
class WifiOnlySyncNotifier extends StateNotifier<bool> {
  WifiOnlySyncNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final settings = await SettingsService.loadSettings();
    if (settings != null) {
      state = settings.wifiOnlySync;
    }
  }

  Future<void> setWifiOnly(bool value) async {
    state = value;
    await SettingsService.setWifiOnlySync(value);
  }
}

final wifiOnlySyncProvider = StateNotifierProvider<WifiOnlySyncNotifier, bool>((ref) {
  return WifiOnlySyncNotifier();
});

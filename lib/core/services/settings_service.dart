import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../../theme/theme.dart';
import '../../theme/sanzo_wada_palettes.dart';
import '../localization/locale_provider.dart';

/// Persistent data transfer object for application settings.
class AppSettingsData {
  final ThemeConfig themeConfig;
  final AppLocale locale;
  final bool onboardingCompleted;

  const AppSettingsData({
    required this.themeConfig,
    required this.locale,
    this.onboardingCompleted = false,
  });

  Map<String, dynamic> toJson() => {
    'syncWithSystem': themeConfig.syncWithSystem,
    'forceDarkMode': themeConfig.forceDarkMode,
    'selectedLightPalette': themeConfig.selectedLightPalette?.name,
    'selectedDarkPalette': themeConfig.selectedDarkPalette?.name,
    'locale': locale.name,
    'onboardingCompleted': onboardingCompleted,
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
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
    );
  }
}

/// Service to persist and load application settings (Theme, Wada Palettes, Locale, Onboarding).
class SettingsService {
  static Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/settings.json');
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
    bool? onboardingCompleted,
  }) async {
    try {
      final file = await _getFile();
      bool completed = onboardingCompleted ?? false;
      if (await file.exists() && onboardingCompleted == null) {
        try {
          final content = await file.readAsString();
          final Map<String, dynamic> map = json.decode(content);
          completed = map['onboardingCompleted'] as bool? ?? false;
        } catch (_) {}
      }

      final data = AppSettingsData(
        themeConfig: themeConfig,
        locale: locale,
        onboardingCompleted: onboardingCompleted ?? completed,
      );
      await file.writeAsString(json.encode(data.toJson()));
    } catch (_) {
      // Ignore write errors in test environments
    }
  }

  static Future<void> setOnboardingCompleted(bool completed) async {
    try {
      final current = await loadSettings();
      if (current != null) {
        await saveSettings(
          current.themeConfig,
          current.locale,
          onboardingCompleted: completed,
        );
      } else {
        await saveSettings(
          const ThemeConfig(),
          AppLocale.de,
          onboardingCompleted: completed,
        );
      }
    } catch (_) {}
  }
}

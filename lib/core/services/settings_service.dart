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

  const AppSettingsData({
    required this.themeConfig,
    required this.locale,
  });

  Map<String, dynamic> toJson() => {
    'syncWithSystem': themeConfig.syncWithSystem,
    'forceDarkMode': themeConfig.forceDarkMode,
    'selectedLightPalette': themeConfig.selectedLightPalette?.name,
    'selectedDarkPalette': themeConfig.selectedDarkPalette?.name,
    'locale': locale.name,
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
    );
  }
}

/// Service to persist and load application settings (Theme, Wada Palettes, Locale).
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

  static Future<void> saveSettings(ThemeConfig themeConfig, AppLocale locale) async {
    try {
      final file = await _getFile();
      final data = AppSettingsData(themeConfig: themeConfig, locale: locale);
      await file.writeAsString(json.encode(data.toJson()));
    } catch (_) {
      // Ignore write errors in test environments
    }
  }
}

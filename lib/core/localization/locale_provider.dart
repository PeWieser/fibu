import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Selection mode for language: System default or manual override.
enum AppLocaleMode {
  system,
  de,
  en;

  String get displayName {
    switch (this) {
      case AppLocaleMode.system:
        return 'System (Automatisch)';
      case AppLocaleMode.de:
        return 'Deutsch';
      case AppLocaleMode.en:
        return 'English';
    }
  }
}

/// Supported resolved locales in Fibu: German and English.
enum AppLocale {
  de(Locale('de', 'DE'), 'Deutsch'),
  en(Locale('en', 'US'), 'English');

  final Locale locale;
  final String displayName;

  const AppLocale(this.locale, this.displayName);
}

/// State notifier managing the language selection mode (system, de, en).
class LocaleModeNotifier extends StateNotifier<AppLocaleMode> {
  LocaleModeNotifier() : super(AppLocaleMode.de) {
    _loadLocaleMode();
  }

  Future<File> _getSettingsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/settings.json');
  }

  Future<void> _loadLocaleMode() async {
    try {
      final file = await _getSettingsFile();
      if (file.existsSync()) {
        final content = await file.readAsString();
        final Map<String, dynamic> data = json.decode(content);
        if (data['localeMode'] != null) {
          final mode = AppLocaleMode.values.firstWhere(
            (m) => m.name == data['localeMode'],
            orElse: () => AppLocaleMode.de,
          );
          state = mode;
        } else if (data['locale'] != null) {
          final legacyName = data['locale'] as String;
          if (legacyName == 'de') state = AppLocaleMode.de;
          if (legacyName == 'en') state = AppLocaleMode.en;
        }
      }
    } catch (_) {}
  }

  Future<void> _persistSettings() async {
    try {
      final file = await _getSettingsFile();
      Map<String, dynamic> data = {};
      if (file.existsSync()) {
        try {
          data = json.decode(await file.readAsString());
        } catch (_) {}
      }
      data['localeMode'] = state.name;
      await file.writeAsString(json.encode(data));
    } catch (_) {}
  }

  void setLocaleMode(AppLocaleMode mode) {
    state = mode;
    _persistSettings();
  }

  void setLocale(AppLocale locale) {
    if (locale == AppLocale.de) {
      setLocaleMode(AppLocaleMode.de);
    } else {
      setLocaleMode(AppLocaleMode.en);
    }
  }

  void toggleLocale() {
    if (state == AppLocaleMode.de) {
      setLocaleMode(AppLocaleMode.en);
    } else {
      setLocaleMode(AppLocaleMode.de);
    }
  }
}

/// Riverpod provider for the language configuration mode (system / de / en).
final localeModeProvider = StateNotifierProvider<LocaleModeNotifier, AppLocaleMode>((ref) {
  return LocaleModeNotifier();
});

/// Riverpod provider delivering the resolved active AppLocale (de or en).
final localeProvider = Provider<AppLocale>((ref) {
  final mode = ref.watch(localeModeProvider);
  if (mode == AppLocaleMode.de) return AppLocale.de;
  if (mode == AppLocaleMode.en) return AppLocale.en;

  // Resolve from device/system/iOS per-app language setting
  final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
  final code = systemLocale.languageCode.toLowerCase();
  if (code.startsWith('en')) {
    return AppLocale.en;
  }
  return AppLocale.de;
});

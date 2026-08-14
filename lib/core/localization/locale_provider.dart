import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Supported locales in Fibu: German and English.
enum AppLocale {
  de(Locale('de', 'DE'), 'Deutsch'),
  en(Locale('en', 'US'), 'English');

  final Locale locale;
  final String displayName;

  const AppLocale(this.locale, this.displayName);
}

/// State notifier managing the user's selected language with persistence.
class LocaleNotifier extends StateNotifier<AppLocale> {
  LocaleNotifier() : super(AppLocale.de) {
    _loadLocale();
  }

  Future<File> _getSettingsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/settings.json');
  }

  Future<void> _loadLocale() async {
    try {
      final file = await _getSettingsFile();
      if (file.existsSync()) {
        final content = await file.readAsString();
        final Map<String, dynamic> data = json.decode(content);
        if (data['locale'] != null) {
          final loc = AppLocale.values.firstWhere(
            (l) => l.name == data['locale'],
            orElse: () => AppLocale.de,
          );
          state = loc;
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
      data['locale'] = state.name;
      await file.writeAsString(json.encode(data));
    } catch (_) {}
  }

  void setLocale(AppLocale locale) {
    state = locale;
    _persistSettings();
  }

  void toggleLocale() {
    state = state == AppLocale.de ? AppLocale.en : AppLocale.de;
    _persistSettings();
  }
}

/// Riverpod provider for the active app locale.
final localeProvider = StateNotifierProvider<LocaleNotifier, AppLocale>((ref) {
  return LocaleNotifier();
});

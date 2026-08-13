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

/// State notifier managing the user's selected language.
class LocaleNotifier extends StateNotifier<AppLocale> {
  LocaleNotifier() : super(AppLocale.de);

  void setLocale(AppLocale locale) {
    state = locale;
  }

  void toggleLocale() {
    state = state == AppLocale.de ? AppLocale.en : AppLocale.de;
  }
}

/// Riverpod provider for the active app locale.
final localeProvider = StateNotifierProvider<LocaleNotifier, AppLocale>((ref) {
  return LocaleNotifier();
});

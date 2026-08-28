import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fibu/core/localization/locale_provider.dart';
import 'package:fibu/core/localization/app_strings.dart';

void main() {
  group('LocaleMode and System Language Tests', () {
    test('default localeMode follows the system', () {
      // Default ist `system` (Sprache des Geräts) — passend zum Loader, der
      // unbekannte Persistenzwerte ebenfalls auf `system` zurückfallen lässt.
      final container = ProviderContainer();
      final mode = container.read(localeModeProvider);
      expect(mode, AppLocaleMode.system);
    });

    test('setting localeMode to de and en updates active localeProvider', () {
      final container = ProviderContainer();
      
      container.read(localeModeProvider.notifier).setLocaleMode(AppLocaleMode.de);
      expect(container.read(localeProvider), AppLocale.de);
      
      container.read(localeModeProvider.notifier).setLocaleMode(AppLocaleMode.en);
      expect(container.read(localeProvider), AppLocale.en);
    });

    test('AppStrings provides correct About and system language translations', () {
      const deStrings = AppStrings(AppLocale.de);
      expect(deStrings.aboutSectionTitle, 'Über Fibu');
      expect(deStrings.systemLanguage, 'System (Automatisch)');
      expect(deStrings.appVersionValue, '1.0.0 (Build 1)');
      expect(deStrings.licenseValue, 'MIT License');

      const enStrings = AppStrings(AppLocale.en);
      expect(enStrings.aboutSectionTitle, 'About Fibu');
      expect(enStrings.systemLanguage, 'System (Automatic)');
      expect(enStrings.appVersionValue, '1.0.0 (Build 1)');
    });
  });
}

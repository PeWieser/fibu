import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/settings_service.dart';

/// State notifier managing whether the user has completed the onboarding flow.
class OnboardingNotifier extends StateNotifier<bool> {
  OnboardingNotifier() : super(false) {
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    try {
      final settings = await SettingsService.loadSettings();
      if (settings != null) {
        state = settings.onboardingCompleted;
      }
    } catch (_) {
      // Fallback to default false in test / offline environments
    }
  }

  /// Marks onboarding as complete and persists the setting.
  Future<void> completeOnboarding() async {
    state = true;
    await SettingsService.setOnboardingCompleted(true);
  }

  /// Resets onboarding status back to incomplete (useful for re-runs / tests).
  Future<void> resetOnboarding() async {
    state = false;
    await SettingsService.setOnboardingCompleted(false);
  }
}

/// Riverpod provider for tracking and mutating onboarding completion state.
final onboardingControllerProvider =
    StateNotifierProvider<OnboardingNotifier, bool>((ref) {
  return OnboardingNotifier();
});

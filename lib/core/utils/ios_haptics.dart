import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Native iOS haptic feedback helpers (wrapped so desktop/Android stay silent).
///
/// Use these for confirmations and state changes to give the app a native
/// "feel" without blocking the UI thread.
abstract class IosHaptics {
  static bool get _supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Light tap feedback (selection, toggle).
  static void light() {
    if (_supported) HapticFeedback.lightImpact();
  }

  /// Medium feedback (confirmation, task created).
  static void medium() {
    if (_supported) HapticFeedback.mediumImpact();
  }

  /// Success/notification-style feedback (sync completed).
  static void success() {
    if (_supported) HapticFeedback.heavyImpact();
  }

  /// Selection change feedback.
  static void selection() {
    if (_supported) HapticFeedback.selectionClick();
  }
}

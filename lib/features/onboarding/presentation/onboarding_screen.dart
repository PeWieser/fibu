import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../theme/theme.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/services/app_log_service.dart';
import '../../../core/utils/ios_haptics.dart';
import 'onboarding_controller.dart';

/// Ein einziges, ruhiges Onboarding: ein Hinweis, ein Button.
///
/// Fragt die Foto-/Mediathek-Berechtigung ab. Sobald erteilt → kurze
/// Bestätigung (Häkchen + Haptik) → ausblenden → direkt in die App.
/// Wird die Berechtigung abgelehnt, wird der Button zum Pfad in die
/// Systemeinstellungen (kein Dead-End, keine weiteren Seiten).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _requesting = false;
  bool _granted = false;
  bool _denied = false;
  bool _fadingOut = false;

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<void> _complete() async {
    await ref.read(onboardingControllerProvider.notifier).completeOnboarding();
  }

  /// Fordert den Fotozugriff an; bei Erfolg kurze Bestätigung → ausblenden.
  Future<void> _requestAccess() async {
    if (_requesting) return;
    setState(() => _requesting = true);

    // Auf Desktop gibt es keine System-Mediathek — kein Grund zu blockieren.
    if (!_isMobile) {
      await _complete();
      return;
    }

    try {
      final ps = await PhotoManager.requestPermissionExtend();
      final granted = ps.isAuth || ps.hasAccess;
      AppLog.info('media', granted
          ? 'Foto/Mediathek-Berechtigung erteilt'
          : 'Foto/Mediathek-Berechtigung verweigert');
      if (!mounted) return;

      if (granted) {
        IosHaptics.success();
        setState(() {
          _requesting = false;
          _granted = true;
        });
        // Kurz die Bestätigung zeigen, dann sanft ausblenden und fertig.
        await Future.delayed(const Duration(milliseconds: 850));
        if (!mounted) return;
        setState(() => _fadingOut = true);
        await Future.delayed(const Duration(milliseconds: 220));
        if (!mounted) return;
        await _complete();
      } else {
        // Abgelehnt → iOS zeigt den nativen Prompt nicht mehr automatisch.
        setState(() {
          _requesting = false;
          _denied = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _requesting = false);
    }
  }

  /// Nach einer Ablehnung: direkt in die Systemeinstellungen, danach neu prüfen.
  Future<void> _openSettings() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    try {
      try {
        await PhotoManager.openSetting();
      } catch (_) {}
      final ps = await PhotoManager.requestPermissionExtend();
      final granted = ps.isAuth || ps.hasAccess;
      if (!mounted) return;
      if (granted) {
        IosHaptics.success();
        setState(() {
          _requesting = false;
          _granted = true;
          _denied = false;
        });
        await Future.delayed(const Duration(milliseconds: 850));
        if (!mounted) return;
        setState(() => _fadingOut = true);
        await Future.delayed(const Duration(milliseconds: 220));
        if (!mounted) return;
        await _complete();
      } else {
        setState(() => _requesting = false);
      }
    } catch (_) {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appThemeProvider);
    final strings = ref.watch(stringsProvider);

    final body = AnimatedOpacity(
      opacity: _fadingOut ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _granted
                ? _buildDone(theme, strings)
                : _buildAsk(theme, strings),
          ),
        ),
      ),
    );

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return CupertinoPageScaffold(
        backgroundColor: theme.canvas,
        child: SafeArea(child: body),
      );
    }
    return material.Scaffold(
      backgroundColor: theme.canvas,
      body: SafeArea(child: body),
    );
  }

  Widget _buildAsk(AppThemeData theme, AppStrings strings) {
    return Column(
      key: const ValueKey('ask'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: theme.accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(CupertinoIcons.photo_on_rectangle, size: 44, color: theme.accent),
        ),
        const SizedBox(height: 28),
        Text(
          strings.onboardingAccessTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: theme.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          strings.onboardingAccessHint,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            height: 1.4,
            color: theme.textSecondary,
          ),
        ),
        const SizedBox(height: 32),
        _primaryButton(
          theme,
          label: _denied ? strings.onboardingOpenSettings : strings.onboardingAllowAccess,
          onPressed: _requesting ? null : (_denied ? _openSettings : _requestAccess),
        ),
      ],
    );
  }

  Widget _buildDone(AppThemeData theme, AppStrings strings) {
    return Column(
      key: const ValueKey('done'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: theme.success.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(
            CupertinoIcons.checkmark_alt_circle_fill,
            size: 52,
            color: theme.success,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          strings.onboardingAccessGranted,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: theme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _primaryButton(
    AppThemeData theme, {
    required String label,
    required VoidCallback? onPressed,
  }) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            color: theme.accent,
            disabledColor: theme.accent.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(14),
            padding: const EdgeInsets.symmetric(vertical: 14),
            onPressed: onPressed,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFFFFFFF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: material.FilledButton(
        style: material.FilledButton.styleFrom(
          backgroundColor: theme.accent,
          foregroundColor: material.Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

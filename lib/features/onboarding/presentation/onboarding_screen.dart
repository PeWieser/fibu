import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../theme/theme.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/services/app_log_service.dart';
import '../../../core/services/rclone_provider.dart';
import '../../../core/services/remote_registry_service.dart';
import '../../settings/presentation/cloud_drives_screen.dart';
import 'onboarding_controller.dart';

/// A deliberately minimal, Apple-style first-run flow with exactly three focused
/// steps: Welcome → Connect a cloud → Grant permissions. Everything else lives in
/// Settings so the first launch stays calm and uncluttered.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;
  bool _photosGranted = false;

  static const _lastStep = 2;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    setState(() => _index = page);
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _next() async {
    if (_index < _lastStep) {
      _goTo(_index + 1);
      return;
    }

    // The photo permission is mandatory: media backups (created later via the
    // task wizard) cannot work without it, so onboarding must not finish
    // before it has been granted. Ask for it if the user tries to skip.
    if (!_photosGranted) {
      await _requestPhotos();
    }
    if (!_photosGranted || !mounted) return;

    await ref.read(onboardingControllerProvider.notifier).completeOnboarding();
  }

  /// Requests the photo/media permission and updates [_photosGranted].
  /// When the permission was declined, an explanation dialog is shown that
  /// also offers opening the system settings (recovery path for a previously
  /// denied permission).
  Future<void> _requestPhotos() async {
    final granted = await _requestPhotoPermission();
    AppLog.info('media', granted
        ? 'Foto/Mediathek-Berechtigung erteilt'
        : 'Foto/Mediathek-Berechtigung verweigert – Hinweisdialog gezeigt');
    if (!mounted) return;
    setState(() => _photosGranted = granted);
    if (!granted) {
      await _showPhotoAccessRequiredDialog();
    }
  }

  /// Returns whether the photo permission is granted, requesting it from the
  /// operating system when necessary.
  Future<bool> _requestPhotoPermission() async {
    if (_photosGranted) return true;

    // photo_manager only exists on mobile platforms (Android, iOS, macOS).
    // On desktop there is no system photo library, so the permission cannot
    // be required there.
    if (!kIsWeb &&
        defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return true;
    }

    try {
      final ps = await PhotoManager.requestPermissionExtend();
      return ps.isAuth || ps.hasAccess;
    } catch (_) {
      // Plugin unavailable (e.g. desktop builds or widget tests running on a
      // bare Dart VM) – do not hard-block onboarding in that case.
      return true;
    }
  }

  /// Tells the user that photo access is mandatory and offers a shortcut to
  /// the system settings – the way to recover when iOS/Android no longer shows
  /// the permission prompt after a denial.
  Future<void> _showPhotoAccessRequiredDialog() async {
    final strings = ref.read(stringsProvider);

    final openSettings = defaultTargetPlatform == TargetPlatform.iOS
        ? await showCupertinoDialog<bool>(
            context: context,
            builder: (dialogCtx) => CupertinoAlertDialog(
              title: Text(strings.onboardingPhotoAccessRequiredTitle),
              content: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(strings.onboardingPhotoAccessRequiredMessage),
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: Text(strings.cancel),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  child: Text(strings.openSystemSettings),
                ),
              ],
            ),
          )
        : await material.showDialog<bool>(
            context: context,
            builder: (dialogCtx) => material.AlertDialog(
              title: Text(strings.onboardingPhotoAccessRequiredTitle),
              content: Text(strings.onboardingPhotoAccessRequiredMessage),
              actions: [
                material.TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: Text(strings.cancel),
                ),
                material.FilledButton(
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  child: Text(strings.openSystemSettings),
                ),
              ],
            ),
          );

    if (openSettings == true) {
      try {
        await PhotoManager.openSetting();
      } catch (_) {
        // Settings cannot be opened on unsupported platforms – ignore.
      }
      // Re-check the permission after returning from the system settings.
      if (mounted) {
        final granted = await _requestPhotoPermission();
        if (mounted) setState(() => _photosGranted = granted);
      }
    }
  }

  Future<void> _connectCloud() async {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    await Navigator.of(context).push(
      isIOS
          ? CupertinoPageRoute<void>(builder: (_) => const CloudDrivesScreen())
          : material.MaterialPageRoute<void>(builder: (_) => const CloudDrivesScreen()),
    );
    // Refresh the connected-remote count when returning.
    ref.invalidate(remoteEntriesProvider);
    ref.invalidate(remotesProvider);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appThemeProvider);
    final strings = ref.watch(stringsProvider);
    final remotes = ref.watch(remotesProvider);
    final connectedCount = remotes.maybeWhen(data: (r) => r.length, orElse: () => 0);

    final pages = <Widget>[
      _OnboardingPage(
        theme: theme,
        icon: CupertinoIcons.cloud_upload_fill,
        title: strings.onboardingWelcomeTitle,
        subtitle: strings.onboardingWelcomeIntro,
      ),
      _OnboardingPage(
        theme: theme,
        icon: CupertinoIcons.link,
        title: strings.onboardingConnectCloudTitle,
        subtitle: connectedCount > 0
            ? strings.onboardingConnectedCount(connectedCount)
            : strings.onboardingConnectCloudSubtitle,
        action: _ActionButton(
          theme: theme,
          label: connectedCount > 0
              ? strings.onboardingConnectMoreCloud
              : strings.onboardingConnectCloud,
          onPressed: _connectCloud,
        ),
      ),
      _OnboardingPage(
        theme: theme,
        icon: CupertinoIcons.photo_on_rectangle,
        title: strings.onboardingGrantAccessTitle,
        subtitle: strings.onboardingGrantAccessSubtitle,
        action: _ActionButton(
          theme: theme,
          label: _photosGranted ? strings.onboardingPhotosGranted : strings.onboardingAllowPhotos,
          onPressed: _photosGranted ? null : _requestPhotos,
        ),
      ),
    ];

    final isLastStep = _index == _lastStep;
    // Photo access is required to finish onboarding, so the final
    // "Get Started" button stays blocked until the permission was granted.
    final waitingForPhotos = isLastStep && !_photosGranted;

    final body = Column(
      children: [
        Expanded(
          child: PageView(
            controller: _controller,
            onPageChanged: (i) => setState(() => _index = i),
            children: pages,
          ),
        ),
        _Dots(count: pages.length, index: _index, color: theme.accent),
        if (waitingForPhotos) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              strings.onboardingPhotosRequiredHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: _ActionButton(
            theme: theme,
            label: isLastStep ? strings.onboardingGetStarted : strings.onboardingNext,
            filled: true,
            onPressed: waitingForPhotos ? null : _next,
          ),
        ),
      ],
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
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.theme,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final AppThemeData theme;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: theme.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 44, color: theme.accent),
          ),
          const SizedBox(height: 32),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: theme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.4,
              color: theme.textSecondary,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 28),
            action!,
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.theme,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final AppThemeData theme;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (filled) {
        final enabled = onPressed != null;
        return ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: theme.accent,
              // Deaktiviert: deutlich sichtbarer, gedimmter Hintergrund +
              // explizit weißer Text (sonst wirkt der Button „leer“).
              disabledColor: theme.accent.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(14),
              padding: const EdgeInsets.symmetric(vertical: 14),
              onPressed: onPressed,
              child: Text(
                label,
                style: TextStyle(
                  color: enabled
                      ? const Color(0xFFFFFFFF)
                      : const Color(0xFFFFFFFF).withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }
      return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: CupertinoButton(
          onPressed: onPressed,
          child: Text(label, style: TextStyle(color: theme.accent, fontWeight: FontWeight.w600)),
        ),
      );
    }

    if (filled) {
      return SizedBox(
        width: double.infinity,
        child: material.FilledButton(
          style: material.FilledButton.styleFrom(
            backgroundColor: theme.accent,
            foregroundColor: material.Colors.white,
            disabledBackgroundColor:
                theme.accent.withValues(alpha: 0.25),
            disabledForegroundColor:
                material.Colors.white.withValues(alpha: 0.85),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: onPressed,
          child: Text(label),
        ),
      );
    }
    return material.OutlinedButton(
      onPressed: onPressed,
      child: Text(label, style: TextStyle(color: theme.accent)),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index, required this.color});

  final int count;
  final int index;
  final material.Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? color : color.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

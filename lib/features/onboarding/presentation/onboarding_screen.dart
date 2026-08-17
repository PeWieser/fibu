import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../theme/theme.dart';
import '../../../core/services/rclone_provider.dart';
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
    } else {
      await ref.read(onboardingControllerProvider.notifier).completeOnboarding();
    }
  }

  Future<void> _requestPhotos() async {
    final ps = await PhotoManager.requestPermissionExtend();
    if (mounted) {
      setState(() => _photosGranted = ps.isAuth || ps.hasAccess);
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
    ref.invalidate(remotesProvider);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appThemeProvider);
    final remotes = ref.watch(remotesProvider);
    final connectedCount = remotes.maybeWhen(data: (r) => r.length, orElse: () => 0);

    final pages = <Widget>[
      _OnboardingPage(
        theme: theme,
        icon: CupertinoIcons.cloud_upload_fill,
        title: 'Willkommen bei Fibu',
        subtitle:
            'Deine Fotos und Dateien – sicher in deiner eigenen Cloud gespiegelt. '
            'In drei kurzen Schritten bist du startklar.',
      ),
      _OnboardingPage(
        theme: theme,
        icon: CupertinoIcons.link,
        title: 'Cloud verbinden',
        subtitle: connectedCount > 0
            ? '$connectedCount Cloud${connectedCount == 1 ? '' : 's'} verbunden. Du kannst weitere später in den Einstellungen hinzufügen.'
            : 'Verbinde einen Cloud-Speicher (z. B. Google Drive, OneDrive, Dropbox), '
                'damit Fibu deine Daten dorthin sichern kann.',
        action: _ActionButton(
          theme: theme,
          label: connectedCount > 0 ? 'Weitere Cloud verbinden' : 'Cloud verbinden',
          onPressed: _connectCloud,
        ),
      ),
      _OnboardingPage(
        theme: theme,
        icon: CupertinoIcons.photo_on_rectangle,
        title: 'Zugriff erlauben',
        subtitle:
            'Fibu braucht Zugriff auf deine Fotos und Dateien, um sie zu sichern. '
            'Der Zugriff bleibt lokal auf deinem Gerät.',
        action: _ActionButton(
          theme: theme,
          label: _photosGranted ? 'Fotozugriff erteilt ✓' : 'Fotos erlauben',
          onPressed: _photosGranted ? null : _requestPhotos,
        ),
      ),
    ];

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
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: _ActionButton(
            theme: theme,
            label: _index == _lastStep ? 'Loslegen' : 'Weiter',
            filled: true,
            onPressed: _next,
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
        return SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            color: theme.accent,
            borderRadius: BorderRadius.circular(14),
            onPressed: onPressed,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        );
      }
      return CupertinoButton(
        onPressed: onPressed,
        child: Text(label, style: TextStyle(color: theme.accent, fontWeight: FontWeight.w600)),
      );
    }

    if (filled) {
      return SizedBox(
        width: double.infinity,
        child: material.FilledButton(
          style: material.FilledButton.styleFrom(
            backgroundColor: theme.accent,
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

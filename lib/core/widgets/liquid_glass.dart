import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/theme.dart';
import '../services/liquid_glass_service.dart';

/// Natives Liquid-Glass-Panel (iOS 26+) bzw. unveränderte Surface-Karte davor.
///
/// Ab iOS 26: UIKit [UIGlassEffect] in einer Platform-View.
/// Unter iOS 26 / Android / Windows: [fallback] oder opake [theme.surface]-Karte.
class LiquidGlassPanel extends ConsumerWidget {
  const LiquidGlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.fallback,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Widget? fallback;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final radius = borderRadius ?? BorderRadius.circular(theme.radiusLg);
    final glassAsync = ref.watch(liquidGlassAvailableProvider);
    final useGlass = glassAsync.valueOrNull == true &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS;

    final content = padding == null
        ? child
        : Padding(padding: padding!, child: child);

    if (!useGlass) {
      if (fallback != null) return fallback!;
      return Container(
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: radius,
          border: Border.all(
            color: theme.textSecondary.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
        clipBehavior: clipBehavior,
        child: content,
      );
    }

    // Glass-View mit IgnorePointer: Platform-Views gewinnen sonst Hit-Tests
    // und blockieren Buttons/Zeilen im Child (Dashboard-Setup etc.).
    return ClipRRect(
      borderRadius: radius,
      clipBehavior: clipBehavior,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: _NativeGlassView(cornerRadius: radius.topLeft.x),
            ),
          ),
          content,
        ],
      ),
    );
  }
}

/// Volle Breite, unten: Glass-Streifen hinter einer transparenten Tab-Bar.
/// Höhe typisch Tab-Bar + Home-Indicator (z. B. 83).
class LiquidGlassTabBarBackdrop extends ConsumerWidget {
  const LiquidGlassTabBarBackdrop({
    super.key,
    required this.height,
  });

  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glassAsync = ref.watch(liquidGlassAvailableProvider);
    final useGlass = glassAsync.valueOrNull == true &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!useGlass) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      width: double.infinity,
      child: const _NativeGlassView(cornerRadius: 0),
    );
  }
}

/// Ob Liquid Glass aktiv ist (für Nav-Bars: transparenter Hintergrund).
bool liquidGlassActive(WidgetRef ref) {
  return ref.watch(liquidGlassAvailableProvider).valueOrNull == true &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.iOS;
}

/// Hintergrundfarbe für Cupertino-Nav-Bars: transparent bei Glass, sonst surface.
Color iosBarBackground(WidgetRef ref, AppThemeData theme) {
  // Derselbe abgesetzte Ton wie die TabBar, damit beide Leisten als eigene
  // Ebene erkennbar bleiben (Freifläche und Karten teilen sich eine Farbe).
  return liquidGlassActive(ref) ? const Color(0x00000000) : theme.bar;
}

class _NativeGlassView extends StatelessWidget {
  const _NativeGlassView({required this.cornerRadius});

  final double cornerRadius;

  @override
  Widget build(BuildContext context) {
    // Hybrid composition: Glass sampelt den Flutter-Content dahinter.
    // IgnorePointer: Touches gehen an Flutter-Kinder (Buttons, Listen).
    return IgnorePointer(
      child: UiKitView(
        viewType: LiquidGlassService.viewType,
        creationParams: <String, dynamic>{
          'cornerRadius': cornerRadius,
        },
        creationParamsCodec: const StandardMessageCodec(),
      ),
    );
  }
}

/// Convenience: Cupertino-Listensektion mit Glass auf iOS 26+.
class LiquidGlassGroupedBox extends ConsumerWidget {
  const LiquidGlassGroupedBox({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    return LiquidGlassPanel(
      borderRadius: BorderRadius.circular(theme.radiusLg),
      fallback: Container(
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(theme.radiusLg),
          border: Border.all(
            color: theme.textSecondary.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
        child: child,
      ),
      child: child,
    );
  }
}

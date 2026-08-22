import 'dart:ui' show FontFeature;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/rclone_provider.dart';
import '../../../../core/utils/format.dart';
import '../../../../theme/theme.dart';
import '../../../../core/localization/app_strings.dart';

/// Dashboard-Speicherkarte über ALLE verbundenen Cloud-Laufwerke.
/// Absichtlich schlicht (Nutzer-Designfeedback, nach HIG):
///  * Y von Z belegt (Summe aller Remotes),
///  * ein Balken: Fibu-Beleg in Akzentfarbe, sonstiger belegter Platz in
///    blasserem Akzent, freier Platz als Theme-Track (hell/dunkel adaptiv).
class MultiRemoteStorageCard extends ConsumerWidget {
  const MultiRemoteStorageCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final strings = ref.watch(stringsProvider);
    final remotesAsync = ref.watch(remotesProvider);

    return remotesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: material.CircularProgressIndicator()),
      ),
      error: (err, _) =>
          Text('${strings.error}: $err', style: TextStyle(color: theme.error)),
      data: (remotes) {
        if (remotes.isEmpty) return const SizedBox.shrink();

        var totalUsed = 0;
        var totalQuota = 0;
        var fibuUsed = 0;
        for (final remote in remotes) {
          final quota = ref.watch(remoteQuotaProvider(remote)).valueOrNull;
          if (quota != null) {
            totalUsed += quota.usedBytes;
            totalQuota += quota.totalBytes;
          }
          final fibu = ref.watch(remoteFibuUsageProvider(remote)).valueOrNull;
          if (fibu != null) fibuUsed += fibu;
        }
        fibuUsed = fibuUsed.clamp(0, totalUsed);
        final otherUsed = totalUsed - fibuUsed;
        final free = totalQuota > totalUsed ? totalQuota - totalUsed : 0;

        // Farbkonzept (wie besprochen): Fibu = Akzent gesättigt, übriger belegt
        // = blass, frei = Track (je Theme hell/dunkel adaptiv).
        final fibuColor = theme.accent;
        final otherColor = theme.accent.withValues(alpha: 0.3);
        final freeColor = theme.textSecondary.withValues(alpha: 0.15);

        return Container(
          padding: EdgeInsets.all(theme.lg),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(theme.radiusLg),
            border: Border.all(color: theme.textSecondary.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.cloudBackupStorage,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: theme.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(theme.radiusSm),
                child: SizedBox(
                  height: 10,
                  child: (totalUsed + free) <= 0
                      ? Container(color: freeColor)
                      : Row(
                          children: [
                            if (fibuUsed > 0)
                              Expanded(flex: fibuUsed, child: Container(color: fibuColor)),
                            if (otherUsed > 0)
                              Expanded(flex: otherUsed, child: Container(color: otherColor)),
                            if (free > 0)
                              Expanded(flex: free, child: Container(color: freeColor)),
                          ],
                        ),
                ),
              ),
              SizedBox(height: theme.sm),
              Text(
                totalQuota > 0
                    ? strings.quotaSummaryUsedOf(
                        formatBytes(totalUsed), formatBytes(totalQuota))
                    : '${formatBytes(totalUsed)} · ${strings.quotaSummaryUnavailable}',
                style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 12,
                    fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
        );
      },
    );
  }
}

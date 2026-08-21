import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/rclone_provider.dart';
import '../../../../core/utils/format.dart';
import '../../../../theme/theme.dart';
import '../../../../core/localization/app_strings.dart';

/// Dashboard-Speicherkarte: Kombiniert die genutzten Bytes aller verbundenen
/// Cloud-Laufwerke in EINEM gestapelten Balken — je Remote in der
/// Provider-Farbe; der von Fibu belegte Anteil (gesättigt) ist von
/// generellem Speicher (abgeblasst) klar unterscheidbar. Mit Legende.
class MultiRemoteStorageCard extends ConsumerWidget {
  const MultiRemoteStorageCard({super.key});

  /// Stark vereinfachte Provider-Erkennung anhand des Remote-Namens.
  static Color _providerColor(String remoteName, Color fallback) {
    final n = remoteName.toLowerCase();
    if (n.contains('mega')) return const Color(0xFFD9272E); // MEGA-Rot
    if (n.contains('dropbox')) return const Color(0xFF0061FF); // Dropbox-Blau
    if (n.contains('gdrive') || n.contains('drive') || n.contains('google')) {
      return const Color(0xFF1A73E8); // Google-Blau
    }
    if (n.contains('onedrive') || n.contains('one')) return const Color(0xFF0364B8); // OneDrive
    if (n.contains('box')) return const Color(0xFF0061D5);
    if (n.contains('pcloud')) return const Color(0xFF00A85B);
    if (n.contains('yandex')) return const Color(0xFFFC3F1D);
    if (n.contains('s3') || n.contains('aws') || n.contains('minio')) {
      return const Color(0xFFFF9900); // AWS-Orange
    }
    if (n.contains('b2') || n.contains('backblaze')) return const Color(0xFFE12127);
    if (n.contains('webdav') || n.contains('nextcloud') || n.contains('owncloud')) {
      return const Color(0xFF0082C9); // Nextcloud-Blau
    }
    if (n.contains('sftp') || n.contains('ftp')) return const Color(0xFF8E8E93);
    return fallback;
  }

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
      error: (err, _) => Text('${strings.error}: $err', style: TextStyle(color: theme.error)),
      data: (remotes) {
        if (remotes.isEmpty) return const SizedBox.shrink();

        // Pro Remote: Quota (kann null/fehlend sein, z. B. MEGA ohne about)
        // + Fibu-Beleg — werden asymnchron nachgeladen und sofort angezeigt.
        final entries = remotes.map((remote) {
          final quota = ref.watch(remoteQuotaProvider(remote)).valueOrNull;
          final fibu = ref.watch(remoteFibuUsageProvider(remote)).valueOrNull ?? -1;
          return (remote: remote, quota: quota, fibu: fibu);
        }).toList();

        final totalUsed = entries.fold<int>(
            0, (sum, e) => sum + (e.quota?.usedBytes ?? 0));
        final totalQuota = entries.fold<int>(
            0, (sum, e) => sum + (e.quota?.totalBytes ?? 0));

        final metrics = <int>[];
        final colors = <Color>[];
        for (final e in entries) {
          final base = _providerColor(e.remote, theme.accent);
          final used = e.quota?.usedBytes ?? 0;
          final fibu = e.fibu < 0 ? 0 : e.fibu;
          metrics.add((used - fibu).clamp(0, used));
          metrics.add(fibu);
          colors.add(base.withValues(alpha: 0.28)); // anderer Remote-Inhalt, blass
          colors.add(base); // Fibu-Anteil, gesättigt
        }

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
              SizedBox(height: theme.xs),
              Text(
                totalQuota > 0
                    ? '${formatBytes(totalUsed)} von ${formatBytes(totalQuota)}'
                    : '${formatBytes(totalUsed)} (Gesamt ${strings.storageNotAvailable})',
                style: TextStyle(color: theme.textSecondary, fontSize: 13),
              ),
              SizedBox(height: theme.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(theme.radiusSm),
                child: SizedBox(
                  height: 10,
                  child: metrics.every((m) => m == 0)
                      ? Container(color: theme.textSecondary.withValues(alpha: 0.12))
                      : Row(
                          children: [
                            for (var i = 0; i < metrics.length; i++)
                              if (metrics[i] > 0)
                                Expanded(
                                  flex: metrics[i],
                                  child: Container(color: colors[i]),
                                ),
                          ],
                        ),
                ),
              ),
              SizedBox(height: theme.md),
              // Legende je Remote: Dot in Providerfarbe, Name, belegt + Fibu-Anteil
              ...entries.map((e) {
                final color = _providerColor(e.remote, theme.accent);
                final usedText = e.quota == null
                    ? strings.storageNotAvailable
                    : (e.quota!.totalBytes > 0
                        ? '${formatBytes(e.quota!.usedBytes)} / ${formatBytes(e.quota!.totalBytes)}'
                        : strings.storageNotAvailable);
                final fibuText = e.fibu >= 0 ? ' · Fibu: ${formatBytes(e.fibu)}' : '';
                return Padding(
                  padding: EdgeInsets.only(bottom: theme.xs),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      SizedBox(width: theme.sm),
                      Expanded(
                        child: Text(
                          e.remote,
                          style: TextStyle(color: theme.textPrimary, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        usedText + fibuText,
                        style: TextStyle(color: theme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

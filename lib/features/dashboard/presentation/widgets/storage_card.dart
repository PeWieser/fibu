import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';

import '../../../../theme/theme.dart';
import '../../../../core/services/rclone_service.dart';
import 'dashboard_dialogs.dart';

/// Platform-adaptive storage card displaying space quota information (used, total, and percentage indicator).
/// Follows platform specific design languages (Fluent on Windows, Cupertino on iOS, Material 3 on Android).
/// Clickable: Tapping triggers a detailed space utilization popup modal.
class StorageCard extends StatelessWidget {
  final QuotaInfo quota;
  final String title;

  const StorageCard({
    super.key,
    required this.quota,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final platform = defaultTargetPlatform;
    final theme = context.theme;

    return GestureDetector(
      onTap: () => showStorageBreakdownDialog(context, quota),
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        label: 'Storage card for $title. Click for detailed space breakdown.',
        button: true,
        child: _buildLayout(context, platform, theme),
      ),
    );
  }

  Widget _buildLayout(BuildContext context, TargetPlatform platform, AppThemeData theme) {
    if (platform == TargetPlatform.windows) {
      return _buildWindows(context, theme);
    } else if (platform == TargetPlatform.iOS) {
      return _buildIOS(context, theme);
    } else {
      return _buildAndroid(context, theme);
    }
  }

  Widget _buildWindows(BuildContext context, AppThemeData theme) {
    final percentage = quota.usedPercentage;
    return fluent.Card(
      padding: EdgeInsets.all(theme.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          fluent.Text(
            title,
            style: fluent.FluentTheme.of(context).typography.subtitle,
          ),
          SizedBox(height: theme.sm),
          fluent.ProgressBar(
            value: percentage,
            backgroundColor: theme.canvas,
            activeColor: theme.accent,
          ),
          SizedBox(height: theme.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              fluent.Text(
                'Used: ${(quota.usedBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB',
                style: fluent.FluentTheme.of(context).typography.caption,
              ),
              fluent.Text(
                'Total: ${(quota.totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB',
                style: fluent.FluentTheme.of(context).typography.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIOS(BuildContext context, AppThemeData theme) {
    final percentage = quota.usedPercentage;
    return Container(
      padding: EdgeInsets.all(theme.lg),
      decoration: BoxDecoration(
        color: cupertino.CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(theme.radiusLg),
        border: Border.all(
          color: cupertino.CupertinoColors.separator.resolveFrom(context),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: theme.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(theme.radiusSm),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Container(color: cupertino.CupertinoColors.systemGrey5.resolveFrom(context)),
                  FractionallySizedBox(
                    widthFactor: percentage / 100,
                    child: Container(color: theme.accent),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: theme.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Used: ${(quota.usedBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB',
                style: TextStyle(fontSize: 12, color: theme.textSecondary),
              ),
              Text(
                'Total: ${(quota.totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB',
                style: TextStyle(fontSize: 12, color: theme.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAndroid(BuildContext context, AppThemeData theme) {
    final percentage = quota.usedPercentage;
    return material.Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.radiusLg),
        side: BorderSide(
          color: material.Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: material.Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: theme.sm),
            material.LinearProgressIndicator(
              value: percentage / 100,
              borderRadius: BorderRadius.circular(theme.radiusSm),
              color: theme.accent,
            ),
            SizedBox(height: theme.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Used: ${(quota.usedBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB',
                  style: material.Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Total: ${(quota.totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB',
                  style: material.Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

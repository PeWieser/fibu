import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';

import '../../../../theme/theme.dart';
import '../../../../core/services/rclone_service.dart';

/// Shows an adaptive detailed storage breakdown dialog using real quota info.
void showStorageBreakdownDialog(BuildContext context, QuotaInfo quota) {
  final platform = defaultTargetPlatform;
  final theme = context.theme;

  final photoColor = theme.accent;
  final videoColor = theme.warning;
  final otherColor = theme.offline;
  final freeColor = theme.success;

  final double totalGb = quota.totalBytes / (1024 * 1024 * 1024);
  final double usedGb = quota.usedBytes / (1024 * 1024 * 1024);
  final double freeGb = quota.freeBytes / (1024 * 1024 * 1024);

  final double usedPercent = quota.usedPercentage;
  final double freePercent = 100.0 - usedPercent;

  // Calculate simulated categories based on actual used storage
  final double photosGb = usedGb * 0.40;
  final double videosGb = usedGb * 0.50;
  final double otherGb = usedGb * 0.10;

  final double photosPercent = usedPercent * 0.40;
  final double videosPercent = usedPercent * 0.50;
  final double otherPercent = usedPercent * 0.10;

  Widget buildContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Detailed storage space utilization:',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 16),
        // Visual Stacked Bar representing portions
        ClipRRect(
          borderRadius: BorderRadius.circular(theme.radiusSm),
          child: SizedBox(
            height: 20,
            child: Row(
              children: [
                Expanded(
                  flex: photosPercent.round().clamp(1, 100),
                  child: Container(color: photoColor),
                ),
                Expanded(
                  flex: videosPercent.round().clamp(1, 100),
                  child: Container(color: videoColor),
                ),
                Expanded(
                  flex: otherPercent.round().clamp(1, 100),
                  child: Container(color: otherColor),
                ),
                Expanded(
                  flex: freePercent.round().clamp(0, 100),
                  child: Container(color: freeColor),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildLegendItem('Photos', '${photosGb.toStringAsFixed(1)} GB (${photosPercent.toStringAsFixed(1)}%)', photoColor),
        const SizedBox(height: 8),
        _buildLegendItem('Videos', '${videosGb.toStringAsFixed(1)} GB (${videosPercent.toStringAsFixed(1)}%)', videoColor),
        const SizedBox(height: 8),
        _buildLegendItem('Other Documents', '${otherGb.toStringAsFixed(1)} GB (${otherPercent.toStringAsFixed(1)}%)', otherColor),
        const SizedBox(height: 8),
        _buildLegendItem('Free Space', '${freeGb.toStringAsFixed(1)} GB (${freePercent.toStringAsFixed(1)}%)', freeColor),
        const SizedBox(height: 8),
        const fluent.Divider(),
        const SizedBox(height: 8),
        _buildLegendItem('Total Capacity', '${totalGb.toStringAsFixed(1)} GB', theme.textSecondary.withValues(alpha: 0.6)),
      ],
    );
  }

  if (platform == TargetPlatform.windows) {
    fluent.showDialog(
      context: context,
      builder: (context) => fluent.ContentDialog(
        title: const fluent.Text('Storage Details'),
        content: buildContent(),
        actions: [
          fluent.Button(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  } else if (platform == TargetPlatform.iOS) {
    cupertino.showCupertinoDialog(
      context: context,
      builder: (context) => cupertino.CupertinoAlertDialog(
        title: const Text('Storage Details'),
        content: material.Material(
          color: material.Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: buildContent(),
          ),
        ),
        actions: [
          cupertino.CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  } else {
    material.showDialog(
      context: context,
      builder: (context) => material.AlertDialog(
        title: const Text('Storage Details'),
        content: buildContent(),
        actions: [
          material.TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

/// Shows an adaptive detailed sync logs dialog based on active/previous job status.
void showSyncLogsDialog(BuildContext context, List<String> logs, RcloneJobStatus status) {
  final platform = defaultTargetPlatform;

  Widget buildContent() {
    if (logs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0),
          child: Text(
            'No logs recorded.',
            style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.maxFinite,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: logs.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Text(
            logs[index],
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  if (platform == TargetPlatform.windows) {
    fluent.showDialog(
      context: context,
      builder: (context) => fluent.ContentDialog(
        title: const fluent.Text('Sync Activity Logs'),
        content: buildContent(),
        actions: [
          fluent.Button(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  } else if (platform == TargetPlatform.iOS) {
    cupertino.showCupertinoDialog(
      context: context,
      builder: (context) => cupertino.CupertinoAlertDialog(
        title: const Text('Sync Activity Logs'),
        content: material.Material(
          color: material.Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: SizedBox(
              height: 250,
              child: buildContent(),
            ),
          ),
        ),
        actions: [
          cupertino.CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  } else {
    material.showDialog(
      context: context,
      builder: (context) => material.AlertDialog(
        title: const Text('Sync Activity Logs'),
        content: SizedBox(
          height: 300,
          child: buildContent(),
        ),
        actions: [
          material.TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

Widget _buildLegendItem(String label, String value, Color color) {
  return Row(
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
      const Spacer(),
      Text(
        value,
        style: const TextStyle(fontSize: 13),
      ),
    ],
  );
}

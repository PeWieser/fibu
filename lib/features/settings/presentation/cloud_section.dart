import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/navigation/app_nav.dart';
import '../../../core/services/active_cloud.dart';
import '../../../core/services/remote_registry_service.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/windows_controls.dart';
import '../../../theme/theme.dart';
import '../../dashboard/presentation/cloud_photos_screen.dart';
import 'add_remote_wizard.dart';
import 'cloud_drives_screen.dart';

/// „Cloud" in den Einstellungen — **eine** Cloud, keine Liste.
///
/// Modell seit dem Umbau: Die App sichert auf genau ein Ziel. Das kann ein
/// gewöhnliches Laufwerk sein oder ein virtuelles (Union, Combine, Crypt,
/// Chunker), das im Assistent aus mehreren Laufwerken gebündelt wird; die
/// Bestandteile stehen dann als Zahl dabei.
///
/// Umbenennen, Ersetzen und Trennen bleiben in der Laufwerksverwaltung — dort
/// stehen die Bestätigungsdialoge mit Klartext-Folge bereits (AGENTS.md
/// Regel 6), und sie zweimal zu bauen wäre zweimal dieselbe Wahrheit.
class CloudSection extends ConsumerWidget {
  const CloudSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final strings = ref.watch(stringsProvider);
    final cloud = ref.watch(activeRemoteProvider).valueOrNull;
    final quota = ref.watch(activeCloudQuotaProvider).valueOrNull;
    final members =
        ref.watch(activeCloudMembersProvider).valueOrNull ?? const <String>[];

    if (cloud == null) {
      return Win.tile(
        theme: theme,
        title: strings.cloudConnect,
        subtitle: strings.cloudNone,
        leading: fluent.FluentIcons.cloud_add,
        trailing: const Icon(fluent.FluentIcons.chevron_right, size: 12),
        onPressed: () => _connect(context, ref),
        semanticLabel: strings.cloudConnect,
        first: true,
        last: true,
      );
    }

    final subtitle = <String>[
      RemoteEntry.prettyType(cloud.type),
      if (quota != null && quota.totalBytes > 0)
        strings.quotaSummaryUsedOf(
            formatBytes(quota.usedBytes), formatBytes(quota.totalBytes)),
      if (members.isNotEmpty) strings.cloudMembersCount(members.length),
    ].join('  ·  ');

    return Win.group(
      theme: theme,
      children: [
        Win.tile(
          theme: theme,
          title: cloud.name,
          subtitle: subtitle,
          leading: fluent.FluentIcons.cloud,
          first: true,
        ),
        Win.tile(
          theme: theme,
          title: strings.exploreRemoteFiles,
          leading: fluent.FluentIcons.photo2,
          trailing: const Icon(fluent.FluentIcons.chevron_right, size: 12),
          onPressed: () => AppNav.push(
              context, CloudPhotosScreen(initialRemote: cloud.id)),
          semanticLabel: strings.exploreRemoteFiles,
        ),
        Win.tile(
          theme: theme,
          title: strings.manageCloudDrives,
          subtitle: strings.cloudManageHint,
          leading: fluent.FluentIcons.settings,
          trailing: const Icon(fluent.FluentIcons.chevron_right, size: 12),
          onPressed: () => AppNav.push(context, const CloudDrivesScreen()),
          semanticLabel: strings.manageCloudDrives,
          last: true,
        ),
      ],
    );
  }

  /// Assistent öffnen und danach die Laufwerksliste neu lesen — sonst steht
  /// die neue Cloud zwar in rclone, aber nicht in der Anzeige.
  Future<void> _connect(BuildContext context, WidgetRef ref) async {
    final added = await AppNav.push<String>(
      context,
      const AddRemoteWizardDialog(platform: TargetPlatform.windows),
    );
    if (added != null) {
      ref.invalidate(remoteEntriesProvider);
    }
  }
}

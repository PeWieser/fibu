import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/navigation/app_nav.dart';
import '../../../core/services/active_cloud.dart';
import '../../../core/services/remote_registry_service.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/ui.dart';
import '../../../theme/theme.dart';
import '../../dashboard/presentation/cloud_photos_screen.dart';
import 'add_remote_wizard.dart';
import 'cloud_drives_screen.dart';

/// „Cloud" in den Einstellungen — **eine** Cloud, keine Liste.
///
/// Plattformneutral über [Ui]: dieselbe Struktur auf Windows, iOS und
/// Android, plattformabhängig ist nur die Darstellung.
///
/// Umbenennen, Ersetzen und Trennen bleiben in der Laufwerksverwaltung — dort
/// stehen die Bestätigungsdialoge mit Klartext-Folge bereits (AGENTS.md
/// Regel 6), und sie dreimal zu bauen wäre dreimal dieselbe Wahrheit.
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
      return Ui.tile(
        theme: theme,
        title: strings.cloudConnect,
        subtitle: strings.cloudNone,
        leading: Ui.cloudAdd,
        onTap: () => _connect(context, ref),
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

    return Ui.group(
      theme: theme,
      children: [
        Ui.tile(
          theme: theme,
          title: cloud.name,
          subtitle: subtitle,
          leading: Ui.cloud,
          first: true,
        ),
        Ui.tile(
          theme: theme,
          title: strings.exploreRemoteFiles,
          leading: Ui.folder,
          onTap: () =>
              AppNav.push(context, CloudPhotosScreen(initialRemote: cloud.id)),
          semanticLabel: strings.exploreRemoteFiles,
        ),
        Ui.tile(
          theme: theme,
          title: strings.manageCloudDrives,
          subtitle: strings.cloudManageHint,
          leading: Ui.settings,
          onTap: () => AppNav.push(context, const CloudDrivesScreen()),
          semanticLabel: strings.manageCloudDrives,
          last: true,
        ),
      ],
    );
  }

  /// Assistent öffnen und danach die Laufwerksliste neu lesen.
  Future<void> _connect(BuildContext context, WidgetRef ref) async {
    final added = await AppNav.push<String>(
      context,
      AddRemoteWizardDialog(platform: defaultTargetPlatform),
    );
    if (added != null) ref.invalidate(remoteEntriesProvider);
  }
}

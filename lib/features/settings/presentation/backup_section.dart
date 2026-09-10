import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/services/active_cloud.dart';
import '../../../core/services/remote_registry_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/widgets/ui.dart';
import '../../../theme/theme.dart';
import '../../tasks/presentation/tasks_controller.dart';

/// „Sicherung" in den Einstellungen — **eine** Sicherung, direkt editierbar.
///
/// Früher war das ein Aufgaben-Tab mit einer Liste und einem dreistufigen
/// Dialog. Es gibt aber genau eine Sicherung: Ordner, Abgleich, Zielordner,
/// Zeitplan, zwei Schalter. Das passt in eine Einstellungen-Seite und braucht
/// weder Liste noch Dialog.
///
/// Plattformneutral über [Ui] — dieselbe Struktur auf Windows, iOS und
/// Android.
///
/// „Nur WLAN" schreibt auf den **globalen** Schalter
/// (`wifiOnlySyncProvider`), nicht auf ein Feld der Sicherung — es gibt eine
/// Wahrheit, und die steht hier, weil sie das Sichern betrifft.
class BackupSection extends ConsumerStatefulWidget {
  const BackupSection({super.key});

  @override
  ConsumerState<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<BackupSection> {
  /// Controller für „Ordner in der Cloud". Bewusst im State und nicht im
  /// Build erzeugt: Ein Controller pro Rebuild würde den Cursor zurücksetzen
  /// und nie freigegeben werden.
  final TextEditingController _folderCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final tasks = ref.read(tasksListProvider);
    _folderCtrl.text =
        tasks.isEmpty ? 'fibu-backup' : tasks.first.targetFolderName;
  }

  @override
  void dispose() {
    _folderCtrl.dispose();
    super.dispose();
  }

  /// Dasselbe Schlüsselvokabular wie der Planer: `Daily`, die Wochentage,
  /// `Manual`.
  static const List<String> _dayKeys = [
    'Daily',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
    'Manual',
  ];

  String _dayLabel(AppStrings strings, String key) {
    switch (key) {
      case 'Daily':
        return strings.dayDaily;
      case 'Monday':
        return strings.dayMonday;
      case 'Tuesday':
        return strings.dayTuesday;
      case 'Wednesday':
        return strings.dayWednesday;
      case 'Thursday':
        return strings.dayThursday;
      case 'Friday':
        return strings.dayFriday;
      case 'Saturday':
        return strings.daySaturday;
      case 'Sunday':
        return strings.daySunday;
      default:
        return strings.dayManual;
    }
  }

  Map<String, String> _dayItems(AppStrings strings) =>
      {for (final key in _dayKeys) key: _dayLabel(strings, key)};

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final strings = ref.watch(stringsProvider);
    final tasks = ref.watch(tasksListProvider);
    final hasCloud = ref.watch(activeRemoteIdProvider).valueOrNull != null;

    // Ohne Cloud gibt es nichts zu sichern — die Cloud-Sektion darüber
    // fordert zum Verbinden auf, hier steht nur der Grund.
    if (!hasCloud) {
      return Ui.tile(
        theme: theme,
        title: strings.backupSection,
        subtitle: strings.backupNeedsCloud,
        leading: Ui.lock,
        first: true,
        last: true,
      );
    }

    // Ohne Sicherung: eine Zeile, die sie anlegt. Die Felder stehen danach
    // direkt darunter — kein Dialog, kein Wizard.
    if (tasks.isEmpty) {
      return Ui.tile(
        theme: theme,
        title: strings.backupCreate,
        subtitle: strings.backupCreateHint,
        leading: Ui.add,
        onTap: _createBackup,
        semanticLabel: strings.backupCreate,
        first: true,
        last: true,
      );
    }

    final task = tasks.first;
    final notifier = ref.read(tasksListProvider.notifier);

    return Ui.group(
      theme: theme,
      children: [
        ..._folders(theme, strings, task, notifier),
        Ui.tile(
          theme: theme,
          title: strings.backupSyncMode,
          subtitle: task.syncMode == SyncMode.mirror
              ? strings.syncModeMirrorDescription
              : strings.syncModeIncrementalDescription,
          leading: Ui.sync,
          trailing: Ui.picker<SyncMode>(
            context: context,
            theme: theme,
            value: task.syncMode,
            items: {
              SyncMode.incremental: strings.syncModeIncremental,
              SyncMode.mirror: strings.syncModeMirror,
            },
            onChanged: (mode) {
              if (mode == null) return;
              notifier.updateTask(task.id, task.copyWith(syncMode: mode));
            },
          ),
        ),
        Ui.tile(
          theme: theme,
          title: strings.backupCloudFolder,
          leading: Ui.folder,
          trailing: Ui.textField(
            theme: theme,
            controller: _folderCtrl,
            placeholder: 'fibu-backup',
            onSubmitted: (value) {
              notifier.updateTask(
                task.id,
                task.copyWith(
                  targetFolderName:
                      value.trim().isEmpty ? 'fibu-backup' : value.trim(),
                ),
              );
            },
          ),
        ),
        Ui.tile(
          theme: theme,
          title: strings.scheduleDayLabel,
          leading: Ui.calendar,
          trailing: Ui.picker<String>(
            context: context,
            theme: theme,
            value: task.scheduleDay,
            items: _dayItems(strings),
            onChanged: (day) {
              if (day == null) return;
              notifier.updateTask(
                task.id,
                task.copyWith(
                  scheduleDay: day,
                  schedule:
                      strings.scheduleDescriptionFor(day, task.scheduleTime),
                ),
              );
            },
          ),
        ),
        if (task.scheduleDay != 'Manual')
          Ui.tile(
            theme: theme,
            title: strings.scheduleTimeLabel,
            leading: Ui.clock,
            trailing: _timePickers(context, theme, strings, task, notifier),
          ),
        Ui.toggle(
          theme: theme,
          title: strings.wifiOnlySyncLabel,
          subtitle: strings.tooltipNetwork,
          value: ref.watch(wifiOnlySyncProvider),
          onChanged: (val) =>
              ref.read(wifiOnlySyncProvider.notifier).setWifiOnly(val),
        ),
        Ui.toggle(
          theme: theme,
          title: strings.backupActiveLabel,
          subtitle: strings.backupActiveHint,
          value: task.isActive,
          onChanged: (val) =>
              notifier.updateTask(task.id, task.copyWith(isActive: val)),
          last: true,
        ),
      ],
    );
  }

  /// Quellordner: eine Zeile pro Ordner mit Entfernen, plus eine Zeile zum
  /// Hinzufügen.
  List<Widget> _folders(AppThemeData theme, AppStrings strings, BackupTask task,
      TasksListNotifier notifier) {
    final folders = task.selectedFolders;
    return [
      for (var i = 0; i < folders.length; i++)
        Ui.tile(
          theme: theme,
          title: folders[i],
          leading: Ui.folder,
          trailing: Ui.iconButton(
            icon: Ui.delete,
            semanticLabel: strings.delete,
            onPressed: () {
              final next = List<String>.from(folders)..removeAt(i);
              notifier.updateTask(
                task.id,
                task.copyWith(
                  selectedFolders: next,
                  sourcePath: next.isEmpty ? '' : 'files:${next.join('|')}',
                ),
              );
            },
          ),
          first: i == 0,
        ),
      Ui.tile(
        theme: theme,
        title:
            folders.isEmpty ? strings.backupNoFolder : strings.backupAddFolder,
        leading: Ui.add,
        onTap: () => _addFolder(task, notifier),
        semanticLabel: strings.backupAddFolder,
      ),
    ];
  }

  Widget _timePickers(BuildContext context, AppThemeData theme,
      AppStrings strings, BackupTask task, TasksListNotifier notifier) {
    final parts = task.scheduleTime.split(':');
    final hour = parts.isNotEmpty ? parts[0] : '02';
    final minute = parts.length > 1 ? parts[1] : '00';
    final hours = {
      for (var h = 0; h < 24; h++) h.toString().padLeft(2, '0'): h.toString().padLeft(2, '0'),
    };
    final minutes = {
      for (var m = 0; m < 60; m += 5) m.toString().padLeft(2, '0'): m.toString().padLeft(2, '0'),
    };

    void setTime(String h, String mi) {
      notifier.updateTask(
        task.id,
        task.copyWith(
          scheduleTime: '$h:$mi',
          schedule: strings.scheduleDescriptionFor(task.scheduleDay, '$h:$mi'),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Ui.picker<String>(
          context: context,
          theme: theme,
          value: hour,
          items: hours,
          onChanged: (h) {
            if (h != null) setTime(h, minute);
          },
        ),
        const Text(' : '),
        Ui.picker<String>(
          context: context,
          theme: theme,
          value: minute,
          items: minutes,
          onChanged: (mi) {
            if (mi != null) setTime(hour, mi);
          },
        ),
      ],
    );
  }

  Future<void> _addFolder(BackupTask task, TasksListNotifier notifier) async {
    final path = await FilePicker.getDirectoryPath();
    if (path == null || path.isEmpty) return;
    final folders = List<String>.from(task.selectedFolders);
    if (folders.contains(path)) return;
    folders.add(path);
    notifier.updateTask(
      task.id,
      task.copyWith(
        selectedFolders: folders,
        sourcePath: 'files:${folders.join('|')}',
      ),
    );
  }

  /// Legt die eine Sicherung mit sinnvollen Vorgaben an.
  void _createBackup() {
    final strings = ref.read(stringsProvider);
    final cloud = ref.read(activeRemoteIdProvider).valueOrNull ?? '';
    final cloudName = ref.read(remoteDisplayNameProvider(cloud));
    final now = DateTime.now();
    final minute = ((now.minute ~/ 5) * 5 + 5) % 60;
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    _folderCtrl.text = 'fibu-backup';

    ref.read(tasksListProvider.notifier).addTask(
          BackupTask(
            id: 'backup_${now.millisecondsSinceEpoch}',
            name: 'Sicherung auf $cloudName',
            sourcePath: '',
            targetRemotes: cloud.isEmpty ? const [] : [cloud],
            schedule: strings.scheduleDescriptionFor('Daily', time),
            scheduleDay: 'Daily',
            scheduleTime: time,
            isActive: true,
            syncMode: SyncMode.incremental,
            targetFolderName: 'fibu-backup',
          ),
        );
  }
}

import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/services/active_cloud.dart';
import '../../../core/services/remote_registry_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/widgets/windows_controls.dart';
import '../../../theme/theme.dart';
import '../../tasks/presentation/tasks_controller.dart';

/// „Sicherung" in den Einstellungen — **eine** Sicherung, direkt editierbar.
///
/// Früher war das ein Aufgaben-Tab mit einer Liste und einem dreistufigen
/// Dialog. Es gibt aber genau eine Sicherung: Ordner, Abgleich, Zielordner,
/// Zeitplan, zwei Schalter. Das passt in eine Einstellungen-Seite und braucht
/// weder Liste noch Dialog.
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

  /// Dasselbe Schlüsselvokabular wie der Aufgaben-Editor und der Planer:
  /// `Daily`, die Wochentage, `Manual`.
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

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final strings = ref.watch(stringsProvider);
    final tasks = ref.watch(tasksListProvider);
    final hasCloud = ref.watch(activeRemoteIdProvider).valueOrNull != null;

    // Ohne Cloud gibt es nichts zu sichern — die Cloud-Sektion darüber
    // fordert zum Verbinden auf, hier steht nur der Grund.
    if (!hasCloud) {
      return Win.tile(
        theme: theme,
        title: strings.backupSection,
        subtitle: strings.backupNeedsCloud,
        leading: fluent.FluentIcons.lock,
        first: true,
        last: true,
      );
    }

    // Ohne Sicherung: eine Zeile, die sie anlegt. Die Felder stehen danach
    // direkt darunter — kein Dialog, kein Wizard.
    if (tasks.isEmpty) {
      return Win.tile(
        theme: theme,
        title: strings.backupCreate,
        subtitle: strings.backupCreateHint,
        leading: fluent.FluentIcons.add,
        trailing: const Icon(fluent.FluentIcons.chevron_right, size: 12),
        onPressed: _createBackup,
        semanticLabel: strings.backupCreate,
        first: true,
        last: true,
      );
    }

    final task = tasks.first;
    final notifier = ref.read(tasksListProvider.notifier);

    return Win.group(
      theme: theme,
      children: [
        _folders(theme, strings, task, notifier),
        Win.tile(
          theme: theme,
          title: strings.backupSyncMode,
          subtitle: task.syncMode == SyncMode.mirror
              ? strings.syncModeMirrorDescription
              : strings.syncModeIncrementalDescription,
          leading: fluent.FluentIcons.sync,
          trailing: fluent.ComboBox<SyncMode>(
            value: task.syncMode,
            items: [
              fluent.ComboBoxItem(
                value: SyncMode.incremental,
                child: Text(strings.syncModeIncremental),
              ),
              fluent.ComboBoxItem(
                value: SyncMode.mirror,
                child: Text(strings.syncModeMirror),
              ),
            ],
            onChanged: (mode) {
              if (mode == null) return;
              notifier.updateTask(
                  task.id, task.copyWith(syncMode: mode));
            },
          ),
        ),
        Win.tile(
          theme: theme,
          title: strings.backupCloudFolder,
          leading: fluent.FluentIcons.folder,
          trailing: SizedBox(
            width: 220,
            child: fluent.TextBox(
              controller: _folderCtrl,
              placeholder: 'fibu-backup',
              onSubmitted: (value) {
                notifier.updateTask(
                  task.id,
                  task.copyWith(
                    targetFolderName: value.trim().isEmpty
                        ? 'fibu-backup'
                        : value.trim(),
                  ),
                );
              },
            ),
          ),
        ),
        if (task.scheduleDay != 'Manual') ...[
          Win.tile(
            theme: theme,
            title: strings.scheduleDayLabel,
            leading: fluent.FluentIcons.calendar,
            trailing: fluent.ComboBox<String>(
              value: task.scheduleDay,
              items: _dayKeys
                  .map((key) => fluent.ComboBoxItem(
                      value: key, child: Text(_dayLabel(strings, key))))
                  .toList(),
              onChanged: (day) {
                if (day == null) return;
                notifier.updateTask(
                  task.id,
                  task.copyWith(
                    scheduleDay: day,
                    schedule: strings.scheduleDescriptionFor(
                        day, task.scheduleTime),
                  ),
                );
              },
            ),
          ),
          Win.tile(
            theme: theme,
            title: strings.scheduleTimeLabel,
            leading: fluent.FluentIcons.clock,
            trailing: _timePickers(theme, strings, task, notifier),
          ),
        ] else
          Win.tile(
            theme: theme,
            title: strings.scheduleDayLabel,
            subtitle: strings.dayManual,
            leading: fluent.FluentIcons.calendar,
            trailing: fluent.ComboBox<String>(
              value: task.scheduleDay,
              items: _dayKeys
                  .map((key) => fluent.ComboBoxItem(
                      value: key, child: Text(_dayLabel(strings, key))))
                  .toList(),
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
        Win.toggle(
          theme: theme,
          title: strings.wifiOnlySyncLabel,
          subtitle: strings.tooltipNetwork,
          value: ref.watch(wifiOnlySyncProvider),
          onChanged: (val) =>
              ref.read(wifiOnlySyncProvider.notifier).setWifiOnly(val),
        ),
        Win.toggle(
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

  /// Quellordner: Liste mit Entfernen, plus eine Zeile zum Hinzufügen.
  Widget _folders(AppThemeData theme, AppStrings strings, BackupTask task,
      TasksListNotifier notifier) {
    final folders = task.selectedFolders;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < folders.length; i++)
          Win.tile(
            theme: theme,
            title: folders[i],
            leading: fluent.FluentIcons.folder,
            trailing: fluent.IconButton(
              icon: Icon(fluent.FluentIcons.delete,
                  semanticLabel: strings.delete),
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
        Win.tile(
          theme: theme,
          title: folders.isEmpty
              ? strings.backupNoFolder
              : strings.backupAddFolder,
          leading: fluent.FluentIcons.add,
          onPressed: () => _addFolder(task, notifier),
          semanticLabel: strings.backupAddFolder,
          first: folders.isEmpty,
        ),
      ],
    );
  }

  Widget _timePickers(AppThemeData theme, AppStrings strings, BackupTask task,
      TasksListNotifier notifier) {
    final parts = task.scheduleTime.split(':');
    final hour = parts.isNotEmpty ? parts[0] : '02';
    final minute = parts.length > 1 ? parts[1] : '00';
    final hours =
        List.generate(24, (i) => i.toString().padLeft(2, '0'));
    final minutes = List.generate(12, (i) => (i * 5).toString().padLeft(2, '0'));

    void setTime(String h, String m) {
      notifier.updateTask(
        task.id,
        task.copyWith(
          scheduleTime: '$h:$m',
          schedule:
              strings.scheduleDescriptionFor(task.scheduleDay, '$h:$m'),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        fluent.ComboBox<String>(
          value: hour,
          items: hours
              .map((h) => fluent.ComboBoxItem(value: h, child: Text(h)))
              .toList(),
          onChanged: (h) {
            if (h != null) setTime(h, minute);
          },
        ),
        SizedBox(width: theme.xs),
        fluent.ComboBox<String>(
          value: minute,
          items: minutes
              .map((m) => fluent.ComboBoxItem(value: m, child: Text(m)))
              .toList(),
          onChanged: (m) {
            if (m != null) setTime(hour, m);
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

  /// Legt die eine Sicherung mit sinnvollen Vorgaben an. Ziel ist die
  /// verbundene Cloud, Ordner und Zeitplan stehen danach direkt hier.
  void _createBackup() {
    final strings = ref.read(stringsProvider);
    final cloud = ref.read(activeRemoteIdProvider).valueOrNull ?? '';
    final cloudName = ref.read(remoteDisplayNameProvider(cloud));
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${((now.minute ~/ 5) * 5 + 5).toString().padLeft(2, '0')}';

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

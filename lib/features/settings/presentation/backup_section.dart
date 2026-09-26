import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/services/active_cloud.dart';
import '../../../core/services/rclone_provider.dart';
import '../../../core/services/remote_registry_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/utils/ios_haptics.dart';
import '../../../core/widgets/ui.dart';
import '../../../theme/theme.dart';
import '../../tasks/presentation/tasks_controller.dart';

/// „Sicherung" in den Einstellungen — **eine** Sicherung, direkt editierbar.
///
/// Früher war das ein Aufgaben-Tab mit einer Liste und einem dreistufigen
/// Dialog. Es gibt aber genau eine Sicherung: Quelle, Abgleich, Zielordner,
/// Zeitplan, zwei Schalter. Das passt in eine Einstellungen-Seite und braucht
/// weder Liste noch Dialog.
///
/// **Zwei Modelle, eine Wahrheit pro Plattform:**
/// * Windows und Android: Quell**ordner** (FilePicker), Wiederholung und
///   Uhrzeit — der eigene Planer hält die Zeit ein, solange die App läuft.
/// * iOS: Quelle = **Fotoalben** (PhotoKit), kein Uhrzeit-Wähler. Wann der
///   Hintergrundtask läuft, entscheidet das System (BGProcessingTask) — eine
///   Auswahl wäre ein Versprechen, das die App nicht halten kann.
///
/// Plattformneutral über [Ui] — dieselbe Struktur, jeweils die richtige
/// Wahrheit.
///
/// „Nur WLAN" schreibt auf den **globalen** Schalter
/// (`wifiOnlySyncProvider`), nicht auf ein Feld der Sicherung — es gibt eine
/// Wahrheit, und die steht hier, weil sie das Sichern betrifft.
class BackupSection extends ConsumerWidget {
  const BackupSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return const _IosBackupSection();
    }
    return const _SharedBackupSection();
  }
}

/// Windows und Android: Ordner als Quelle, Wiederholung + Uhrzeit planbar.
class _SharedBackupSection extends ConsumerStatefulWidget {
  const _SharedBackupSection();

  @override
  ConsumerState<_SharedBackupSection> createState() =>
      _SharedBackupSectionState();
}

class _SharedBackupSectionState extends ConsumerState<_SharedBackupSection> {
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

// ===========================================================================
// iOS: Fotoalben als Quelle, das System als Zeitplan
// ===========================================================================

/// Ein Album der iOS-Medienquellauswahl: Name plus asynchron nachgeladene
/// Anzahl der enthaltenen Medien.
///
/// Die Auswahl selbst arbeitet nur mit [name] — [count] ist reine Anzeige
/// und je nach Ladestand auch null.
class _AlbumOption {
  _AlbumOption(this.entity);

  /// Zugrunde liegende PhotoKit-Entity (für `assetCountAsync`).
  final AssetPathEntity entity;

  /// Anzahl der Medien im Album (null, solange noch geladen wird).
  int? count;

  String get name => entity.name;
}

/// „Sicherung" auf iOS: eine Zeile für die Fotoalben, eine für den
/// Zielordner in der Cloud — und ein Zeitplan, den man nicht einstellt, weil
/// iOS ihn selbst setzt.
class _IosBackupSection extends ConsumerStatefulWidget {
  const _IosBackupSection();

  @override
  ConsumerState<_IosBackupSection> createState() => _IosBackupSectionState();
}

class _IosBackupSectionState extends ConsumerState<_IosBackupSection> {
  /// Controller für „Ordner in der Cloud". Bewusst im State und nicht im
  /// Build erzeugt: Ein Controller pro Rebuild würde den Cursor zurücksetzen
  /// und nie freigegeben werden.
  final TextEditingController _folderCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final List<BackupTask> tasks = ref.read(tasksListProvider);
    _folderCtrl.text =
        tasks.isEmpty ? 'fibu-backup' : tasks.first.targetFolderName;
  }

  @override
  void dispose() {
    _folderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final strings = ref.watch(stringsProvider);
    final tasks = ref.watch(tasksListProvider);
    final hasCloud = ref.watch(activeRemoteIdProvider).valueOrNull != null;

    // Ohne Cloud gibt es nichts zu sichern — dieselbe Wahrheit wie überall:
    // die Cloud-Sektion fordert zum Verbinden auf, hier steht der Grund.
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

    // Ohne Sicherung: eine Zeile, die sie anlegt — mit Alben als Quelle und
    // dem System als Zeitplan. Kein Wizard, keine Frage nach Ordner oder
    // Uhrzeit: die Vorgaben sind die richtigen Antworten.
    if (tasks.isEmpty) {
      return Ui.tile(
        theme: theme,
        title: strings.backupCreate,
        subtitle: strings.backupCreateHintAlbums,
        leading: Ui.add,
        onTap: _createBackup,
        semanticLabel: strings.backupCreate,
        first: true,
        last: true,
      );
    }

    final BackupTask task = tasks.first;
    final TasksListNotifier notifier = ref.read(tasksListProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Ui.group(
          theme: theme,
          children: [
            Ui.tile(
              theme: theme,
              title: strings.backupAlbums,
              subtitle: _sourceSummary(strings, task),
              leading: cupertino.CupertinoIcons.photo_on_rectangle,
              onTap: _openAlbumSheet,
              semanticLabel: strings.backupAlbums,
              first: true,
            ),
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
                onChanged: (SyncMode? mode) {
                  if (mode == null) return;
                  final bool switchedToMirror = mode == SyncMode.mirror &&
                      task.syncMode != SyncMode.mirror;
                  notifier.updateTask(task.id, task.copyWith(syncMode: mode));
                  // Wechsel Inkrementell → Spiegelung: bestehende Cloud-Dateien
                  // beim ersten Spiegel-Lauf adoptieren statt als Massen-Download
                  // in die Mediathek zu fallen — wie schon in der alten
                  // iOS-Bearbeitung.
                  if (switchedToMirror) {
                    unawaited(_adoptExistingCloudFiles());
                  }
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
                onSubmitted: (String value) {
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
            // Zeitplan: reine Anzeige, bewusst ohne Wähler. Die Beschreibung
            // sagt die Wahrheit („Automatisch (iOS-System)" bzw. „von iOS
            // gesteuert"); die Zeile darunter erklärt, warum.
            Ui.tile(
              theme: theme,
              title: strings.scheduleLabel,
              subtitle: strings.scheduleDescriptionFor(
                  task.scheduleDay, task.scheduleTime),
              leading: Ui.calendar,
            ),
            Ui.toggle(
              theme: theme,
              title: strings.wifiOnlySyncLabel,
              subtitle: strings.tooltipNetwork,
              value: ref.watch(wifiOnlySyncProvider),
              onChanged: (bool val) =>
                  ref.read(wifiOnlySyncProvider.notifier).setWifiOnly(val),
            ),
            Ui.toggle(
              theme: theme,
              title: strings.backupActiveLabel,
              subtitle: strings.backupActiveHint,
              value: task.isActive,
              onChanged: (bool val) =>
                  notifier.updateTask(task.id, task.copyWith(isActive: val)),
              last: true,
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(theme.lg, theme.sm, theme.lg, theme.xs),
          child: Text(
            strings.schedulePlatformNote,
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  /// Zeilen-Untertitel der Quelle: die gewählten Alben, „Alle Alben" — oder
  /// die sichtbare Lücke, wenn die Quelle (noch) keine Mediathek ist, z. B.
  /// eine von Windows übertragene Ordner-Aufgabe.
  String _sourceSummary(AppStrings strings, BackupTask task) {
    final List<String> albums = task.effectiveAlbums;
    if (albums.isNotEmpty) {
      if (albums.length <= BackupTask.maxAlbumNamesInSummary) {
        return albums.join(', ');
      }
      final int rest = albums.length - BackupTask.maxAlbumNamesInSummary;
      return '${albums.take(BackupTask.maxAlbumNamesInSummary).join(', ')}, $rest+';
    }
    // Leer + Mediathek-Quelle heißt im Modell „alle" — und genau das sagt
    // die Zeile dann. Alles andere ist eine Quelle, die gewählt werden will.
    return TasksListNotifier.isMediaLibrarySource(task.sourcePath)
        ? strings.backupAllAlbums
        : strings.backupAlbumsNeeded;
  }

  void _openAlbumSheet() {
    IosHaptics.selection();
    cupertino.showCupertinoModalPopup<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext sheetCtx) => const _AlbumPickerSheet(),
    );
  }

  /// Adoption ist ein Bonus — ein Fehlschlag darf die Modus-Wahl nicht
  /// stören.
  Future<void> _adoptExistingCloudFiles() async {
    try {
      await ref.read(rcloneServiceProvider).markMirrorAdoption();
    } catch (_) {
      // bewusst still: der Modus ist gesetzt, die Adoption kommt beim
      // nächsten Lauf erneut in Frage.
    }
  }

  /// Legt die eine Sicherung an: alle Alben, Ziel die verbundene Cloud,
  /// Zeitplan das System. Drei offene Fragen — alle mit der richtigen
  /// Vorgabe beantwortet.
  void _createBackup() {
    final strings = ref.read(stringsProvider);
    final cloud = ref.read(activeRemoteIdProvider).valueOrNull ?? '';
    final cloudName = ref.read(remoteDisplayNameProvider(cloud));
    final now = DateTime.now();
    _folderCtrl.text = 'fibu-backup';

    ref.read(tasksListProvider.notifier).addTask(
          BackupTask(
            id: 'backup_${now.millisecondsSinceEpoch}',
            name: 'Sicherung auf $cloudName',
            // „Alle Alben" als sichtbare Vorgabe — inklusive künftiger Alben.
            sourcePath: 'all',
            targetRemotes: cloud.isEmpty ? const [] : [cloud],
            schedule: strings.scheduleDescriptionFor('iOS System', '02:00'),
            // Kein Wecker: iOS plant den Hintergrundtask selbst.
            scheduleDay: 'iOS System',
            scheduleTime: '02:00',
            isActive: true,
            syncMode: SyncMode.incremental,
            targetFolderName: 'fibu-backup',
          ),
        );
    IosHaptics.medium();
  }
}

/// Alben-Blatt der iOS-Sicherung: „Alle Alben" oder eine Menge einzelner
/// Alben. Jede Änderung schreibt sofort — es gibt keinen zweiten, versteckten
/// Zustand, und die Tipp-Reihenfolge ändert nie die Mirror-Kennung.
class _AlbumPickerSheet extends ConsumerStatefulWidget {
  const _AlbumPickerSheet();

  @override
  ConsumerState<_AlbumPickerSheet> createState() => _AlbumPickerSheetState();
}

class _AlbumPickerSheetState extends ConsumerState<_AlbumPickerSheet> {
  List<_AlbumOption> _albums = <_AlbumOption>[];
  bool _loading = true;

  /// Foto-Berechtigung verweigert: der echte Grund statt „Keine Alben
  /// gefunden" (Audit Fehlermeldungen, E-T3).
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    // Ohne setState hier: die Felder stehen schon auf „lädt" (`_loading` =
    // true), und dieser Aufruf kommt aus initState — ein setState mitten im
    // ersten Build wäre ein vermeidbares Risiko.
    try {
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      final bool allowed = ps.isAuth || ps.hasAccess;
      final List<AssetPathEntity> paths = allowed
          ? await PhotoManager.getAssetPathList(
              type: RequestType.common, hasAll: true)
          : <AssetPathEntity>[];
      if (!mounted) return;
      setState(() {
        _albums = paths.map((AssetPathEntity p) => _AlbumOption(p)).toList();
        _loading = false;
        _permissionDenied = !allowed;
      });
      // Anzahl je Album nicht-blockierend nachladen — Name und Auswahl
      // stehen schon ab hier zur Verfügung.
      await _loadAlbumCounts();
    } catch (_) {
      // Ohne PhotoKit (Tests, defekte Installation) bleibt die Liste leer —
      // die Zeile darunter sagt dann ehrlich, was los ist.
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadAlbumCounts() async {
    // Iteration über eine KOPIE: leere Alben fallen aus der Liste.
    for (final _AlbumOption album in List<_AlbumOption>.of(_albums)) {
      try {
        final int count = await album.entity.assetCountAsync;
        if (!mounted) return;
        if (!_albums.contains(album)) continue;
        setState(() {
          album.count = count;
          if (count == 0) {
            _albums.remove(album);
            // Gewählte Alben bleiben gewählt, auch wenn sie gerade leer
            // sind — kein stiller Datenverlust. Sie erscheinen in der
            // Zeilen-Zusammenfassung, bis man sie abwählt.
          }
        });
      } catch (_) {
        // Der Zähler ist Anzeige — die Auswahl hängt am Namen.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final strings = ref.watch(stringsProvider);
    final double sheetHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: theme.canvas,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(theme.radiusLg)),
      ),
      child: cupertino.CupertinoPageScaffold(
        backgroundColor: theme.canvas,
        navigationBar: cupertino.CupertinoNavigationBar(
          backgroundColor: theme.surface,
          middle: Text(strings.backupAlbums),
          trailing: SizedBox(
            height: 44,
            child: cupertino.CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
              child: Text(strings.doneEditing),
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: _buildBody(theme, strings),
        ),
      ),
    );
  }

  Widget _buildBody(AppThemeData theme, AppStrings strings) {
    if (_loading) {
      return const Center(child: cupertino.CupertinoActivityIndicator());
    }
    if (_permissionDenied) {
      return _message(theme, strings.errPhotoPermission);
    }
    if (_albums.isEmpty) {
      return _message(theme, strings.noAlbumsFound);
    }
    final tasks = ref.watch(tasksListProvider);
    if (tasks.isEmpty) {
      // Nicht erreichbar, solange das Blatt nur neben einer Sicherung
      // geöffnet wird — aber ohne Aufgabe gibt es nichts zu speichern.
      return _message(theme, strings.errUnknown);
    }
    final BackupTask task = tasks.first;
    final List<String> selection = task.effectiveAlbums;
    // „Alle Alben" ist eine ausdrückliche Wahl (`all`) — nie die Abwesenheit
    // einer Wahl. Leer + Mediathek-Quelle = alle; alles andere = Lücke.
    final bool isAll = selection.isEmpty &&
        TasksListNotifier.isMediaLibrarySource(task.sourcePath);

    final int totalCount =
        _albums.fold<int>(0, (int sum, _AlbumOption a) => sum + (a.count ?? 0));
    final bool anyCountKnown = _albums.any((_AlbumOption a) => a.count != null);

    return ListView(
      children: [
        cupertino.CupertinoListSection.insetGrouped(
          backgroundColor: theme.surface,
          children: [
            Semantics(
              checked: isAll,
              toggled: true,
              button: true,
              label: strings.backupAllAlbums,
              child: cupertino.CupertinoListTile(
                title: Text(
                  strings.backupAllAlbums,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: anyCountKnown
                    ? Text(
                        strings.albumsTotalMediaCount(totalCount),
                        style: TextStyle(
                            color: theme.textSecondary, fontSize: 12),
                      )
                    : null,
                trailing: _checkIcon(theme, isAll),
                onTap: () {
                  IosHaptics.selection();
                  _apply(task.copyWithAllAlbums());
                },
              ),
            ),
            for (final _AlbumOption album in _albums)
              Semantics(
                checked: selection.contains(album.name),
                toggled: true,
                button: true,
                label: album.name,
                child: cupertino.CupertinoListTile(
                  title:
                      Text(album.name, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                    // Anzahl wird asynchron nachgeladen — bis dahin „…".
                    album.count == null
                        ? '…'
                        : strings.albumMediaCount(album.count!),
                    style:
                        TextStyle(color: theme.textSecondary, fontSize: 12),
                  ),
                  trailing: _checkIcon(theme, selection.contains(album.name)),
                  onTap: () => _toggleAlbum(task, album.name),
                ),
              ),
          ],
        ),
        // Sichtbare Lücke statt stiller „alles sichern"-Annahme — für „alle"
        // gibt es die ausdrückliche Zeile darüber.
        if (!isAll && selection.isEmpty)
          Padding(
            padding:
                EdgeInsets.fromLTRB(theme.lg, theme.sm, theme.lg, theme.sm),
            child: Text(
              strings.emptySelectionAlbumsHint,
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
      ],
    );
  }

  Widget _message(AppThemeData theme, String text) {
    return Padding(
      padding: EdgeInsets.all(theme.lg),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.textSecondary, fontSize: 13),
        ),
      ),
    );
  }

  Widget _checkIcon(AppThemeData theme, bool checked) {
    return Icon(
      checked
          ? cupertino.CupertinoIcons.check_mark_circled_solid
          : cupertino.CupertinoIcons.circle,
      color: checked ? theme.accent : theme.textSecondary,
      size: 22,
    );
  }

  void _toggleAlbum(BackupTask task, String name) {
    final Set<String> next = task.effectiveAlbums.toSet();
    if (!next.remove(name)) {
      next.add(name);
    }
    IosHaptics.selection();
    _apply(task.copyWithAlbums(next));
  }

  void _apply(BackupTask updated) {
    ref.read(tasksListProvider.notifier).updateTask(updated.id, updated);
  }
}

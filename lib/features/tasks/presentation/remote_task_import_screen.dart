import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/services/remote_registry_service.dart';
import '../../../core/services/sync_config_service.dart';
import '../../../core/utils/ios_haptics.dart';
import '../../../theme/theme.dart';
import 'tasks_controller.dart';

/// Auswahl der auf den Cloud-Laufwerken erkannten Aufgaben (Multiple Choice)
/// mit „Importieren“ oben rechts — für den Fall, dass der Import-Dialog nach
/// dem Verbinden eines Remotes übersprungen wurde.
class RemoteTaskImportScreen extends ConsumerStatefulWidget {
  const RemoteTaskImportScreen({super.key, required this.candidates});

  final List<BackupTask> candidates;

  @override
  ConsumerState<RemoteTaskImportScreen> createState() =>
      _RemoteTaskImportScreenState();
}

class _RemoteTaskImportScreenState
    extends ConsumerState<RemoteTaskImportScreen> {
  final Set<String> _selected = {};

  void _toggle(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _import() {
    final tasks = widget.candidates
        .where((t) => _selected.contains(t.id))
        .toList(growable: false);
    if (tasks.isEmpty) return;
    ref.read(tasksListProvider.notifier).importTasks(tasks);
    ref.invalidate(remoteTaskCandidatesProvider);
    if (defaultTargetPlatform == TargetPlatform.iOS) IosHaptics.success();
    Navigator.of(context).pop(tasks.length);
  }

  /// Kurzbeschreibung einer Kandidaten-Aufgabe: Ziel-Laufwerk + Zielordner.
  String _subtitle(BackupTask task) {
    final entries =
        ref.read(remoteEntriesProvider).valueOrNull ?? const <RemoteEntry>[];
    final names = task.targetRemotes.map((id) {
      for (final e in entries) {
        if (e.id == id) return e.name;
      }
      return id;
    }).join(', ');
    return names.isEmpty ? task.targetFolderName : '$names · ${task.targetFolderName}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final strings = ref.watch(stringsProvider);
    final platform = defaultTargetPlatform;
    final canImport = _selected.isNotEmpty;

    if (platform == TargetPlatform.iOS) {
      return cupertino.CupertinoPageScaffold(
        backgroundColor: theme.canvas,
        navigationBar: cupertino.CupertinoNavigationBar(
          middle: Text(strings.importRemoteTasksTitle),
          trailing: cupertino.CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: canImport ? _import : null,
            child: Text(
              strings.importAction,
              style: TextStyle(
                color: canImport ? theme.accent : theme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        child: SafeArea(
          child: ListView(
            children: [
              Padding(
                padding: EdgeInsets.all(theme.lg),
                child: Text(
                  strings.remoteTasksExplanation,
                  style: TextStyle(color: theme.textSecondary, fontSize: 13, height: 1.35),
                ),
              ),
              cupertino.CupertinoListSection.insetGrouped(
                children: [
                  for (final task in widget.candidates)
                    cupertino.CupertinoListTile(
                      title: Text(task.name, style: const TextStyle(fontSize: 16)),
                      subtitle: Text(
                        _subtitle(task),
                        style: TextStyle(color: theme.textSecondary, fontSize: 12),
                      ),
                      trailing: Icon(
                        _selected.contains(task.id)
                            ? cupertino.CupertinoIcons.checkmark_circle_fill
                            : cupertino.CupertinoIcons.circle,
                        color: _selected.contains(task.id)
                            ? theme.accent
                            : theme.textSecondary,
                        size: 24,
                        semanticLabel: task.name,
                      ),
                      onTap: () {
                        IosHaptics.selection();
                        _toggle(task.id);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (platform == TargetPlatform.windows) {
      return fluent.ScaffoldPage(
        header: fluent.PageHeader(
          title: fluent.Text(strings.importRemoteTasksTitle),
          commandBar: fluent.CommandBar(
            primaryItems: [
              fluent.CommandBarButton(
                icon: const Icon(fluent.FluentIcons.download, size: 16,
                    semanticLabel: 'Import'),
                label: Text(strings.importAction),
                onPressed: canImport ? _import : null,
              ),
            ],
          ),
        ),
        content: ListView(
          padding: EdgeInsets.all(theme.lg),
          children: [
            Text(strings.remoteTasksExplanation,
                style: TextStyle(color: theme.textSecondary, fontSize: 13)),
            SizedBox(height: theme.md),
            for (final task in widget.candidates)
              fluent.Card(
                margin: EdgeInsets.only(bottom: theme.sm),
                child: fluent.ListTile.selectable(
                  selected: _selected.contains(task.id),
                  onSelectionChange: (_) => _toggle(task.id),
                  leading: fluent.Checkbox(
                    checked: _selected.contains(task.id),
                    onChanged: (_) => _toggle(task.id),
                  ),
                  title: fluent.Text(task.name),
                  subtitle: fluent.Text(_subtitle(task),
                      style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                ),
              ),
          ],
        ),
      );
    }

    return material.Scaffold(
      appBar: material.AppBar(
        title: Text(strings.importRemoteTasksTitle),
        actions: [
          material.TextButton(
            onPressed: canImport ? _import : null,
            child: Text(strings.importAction),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(theme.lg),
        children: [
          Text(strings.remoteTasksExplanation,
              style: TextStyle(color: theme.textSecondary, fontSize: 13)),
          SizedBox(height: theme.md),
          for (final task in widget.candidates)
            material.CheckboxListTile(
              value: _selected.contains(task.id),
              onChanged: (_) => _toggle(task.id),
              title: Text(task.name),
              subtitle: Text(_subtitle(task)),
              controlAffinity: material.ListTileControlAffinity.leading,
            ),
        ],
      ),
    );
  }
}

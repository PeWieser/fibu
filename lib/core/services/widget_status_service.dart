import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../utils/app_paths.dart';
import 'app_log_service.dart';
import 'rclone_provider.dart';
import 'rclone_service.dart';

/// Zustand eines einzelnen Backup-Tasks für das iOS-Homescreen-Widget.
class WidgetTaskState {
  final String taskId;
  final String name;

  /// 'ok' | 'error' | 'never' | 'pending'
  final String status;
  final String lastSyncIso;

  /// Lokale Medienzahl der Task-Alben beim letzten erfolgreichen Sync.
  final int mediaCountAtLastSync;

  /// Remote-Medienzahl (nur Photos/<Album>/…) beim letzten erfolgreichen Sync.
  /// -1 = noch nie gemessen / nicht verfügbar.
  final int remoteCountAtLastSync;

  const WidgetTaskState({
    required this.taskId,
    required this.name,
    required this.status,
    required this.lastSyncIso,
    this.mediaCountAtLastSync = 0,
    this.remoteCountAtLastSync = -1,
  });

  Map<String, dynamic> toJson() => {
        'taskId': taskId,
        'name': name,
        'status': status,
        'lastSyncIso': lastSyncIso,
        'mediaCountAtLastSync': mediaCountAtLastSync,
        'remoteCountAtLastSync': remoteCountAtLastSync,
      };

  factory WidgetTaskState.fromJson(Map<String, dynamic> j) => WidgetTaskState(
        taskId: j['taskId'] as String? ?? '',
        name: j['name'] as String? ?? '',
        status: j['status'] as String? ?? 'never',
        lastSyncIso: j['lastSyncIso'] as String? ?? '',
        mediaCountAtLastSync: (j['mediaCountAtLastSync'] as num?)?.toInt() ?? 0,
        remoteCountAtLastSync:
            (j['remoteCountAtLastSync'] as num?)?.toInt() ?? -1,
      );
}

/// Vollständiger Widget-Datensatz (wird als JSON in die App-Group geschrieben).
class WidgetStatusData {
  final String lastSyncIso;
  final bool needsSync;
  final String lastError;
  final int activeTaskCount;
  final List<WidgetTaskState> tasks;

  const WidgetStatusData({
    this.lastSyncIso = '',
    this.needsSync = false,
    this.lastError = '',
    this.activeTaskCount = 0,
    this.tasks = const [],
  });

  Map<String, dynamic> toJson() => {
        'lastSyncIso': lastSyncIso,
        'needsSync': needsSync,
        'lastError': lastError,
        'activeTaskCount': activeTaskCount,
        'tasks': tasks.map((t) => t.toJson()).toList(),
      };

  factory WidgetStatusData.fromJson(Map<String, dynamic> j) =>
      WidgetStatusData(
        lastSyncIso: j['lastSyncIso'] as String? ?? '',
        needsSync: j['needsSync'] as bool? ?? false,
        lastError: j['lastError'] as String? ?? '',
        activeTaskCount: (j['activeTaskCount'] as num?)?.toInt() ?? 0,
        tasks: (j['tasks'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((m) => WidgetTaskState.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );

  WidgetStatusData copyWith({
    String? lastSyncIso,
    bool? needsSync,
    String? lastError,
    int? activeTaskCount,
    List<WidgetTaskState>? tasks,
  }) =>
      WidgetStatusData(
        lastSyncIso: lastSyncIso ?? this.lastSyncIso,
        needsSync: needsSync ?? this.needsSync,
        lastError: lastError ?? this.lastError,
        activeTaskCount: activeTaskCount ?? this.activeTaskCount,
        tasks: tasks ?? this.tasks,
      );
}

/// Notifier zum Widget-Status.
///
/// Sync-Bedarf pro Task:
///  * Lokal: nur die in der Aufgabe konfigurierten Alben zählen
///    (leer = gesamtes „Alle Fotos“-Album einmal).
///  * Remote (optional, seltener): Dateien unter `…/Photos/<Album>/`
///    am Ziel-Remote — Gegenstück zu den lokalen Task-Alben.
/// Kein Vollscan der gesamten Mediathek und kein rekursiver Cloud-Tree
/// alle 10 s.
class WidgetStatusNotifier extends StateNotifier<WidgetStatusData> {
  WidgetStatusNotifier({RcloneService? rclone})
      : _rclone = rclone,
        super(const WidgetStatusData()) {
    ready = _load();
  }

  RcloneService? _rclone;

  /// Wird vom Riverpod-Provider gesetzt (und bei Service-Wechsel aktualisiert).
  // ignore: use_setters_to_change_properties
  void attachRclone(RcloneService? service) => _rclone = service;

  late final Future<void> ready;

  static Future<void> refreshInBackground() async {
    final notifier = WidgetStatusNotifier();
    try {
      await notifier.ready;
    } finally {
      notifier.dispose();
    }
  }

  static const _channel = MethodChannel('fibu/widget');

  bool get _useChannel =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<File> _file() async => File(
      '${(await appSupportRoot()).path}/fibu_state/widget_status.json');

  Future<void> _load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        final data = jsonDecode(await f.readAsString());
        if (data is Map) {
          state = WidgetStatusData.fromJson(Map<String, dynamic>.from(data));
        }
      }
    } catch (_) {}
    await recomputeAndPush();
  }

  Future<void> _persist() async {
    try {
      final f = await _file();
      if (!await f.parent.exists()) await f.parent.create(recursive: true);
      await f.writeAsString(jsonEncode(state.toJson()));
    } catch (_) {}
  }

  Future<void> _pushToWidget() async {
    if (!_useChannel) return;
    try {
      await _channel.invokeMethod<void>('setStatus', state.toJson());
    } catch (e) {
      AppLog.warn('widget', 'Widget-Status konnte nicht gepusht werden: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Task-Metadaten aus tasks.json
  // ---------------------------------------------------------------------------

  static bool _isMediaSource(String sourcePath) {
    final s = sourcePath.toLowerCase().trim();
    return s.startsWith('all') ||
        s.startsWith('photos') ||
        s.startsWith('videos') ||
        s == 'media' ||
        s == 'alle fotos' ||
        s == 'alle videos' ||
        s == 'alles';
  }

  static RequestType _requestTypeFor(String sourcePath) {
    final s = sourcePath.toLowerCase().trim();
    if (s.startsWith('videos') || s == 'alle videos') return RequestType.video;
    if (s.startsWith('photos') || s == 'alle fotos') return RequestType.image;
    return RequestType.common;
  }

  /// Alben aus selectedAlbums und/oder sourcePath „photos:A|B“.
  static List<String> _albumsForTask(Map<String, dynamic> t) {
    final fromField = <String>[
      for (final e in (t['selectedAlbums'] as List? ?? const []))
        if (e is String && e.trim().isNotEmpty) e.trim(),
    ];
    if (fromField.isNotEmpty) return fromField;

    final src = (t['sourcePath'] as String? ?? '').trim();
    final lower = src.toLowerCase();
    if (lower.startsWith('photos:') ||
        lower.startsWith('videos:') ||
        lower.startsWith('all:')) {
      final rest = src.substring(src.indexOf(':') + 1);
      return [
        for (final p in rest.split('|'))
          if (p.trim().isNotEmpty) p.trim(),
      ];
    }
    return const []; // leer = gesamte Bibliothek (All-Album)
  }

  /// Ziel-Remote-ID und Basisordner einer Aufgabe.
  static ({String remoteId, String remotePath})? _targetForTask(
      Map<String, dynamic> t) {
    String raw = '';
    final remotes = t['targetRemotes'];
    if (remotes is List && remotes.isNotEmpty) {
      raw = remotes.first.toString();
    } else {
      raw = t['targetRemote']?.toString() ?? '';
    }
    if (raw.isEmpty) return null;
    final parts = raw.split(':');
    final id = parts.first.trim();
    if (id.isEmpty) return null;
    var path = parts.length > 1 ? parts.sublist(1).join(':') : '';
    final mode = t['targetFolderMode'] as String? ?? 'newFolder';
    final folder = (t['targetFolderName'] as String? ?? 'fibu-backup')
        .trim()
        .replaceAll(RegExp(r'^/|/$'), '');
    if (mode != 'root' && folder.isNotEmpty) {
      path = path.isEmpty ? folder : '$path/$folder';
    }
    return (remoteId: id, remotePath: path);
  }

  // ---------------------------------------------------------------------------
  // Lokale Zählung: nur Task-Alben
  // ---------------------------------------------------------------------------

  /// Zählt Medien in den angegebenen Alben. [albums] leer → einmal „Alle“.
  Future<int> _countLocalAlbums({
    required RequestType type,
    required List<String> albums,
  }) async {
    try {
      final ps = await PhotoManager.requestPermissionExtend();
      if (!ps.isAuth && !ps.hasAccess) return 0;

      if (albums.isEmpty) {
        final paths = await PhotoManager.getAssetPathList(
          type: type,
          hasAll: true,
          onlyAll: true,
        );
        if (paths.isEmpty) return 0;
        return await paths.first.assetCountAsync;
      }

      final paths = await PhotoManager.getAssetPathList(
        type: type,
        hasAll: true,
        onlyAll: false,
      );
      final want = albums.map((a) => a.trim().toLowerCase()).toSet();
      var total = 0;
      final seenIds = <String>{}; // falls iOS dasselbe Album doppelt liefert
      for (final p in paths) {
        if (p.isAll) continue;
        final key = p.name.trim().toLowerCase();
        if (!want.contains(key)) continue;
        if (!seenIds.add(p.id)) continue;
        try {
          total += await p.assetCountAsync;
        } catch (_) {}
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  // ---------------------------------------------------------------------------
  // Remote-Zählung: nur Photos/<Album>/ Dateien (flach, billig)
  // ---------------------------------------------------------------------------

  Future<int?> _countRemoteAlbums({
    required String remoteId,
    required String remotePath,
    required List<String> albums,
  }) async {
    final rc = _rclone;
    if (rc == null) return null;
    try {
      final photosRoot =
          remotePath.isEmpty ? 'Photos' : '$remotePath/Photos';
      // Album-Liste remote
      final top = await rc.listFiles(remoteId, photosRoot);
      final albumDirs = top.where((f) => f.isDir).toList();
      final want = albums.map((a) => a.trim().toLowerCase()).toSet();
      final selected = albums.isEmpty
          ? albumDirs
          : albumDirs
              .where((d) => want.contains(d.name.trim().toLowerCase()))
              .toList();

      var total = 0;
      for (final dir in selected) {
        final path = '$photosRoot/${dir.name}';
        try {
          final files = await rc.listFiles(remoteId, path);
          total += files.where((f) => !f.isDir).length;
        } catch (_) {
          // Album remote fehlt → 0 Dateien dort
        }
      }
      return total;
    } catch (e) {
      AppLog.info('widget', 'Remote-Alben-Count übersprungen: $e');
      return null;
    }
  }

  /// Volle Neubewertung.
  ///
  /// [includeRemote]: teure Remote-Listen — typisch jeder 6. Auto-Refresh-Zyklus
  /// (~60 s), nicht alle 10 s.
  Future<void> recomputeAndPush({bool includeRemote = false}) async {
    try {
      final tasksFile = await privateAppFile('tasks.json');
      List<Map<String, dynamic>> rawTasks = const [];
      if (await tasksFile.exists()) {
        final decoded = jsonDecode(await tasksFile.readAsString());
        if (decoded is List) {
          rawTasks = [
            for (final e in decoded)
              if (e is Map) Map<String, dynamic>.from(e),
          ];
        }
      }
      final activeTasks =
          rawTasks.where((t) => t['isActive'] as bool? ?? false).toList();

      final tasks = <WidgetTaskState>[];
      var needsSync = false;

      for (final t in activeTasks) {
        final id = t['id'] as String? ?? '';
        final name = t['name'] as String? ?? '';
        final src = t['sourcePath'] as String? ?? '';
        final isMedia = _isMediaSource(src);
        final albums = _albumsForTask(t);

        final existing = state.tasks.where((s) => s.taskId == id);
        WidgetTaskState st = existing.isNotEmpty
            ? existing.first
            : WidgetTaskState(
                taskId: id,
                name: name,
                status: 'never',
                lastSyncIso: '',
              );

        if (st.status == 'never' || st.status == 'error') {
          needsSync = true;
        }

        if (isMedia) {
          final localNow = await _countLocalAlbums(
            type: _requestTypeFor(src),
            albums: albums,
          );
          final localChanged = st.mediaCountAtLastSync != localNow;

          int? remoteNow;
          if (includeRemote) {
            final target = _targetForTask(t);
            if (target != null) {
              remoteNow = await _countRemoteAlbums(
                remoteId: target.remoteId,
                remotePath: target.remotePath,
                albums: albums,
              );
            }
          }
          final remoteChanged = remoteNow != null &&
              st.remoteCountAtLastSync >= 0 &&
              st.remoteCountAtLastSync != remoteNow;

          if (localChanged || remoteChanged) {
            needsSync = true;
            if (st.status == 'ok' || st.status == 'pending') {
              st = WidgetTaskState(
                taskId: st.taskId,
                name: st.name.isNotEmpty ? st.name : name,
                status: 'pending',
                lastSyncIso: st.lastSyncIso,
                mediaCountAtLastSync: st.mediaCountAtLastSync,
                remoteCountAtLastSync: st.remoteCountAtLastSync,
              );
            }
          } else if (st.status == 'pending' &&
              st.lastSyncIso.isNotEmpty &&
              !localChanged &&
              !remoteChanged) {
            // Counts wieder wie beim letzten Sync → kein Bedarf.
            st = WidgetTaskState(
              taskId: st.taskId,
              name: st.name.isNotEmpty ? st.name : name,
              status: 'ok',
              lastSyncIso: st.lastSyncIso,
              mediaCountAtLastSync: st.mediaCountAtLastSync,
              remoteCountAtLastSync: st.remoteCountAtLastSync,
            );
          } else if (st.status == 'pending') {
            needsSync = true;
          }

          // Aktuelle Messung nur im Log — Baseline bleibt lastSync-Stand.
          AppLog.info(
            'widget',
            'Task „$name“: lokal=$localNow (basis=${st.mediaCountAtLastSync})'
            '${remoteNow != null ? ', remote=$remoteNow (basis=${st.remoteCountAtLastSync})' : ''}'
            ', alben=${albums.isEmpty ? 'alle' : albums.join('|')}',
          );
        } else if (st.status == 'pending') {
          needsSync = true;
        }

        if (existing.isEmpty && st.status == 'never') {
          needsSync = true;
        }
        tasks.add(st);
      }

      final hasError = tasks.any((t) => t.status == 'error');
      state = state.copyWith(
        tasks: tasks,
        activeTaskCount: activeTasks.length,
        needsSync: needsSync || hasError,
      );
      if (!hasError) state = state.copyWith(lastError: '');
      AppLog.info('widget',
          'Widget-Status: ${state.activeTaskCount} aktive Tasks, needsSync=${state.needsSync}, remoteCheck=$includeRemote');
      await _persist();
      await _pushToWidget();
    } catch (e) {
      AppLog.warn('widget', 'Widget-Recompute fehlgeschlagen: $e');
    }
  }

  /// Nach abgeschlossenem Task-Run: Baseline = aktuelle Task-Alben (lokal+remote).
  Future<void> reportTaskRun(String taskId, String taskName,
      {String? error, Map<String, dynamic>? taskJson}) async {
    final now = DateTime.now().toUtc().toIso8601String();

    // Task-Metadaten: bevorzugt übergeben, sonst aus tasks.json.
    Map<String, dynamic>? meta = taskJson;
    if (meta == null) {
      try {
        final tasksFile = await privateAppFile('tasks.json');
        if (await tasksFile.exists()) {
          final decoded = jsonDecode(await tasksFile.readAsString());
          if (decoded is List) {
            for (final e in decoded) {
              if (e is Map && e['id'] == taskId) {
                meta = Map<String, dynamic>.from(e);
                break;
              }
            }
          }
        }
      } catch (_) {}
    }

    var localCount = 0;
    var remoteCount = -1;
    if (meta != null && error == null) {
      final src = meta['sourcePath'] as String? ?? '';
      if (_isMediaSource(src)) {
        final albums = _albumsForTask(meta);
        localCount = await _countLocalAlbums(
          type: _requestTypeFor(src),
          albums: albums,
        );
        final target = _targetForTask(meta);
        if (target != null) {
          final r = await _countRemoteAlbums(
            remoteId: target.remoteId,
            remotePath: target.remotePath,
            albums: albums,
          );
          if (r != null) remoteCount = r;
        }
      }
    } else {
      // Fallback: alten Stand behalten, falls Task-Meta fehlt.
      final prev = state.tasks.where((t) => t.taskId == taskId);
      if (prev.isNotEmpty) {
        localCount = prev.first.mediaCountAtLastSync;
        remoteCount = prev.first.remoteCountAtLastSync;
      }
    }

    final updated = [...state.tasks];
    final idx = updated.indexWhere((t) => t.taskId == taskId);
    final item = WidgetTaskState(
      taskId: taskId,
      name: taskName.isNotEmpty ? taskName : taskId,
      status: error == null ? 'ok' : 'error',
      lastSyncIso: now,
      mediaCountAtLastSync: localCount,
      remoteCountAtLastSync: remoteCount,
    );
    if (idx >= 0) {
      updated[idx] = item;
    } else {
      updated.add(item);
    }

    final stillNeeds = error != null ||
        updated.any((t) =>
            t.status == 'never' ||
            t.status == 'error' ||
            t.status == 'pending');

    state = state.copyWith(
      tasks: updated,
      lastSyncIso: now,
      lastError: error ?? '',
      needsSync: stillNeeds,
    );
    await _persist();
    await _pushToWidget();
  }
}

/// Zentraler Provider für den Widget-Status.
final widgetStatusProvider =
    StateNotifierProvider<WidgetStatusNotifier, WidgetStatusData>((ref) {
  final notifier = WidgetStatusNotifier(
    rclone: ref.watch(rcloneServiceProvider),
  );
  ref.listen<RcloneService>(rcloneServiceProvider, (_, next) {
    notifier.attachRclone(next);
  });
  return notifier;
});

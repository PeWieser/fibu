import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/services/network_status_service.dart';
import '../../../core/services/rclone_service.dart';
import '../../../core/services/rclone_provider.dart';
import '../../../core/services/settings_service.dart';
import '../../tasks/presentation/tasks_controller.dart';

/// State object representing the status and progress of the active background backup task.
class ActiveJobState {
  final String? jobId;
  final RcloneJobStatus status;
  final double percentage;
  final String currentFile;
  final String eta;
  final List<String> logs;

  /// Anzahl bereits übertragener Dateien (0 = keine Info).
  final int itemsDone;

  /// Gesamtzahl der Dateien des aktuellen Laufs (0 = unbekannt).
  final int itemsTotal;

  const ActiveJobState({
    this.jobId,
    this.status = RcloneJobStatus.completed,
    this.percentage = 0.0,
    this.currentFile = '',
    this.eta = '',
    this.logs = const [],
    this.itemsDone = 0,
    this.itemsTotal = 0,
  });

  ActiveJobState copyWith({
    String? jobId,
    RcloneJobStatus? status,
    double? percentage,
    String? currentFile,
    String? eta,
    List<String>? logs,
    int? itemsDone,
    int? itemsTotal,
  }) {
    return ActiveJobState(
      jobId: jobId ?? this.jobId,
      status: status ?? this.status,
      percentage: percentage ?? this.percentage,
      currentFile: currentFile ?? this.currentFile,
      eta: eta ?? this.eta,
      logs: logs ?? this.logs,
      itemsDone: itemsDone ?? this.itemsDone,
      itemsTotal: itemsTotal ?? this.itemsTotal,
    );
  }
}

/// StateNotifier handling the execution, status tracking, and progress reporting of backup tasks.
class ActiveJobNotifier extends StateNotifier<ActiveJobState> {
  final RcloneService _rcloneService;
  final Ref _ref;
  StreamSubscription? _globalStatusSub;
  StreamSubscription? _progressSub;
  bool _isCancelled = false;

  ActiveJobNotifier(this._rcloneService, this._ref) : super(const ActiveJobState()) {
    // Listen globally to status updates
    _globalStatusSub = _rcloneService.watchJobStatus().listen(_handleStatusChange);
  }

  String _timestamp() {
    final now = DateTime.now();
    return '[${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}]';
  }

  /// Übersetzt rohe Sync-/Netzwerkfehler in klare, lokalisierte Meldungen.
  String _friendlySyncError(AppStrings strings, Object error) {
    final raw = error.toString().replaceAll('Exception: ', '').trim();
    final lower = raw.toLowerCase();
    if (lower.contains('offline') ||
        lower.contains('network') ||
        lower.contains('netzwerk') ||
        lower.contains('internet') ||
        lower.contains('socket') ||
        lower.contains('timed out') ||
        lower.contains('timeout')) {
      return strings.networkUnavailableError;
    }
    if (lower.contains('didn\'t find section') ||
        lower.contains("couldn't find") ||
        lower.contains('not found in config') ||
        lower.contains('no such remote') ||
        lower.contains('no section')) {
      return strings.remoteNotFoundHint;
    }
    if (lower.contains('unauthorized') ||
        lower.contains('forbidden') ||
        lower.contains('401') ||
        lower.contains('403') ||
        lower.contains('token') ||
        lower.contains('auth') ||
        lower.contains('anmeldung')) {
      return strings.syncAuthError;
    }
    if (lower.contains('quota') ||
        lower.contains('insufficient storage') ||
        lower.contains('speicherplatz') ||
        lower.contains('no space')) {
      return strings.syncQuotaError;
    }
    return raw;
  }

  /// Prüft die globalen Netzwerkregeln vor einem Sync.
  ///
  /// Liefert null, wenn synchronisiert werden darf, sonst eine lokalisierte
  /// Sperr-Begründung (Offline bzw. globales WLAN-only bei Mobilfunk).
  String? _networkBlockReason(AppStrings strings) {
    final net = _ref.read(networkStatusProvider);
    if (!net.online) return strings.networkUnavailableError;
    if (_ref.read(wifiOnlySyncProvider) && !net.onWifi) {
      return strings.cellularSyncBlockedNotice;
    }
    return null;
  }

  /// Synchronisiert eine einzelne Aufgabe. Gibt true bei Erfolg, false bei
  /// Abbruch oder Fehler zurück. Setzt dabei den Job-State selbst.
  Future<bool> _syncSingleTask(BackupTask task) async {
    final parts = task.targetRemote.split(':');
    final remoteName = parts[0];
    final targetFolder = task.targetFolderMode == TargetFolderMode.root
        ? ''
        : task.targetFolderName.trim().replaceAll(RegExp(r'^/|/$'), '');
    final remotePath = parts.length > 1 && parts[1].isNotEmpty
        ? (targetFolder.isNotEmpty ? '${parts[1]}/$targetFolder' : parts[1])
        : targetFolder;

    final List<String> includeFilters = [];
    final srcLower = task.sourcePath.toLowerCase();
    final srcBase = srcLower.startsWith('photos:')
        ? 'photos'
        : (srcLower.startsWith('videos:')
            ? 'videos'
            : (srcLower.startsWith('all:') ? 'all' : srcLower));
    if (srcBase == 'photos' || srcBase == 'alle fotos') {
      includeFilters.addAll(['*.jpg', '*.jpeg', '*.png', '*.heic', '*.webp', '*.gif', '*.raw', '*.cr2', '*.nef', '*.dng', '*.heif']);
    } else if (srcBase == 'videos' || srcBase == 'alle videos') {
      includeFilters.addAll(['*.mp4', '*.mov', '*.avi', '*.mkv', '*.webm', '*.m4v', '*.3gp']);
    } else if (srcBase == 'all' || srcBase == 'alles' || srcBase == 'media' || srcBase == 'mediathek') {
      includeFilters.addAll([
        '*.jpg', '*.jpeg', '*.png', '*.heic', '*.webp', '*.gif', '*.raw', '*.cr2', '*.nef', '*.dng', '*.heif',
        '*.mp4', '*.mov', '*.avi', '*.mkv', '*.webm', '*.m4v', '*.3gp',
      ]);
    }

    final strings = _ref.read(stringsProvider);

    // Globale Netzwerkregeln direkt vor dem Task-Start prüfen (die
    // Verbindung kann mitten in der Queue abreißen).
    final blockReason = _networkBlockReason(strings);
    if (blockReason != null) {
      final t = _timestamp();
      state = state.copyWith(
        status: RcloneJobStatus.failed,
        currentFile: blockReason,
        logs: [...state.logs, '$t Task "${task.name}": $blockReason'],
      );
      return false;
    }

    final isEcho = task.syncMode == SyncMode.mirror;
    final modeLabel = isEcho ? '2-Way Mirror (Echo)' : 'Incremental';
    final startMsg = '${_timestamp()} Task "${task.name}" ($modeLabel): starting sync to $remoteName:$remotePath...';
    state = state.copyWith(
      logs: [...state.logs, startMsg],
    );

    try {
      final jobId = await _rcloneService.startBackupJob(
        localPath: task.sourcePath,
        remoteName: remoteName,
        remotePath: remotePath,
        options: SyncOptions(
          isEchoMode: isEcho,
          includeFilters: includeFilters,
          excludeFilters: task.excludedFiles,
        ),
      );

      if (!mounted) return false;
      state = state.copyWith(
        jobId: jobId,
        status: RcloneJobStatus.pending,
        percentage: 0.0,
        currentFile: 'Starting: ${task.name}...',
      );

      // Subscribe to this job's progress
      _progressSub?.cancel();
      _progressSub = _rcloneService.watchJobProgress(jobId).listen((event) {
        if (!mounted) return;
        if (event.jobId == state.jobId) {
          final t = _timestamp();
          final logLine = '$t [Progress] ${event.percentage.toStringAsFixed(1)}% - ${event.currentFile}';

          final newLogs = List<String>.from(state.logs);
          if (newLogs.isEmpty || !newLogs.last.contains(event.currentFile)) {
            newLogs.add(logLine);
          } else {
            newLogs[newLogs.length - 1] = logLine;
          }

          state = state.copyWith(
            percentage: event.percentage,
            currentFile: '[${task.name}] ${event.currentFile}',
            eta: event.eta,
            itemsDone: event.itemsDone,
            itemsTotal: event.itemsTotal,
            logs: newLogs,
          );
        }
      });

      // Wait for this job to finish
      final completer = Completer<void>();
      final statusSub = _rcloneService.watchJobStatus().listen((event) {
        if (event.jobId == jobId) {
          if (event.status == RcloneJobStatus.completed) {
            if (!completer.isCompleted) completer.complete();
          } else if (event.status == RcloneJobStatus.failed) {
            if (!completer.isCompleted) completer.completeError(event.error ?? 'Sync process failed');
          } else if (event.status == RcloneJobStatus.cancelled) {
            if (!completer.isCompleted) completer.completeError('Backup cancelled');
          }
        }
      });

      try {
        await completer.future;
        if (!mounted) {
          await statusSub.cancel();
          return false;
        }
        final endMsg = '${_timestamp()} Task "${task.name}" completed successfully!';
        state = state.copyWith(
          logs: [...state.logs, endMsg],
        );
      } finally {
        await statusSub.cancel();
      }
      return true;
    } catch (e) {
      _progressSub?.cancel();
      _progressSub = null;
      if (!mounted) return false;
      final isCancelled = e.toString() == 'Backup cancelled' || _isCancelled;
      final friendly = _friendlySyncError(strings, e);
      final failMsg = '${_timestamp()} Task "${task.name}" failed: $friendly';
      state = state.copyWith(
        status: isCancelled ? RcloneJobStatus.cancelled : RcloneJobStatus.failed,
        currentFile: isCancelled ? 'Backup stopped.' : friendly,
        logs: [...state.logs, failMsg],
      );
      return false;
    }
  }

  /// Synchronisiert die gesamte aktive Warteschlange.
  Future<void> triggerSyncAll() async {
    // Prevent duplicate triggers
    if (state.status == RcloneJobStatus.syncing || state.status == RcloneJobStatus.pending) {
      return;
    }

    _isCancelled = false;
    final strings = _ref.read(stringsProvider);

    // Offline/WLAN-only blockieren, bevor überhaupt ein Task startet.
    final blockReason = _networkBlockReason(strings);
    final timestamp = _timestamp();
    if (blockReason != null) {
      state = ActiveJobState(
        status: RcloneJobStatus.failed,
        currentFile: blockReason,
        logs: ['$timestamp Queue started.', '$timestamp $blockReason'],
      );
      return;
    }

    final activeTasks = _ref.read(tasksListProvider).where((t) => t.isActive).toList();

    if (activeTasks.isEmpty) {
      state = ActiveJobState(
        status: RcloneJobStatus.failed,
        currentFile: 'No active backup tasks found. Enable tasks in the Tasks tab.',
        logs: ['$timestamp Queue started.', '$timestamp Error: No active backup tasks found.'],
      );
      return;
    }

    state = ActiveJobState(
      status: RcloneJobStatus.pending,
      currentFile: 'Preparing active backup jobs...',
      logs: ['$timestamp Queue started. Analyzing active tasks...'],
    );

    for (final task in activeTasks) {
      if (_isCancelled) break;
      if (!mounted) return;
      final ok = await _syncSingleTask(task);
      if (!ok) {
        // Ein Task ist fehlgeschlagen/abgebrochen → Queue beenden (wie bisher).
        _progressSub?.cancel();
        _progressSub = null;
        return;
      }
    }

    _progressSub?.cancel();
    _progressSub = null;

    if (!_isCancelled) {
      if (!mounted) return;
      final doneMsg = '${_timestamp()} Queue finished successfully. All active tasks synchronized.';
      state = const ActiveJobState(
        status: RcloneJobStatus.completed,
        currentFile: 'All active backup tasks completed successfully!',
      ).copyWith(
        logs: [...state.logs, doneMsg],
      );
    }
  }

  /// Synchronisiert ausschließlich die angegebene Aufgabe (für die Detail-Ansicht).
  Future<void> triggerSyncTask(String taskId) async {
    // Prevent duplicate triggers
    if (state.status == RcloneJobStatus.syncing || state.status == RcloneJobStatus.pending) {
      return;
    }

    _isCancelled = false;
    BackupTask? task;
    for (final t in _ref.read(tasksListProvider)) {
      if (t.id == taskId) {
        task = t;
        break;
      }
    }
    if (task == null) {
      state = ActiveJobState(
        status: RcloneJobStatus.failed,
        currentFile: 'Task not found.',
        logs: [...state.logs, '${_timestamp()} Error: Task not found.'],
      );
      return;
    }

    final timestamp = _timestamp();
    final strings = _ref.read(stringsProvider);
    final blockReason = _networkBlockReason(strings);
    if (blockReason != null) {
      state = ActiveJobState(
        status: RcloneJobStatus.failed,
        currentFile: blockReason,
        logs: ['$timestamp $blockReason'],
      );
      return;
    }

    state = ActiveJobState(
      status: RcloneJobStatus.pending,
      currentFile: 'Preparing ${task.name}...',
      logs: ['$timestamp Task sync started. Preparing "${task.name}"...'],
    );

    final ok = await _syncSingleTask(task);
    _progressSub?.cancel();
    _progressSub = null;
    if (!mounted) return;
    if (ok) {
      final doneMsg = '${_timestamp()} Task "${task.name}" synchronized successfully.';
      state = const ActiveJobState(
        status: RcloneJobStatus.completed,
        currentFile: 'Task synchronized successfully!',
      ).copyWith(
        logs: [...state.logs, doneMsg],
      );
    }
  }

  void _handleStatusChange(RcloneJobEvent event) {
    if (event.jobId == state.jobId) {
      if (event.status == RcloneJobStatus.completed ||
          event.status == RcloneJobStatus.failed ||
          event.status == RcloneJobStatus.cancelled) {
        _progressSub?.cancel();
        _progressSub = null;
      }
    }
  }

  Future<void> cancelActiveSync() async {
    _isCancelled = true;
    final activeId = state.jobId;
    if (activeId != null) {
      await _rcloneService.cancelBackupJob(activeId);
    }
    final cancelMsg = '${_timestamp()} Sync cancelled by user.';
    state = ActiveJobState(
      status: RcloneJobStatus.cancelled,
      currentFile: 'Sync cancelled by user.',
      logs: [...state.logs, cancelMsg],
    );
  }

  @override
  void dispose() {
    _globalStatusSub?.cancel();
    _progressSub?.cancel();
    super.dispose();
  }
}

/// Riverpod provider for active job state.
final activeJobProvider = StateNotifierProvider<ActiveJobNotifier, ActiveJobState>((ref) {
  return ActiveJobNotifier(ref.watch(rcloneServiceProvider), ref);
});

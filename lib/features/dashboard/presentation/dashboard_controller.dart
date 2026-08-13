import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/rclone_service.dart';
import '../../../core/services/rclone_provider.dart';
import '../../tasks/presentation/tasks_controller.dart';

/// State object representing the status and progress of the active background backup task.
class ActiveJobState {
  final String? jobId;
  final RcloneJobStatus status;
  final double percentage;
  final String currentFile;
  final String eta;
  final List<String> logs;

  const ActiveJobState({
    this.jobId,
    this.status = RcloneJobStatus.completed,
    this.percentage = 0.0,
    this.currentFile = '',
    this.eta = '',
    this.logs = const [],
  });

  ActiveJobState copyWith({
    String? jobId,
    RcloneJobStatus? status,
    double? percentage,
    String? currentFile,
    String? eta,
    List<String>? logs,
  }) {
    return ActiveJobState(
      jobId: jobId ?? this.jobId,
      status: status ?? this.status,
      percentage: percentage ?? this.percentage,
      currentFile: currentFile ?? this.currentFile,
      eta: eta ?? this.eta,
      logs: logs ?? this.logs,
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

  Future<void> triggerSyncAll() async {
    // Prevent duplicate triggers
    if (state.status == RcloneJobStatus.syncing || state.status == RcloneJobStatus.pending) {
      return;
    }

    _isCancelled = false;
    final activeTasks = _ref.read(tasksListProvider).where((t) => t.isActive).toList();

    final timestamp = _timestamp();
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

      final parts = task.targetRemote.split(':');
      final remoteName = parts[0];
      final remotePath = parts.length > 1 ? parts[1] : '';

      final startMsg = '${_timestamp()} Task "${task.name}": starting copy to ${task.targetRemote}...';
      state = state.copyWith(
        logs: [...state.logs, startMsg],
      );

      try {
        final jobId = await _rcloneService.startBackupJob(
          localPath: task.sourcePath,
          remoteName: remoteName,
          remotePath: remotePath,
          options: const SyncOptions(isEchoMode: false),
        );

        if (!mounted) return;
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
            return;
          }
          final endMsg = '${_timestamp()} Task "${task.name}" completed successfully!';
          state = state.copyWith(
            logs: [...state.logs, endMsg],
          );
        } finally {
          await statusSub.cancel();
        }
      } catch (e) {
        _progressSub?.cancel();
        _progressSub = null;
        if (!mounted) return;
        final failMsg = '${_timestamp()} Task "${task.name}" failed: $e';
        state = state.copyWith(
          status: e.toString() == 'Backup cancelled' || _isCancelled ? RcloneJobStatus.cancelled : RcloneJobStatus.failed,
          currentFile: 'Backup stopped: $e',
          logs: [...state.logs, failMsg],
        );
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

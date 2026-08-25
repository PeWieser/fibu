import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/services/network_status_service.dart';
import '../../../core/services/remote_registry_service.dart';
import '../../../core/services/widget_status_service.dart';
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

  /// Bereits übertragene Bytes der aktuellen Transfer-Phase (0 = keine Info).
  final int bytesTransferred;

  /// Insgesamt zu übertragende Bytes der aktuellen Transfer-Phase.
  final int totalBytes;

  const ActiveJobState({
    this.jobId,
    this.status = RcloneJobStatus.completed,
    this.percentage = 0.0,
    this.currentFile = '',
    this.eta = '',
    this.logs = const [],
    this.itemsDone = 0,
    this.itemsTotal = 0,
    this.bytesTransferred = 0,
    this.totalBytes = 0,
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
    int? bytesTransferred,
    int? totalBytes,
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
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      totalBytes: totalBytes ?? this.totalBytes,
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
  ///
  /// Bei mehreren Ziel-Laufwerken (Strategie „mirrorAll“) wird nacheinander
  /// auf JEDES verbundene Ziel synchronisiert.
  Future<bool> _syncSingleTask(BackupTask task) async {
    final strings = _ref.read(stringsProvider);
    final targets = task.targetRemotes.isNotEmpty
        ? task.targetRemotes
        : (task.targetRemote.isNotEmpty ? [task.targetRemote] : const <String>[]);

    if (targets.isEmpty) {
      final t = _timestamp();
      state = state.copyWith(
        status: RcloneJobStatus.failed,
        currentFile: strings.remoteNotFoundHint,
        logs: [...state.logs, '$t Task "${task.name}": ${strings.remoteNotFoundHint}'],
      );
      return false;
    }

    // Vorprüfung: Existiert das Ziel noch? (Registry = Quelle der Wahrheit.)
    // So scheitert der Lauf mit einer klaren Meldung statt eines rclone-
    // Fehlers „didn't find section in config file“.
    final entries = _ref.read(remoteEntriesProvider).valueOrNull;
    if (entries != null) {
      for (final target in targets) {
        final id = target.split(':').first;
        final known = entries.any((e) => e.id == id || e.name == id);
        if (!known) {
          final t = _timestamp();
          final msg = strings.remoteMissingInTask(id);
          state = state.copyWith(
            status: RcloneJobStatus.failed,
            currentFile: strings.remoteNotFoundHint,
            logs: [...state.logs, '$t Task "${task.name}": $msg'],
          );
          return false;
        }
      }
    }

    for (final target in targets) {
      final ok = await _syncTaskToRemote(task, target, strings);
      if (!ok) return false;
    }
    return true;
  }

  /// Führt den eigentlichen Sync einer Aufgabe auf EIN Ziel-Remote aus.
  Future<bool> _syncTaskToRemote(
    BackupTask task,
    String target,
    AppStrings strings,
  ) async {
    final parts = target.split(':');
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
    final modeLabel = isEcho ? 'Mirror-Sync (2-Wege)' : 'Incremental';
    final startMsg = '${_timestamp()} Task "${task.name}" ($modeLabel): starting sync to $remoteName:$remotePath...';
    state = state.copyWith(
      percentage: 0.0,
      itemsDone: 0,
      itemsTotal: 0,
      bytesTransferred: 0,
      totalBytes: 0,
      currentFile: strings.startingTask(task.name),
      logs: [...state.logs, startMsg],
    );

    final startedAt = DateTime.now();
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
        currentFile: strings.startingTask(task.name),
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

          // Bevorzuge Byte-Prozentsatz, sobald die Engine echte Bytes
          // liefert (Upload/Download). Bei Scan/Staging-Phasen ohne
          // Byte-Info (totalBytes == 0) beim rohen Event-Prozentsatz bleiben.
          final effectivePct = event.totalBytes > 0
              ? (event.bytesTransferred / event.totalBytes * 100.0)
                  .clamp(0.0, 100.0)
                  .toDouble()
              : event.percentage;

          state = state.copyWith(
            percentage: effectivePct,
            currentFile: '[${task.name}] ${event.currentFile}',
            eta: event.eta,
            itemsDone: event.itemsDone,
            itemsTotal: event.itemsTotal,
            bytesTransferred: event.bytesTransferred,
            totalBytes: event.totalBytes,
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
        // Blitz-Läufe (nichts zu übertragen) kurz halten: Ein Balken, der
        // nur aufblitzt, wirkt hektisch. Mindestens ~1,6 s sichtbare Ruhe —
        // echte Übertragungen dauern ohnehin länger und warten nie.
        final elapsed = DateTime.now().difference(startedAt);
        // Ruhiger Balken bei No-Op-Syncs (~2 s), damit nichts nur aufblitzt.
        // Echte Transfers dauern länger und warten hier nie.
        const minVisible = Duration(milliseconds: 2000);
        if (elapsed < minVisible) {
          await Future.delayed(minVisible - elapsed);
        }
        if (!mounted) {
          await statusSub.cancel();
          return false;
        }
        final endMsg = '${_timestamp()} Task "${task.name}" completed successfully!';
        state = state.copyWith(
          logs: [...state.logs, endMsg],
        );
        // Homescreen-Widget informieren: Task ist erfolgreich synchronisiert.
        // Task-JSON mitgeben → Baseline = genau die konfigurierten Alben.
        await _ref.read(widgetStatusProvider.notifier).reportTaskRun(
              task.id,
              task.name,
              taskJson: _taskJsonForWidget(task),
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
      await _ref.read(widgetStatusProvider.notifier).reportTaskRun(
            task.id,
            task.name,
            error: friendly,
            taskJson: _taskJsonForWidget(task),
          );
      state = state.copyWith(
        status: isCancelled ? RcloneJobStatus.cancelled : RcloneJobStatus.failed,
        currentFile: isCancelled ? strings.backupStopped : friendly,
        logs: [...state.logs, failMsg],
      );
      return false;
    }
  }

  /// Cloud-Speicheranzeigen invalidieren — nach jedem Sync-Lauf hat sich
  /// die Belegung geändert; Dashboard-Karte & Quota laden dann frisch.
  void _refreshQuotaProviders() {
    _ref.invalidate(primaryQuotaProvider);
    _ref.invalidate(remoteQuotaProvider);
    _ref.invalidate(remoteFibuUsageProvider);
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
        currentFile: strings.noActiveTasksError,
        logs: ['$timestamp Queue started.', '$timestamp Error: No active backup tasks found.'],
      );
      return;
    }

    state = ActiveJobState(
      status: RcloneJobStatus.pending,
      currentFile: strings.queuePreparingJobs,
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
        _refreshQuotaProviders();
        return;
      }
    }
    _refreshQuotaProviders();

    _progressSub?.cancel();
    _progressSub = null;

    if (!_isCancelled) {
      if (!mounted) return;
      final doneMsg = '${_timestamp()} Queue finished successfully. All active tasks synchronized.';
      state = ActiveJobState(
        status: RcloneJobStatus.completed,
        currentFile: AppStrings.current.allTasksCompleted,
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
    final strings = _ref.read(stringsProvider);
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
        currentFile: strings.taskNotFoundError,
        logs: [...state.logs, '${_timestamp()} Error: ${strings.taskNotFoundError}'],
      );
      return;
    }

    final timestamp = _timestamp();
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
      currentFile: strings.preparingTask(task.name),
      logs: ['$timestamp Task sync started. Preparing "${task.name}"...'],
    );

    final ok = await _syncSingleTask(task);
    _progressSub?.cancel();
    _progressSub = null;
    _refreshQuotaProviders();
    if (!mounted) return;
    if (ok) {
      final doneMsg = '${_timestamp()} Task "${task.name}" synchronized successfully.';
      state = ActiveJobState(
        status: RcloneJobStatus.completed,
        currentFile: AppStrings.current.taskSyncedSuccess,
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
      currentFile: AppStrings.current.syncCancelledByUser,
      logs: [...state.logs, cancelMsg],
    );
  }

  /// Task-Felder, die der Widget-Status für die Alben-Baseline braucht.
  Map<String, dynamic> _taskJsonForWidget(BackupTask task) => {
        'id': task.id,
        'name': task.name,
        'sourcePath': task.sourcePath,
        'selectedAlbums': task.selectedAlbums,
        'targetRemotes': task.targetRemotes,
        'targetRemote': task.targetRemote,
        'targetFolderMode': task.targetFolderMode == TargetFolderMode.root
            ? 'root'
            : (task.targetFolderMode == TargetFolderMode.newFolder
                ? 'newFolder'
                : 'custom'),
        'targetFolderName': task.targetFolderName,
        'isActive': task.isActive,
      };

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

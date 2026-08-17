import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

import 'librclone_channel.dart';
import 'rclone_provider_registry.dart';
import 'rclone_service.dart';

/// Real rclone-backed service for iOS (and Android) using the gomobile
/// `librclone` engine through [LibrcloneChannel].
///
/// Unlike the previous simulated mobile service, every transfer, listing and
/// quota query is a genuine rclone remote-control call, so backups actually
/// reach the cloud and progress reflects real byte counts.
class IosRcloneService implements RcloneService {
  final LibrcloneChannel _rc = LibrcloneChannel.instance;

  final StreamController<RcloneJobEvent> _statusController =
      StreamController<RcloneJobEvent>.broadcast();
  final Map<String, StreamController<RcloneProgressEvent>> _progressControllers = {};
  // Maps our public jobId -> the librclone async job id + stats group.
  final Map<String, int> _rcJobIds = {};

  Future<void> _ensureEngine() async {
    final dir = await getApplicationDocumentsDirectory();
    final configPath = '${dir.path}/rclone.conf';
    await _rc.ensureInitialized(configPath);
  }

  // ---------------------------------------------------------------------------
  // Remote configuration
  // ---------------------------------------------------------------------------

  @override
  Future<List<String>> listRemotes() async {
    await _ensureEngine();
    final res = await _rc.rpc('config/listremotes');
    final remotes = (res['remotes'] as List<dynamic>? ?? []).cast<String>();
    return remotes;
  }

  @override
  Future<void> addRemote({
    required String name,
    required String type,
    required Map<String, String> config,
  }) async {
    await _ensureEngine();
    await _rc.rpc('config/create', {
      'name': name,
      'type': type,
      'parameters': config,
      'opt': {'obscure': true, 'nonInteractive': true},
    });
  }

  @override
  Future<void> removeRemote(String name) async {
    await _ensureEngine();
    await _rc.rpc('config/delete', {'name': name});
  }

  @override
  Future<String> obscurePassword(String plainPassword) async {
    await _ensureEngine();
    final res = await _rc.rpc('core/obscure', {'clear': plainPassword});
    return res['obscured'] as String? ?? plainPassword;
  }

  // ---------------------------------------------------------------------------
  // Quota
  // ---------------------------------------------------------------------------

  @override
  Future<QuotaInfo> getQuota(String remoteName) async {
    await _ensureEngine();
    try {
      final res = await _rc.rpc('operations/about', {'fs': '$remoteName:'});
      final total = (res['total'] as num?)?.toInt() ?? 0;
      final used = (res['used'] as num?)?.toInt() ?? 0;
      final free = (res['free'] as num?)?.toInt() ?? (total - used).clamp(0, total);
      return QuotaInfo(totalBytes: total, usedBytes: used, freeBytes: free);
    } catch (_) {
      // Providers without an `about` command: report unknown rather than fake data.
      return const QuotaInfo(totalBytes: 0, usedBytes: 0, freeBytes: 0);
    }
  }

  // ---------------------------------------------------------------------------
  // Listing / read / delete
  // ---------------------------------------------------------------------------

  @override
  Future<List<RcloneFileInfo>> listFiles(String remoteName, String path) async {
    await _ensureEngine();
    final res = await _rc.rpc('operations/list', {
      'fs': '$remoteName:',
      'remote': path,
    });
    final list = (res['list'] as List<dynamic>? ?? []);
    return list.map((raw) {
      final m = raw as Map<String, dynamic>;
      return RcloneFileInfo(
        name: m['Name'] as String? ?? '',
        size: (m['Size'] as num?)?.toInt() ?? 0,
        isDir: m['IsDir'] as bool? ?? false,
        modTime: m['ModTime'] as String? ?? '',
      );
    }).toList();
  }

  @override
  Future<void> deleteFile(String remoteName, String path) async {
    await _ensureEngine();
    await _rc.rpc('operations/deletefile', {
      'fs': '$remoteName:',
      'remote': path,
    });
  }

  @override
  Future<String?> catFile(String remoteName, String path) async {
    // Download to a temp file, then read as text. Binary callers should use the
    // returned temp file from [downloadToCache] instead.
    final local = await downloadToCache(remoteName, path);
    if (local == null) return null;
    try {
      return await local.readAsString();
    } catch (_) {
      return null; // Not a text file.
    }
  }

  /// Downloads a single remote file into the app cache and returns the local file.
  Future<File?> downloadToCache(String remoteName, String path) async {
    await _ensureEngine();
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}/fibu_preview_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    final fileName = path.split('/').last;
    final srcDir = path.contains('/') ? path.substring(0, path.lastIndexOf('/')) : '';
    try {
      await _rc.rpc('operations/copyfile', {
        'srcFs': '$remoteName:$srcDir',
        'srcRemote': fileName,
        'dstFs': cacheDir.path,
        'dstRemote': fileName,
      });
      final local = File('${cacheDir.path}/$fileName');
      return await local.exists() ? local : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> copyFileToRemote(
    String localFilePath,
    String remoteName,
    String remotePath,
  ) async {
    await _ensureEngine();
    final fileName = localFilePath.split(Platform.pathSeparator).last;
    final srcDir = localFilePath.substring(0, localFilePath.length - fileName.length - 1);
    await _rc.rpc('operations/copyfile', {
      'srcFs': srcDir,
      'srcRemote': fileName,
      'dstFs': '$remoteName:$remotePath',
      'dstRemote': fileName,
    });
  }

  @override
  Future<void> downloadDirectory(
    String remoteName,
    String remotePath,
    String localPath,
  ) async {
    await _ensureEngine();
    await _rc.rpc('sync/copy', {
      'srcFs': '$remoteName:$remotePath',
      'dstFs': localPath,
    });
  }

  @override
  Future<List<RcloneProviderInfo>> listProviders() async {
    // The static registry is the curated, localized provider list used by the UI.
    return RcloneProviderRegistry.providers.map((p) => p.toProviderInfo()).toList();
  }

  // ---------------------------------------------------------------------------
  // Backup jobs (real transfer + real progress)
  // ---------------------------------------------------------------------------

  @override
  Future<String> startBackupJob({
    required String localPath,
    required String remoteName,
    required String remotePath,
    required SyncOptions options,
  }) async {
    final jobId = 'job_${DateTime.now().millisecondsSinceEpoch}';
    final progressController = StreamController<RcloneProgressEvent>.broadcast();
    _progressControllers[jobId] = progressController;

    _statusController.add(RcloneJobEvent(jobId: jobId, status: RcloneJobStatus.syncing));
    unawaited(_runJob(jobId, localPath, remoteName, remotePath, options, progressController));
    return jobId;
  }

  Future<void> _runJob(
    String jobId,
    String localPath,
    String remoteName,
    String remotePath,
    SyncOptions options,
    StreamController<RcloneProgressEvent> progress,
  ) async {
    try {
      await _ensureEngine();

      // Pre-flight: network guard.
      final conn = await Connectivity().checkConnectivity();
      if (conn.contains(ConnectivityResult.none) || conn.isEmpty) {
        _fail(jobId, 'Offline: Keine aktive Netzwerkverbindung');
        return;
      }

      // Resolve the local source. Media backups are staged from PhotoKit into a
      // temp directory that mirrors the album hierarchy, then synced as a folder.
      final String srcFs = await _resolveLocalSource(localPath, options);

      final group = 'job/$jobId';
      final method = options.isEchoMode ? 'sync/sync' : 'sync/copy';
      final startRes = await _rc.rpc(method, {
        'srcFs': srcFs,
        'dstFs': '$remoteName:$remotePath',
        '_async': true,
        '_group': group,
        if (options.includeFilters.isNotEmpty || options.excludeFilters.isNotEmpty)
          '_filter': {
            if (options.includeFilters.isNotEmpty) 'IncludeRule': options.includeFilters,
            if (options.excludeFilters.isNotEmpty) 'ExcludeRule': options.excludeFilters,
          },
        if (options.maxSpeedKbps > 0)
          '_config': {'BwLimit': '${options.maxSpeedKbps}k'},
      });

      final rcJobId = (startRes['jobid'] as num?)?.toInt();
      if (rcJobId == null) {
        _fail(jobId, 'rclone lieferte keine Job-ID zurück');
        return;
      }
      _rcJobIds[jobId] = rcJobId;

      await _pollJob(jobId, rcJobId, group, progress);
    } catch (e) {
      _fail(jobId, e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (!progress.isClosed) await progress.close();
      _progressControllers.remove(jobId);
      _rcJobIds.remove(jobId);
    }
  }

  /// Polls `job/status` (finished/error) and `core/stats` (bytes/speed/eta) and
  /// feeds real progress into the UI streams.
  Future<void> _pollJob(
    String jobId,
    int rcJobId,
    String group,
    StreamController<RcloneProgressEvent> progress,
  ) async {
    while (true) {
      await Future.delayed(const Duration(milliseconds: 500));

      Map<String, dynamic> stats;
      try {
        stats = await _rc.rpc('core/stats', {'group': group});
      } catch (_) {
        stats = const {};
      }

      final total = (stats['totalBytes'] as num?)?.toInt() ?? 0;
      final transferred = (stats['bytes'] as num?)?.toInt() ?? 0;
      final speed = (stats['speed'] as num?)?.toDouble() ?? 0.0;
      final etaSecs = (stats['eta'] as num?)?.toInt();
      final currentFile = _currentTransferName(stats);
      final pct = total > 0 ? (transferred / total * 100.0).clamp(0.0, 100.0) : 0.0;

      if (!progress.isClosed) {
        progress.add(RcloneProgressEvent(
          jobId: jobId,
          bytesTransferred: transferred,
          totalBytes: total,
          percentage: pct,
          currentFile: currentFile,
          eta: etaSecs != null ? '${etaSecs}s' : '—',
          speedBytesPerSecond: speed,
        ));
      }

      final status = await _rc.rpc('job/status', {'jobid': rcJobId});
      final finished = status['finished'] as bool? ?? false;
      if (!finished) continue;

      final success = status['success'] as bool? ?? false;
      if (success) {
        if (!progress.isClosed) {
          progress.add(RcloneProgressEvent(
            jobId: jobId,
            bytesTransferred: total,
            totalBytes: total,
            percentage: 100.0,
            currentFile: 'Abgeschlossen',
            eta: '0s',
            speedBytesPerSecond: 0,
          ));
        }
        _statusController.add(RcloneJobEvent(jobId: jobId, status: RcloneJobStatus.completed));
      } else {
        final err = status['error'] as String? ?? 'Unbekannter Fehler';
        _fail(jobId, err);
      }
      return;
    }
  }

  String _currentTransferName(Map<String, dynamic> stats) {
    final transferring = stats['transferring'] as List<dynamic>?;
    if (transferring != null && transferring.isNotEmpty) {
      final first = transferring.first as Map<String, dynamic>;
      return first['name'] as String? ?? '';
    }
    return '';
  }

  void _fail(String jobId, String error) {
    _statusController.add(RcloneJobEvent(
      jobId: jobId,
      status: RcloneJobStatus.failed,
      error: error,
    ));
  }

  @override
  Future<void> cancelBackupJob(String jobId) async {
    final rcJobId = _rcJobIds[jobId];
    if (rcJobId != null) {
      try {
        await _rc.rpc('job/stop', {'jobid': rcJobId});
      } catch (_) {}
    }
    _statusController.add(RcloneJobEvent(jobId: jobId, status: RcloneJobStatus.cancelled));
  }

  @override
  Stream<RcloneProgressEvent> watchJobProgress(String jobId) {
    return _progressControllers[jobId]?.stream ?? const Stream.empty();
  }

  @override
  Stream<RcloneJobEvent> watchJobStatus() => _statusController.stream;

  // ---------------------------------------------------------------------------
  // Local source resolution (media staging + files)
  // ---------------------------------------------------------------------------

  /// Returns a local filesystem path (rclone `srcFs`) for the requested backup.
  ///
  /// For media keywords, PhotoKit assets are exported into a staging directory
  /// that mirrors the album structure (`Photos/<Album>/<file>`), which rclone
  /// then syncs to the cloud with a genuine 1:1 hierarchy.
  Future<String> _resolveLocalSource(String localPath, SyncOptions options) async {
    final lower = localPath.trim().toLowerCase();
    final isMedia = const {
      'photos', 'alle fotos', 'all', 'alles', 'media', 'mediathek', 'videos', 'alle videos',
    }.contains(lower);

    if (isMedia &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android)) {
      return _stageMediaLibrary(lower, options);
    }

    // Direct filesystem path (Files app folder / documents subfolder).
    if (localPath.startsWith('/') || localPath.contains(':\\')) {
      return localPath;
    }
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/$localPath';
  }

  Future<String> _stageMediaLibrary(String lower, SyncOptions options) async {
    final ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth && !ps.hasAccess) {
      throw Exception('Keine Berechtigung für Fotos und Mediathek (Zugriff verweigert)');
    }

    final tempDir = await getTemporaryDirectory();
    final staging = Directory('${tempDir.path}/fibu_media_staging');
    if (await staging.exists()) {
      await staging.delete(recursive: true);
    }
    await staging.create(recursive: true);

    final reqType = (lower == 'videos' || lower == 'alle videos')
        ? RequestType.video
        : RequestType.common;

    final albums = await PhotoManager.getAssetPathList(type: reqType, hasAll: true);
    final processed = <String>{};

    for (final album in albums) {
      final count = await album.assetCountAsync;
      if (count == 0) continue;
      const batch = 100;
      for (int start = 0; start < count; start += batch) {
        final assets = await album.getAssetListRange(
          start: start,
          end: (start + batch).clamp(0, count),
        );
        for (final asset in assets) {
          if (processed.contains(asset.id)) continue;
          processed.add(asset.id);

          final file = await asset.file;
          if (file == null || !await file.exists()) continue;

          final filename = asset.title ?? file.path.split(Platform.pathSeparator).last;
          if (options.excludeFilters.contains(filename)) continue;

          final albumName = album.name.replaceAll(RegExp(r'[/\\:]'), '_');
          final destDir = Directory('${staging.path}/Photos/$albumName');
          if (!await destDir.exists()) await destDir.create(recursive: true);
          await file.copy('${destDir.path}/$filename');
        }
      }
    }

    return staging.path;
  }
}

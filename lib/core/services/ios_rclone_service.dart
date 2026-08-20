import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

import 'librclone_channel.dart';
import 'mirror_sync_engine.dart';
import 'photo_kit_bridge.dart';
import 'app_log_service.dart';
import 'rclone_provider_registry.dart';
import 'rclone_service.dart';
import 'trash_service.dart';

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

  /// Normalizes a remote name by stripping trailing colons.
  ///
  /// rclone's `config/listremotes` returns names WITH a trailing colon
  /// (e.g. `mega:`), while every RPC below appends the colon itself
  /// (`'$remoteName:'`). Without normalization this produces `mega::` and
  /// breaks every call (list, about, copy, sync). Applied at this boundary so
  /// callers always see clean names – idempotent, so persisted names that
  /// accidentally contain colons are repaired as well.
  static String _normalizeRemoteName(String name) {
    var n = name.trim();
    while (n.endsWith(':')) {
      n = n.substring(0, n.length - 1);
    }
    return n;
  }

  @override
  Future<List<String>> listRemotes() async {
    await _ensureEngine();
    final res = await _rc.rpc('config/listremotes');
    final remotes = (res['remotes'] as List<dynamic>? ?? []).cast<String>();
    final cleaned = remotes.map(_normalizeRemoteName).toList();
    AppLog.info('remote', 'Remotes gelistet (${cleaned.length}): ${cleaned.join(', ') ?: 'keine'}');
    return cleaned;
  }

  @override
  Future<void> addRemote({
    required String name,
    required String type,
    required Map<String, String> config,
  }) async {
    await _ensureEngine();
    // Keine Config-Parameter loggen – enthält Zugangsdaten.
    AppLog.info('remote', 'Remote wird angelegt: "$name" (Typ: $type)');
    await _rc.rpc('config/create', {
      'name': name,
      'type': type,
      'parameters': config,
      'opt': {'obscure': true, 'nonInteractive': true},
    });
    AppLog.info('remote', 'Remote "$name" erfolgreich angelegt');
  }

  @override
  Future<void> removeRemote(String name) async {
    await _ensureEngine();
    await _rc.rpc('config/delete', {'name': _normalizeRemoteName(name)});
    AppLog.info('remote', 'Remote "$name" gelöscht');
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
    final remote = _normalizeRemoteName(remoteName);
    try {
      final res = await _rc.rpc('operations/about', {'fs': '$remote:'});
      final total = (res['total'] as num?)?.toInt() ?? 0;
      final used = (res['used'] as num?)?.toInt() ?? 0;
      final free = (res['free'] as num?)?.toInt() ?? (total - used).clamp(0, total);
      AppLog.info('remote', 'Quota für "$remote": $used/$total Bytes belegt');
      return QuotaInfo(totalBytes: total, usedBytes: used, freeBytes: free);
    } catch (e) {
      // Providers without an `about` command: report unknown rather than fake data.
      AppLog.info('remote',
          'Quota für "$remote" nicht verfügbar (Provider ohne about oder Fehler): $e');
      return const QuotaInfo(totalBytes: 0, usedBytes: 0, freeBytes: 0);
    }
  }

  // ---------------------------------------------------------------------------
  // Listing / read / delete
  // ---------------------------------------------------------------------------

  @override
  Future<List<RcloneFileInfo>> listFiles(String remoteName, String path) async {
    await _ensureEngine();
    final remote = _normalizeRemoteName(remoteName);
    final res = await _rc.rpc('operations/list', {
      'fs': '$remote:',
      'remote': path,
    });
    final list = (res['list'] as List<dynamic>? ?? []);
    AppLog.info('remote', 'Auflistung $remote:${path.isEmpty ? '/' : path} → ${list.length} Einträge');
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
    final remote = _normalizeRemoteName(remoteName);
    await _rc.rpc('operations/deletefile', {
      'fs': '$remote:',
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
    final remote = _normalizeRemoteName(remoteName);
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}/fibu_preview_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    final fileName = path.split('/').last;
    final srcDir = path.contains('/') ? path.substring(0, path.lastIndexOf('/')) : '';
    try {
      await _rc.rpc('operations/copyfile', {
        'srcFs': '$remote:$srcDir',
        'srcRemote': fileName,
        'dstFs': cacheDir.path,
        'dstRemote': fileName,
      }, const Duration(minutes: 10));
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
    final remote = _normalizeRemoteName(remoteName);
    final fileName = localFilePath.split(Platform.pathSeparator).last;
    final srcDir = localFilePath.substring(0, localFilePath.length - fileName.length - 1);

    // remotePath kann ein reiner Ordner (copyFileToRemote general) oder ein
    // voller Dateipfad inkl. Dateiname sein (z.B. writeConfigToRemote).
    final remoteClean = remotePath.endsWith('/') ? remotePath.substring(0, remotePath.length - 1) : remotePath;
    final remoteSegments = remoteClean.split('/').where((s) => s.isNotEmpty).toList();
    final String dstFs;
    final String dstRemote;
    if (remoteSegments.isNotEmpty && remoteSegments.last.contains('.')) {
      // Letztes Segment ist ein Dateiname (enthält '.'), Rest ist Ordner.
      dstRemote = remoteSegments.last;
      dstFs = remoteSegments.length > 1
          ? '$remote:${remoteSegments.sublist(0, remoteSegments.length - 1).join('/')}'
          : '$remote:';
    } else {
      // remotePath ist nur ein Ordner → Dateiname beibehalten.
      dstRemote = fileName;
      dstFs = remoteClean.isEmpty ? '$remote:' : '$remote:$remoteClean';
    }

    await _rc.rpc('operations/copyfile', {
      'srcFs': srcDir,
      'srcRemote': fileName,
      'dstFs': dstFs,
      'dstRemote': dstRemote,
    }, const Duration(minutes: 10));
    AppLog.info('remote', 'Upload → $remote:$dstRemote ($fileName)');
  }

  @override
  Future<void> downloadDirectory(
    String remoteName,
    String remotePath,
    String localPath,
  ) async {
    await _ensureEngine();
    final remote = _normalizeRemoteName(remoteName);
    await _rc.rpc('sync/copy', {
      'srcFs': '$remote:$remotePath',
      'dstFs': localPath,
    });
  }

  @override
  Future<void> downloadFile(
    String remoteName,
    String remotePath,
    String localPath,
  ) async {
    await _ensureEngine();
    final remote = _normalizeRemoteName(remoteName);
    final fileName = remotePath.split('/').last;
    final srcDir = remotePath.contains('/') ? remotePath.substring(0, remotePath.lastIndexOf('/')) : '';
    final dstDir = localPath.substring(0, localPath.lastIndexOf('/'));
    await _rc.rpc('operations/copyfile', {
      'srcFs': '$remote:$srcDir',
      'srcRemote': fileName,
      'dstFs': dstDir,
      'dstRemote': fileName,
    }, const Duration(minutes: 10));
  }

  @override
  Future<List<RcloneProviderInfo>> listProviders() async {
    // The static registry is the curated, localized provider list used by the UI.
    return RcloneProviderRegistry.providers.map((p) => p.toProviderInfo()).toList();
  }

  /// Returns the provider's default OAuth `client_id`/`client_secret` shipped by
  /// rclone (e.g. Google Drive ships public credentials). These come from
  /// `config/providers` option defaults, so no user-provided client is required.
  Future<Map<String, String>> getProviderClientCredentials(String providerId) async {
    try {
      await _ensureEngine();
      final res = await _rc.rpc('config/providers');
      final list = (res['providers'] as List<dynamic>?) ?? const [];
      for (final raw in list) {
        final m = raw as Map<String, dynamic>;
        if ((m['Name'] as String? ?? '').toLowerCase() == providerId.toLowerCase()) {
          final opts = (m['Options'] as List<dynamic>?) ?? const [];
          String clientId = '';
          String clientSecret = '';
          for (final o in opts) {
            final om = o as Map<String, dynamic>;
            final name = om['Name'];
            if (name == 'client_id') clientId = om['Default']?.toString() ?? '';
            if (name == 'client_secret') clientSecret = om['Default']?.toString() ?? '';
          }
          return {'client_id': clientId, 'client_secret': clientSecret};
        }
      }
    } catch (_) {
      // Fall through: no credentials available.
    }
    return const {'client_id': '', 'client_secret': ''};
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
    String rawRemoteName,
    String remotePath,
    SyncOptions options,
    StreamController<RcloneProgressEvent> progress,
  ) async {
    try {
      await _ensureEngine();
      // Kollisionen aus alten persistierten Namen / Doppel-Doppelpunkte vermeiden.
      final remoteName = _normalizeRemoteName(rawRemoteName);

      // Pre-flight: network guard.
      final conn = await Connectivity().checkConnectivity();
      if (conn.contains(ConnectivityResult.none) || conn.isEmpty) {
        _fail(jobId, 'Offline: Keine aktive Netzwerkverbindung');
        return;
      }

      // Resolve the local source. Media backups are staged into a persistent
      // local mirror (FibuMirror) that mirrors the album hierarchy. Staging
      // meldet Zwischenstände, damit die UI nie „ewig ohne Ausgabe lädt“.
      AppLog.info('sync', 'Sync-Job $jobId gestartet → $remoteName:$remotePath');
      final String srcFs = await _resolveLocalSource(localPath, options,
          onStage: (label, done, total) {
        if (progress.isClosed) return;
        progress.add(RcloneProgressEvent(
          jobId: jobId,
          bytesTransferred: 0,
          totalBytes: 0,
          percentage: total > 0 ? (done / total * 100.0).clamp(0.0, 100.0) : 0.0,
          currentFile: 'Vorbereitung: $label',
          eta: '',
          speedBytesPerSecond: 0,
          itemsDone: done,
          itemsTotal: total,
        ));
      });

      // Mirror/Echo-Modus: Mediathek-first, Löschprotokoll-basierter
      // bidirektionaler Sync mit Papierkorb. Lokal hat Vorrang.
      if (options.isEchoMode) {
        if (!progress.isClosed) {
          progress.add(RcloneProgressEvent(
            jobId: jobId,
            bytesTransferred: 0,
            totalBytes: 0,
            percentage: 0,
            currentFile: 'Mirror-Sync (Löschprotokoll) wird ausgeführt…',
            eta: '',
            speedBytesPerSecond: 0,
          ));
        }

        // 0) Mediathek-first: lokal gelöschte Fotos (in der Fotos-App entfernt)
        //    werden aus dem Spiegel entfernt, damit sie als Tombstone
        //    propagieren. Läuft nur auf iOS/Android mit Mediathek-Quelle.
        final wasMedia = _isMediaSource(localPath);
        final bridge = PhotoKitBridge();
        List<String> localDeletions = [];
        if (wasMedia) {
          localDeletions = await bridge.detectLocalDeletions(srcFs);
          for (final rel in localDeletions) {
            final f = File('$srcFs${Platform.pathSeparator}${rel.replaceAll('/', Platform.pathSeparator)}');
            try {
              if (await f.exists()) await f.delete();
            } catch (_) {}
          }
        }

        final engine = MirrorSyncEngine(this);
        final trash = TrashService(this);
        final result = await engine.sync(
          localRoot: srcFs,
          remoteName: remoteName,
          remotePath: remotePath,
          trash: trash,
          onProgress: (phase, item, done, total) {
            if (progress.isClosed) return;
            const phaseLabels = {
              'scan': 'Analysiere lokale & Cloud-Dateien',
              'upload': 'Lade hoch',
              'tombstones': 'Wende Löschprotokoll an',
              'download': 'Lade aus der Cloud',
            };
            final label = phaseLabels[phase] ?? phase;
            final fileName =
                item.isEmpty ? '' : item.split('/').where((s) => s.isNotEmpty).last;
            final hasCounters = total > 0;
            progress.add(RcloneProgressEvent(
              jobId: jobId,
              bytesTransferred: 0,
              totalBytes: 0,
              percentage: hasCounters ? (done / total * 100.0).clamp(0.0, 100.0) : 0.0,
              currentFile: fileName.isEmpty ? '$label…' : '$label: $fileName',
              eta: hasCounters ? '' : '…',
              speedBytesPerSecond: 0,
              itemsDone: done,
              itemsTotal: total,
            ));
          },
        );

        // Nach dem Sync: neu heruntergeladene remote-Dateien in die Mediathek
        // importieren (damit sie in der Fotos-App erscheinen) und Papierkorb
        // nach Ablauf der Aufbewahrungsfrist bereinigen.
        if (wasMedia) {
          await _importNewRemoteIntoLibrary(srcFs, result, engine);
          await trash.purgeLocal(srcFs);
        }

        if (!progress.isClosed) {
          progress.add(RcloneProgressEvent(
            jobId: jobId,
            bytesTransferred: 0,
            totalBytes: 0,
            percentage: 100,
            currentFile:
                'Mirror abgeschlossen (↑${result.uploaded} ↓${result.downloaded} '
                '🗑${result.trashedLocal}/${result.trashedRemote} + '
                '${result.deletedLocal}/${result.deletedRemote})',
            eta: '0s',
            speedBytesPerSecond: 0,
          ));
        }
        _statusController.add(RcloneJobEvent(jobId: jobId, status: RcloneJobStatus.completed));
        AppLog.info('sync',
            'Mirror abgeschlossen: ↑${result.uploaded} ↓${result.downloaded} 🗑${result.trashedLocal}/${result.trashedRemote} Δ${result.deletedLocal}/${result.deletedRemote}');
        return;
      }

      // Inkrementeller Upload (copy): einseitig lokal→remote.
      final group = 'job/$jobId';
      const method = 'sync/copy';
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
      // Datei-Zähler aus core/stats („12 von 45“-Anzeige).
      final itemsDone = (stats['transfers'] as num?)?.toInt() ?? 0;
      final itemsTotal = (stats['totalTransfers'] as num?)?.toInt() ?? 0;

      if (!progress.isClosed) {
        progress.add(RcloneProgressEvent(
          jobId: jobId,
          bytesTransferred: transferred,
          totalBytes: total,
          percentage: pct,
          currentFile: currentFile,
          eta: etaSecs != null ? '${etaSecs}s' : '—',
          speedBytesPerSecond: speed,
          itemsDone: itemsDone,
          itemsTotal: itemsTotal,
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
        AppLog.info('sync', 'Job $jobId abgeschlossen: $transferred/$total Bytes übertragen');
      } else {
        final err = status['error'] as String? ?? 'Unbekannter Fehler';
        _fail(jobId, err);
      }
      return;
    }
  }

  /// Führt einen echten bidirektionalen Sync (rclone `bisync`) zwischen dem
  /// lokalen Spiegel (path1) und dem Remote (path2) aus.
  ///
  /// Bisync propagiert Löschungen in BEIDE Richtungen, erkennt Konflikte und
  /// löst sie per `--conflict-resolve newer` auf. `--max-delete` begrenzt die
  /// Löschungen als Sicherheitsnetz. Erfordert einen persistenten lokalen
  /// Spiegel (bei Medien `FibuMirror`), sonst wäre ein "transient" Spiegel
  /// destruktiv.

  /// True, wenn die Quelle eine Mediathek-Auswahl ist (nur dann läuft die
  /// PhotoKit-Erkennung/der Import).
  bool _isMediaSource(String localPath) {
    final lower = localPath.trim().toLowerCase();
    return lower.startsWith('photos:') ||
        lower.startsWith('videos:') ||
        lower.startsWith('all:') ||
        const {
          'photos', 'alle fotos', 'all', 'alles', 'media', 'mediathek',
          'videos', 'alle videos',
        }.contains(lower);
  }

  /// Importiert die im Mirror neu heruntergeladenen Dateien in die Mediathek,
  /// damit sie in der Fotos-App erscheinen.
  Future<void> _importNewRemoteIntoLibrary(
    String localRoot,
    MirrorSyncResult result,
    MirrorSyncEngine engine,
  ) async {
    final bridge = PhotoKitBridge();
    for (final rel in result.downloadedPaths) {
      final f = File('$localRoot${Platform.pathSeparator}${rel.replaceAll('/', Platform.pathSeparator)}');
      if (!await f.exists()) continue;
      await bridge.importIntoLibrary(f, mimeHint: PhotoKitBridge.mimeHintFor(rel));
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
    AppLog.error('sync', 'Job $jobId fehlgeschlagen: $error');
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
  Future<String> _resolveLocalSource(
    String localPath,
    SyncOptions options, {
    void Function(String label, int done, int total)? onStage,
  }) async {
    final trimmed = localPath.trim();
    final lower = trimmed.toLowerCase();

    // Codierte Auswahl: "photos:Album1|Album2", "videos:...", "all:..." oder
    // "files:<absPfad1>|<absPfad2>".
    if (lower.startsWith('files:')) {
      final paths = trimmed
          .substring('files:'.length)
          .split('|')
          .where((p) => p.trim().isNotEmpty)
          .map((p) => p.trim())
          .toList();
      return _stageFolders(paths);
    }

    if (lower.startsWith('photos:') || lower.startsWith('videos:') || lower.startsWith('all:')) {
      final mediaType = lower.split(':').first;
      final albumList = trimmed
          .substring(mediaType.length + 1)
          .split('|')
          .where((p) => p.trim().isNotEmpty)
          .map((p) => p.trim())
          .toList();
      return _stageMediaLibrary(mediaType, options,
          selectedAlbums: albumList, onStage: onStage);
    }

    final isMedia = const {
      'photos', 'alle fotos', 'all', 'alles', 'media', 'mediathek', 'videos', 'alle videos',
    }.contains(lower);

    if (isMedia &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android)) {
      return _stageMediaLibrary(lower, options, onStage: onStage);
    }

    // Lokale Ordner (Files): persistenter Spiegel für echten 2-Wege-Sync.
    if (lower.startsWith('folders:') || lower.startsWith('dir:')) {
      final prefix = lower.startsWith('folders:') ? 'folders:' : 'dir:';
      final paths = trimmed
          .substring(prefix.length)
          .split('|')
          .where((p) => p.trim().isNotEmpty)
          .map((p) => p.trim())
          .toList();
      return _stageFolders(paths);
    }

    // Direct filesystem path (Files app folder / documents subfolder).
    if (localPath.startsWith('/') || localPath.contains(':\\')) {
      return localPath;
    }
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/$localPath';
  }

  /// Stages the given absolute local folder paths into a temp dir (1:1 hierarchy).
  Future<String> _stageFolders(List<String> paths) async {
    final tempDir = await getTemporaryDirectory();
    final staging = Directory('${tempDir.path}/fibu_files_staging');
    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create(recursive: true);
    for (final p in paths) {
      final src = Directory(p);
      if (!await src.exists()) continue;
      final safeName = p.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      await _copyTree(src, Directory('${staging.path}/Dateien/$safeName'));
    }
    return staging.path;
  }

  Future<void> _copyTree(Directory src, Directory dst) async {
    if (!await dst.exists()) await dst.create(recursive: true);
    await for (final entity in src.list(followLinks: false)) {
      if (entity is Directory) {
        await _copyTree(entity, Directory('${dst.path}/${entity.uri.pathSegments.last}'));
      } else if (entity is File) {
        try {
          await entity.copy('${dst.path}/${entity.uri.pathSegments.last}');
        } catch (_) {
          // Nicht zugängliche Datei überspringen.
        }
      }
    }
  }

  /// Baut einen PERSISTENTEN lokalen Mediathek-Spiegel auf (nicht transient).
  ///
  /// Der Spiegel liegt unter `<Dokumente>/FibuMirror/` und wird bei jedem Lauf
  /// inkrementell aktualisiert: Neue/geänderte Assets werden hineinkopiert,
  /// lokal gelöschte Assets werden im Spiegel gelöscht. Dadurch funktioniert
  /// die Lösch-Propagation in beide Richtungen (bisync lokal↔remote).
  Future<String> _stageMediaLibrary(
    String lower,
    SyncOptions options, {
    List<String> selectedAlbums = const [],
    void Function(String label, int done, int total)? onStage,
  }) async {
    AppLog.info('media', 'Medien-Staging startet (Quelle: $lower, Alben-Filter: ${selectedAlbums.isEmpty ? 'alle' : selectedAlbums.length})');
    final ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth && !ps.hasAccess) {
      AppLog.error('media', 'Foto/Mediathek-Berechtigung verweigert – Staging abgebrochen');
      throw Exception('Keine Berechtigung für Fotos und Mediathek (Zugriff verweigert)');
    }

    final appDir = await getApplicationDocumentsDirectory();
    final mirror = Directory('${appDir.path}/FibuMirror');
    if (!await mirror.exists()) await mirror.create(recursive: true);

    final reqType = (lower == 'videos' || lower == 'alle videos')
        ? RequestType.video
        : RequestType.common;

    final albums = await PhotoManager.getAssetPathList(type: reqType, hasAll: true);
    final processed = <String>{};

    // Nur ausgewählte Alben sichern, sofern welche gewählt wurden (leer = alle).
    final allowAll = selectedAlbums.isEmpty;
    final selectedSet = selectedAlbums.map((a) => a.toLowerCase()).toSet();
    final existingAlbumDirs = <String>{};

    // Lauf-lokale Belegung der Spiegelpfade (Zielpfad → Asset-ID), damit sich
    // Assets mit gleichem Titel/Dateinamen niemals gegenseitig überschreiben.
    final usedPaths = <String, String>{};

    var scannedTotal = 0; // bislang bekannte Gesamtzahl (wächst albumweise)
    var processedCount = 0; // verarbeitete Assets dieses Laufs
    var copiedNew = 0; // tatsächlich neu in den Spiegel kopierte Dateien

    for (final album in albums) {
      final albumName = album.name.replaceAll(RegExp(r'[/\\:]'), '_');
      if (!allowAll && !selectedSet.contains(album.name.trim().toLowerCase())) continue;
      existingAlbumDirs.add(albumName);
      final count = await album.assetCountAsync;
      AppLog.info('media', 'Album „$albumName“: $count Assets');
      if (count == 0) continue;
      scannedTotal += count;
      onStage?.call('Album „$albumName“', processedCount, scannedTotal);
      const batch = 100;
      for (int start = 0; start < count; start += batch) {
        final assets = await album.getAssetListRange(
          start: start,
          end: (start + batch).clamp(0, count),
        );
        for (final asset in assets) {
          if (processed.contains(asset.id)) continue;
          processed.add(asset.id);

          processedCount++;
          if (processedCount % 25 == 0 || processedCount == scannedTotal) {
            onStage?.call('Album „$albumName“', processedCount, scannedTotal);
          }

          final file = await asset.file;
          if (file == null || !await file.exists()) continue;

          final destDir = Directory('${mirror.path}/Photos/$albumName');
          final filename = _resolveMirrorFileName(asset, file, destDir.path, usedPaths);
          if (options.excludeFilters.contains(filename)) continue;

          // Zielordner sicher anlegen, BEVOR Dateipfade darin verwendet werden.
          if (!await destDir.exists()) await destDir.create(recursive: true);
          final destPath = '${destDir.path}/$filename';

          try {
            final dest = File(destPath);
            // Inkrementell: nur kopieren, wenn neu oder anders groß.
            if (!await dest.exists() ||
                (await dest.length()) != (await file.length())) {
              await file.copy(destPath);
              copiedNew++;
            }
          } catch (_) {
            // Nicht les-/schreibbare Assets überspringen, statt den kompletten
            // Spiegel-Lauf (und damit den Sync) abzubrechen.
          }
        }
      }
    }

    // Lokal gelöschte Assets/Alben aus dem Spiegel entfernen, damit die
    // Löschung remote propagiert wird (bisync).
    var removedAlbumDirs = 0;
    final photosRoot = Directory('${mirror.path}/Photos');
    if (await photosRoot.exists()) {
      await for (final albumDir in photosRoot.list(followLinks: false)) {
        if (albumDir is! Directory) continue;
        final albumName = albumDir.uri.pathSegments.last;
        if (!existingAlbumDirs.contains(albumName)) {
          try {
            await albumDir.delete(recursive: true);
            removedAlbumDirs++;
          } catch (_) {}
        }
      }
    }

    AppLog.info('media',
        'Spiegel fertig: $processedCount/$scannedTotal Assets geprüft, $copiedNew neu kopiert, $removedAlbumDirs verwaiste Album-Ordner entfernt');
    onStage?.call('Spiegel bereit', scannedTotal, scannedTotal);
    return mirror.path;
  }

  /// Ermittelt einen verlässlichen, kollisionsfreien Dateinamen für [asset]
  /// im Spiegel-Verzeichnis [destDirPath].
  ///
  /// Hintergrund: Auf iOS ist [AssetEntity.title] häufig null (werden nur mit
  /// `needTitle` geladen) und `asset.file` liefert für einzelne Assets (z. B.
  /// Videos, Screen-Recordings, Live-Photo-Begleitdateien) Dateien ohne
  /// brauchbaren Namen. Ein leerer Name ließ `file.copy('<dir>/')` auf ein
  /// Verzeichnis zeigen → FileSystemException (errno 21).
  ///
  /// Auflösungsreihenfolge: Asset-Titel → Original-Dateiname aus
  /// [source].path → generierter Name aus der Asset-ID. Bei Kollisionen
  /// (gleiche Titel verschiedener Assets) oder einem bereits existierenden
  /// Verzeichnis gleichen Namens wird die bereinigte Asset-ID angehängt –
  /// deterministisch pro Asset, damit inkrementelle Läufe stabil bleiben.
  String _resolveMirrorFileName(
    AssetEntity asset,
    File source,
    String destDirPath,
    Map<String, String> usedPaths,
  ) {
    final pathName = source.path.split(Platform.pathSeparator).last.trim();
    var base = (asset.title ?? '').trim();
    if (base.isEmpty) base = pathName;
    if (base.isEmpty) {
      base =
          'asset_${_safeFilePart(asset.id)}.${_mirrorFallbackExtension(asset, pathName)}';
    }

    // Dateinamen dürfen keine Pfadtrenner enthalten – iOS-Asset-IDs und
    // manche Titel enthalten '/' bzw. '\\'.
    base = base.replaceAll(RegExp(r'[/\\]'), '_');

    final dot = base.lastIndexOf('.');
    final stem = dot > 0 ? base.substring(0, dot) : base;
    final ext = dot > 0 ? base.substring(dot) : '';

    final disambiguator = _safeFilePart(asset.id);
    var candidate = '$stem$ext';
    var counter = 0;
    while (true) {
      final path = '$destDirPath/$candidate';
      final owner = usedPaths[path];
      if (owner == asset.id) {
        // Dasselbe Asset erneut angetroffen → identischer (stabiler) Name.
        return candidate;
      }
      if (owner == null && !FileSystemEntity.isDirectorySync(path)) {
        // Frei und kein bestehendes Verzeichnis → verwendbar.
        usedPaths[path] = asset.id;
        return candidate;
      }
      // Kollision mit anderem Asset oder Verzeichnis → eindeutigen Namen wählen.
      candidate = counter == 0
          ? '${stem}_$disambiguator$ext'
          : '${stem}_${disambiguator}_$counter$ext';
      counter++;
    }
  }

  /// Entfernt alle Zeichen aus [value], die in Dateinamen problematisch sind
  /// (iOS-Asset-IDs sehen z. B. so aus: `UUID/L0/001`).
  static String _safeFilePart(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return cleaned.isEmpty ? 'x' : cleaned;
  }

  /// Best-effort-Dateiendung für Assets ohne verwertbaren Namen, damit der
  /// Medientyp (z. B. für den späteren Mediathek-Re-Import) erhalten bleibt.
  static String _mirrorFallbackExtension(AssetEntity asset, String pathName) {
    final dot = pathName.lastIndexOf('.');
    if (dot > 0 && dot < pathName.length - 1) {
      return pathName.substring(dot + 1);
    }
    final mime = asset.mimeType;
    if (mime != null) {
      switch (mime.toLowerCase()) {
        case 'image/heic':
        case 'image/heif':
          return 'heic';
        case 'image/jpeg':
          return 'jpg';
        case 'image/png':
          return 'png';
        case 'image/gif':
          return 'gif';
        case 'video/quicktime':
          return 'mov';
        case 'video/mp4':
          return 'mp4';
      }
    }
    return asset.type == AssetType.video ? 'mov' : 'jpg';
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

import 'librclone_channel.dart';
import 'mirror_sync_engine.dart';
import 'photo_kit_bridge.dart';
import 'virtual_mirror_sync.dart';
import '../localization/app_strings.dart';
import '../utils/app_paths.dart';
import 'app_log_service.dart';
import 'change_journal_service.dart';
import 'device_identity_service.dart';
import 'pending_deletions_store.dart';
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

  /// Schnell-fehschlagende Netzwerk-Optionen für reine Verbindungs-/Lese-Calls
  /// (about, list): Beim iOS-Stack können rclones Standard-Retries (3× mit
  /// Low-Level-Retries à 10, exponential backoff) einen einfachen Fehler auf
  /// Minuten strecken. Hier begrenzen wir: Verbindungsaufbau max. 15 s, keine
  /// Job-Wiederholungen → der ECHTE Providerr-Fehler kommt sofort hoch,
  /// statt minutenlang zu „hängen“.
  ///
  /// WICHTIG: Im RC-`_config` müssen Durations als Nanosekunden-Ints kommen –
  /// Strings wie "15s" schlagen das Reshape ins Go-Struct fehl
  /// („cannot unmarshal string into ConfigInfo.ExpectContinueTimeout").
  static const int _ns = 1000000000; // Nanosekunden pro Sekunde

  static Map<String, Object> get _fastFailConfig => {
        'Timeout': 15 * _ns,
        'Contimeout': 15 * _ns,
        'ExpectContinueTimeout': 10 * _ns,
        'Retries': 1,
        'LowLevelRetries': 2,
      };

  /// Transfers (eine einzelne Datei rauf/runter): kurze Verbindungs-Timeouts,
  /// aber KEIN globales Transfer-Timeout (große Videos brauchen länger).
  static Map<String, Object> get _transferConfig => {
        'Contimeout': 20 * _ns,
        'ExpectContinueTimeout': 15 * _ns,
      };

  Future<void> _ensureEngine() async {
    // rclone.conf lebt in Library/Application Support (via privateAppFile:
    // migriert eine Alt-Datei aus Documents einmalig herüber). Nutzer sollen
    // davon in der Dateien-App nichts sehen — sichtbar bleibt nur fibu.log.
    final file = await privateAppFile('rclone.conf');
    await _rc.ensureInitialized(file.path);
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
    final remoteNames = cleaned.isEmpty ? 'keine' : cleaned.join(', ');
    AppLog.info('remote', 'Remotes gelistet (${cleaned.length}): $remoteNames');
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
      'opt': {'nonInteractive': true},
    });
    AppLog.info('remote', 'Remote "$name" erfolgreich angelegt');
  }

  @override
  Future<void> removeRemote(String name) async {
    await _ensureEngine();
    await _rc.rpc('config/delete', {'name': _normalizeRemoteName(name)});
    AppLog.info('remote', 'Remote "$name" gelöscht');
  }

  /// Liest den echten Backend-Typ einer Sektion aus der rclone.conf
  /// (config/get) — Grundlage für die Provider-Anzeige in der Remote-Registry
  /// anstelle der früheren Namensraterei.
  @override
  Future<String?> remoteType(String name) async {
    await _ensureEngine();
    try {
      final res = await _rc.rpc('config/get', {'name': _normalizeRemoteName(name)});
      final type = res['type']?.toString() ?? '';
      return type.isEmpty ? null : type;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> obscurePassword(String plainPassword) async {
    await _ensureEngine();
    final res = await _rc.rpc('core/obscure', {'clear': plainPassword});
    return res['obscured'] as String? ?? plainPassword;
  }

  /// Echter Verbindungstest: temporäres Remote anlegen → Wurzelverzeichnis
  /// auflisten (authentifiziert + erreichbar) → temporäres Remote entfernen.
  @override
  Future<void> testConnection({
    required String type,
    required Map<String, String> config,
  }) async {
    await _ensureEngine();
    final tempName = 'fibu_test_${DateTime.now().millisecondsSinceEpoch}';
    AppLog.info('remote', 'Verbindungstest (Typ „$type“) startet …');
    try {
      await _rc.rpc('config/create', {
        'name': tempName,
        'type': type,
        'parameters': config,
        'opt': {'nonInteractive': true},
      });
      await _rc.rpc('operations/list', {
        'fs': '$tempName:',
        'remote': '',
        '_config': _fastFailConfig,
      }, const Duration(seconds: 45));
      AppLog.info('remote', 'Verbindungstest erfolgreich (Typ „$type“)');
    } finally {
      try {
        await _rc.rpc('config/delete', {'name': tempName});
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------------------------
  // Quota
  // ---------------------------------------------------------------------------

  @override
  Future<QuotaInfo> getQuota(String remoteName) async {
    await _ensureEngine();
    final remote = _normalizeRemoteName(remoteName);
    try {
      final res = await _rc.rpc('operations/about', {
        'fs': '$remote:',
        '_config': _fastFailConfig,
      });
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
      '_config': _fastFailConfig,
    });
    final list = (res['list'] as List<dynamic>? ?? []);
    final listedPath = path.isEmpty ? '/' : path;
    AppLog.info('remote', 'Auflistung $remote:$listedPath → ${list.length} Einträge');
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
      '_config': _fastFailConfig,
    });
    AppLog.info('remote', 'Remote-Datei gelöscht: $remote:$path');
  }

  @override
  Future<void> moveRemoteFile(
      String remoteName, String fromPath, String toPath) async {
    await _ensureEngine();
    final remote = _normalizeRemoteName(remoteName);
    // operations/movefile verschiebt serverseitig, ohne die Datei einmal
    // durch das Gerät zu ziehen. Schlägt das fehl (Provider ohne
    // Server-Side-Move), wirft es — der Aufrufer fällt auf Löschen +
    // Neu-Upload zurück.
    await _rc.rpc('operations/movefile', {
      'srcFs': '$remote:',
      'srcRemote': fromPath,
      'dstFs': '$remote:',
      'dstRemote': toPath,
      '_config': _fastFailConfig,
    });
    AppLog.info('remote', 'Remote-Datei verschoben: $remote:$fromPath → $toPath');
  }

  @override
  Future<List<PendingLocalDeletion>> deletePendingLocalDeletions(
      List<PendingLocalDeletion> pending) async {
    if (pending.isEmpty) return const <PendingLocalDeletion>[];
    try {
      final List<String> ids =
          pending.map((PendingLocalDeletion d) => d.assetId).toList();
      final Set<String> deleted =
          (await PhotoManager.editor.deleteWithIds(ids)).toSet();
      final List<PendingLocalDeletion> done = pending
          .where((PendingLocalDeletion d) => deleted.contains(d.assetId))
          .toList();
      AppLog.info('media',
          '${done.length}/${pending.length} ausstehende lokale Löschungen ausgeführt');
      return done;
    } catch (e) {
      AppLog.warn('media', 'Ausstehende Löschungen fehlgeschlagen: $e');
      return const <PendingLocalDeletion>[];
    }
  }

  @override
  Future<void> purgeRemoteDirectory({
    required String remoteName,
    required String remotePath,
  }) async {
    await _ensureEngine();
    final remote = _normalizeRemoteName(remoteName);
    // operations/purge löscht den gesamten entfernten Verzeichnisbaum.
    await _rc.rpc('operations/purge', {
      'fs': '$remote:',
      'remote': remotePath,
      '_config': _transferConfig,
    }, const Duration(minutes: 10));
    AppLog.warn('remote', 'Remote-Ordner gelöscht (purge): $remote:$remotePath');
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
        '_config': _transferConfig,
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
    final dest = _copyDest(localFilePath, remoteName, remotePath);
    await _rc.rpc('operations/copyfile', {
      'srcFs': dest.srcDir,
      'srcRemote': dest.fileName,
      'dstFs': dest.dstFs,
      'dstRemote': dest.dstRemote,
      '_config': _transferConfig,
    }, const Duration(minutes: 10));
    AppLog.info('remote',
        'Upload → ${_normalizeRemoteName(remoteName)}:${dest.dstRemote} (${dest.fileName})');
  }

  /// Zerlegt einen lokalen Dateipfad + Remote-Ziel in die `operations/copyfile`-
  /// Felder (srcFs/srcRemote/dstFs/dstRemote) — von [copyFileToRemote] und der
  /// Progress-Variante gemeinsam genutzt.
  ///
  /// remotePath kann ein reiner Ordner (copyFileToRemote general) oder ein
  /// voller Dateipfad inkl. Dateiname sein (z.B. writeConfigToRemote).
  ({String srcDir, String fileName, String dstFs, String dstRemote}) _copyDest(
    String localFilePath,
    String remoteName,
    String remotePath,
  ) {
    final remote = _normalizeRemoteName(remoteName);
    final fileName = localFilePath.split(Platform.pathSeparator).last;
    final srcDir = localFilePath.substring(
        0, localFilePath.length - fileName.length - 1);

    final remoteClean = remotePath.endsWith('/')
        ? remotePath.substring(0, remotePath.length - 1)
        : remotePath;
    final remoteSegments =
        remoteClean.split('/').where((s) => s.isNotEmpty).toList();
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
    return (srcDir: srcDir, fileName: fileName, dstFs: dstFs, dstRemote: dstRemote);
  }

  @override
  Future<void> copyFileToRemoteWithProgress(
    String localFilePath,
    String remoteName,
    String remotePath, {
    void Function(int bytesTransferred)? onBytes,
  }) async {
    await _ensureEngine();
    final dest = _copyDest(localFilePath, remoteName, remotePath);
    final group = 'mirror_${DateTime.now().microsecondsSinceEpoch}';
    Map<String, dynamic> startRes;
    try {
      startRes = await _rc.rpc('operations/copyfile', {
        'srcFs': dest.srcDir,
        'srcRemote': dest.fileName,
        'dstFs': dest.dstFs,
        'dstRemote': dest.dstRemote,
        '_config': _transferConfig,
        '_async': true,
        '_group': group,
      }, const Duration(minutes: 10));
    } catch (e) {
      // Fallback: synchron (ohne Live-Bytes) — der Mirror zählt die Datei
      // nach Abschluss trotzdem korrekt.
      AppLog.warn('remote', 'Async-Upload nicht möglich, Fallback: $e');
      await _rc.rpc('operations/copyfile', {
        'srcFs': dest.srcDir,
        'srcRemote': dest.fileName,
        'dstFs': dest.dstFs,
        'dstRemote': dest.dstRemote,
        '_config': _transferConfig,
      }, const Duration(minutes: 10));
      return;
    }
    final rcJobId = (startRes['jobid'] as num?)?.toInt();
    if (rcJobId == null) return;
    await _pollSingleTransfer(rcJobId, group, onBytes);
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
      '_config': _transferConfig,
    }, const Duration(minutes: 10));
  }

  @override
  Future<void> downloadFileWithProgress(
    String remoteName,
    String remotePath,
    String localPath, {
    void Function(int bytesTransferred)? onBytes,
  }) async {
    await _ensureEngine();
    final remote = _normalizeRemoteName(remoteName);
    final fileName = remotePath.split('/').last;
    final srcDir = remotePath.contains('/')
        ? remotePath.substring(0, remotePath.lastIndexOf('/'))
        : '';
    final dstDir = localPath.substring(0, localPath.lastIndexOf('/'));
    final group = 'mirror_${DateTime.now().microsecondsSinceEpoch}';
    Map<String, dynamic> startRes;
    try {
      startRes = await _rc.rpc('operations/copyfile', {
        'srcFs': '$remote:$srcDir',
        'srcRemote': fileName,
        'dstFs': dstDir,
        'dstRemote': fileName,
        '_config': _transferConfig,
        '_async': true,
        '_group': group,
      }, const Duration(minutes: 10));
    } catch (e) {
      AppLog.warn('remote', 'Async-Download nicht möglich, Fallback: $e');
      await _rc.rpc('operations/copyfile', {
        'srcFs': '$remote:$srcDir',
        'srcRemote': fileName,
        'dstFs': dstDir,
        'dstRemote': fileName,
        '_config': _transferConfig,
      }, const Duration(minutes: 10));
      return;
    }
    final rcJobId = (startRes['jobid'] as num?)?.toInt();
    if (rcJobId == null) return;
    await _pollSingleTransfer(rcJobId, group, onBytes);
  }

  /// Kopiert eine Datei innerhalb EINES Remotes (Server-seitig, falls das
  /// Backend es unterstützt) — für den Remote-Papierkorb, damit Tombstones
  /// nicht per Download+Upload über das Gerät wandern.
  @override
  Future<bool> copyRemoteFile(
    String remoteName,
    String srcPath,
    String dstPath,
  ) async {
    await _ensureEngine();
    final remote = _normalizeRemoteName(remoteName);
    try {
      final srcDir = srcPath.contains('/')
          ? srcPath.substring(0, srcPath.lastIndexOf('/'))
          : '';
      final srcName = srcPath.split('/').last;
      final dstDir = dstPath.contains('/')
          ? dstPath.substring(0, dstPath.lastIndexOf('/'))
          : '';
      final dstName = dstPath.split('/').last;
      await _rc.rpc('operations/copyfile', {
        'srcFs': '$remote:$srcDir',
        'srcRemote': srcName,
        'dstFs': '$remote:$dstDir',
        'dstRemote': dstName,
        '_config': _transferConfig,
      }, const Duration(minutes: 10));
      return true;
    } catch (_) {
      return false;
    }
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

  /// Job-IDs laufender Syncs. Leer = kein Lauf aktiv.
  final Set<String> _runningJobIds = <String>{};

  /// Job-IDs, die der Nutzer abgebrochen hat. Die Spiegel-Engines fragen das
  /// zwischen den Dateien ab — ohne sie liefe ein „abgebrochener" Lauf
  /// unsichtbar bis zum Ende weiter.
  final Set<String> _cancelledJobs = <String>{};

  @override
  bool get isSyncRunning => _runningJobIds.isNotEmpty;

  @override
  Future<String> startBackupJob({
    required String localPath,
    required String remoteName,
    required String remotePath,
    required SyncOptions options,
  }) async {
    // Parallel-Sperre: Gilt für ALLE Einstiegspunkte (Dashboard, Task-Detail,
    // Scheduler, Quick Actions). Ohne sie könnte ein geplanter Lauf mitten in
    // einen manuellen starten — beide teilen sich Mirror-Zustand und
    // rclone-Statistiken und würden sich gegenseitig korrumpieren.
    if (_runningJobIds.isNotEmpty) {
      AppLog.warn('sync',
          'Sync-Anfrage abgelehnen: Lauf ${_runningJobIds.first} ist noch aktiv');
      throw StateError(AppStrings.current.syncAlreadyRunning);
    }

    final jobId = 'job_${DateTime.now().millisecondsSinceEpoch}';
    final progressController = StreamController<RcloneProgressEvent>.broadcast();
    _progressControllers[jobId] = progressController;
    _runningJobIds.add(jobId);

    _statusController.add(RcloneJobEvent(jobId: jobId, status: RcloneJobStatus.syncing));
    unawaited(_runJob(jobId, localPath, remoteName, remotePath, options, progressController)
        .whenComplete(() {
      _runningJobIds.remove(jobId);
      _cancelledJobs.remove(jobId);
    }));
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
        _fail(jobId, AppStrings.current.syncOfflineNoNetwork);
        return;
      }

      // NEU (Manifest-only Mirror): Medien-Echo läuft komplett ohne
      // persistenten FibuMirror — nur Metadaten lokal, Zustand in
      // Application Support (für Nutzer nicht sichtbar), On-Demand-Export
      // nur der tatsächlich zu übertragenden Assets.
      if (options.isEchoMode && _isMediaSource(localPath)) {
        await _runVirtualMirrorSync(jobId, localPath, remoteName, remotePath, options, progress);
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
          currentFile: AppStrings.current.syncStagePreparing(label),
          eta: '',
          speedBytesPerSecond: 0,
          itemsDone: done,
          itemsTotal: total,
          phase: 'scan',
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
            currentFile: AppStrings.current.syncMirrorRunning,
            eta: '',
            speedBytesPerSecond: 0,
            phase: 'scan',
          ));
        }

        // 0) Mediathek-first: lokal gelöschte Fotos (in der Fotos-App entfernt)
        //    werden aus dem Spiegel entfernt, damit sie als Tombstone
        //    propagieren. Läuft nur auf iOS/Android mit Mediathek-Quelle.
        final wasMedia = _isMediaSource(localPath);
        final bridge = PhotoKitBridge();
        List<String> localDeletions = [];
        if (wasMedia) {
          localDeletions = await bridge.detectLocalDeletions(srcFs,
              onProgress: (label) {
                if (progress.isClosed) return;
                progress.add(RcloneProgressEvent(
                  jobId: jobId,
                  bytesTransferred: 0,
                  totalBytes: 0,
                  percentage: 0,
                  currentFile: AppStrings.current.syncDeletionScan,
                  eta: '',
                  speedBytesPerSecond: 0,
                  phase: 'scan',
                ));
              });
          for (final rel in localDeletions) {
            final f = File('$srcFs${Platform.pathSeparator}${rel.replaceAll('/', Platform.pathSeparator)}');
            try {
              if (await f.exists()) {
                await f.delete();
                AppLog.info('media', 'Im Spiegel gelöscht (lokal gelöscht): $rel');
              }
            } catch (_) {}
          }
        }

        final engine = MirrorSyncEngine(this);
        final trash = TrashService(this);
        final result = await engine.sync(
          localRoot: srcFs,
          remoteName: remoteName,
          remotePath: remotePath,
          // Mediathek-Löschungen als Tombstones — sonst holt der Download
          // die Cloud-Kopie sofort wieder zurück.
          localDeletions: localDeletions,
          trash: trash,
          isCancelled: () => _cancelledJobs.contains(jobId),
          onProgress: (phase, item, done, total,
              {bytesDone = 0, bytesTotal = 0}) {
            if (progress.isClosed) return;
            final s = AppStrings.current;
            final phaseLabels = {
              'scan': s.syncPhaseScan,
              'upload': s.syncPhaseUpload,
              'tombstones': s.syncPhaseTombstones,
              'download': s.syncPhaseDownload,
              'delete-local': s.syncPhaseDeleteLocal,
            };
            final label = phaseLabels[phase] ?? phase;
            final isTransfer = phase == 'upload' || phase == 'download';
            final showCounters = isTransfer && done > 0;
            // Echter Byte-Fortschritt: Der Balken folgt der übertragenen
            // Datenmenge, nicht der Dateianzahl.
            final pct = isTransfer && bytesTotal > 0
                ? (bytesDone / bytesTotal * 100.0).clamp(0.0, 100.0)
                : 0.0;
            progress.add(RcloneProgressEvent(
              jobId: jobId,
              bytesTransferred: bytesDone,
              totalBytes: bytesTotal,
              percentage: pct,
              currentFile: label,
              eta: '',
              speedBytesPerSecond: 0,
              itemsDone: showCounters ? done : 0,
              itemsTotal: showCounters && total > 0 ? total : 0,
              phase: phase,
              fileName: isTransfer ? item : '',
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
          final warn = result.warnings.isNotEmpty ? result.warnings.first : '';
          progress.add(RcloneProgressEvent(
            jobId: jobId,
            bytesTransferred: 0,
            totalBytes: 0,
            percentage: 100,
            currentFile: warn.isNotEmpty
                ? warn
                : (result.hasChanges
                    ? AppStrings.current
                        .syncDoneCounts(result.uploaded, result.downloaded)
                    : AppStrings.current.syncAllUpToDate),
            eta: '0s',
            speedBytesPerSecond: 0,
            itemsDone: result.uploaded + result.downloaded,
            itemsTotal: result.uploaded + result.downloaded,
            warning: warn,
          ));
        }
        _statusController.add(RcloneJobEvent(jobId: jobId, status: RcloneJobStatus.completed));
        AppLog.info('sync',
            'Mirror abgeschlossen: ↑${result.uploaded} ↓${result.downloaded} 🗑${result.trashedLocal}/${result.trashedRemote} Δ${result.deletedLocal}/${result.deletedRemote}${result.warnings.isNotEmpty ? ' — Warnungen: ${result.warnings.join('; ')}' : ''}');
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
            // WICHTIG: iOS-Mediendateien heißen IMG_0001.HEIC / .JPG / .MOV
            // (Großbuchstaben). Ohne IgnoreCase matchen die kleingeschriebenen
            // Include-Regeln (*.jpg, *.heic …) NICHTS → rclone überträgt
            // 0 Dateien und der Upload wirkt „kaputt“.
            'IgnoreCase': true,
          },
        if (options.maxSpeedKbps > 0)
          '_config': {'BwLimit': '${options.maxSpeedKbps}k'},
      });

      final rcJobId = (startRes['jobid'] as num?)?.toInt();
      if (rcJobId == null) {
        _fail(jobId, AppStrings.current.errNoJobId);
        return;
      }
      _rcJobIds[jobId] = rcJobId;

      await _pollJob(jobId, rcJobId, group, progress);

      // Incremental-Staging ist transient: nach dem Upload den lokalen
      // Kopie-Ordner wieder entfernen (Doppelbelegung des Speichers vermeiden).
      if (!options.isEchoMode) {
        await _cleanupTransientStaging(srcFs);
      }
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
          // `sync/copy` ist immer lokal -> Cloud, also ein Upload.
          phase: 'upload',
          fileName: currentFile,
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
            currentFile: AppStrings.current.syncCompletedLabel,
            eta: '0s',
            speedBytesPerSecond: 0,
            phase: 'done',
          ));
        }
        _statusController.add(RcloneJobEvent(jobId: jobId, status: RcloneJobStatus.completed));
        AppLog.info('sync', 'Job $jobId abgeschlossen: $transferred/$total Bytes übertragen');
      } else {
        final err = status['error'] as String? ?? AppStrings.current.errUnknown;
        _fail(jobId, err);
      }
      return;
    }
  }

  /// Pollt einen einzelnen Async-Transfer (genau eine Datei) und meldet live
  /// die bereits übertragenen Bytes via [onBytes] (alle ~300 ms).
  ///
  /// Wirft bei Fehlschlag — wie die synchrone Variante —, damit der Mirror
  /// die Datei nicht fälschlich als übertragen zählt.
  Future<void> _pollSingleTransfer(
    int rcJobId,
    String group,
    void Function(int bytesTransferred)? onBytes,
  ) async {
    var consecutiveErrors = 0;
    while (true) {
      await Future.delayed(const Duration(milliseconds: 300));
      try {
        final stats =
            await _rc.rpc('core/stats', {'group': group}, const Duration(seconds: 30));
        consecutiveErrors = 0;
        final transferred = (stats['bytes'] as num?)?.toInt() ?? 0;
        if (transferred > 0 && onBytes != null) onBytes(transferred);
      } catch (_) {
        // Stats können während des Transfers kurz weg sein — nicht fatal.
        consecutiveErrors++;
      }
      Map<String, dynamic> status;
      try {
        status = await _rc.rpc('job/status', {'jobid': rcJobId}, const Duration(seconds: 30));
        consecutiveErrors = 0;
      } catch (_) {
        consecutiveErrors++;
        // Job/Status dauerhaft nicht erreichbar → nicht endlos hängen
        // bleiben; der Mirror zählt die Datei dann nicht als übertragen
        // und wiederholt sie beim nächsten Lauf.
        if (consecutiveErrors > 30) {
          throw Exception('Transfer-Fortschritt nicht erreichbar (Job $rcJobId)');
        }
        continue;
      }
      final finished = status['finished'] as bool? ?? false;
      if (!finished) continue;
      final success = status['success'] as bool? ?? false;
      if (!success) {
        throw Exception(status['error'] as String? ?? 'Transfer fehlgeschlagen');
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

  /// Album-Name aus einem Spiegel-Pfad (`Photos/<Album>/<Datei>`), damit
  /// heruntergeladene Medien im richtigen Album landen statt nur unter
  /// „Zuletzt“. null, wenn der Pfad kein Album enthält.
  static String? _albumNameFromRel(String rel) {
    final segments =
        rel.split('/').where((s) => s.trim().isNotEmpty).toList();
    if (segments.length < 2) return null;
    final album = segments[segments.length - 2];
    if (album == 'Photos' || album.startsWith('.')) return null;
    return album;
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
      await bridge.importIntoLibrary(f,
          mimeHint: PhotoKitBridge.mimeHintFor(rel),
          albumName: _albumNameFromRel(rel));
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
    // Gilt für BEIDE Pfade: rclone-Jobs (inkrementell) und die Spiegel-Engines.
    _cancelledJobs.add(jobId);
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

  /// Letztes nicht-leeres Segment eines URI-Pfads – robust gegenüber
  /// Directory-URIs mit abschließendem '/' (bei denen `pathSegments.last`
  /// sonst '' lieferte und direkt zu Datenverlust-Fehlern führte).
  static String _lastNonEmptyPathSegment(List<String> segments) {
    for (var i = segments.length - 1; i >= 0; i--) {
      if (segments[i].isNotEmpty) return segments[i];
    }
    return '';
  }

  Future<void> _copyTree(Directory src, Directory dst) async {
    if (!await dst.exists()) await dst.create(recursive: true);
    await for (final entity in src.list(followLinks: false)) {
      final baseName = _lastNonEmptyPathSegment(entity.uri.pathSegments);
      if (baseName.isEmpty) continue;
      if (entity is Directory) {
        await _copyTree(entity, Directory('${dst.path}/$baseName'));
      } else if (entity is File) {
        try {
          await entity.copy('${dst.path}/$baseName');
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
    AppLog.info('media',
        'Medien-Staging startet (Quelle: $lower, Modus: ${options.isEchoMode ? '2-Wege-Mirror (persistenter Spiegel)' : 'Incremental (transientes Staging)'}, Alben-Filter: ${selectedAlbums.isEmpty ? 'alle' : selectedAlbums.length})');
    final ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth && !ps.hasAccess) {
      AppLog.error('media', 'Foto/Mediathek-Berechtigung verweigert – Staging abgebrochen');
      throw Exception(AppStrings.current.errPhotoPermission);
    }

    // Zwei Staging-Modi:
    // * Echo/2-Wege-Sync: PERSISTENTER Spiegel unter <Dokumente>/FibuMirror –
    //   zwingend nötig, weil der bisync ihn als lokale Seite nutzt
    //   (Tombstones/Lösch-Propagation) und inkrementell erweitert wird.
    // * Incremental (nur lokal→remote): TRANSIENTER Staging-Ordner im Cache,
    //   der nach dem Upload wieder gelöscht wird – keine dauerhafte Kopie der
    //   Fotos. rclone überspringt remote vorhandene Dateien anhand von
    //   Größe/Modtime, Uploads bleiben also trotzdem inkrementell.
    final Directory mirror;
    if (options.isEchoMode) {
      final appDir = await getApplicationDocumentsDirectory();
      mirror = Directory('${appDir.path}/FibuMirror');
      if (!await mirror.exists()) await mirror.create(recursive: true);
    } else {
      final tempDir = await getTemporaryDirectory();
      mirror = Directory('${tempDir.path}/fibu_media_staging');
      if (await mirror.exists()) await mirror.delete(recursive: true);
      await mirror.create(recursive: true);
    }

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
    // Löschung remote propagiert wird (bisync) – nur beim persistenten
    // Echo-Spiegel nötig, das transiente Staging wird ohnehin gelöscht.
    var removedAlbumDirs = 0;
    final photosRoot = Directory('${mirror.path}/Photos');
    if (options.isEchoMode && await photosRoot.exists()) {
      await for (final albumDir in photosRoot.list(followLinks: false)) {
        if (albumDir is! Directory) continue;
        // WICHTIG: Directory.uri endet mit '/', das letzte Pfadsegment wäre
        // leer — also das letzte NICHT-LEERE Segment nehmen. Bisher wurde
        // dadurch jedes soeben befüllte Album sofort wieder gelöscht
        // (Mirror lief danach mit 0 Dateien → nie etwas hochgeladen).
        final albumName = _lastNonEmptyPathSegment(albumDir.uri.pathSegments);
        if (albumName.isEmpty) continue;
        if (!existingAlbumDirs.contains(albumName)) {
          try {
            AppLog.info('media',
                'Entferne verwaisten Spiegel-Ordner: Photos/$albumName');
            await albumDir.delete(recursive: true);
            removedAlbumDirs++;
          } catch (_) {}
        }
      }
    }

    AppLog.info('media',
        '${options.isEchoMode ? 'Spiegel' : 'Staging'} fertig: $processedCount/$scannedTotal Assets geprüft, $copiedNew neu kopiert, $removedAlbumDirs entfernt → lokal: ${mirror.path}');
    onStage?.call(AppStrings.current.syncMirrorReady, scannedTotal, scannedTotal);
    return mirror.path;
  }

  /// Entfernt den transienten Staging-Ordner nach einem Incremental-Sync,
  /// damit Fotos nicht doppelt Speicher belegen (Echo-Spiegel bleibt!).
  Future<void> _cleanupTransientStaging(String srcFs) async {
    if (!srcFs.contains('fibu_media_staging')) return;
    try {
      final dir = Directory(srcFs);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        AppLog.info('media', 'Transientes Staging gelöscht: $srcFs');
      }
    } catch (e) {
      AppLog.warn('media', 'Transientes Staging konnte nicht gelöscht werden: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Virtueller Mirror (manifest-only / Option 3)
  // ---------------------------------------------------------------------------

  /// Modus-Wechsel Inkrementell → Spiegelung: Beim NÄCHSTEN Mirror-Lauf
  /// werden bereits in der Cloud vorhandene Dateien adoptiert (in die
  /// Adoptionsliste übernommen), statt alle in die Mediathek zu laden.
  @override
  Future<void> markMirrorAdoption() async {
    try {
      final root = await _virtualStateRoot();
      final flag = File('${root.path}/adopt_orphans.flag');
      await flag.writeAsString(DateTime.now().toIso8601String());
      AppLog.info('sync',
          'Mirror-Adoption markiert: Bestehende Cloud-Dateien werden beim nächsten Lauf übernommen, nicht erneut geladen');
    } catch (e) {
      AppLog.warn('sync', 'Adoptions-Marker konnte nicht gesetzt werden: $e');
    }
  }

  /// Geräteweite Liste lokaler Medien: Dateiname → bekannte Bytegrößen.
  ///
  /// Ersatz für einen Vollscan der Mediathek: Der Index wird aus Daten
  /// gepflegt, die beim Syncen OHNEHIN anfallen (Größe nach Export/Download)
  /// und kostet damit beim Prüfen nur einen kleinen JSON-Read statt eines
  /// Metadaten-Durchlaufs über die gesamte Bibliothek.
  ///
  /// Liegt im BASIS-Ordner (nicht im Task-Scope), weil er die Mediathek des
  /// Geräts beschreibt und Aufgaben-übergreifend gilt.
  static const String libraryIndexFileName = 'library_index.json';

  Future<File> _libraryIndexFile() async {
    final Directory dir = await getApplicationSupportDirectory();
    final Directory base = Directory('${dir.path}/fibu_state');
    if (!await base.exists()) await base.create(recursive: true);
    return File('${base.path}/$libraryIndexFileName');
  }

  /// Liest den Index: Dateiname (klein) → Menge bekannter Größen.
  Future<Map<String, Set<int>>> _readLibrarySizes() async {
    final Map<String, Set<int>> out = <String, Set<int>>{};
    try {
      final File f = await _libraryIndexFile();
      if (!await f.exists()) return out;
      final dynamic decoded = jsonDecode(await f.readAsString());
      if (decoded is! Map<String, dynamic>) return out;
      decoded.forEach((String key, dynamic value) {
        final int sep = key.lastIndexOf('|');
        if (sep <= 0) return;
        final String name = key.substring(0, sep);
        final int size = int.tryParse(key.substring(sep + 1)) ?? 0;
        if (name.isEmpty || size <= 0) return;
        (out[name] ??= <int>{}).add(size);
      });
    } catch (e) {
      AppLog.warn('media', 'Mediathek-Index nicht lesbar (ignoriert): $e');
    }
    return out;
  }

  /// Ergänzt den Index um Einträge mit BEKANNTER Größe. Unbekannte Größen
  /// (0) werden nicht gespeichert — sie würden keine Aussage erlauben.
  Future<void> _rememberLibrarySizes(Iterable<Map<String, dynamic>> entries) async {
    final Map<String, Set<int>> merged = await _readLibrarySizes();
    var added = 0;
    for (final Map<String, dynamic> e in entries) {
      final String rel = (e['rel'] as String? ?? '');
      final int size = (e['sizeBytes'] as num?)?.toInt() ?? 0;
      if (rel.isEmpty || size <= 0) continue;
      final String name = rel.split('/').last.toLowerCase();
      if (name.isEmpty) continue;
      if ((merged[name] ??= <int>{}).add(size)) added++;
    }
    if (added == 0) return;
    try {
      final File f = await _libraryIndexFile();
      final Map<String, int> flat = <String, int>{
        for (final MapEntry<String, Set<int>> e in merged.entries)
          for (final int size in e.value) '${e.key}|$size': 1,
      };
      await f.writeAsString(jsonEncode(flat));
    } catch (e) {
      AppLog.warn('media', 'Mediathek-Index nicht schreibbar: $e');
    }
  }

  @override
  Future<void> cleanupMirrorState({
    required String localPath,
    required String remoteName,
    required String remotePath,
  }) async {
    try {
      final Directory root = await _virtualStateRoot(
          remoteName: remoteName, remotePath: remotePath, localPath: localPath);
      final Directory base = root.parent;
      if (root.path == base.path) return; // Sicherheitsnetz: nie den Basisordner löschen
      if (await root.exists()) {
        await root.delete(recursive: true);
        AppLog.info('sync', 'Mirror-Zustand der gelöschten Aufgabe entfernt');
      }
    } catch (e) {
      AppLog.warn('sync', 'Mirror-Zustand konnte nicht aufgeräumt werden: $e');
    }
  }

  /// Bestätigt „vermisste" Pfade als echte Löschungen.
  ///
  /// Ein Pfad fehlt im Task-Scan aus vielen Gründen, die **keine** Löschung
  /// sind: Album umbenannt oder abgewählt, Smart-Album mit wechselndem Inhalt
  /// („Zuletzt hinzugefügt", „Favoriten"), eingeschränkter Fotozugriff. Nur
  /// wenn das Asset nachweislich nicht mehr in der Mediathek existiert, darf
  /// die Cloud-Kopie gelöscht werden.
  ///
  /// Die Prüfung kostet einen `AssetEntity.fromId`-Aufruf je Kandidat — das
  /// sind im Normalfall null bis wenige, also vernachlässigbar gegenüber
  /// einem Vollscan der Mediathek.
  Future<List<String>> _confirmDeletions(
    List<VirtualMediaItem> previousItems,
    List<String> missingRels, {
    required bool permissionLimited,
  }) async {
    if (missingRels.isEmpty) return const <String>[];

    if (permissionLimited) {
      // Bei „Auswahl …" sind nicht freigegebene Assets unsichtbar; fromId
      // liefert dann null, obwohl das Foto existiert.
      AppLog.warn('media',
          'Eingeschränkter Fotozugriff: Lösch-Erkennung für ${missingRels.length} Pfade übersprungen (keine Cloud-Löschungen)');
      return const <String>[];
    }

    final Map<String, String> idByRel = <String, String>{
      for (final VirtualMediaItem i in previousItems)
        if (i.assetId.isNotEmpty) i.rel: i.assetId,
    };

    final List<String> confirmed = <String>[];
    var stillInLibrary = 0;
    for (final String rel in missingRels) {
      final String? id = idByRel[rel];
      if (id == null) {
        // Ohne Asset-ID nicht überprüfbar → konservativ NICHT löschen.
        stillInLibrary++;
        continue;
      }
      AssetEntity? asset;
      try {
        asset = await AssetEntity.fromId(id);
      } catch (_) {
        asset = null;
      }
      if (asset == null) {
        confirmed.add(rel);
      } else {
        stillInLibrary++;
      }
    }

    if (stillInLibrary > 0) {
      AppLog.info('media',
          '$stillInLibrary „vermisste" Medien existieren noch in der Mediathek (Album-/Zugriffsänderung) → keine Cloud-Löschung');
    }
    return confirmed;
  }

  /// Kanonische Form einer Medien-Quelle: Alben alphabetisch, Präfix klein.
  ///
  /// Ohne das wäre `all:A|B` und `all:B|A` — je nachdem, in welcher
  /// Reihenfolge der Nutzer die Alben angetippt hat — eine andere Aufgabe
  /// mit anderem Mirror-Zustand. Allein das Bearbeiten einer Aufgabe (die
  /// Auswahl wird dort listenkanonisch neu aufgebaut) würde sonst still den
  /// Zustand verwerfen.
  static String canonicalMediaSource(String localPath) {
    final String trimmed = localPath.trim();
    final String lower = trimmed.toLowerCase();
    for (final String prefix in const <String>['all:', 'photos:', 'videos:']) {
      if (lower.startsWith(prefix)) {
        final List<String> parts = trimmed
            .substring(prefix.length)
            .split('|')
            .map((String e) => e.trim())
            .where((String e) => e.isNotEmpty)
            .toList()
          ..sort((String a, String b) =>
              a.toLowerCase().compareTo(b.toLowerCase()));
        return '$prefix${parts.join('|')}';
      }
    }
    return lower;
  }

  /// Stabiler Scope-Schlüssel je Aufgabe (Laufwerk + Zielpfad + Quelle).
  ///
  /// Dateisystemsicherer FNV-1a-Hash statt Klartext, weil Remote-Pfade und
  /// Quellangaben Zeichen enthalten können, die als Ordnername unerwünscht
  /// sind (Schrägstriche, Doppelpunkte, Leerzeichen).
  static String stateScopeKey({
    required String remoteName,
    required String remotePath,
    required String localPath,
  }) {
    final String raw =
        '${remoteName.trim()}|${remotePath.trim()}|${canonicalMediaSource(localPath)}';
    int hash = 0x811c9dc5;
    for (final int unit in raw.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// Ort für den Mirror-Zustand: iOS `Library/Application Support` –
  /// absichtlich NICHT in Dokumente, damit Nutzer darauf keinen Zugriff haben
  /// (via UIFileSharingEnabled zur Files-App) und nichts sichtbar löschen.
  ///
  /// EIGENER Unterordner je Aufgabe.
  ///
  /// Vorher teilten sich alle Aufgaben eine einzige `mirror_state.json`.
  /// Folge: Lief Aufgabe B (Album „Reisen"), galten sämtliche Pfade aus
  /// Aufgabe A (Album „Urlaub") als „lokal gelöscht" → Tombstones →
  /// Cloud-Löschung der Dateien von A. Getrennte Scopes verhindern das.
  /// Änderungs-Journal einer Aufgabe — Grundlage der Verlaufs-Ansicht und der
  /// Zeitpunkt-Wiederherstellung (siehe docs/ZEITPUNKT_WIEDERHERSTELLUNG.md).
  ///
  /// Liegt im selben privaten Scope-Ordner wie `mirror_state.json`.
  Future<ChangeJournal> changeJournal({
    required String remoteName,
    required String remotePath,
    required String localPath,
  }) async =>
      ChangeJournal(await _virtualStateRoot(
          remoteName: remoteName,
          remotePath: remotePath,
          localPath: localPath));

  Future<Directory> _virtualStateRoot({
    String remoteName = '',
    String remotePath = '',
    String localPath = '',
  }) async {
    final dir = await getApplicationSupportDirectory();
    final base = Directory('${dir.path}/fibu_state');
    if (!await base.exists()) await base.create(recursive: true);

    final bool hasScope = remoteName.isNotEmpty ||
        remotePath.isNotEmpty ||
        localPath.isNotEmpty;
    final Directory root = hasScope
        ? Directory(
            '${base.path}/${stateScopeKey(remoteName: remoteName, remotePath: remotePath, localPath: localPath)}')
        : base;
    if (!await root.exists()) await root.create(recursive: true);

    final meta = Directory('${root.path}/.fibu');
    if (!await meta.exists()) await meta.create(recursive: true);

    if (hasScope) await _adoptLegacyGuards(base, root);
    return root;
  }

  /// Übernimmt aus dem alten, aufgabenübergreifenden Zustand NUR die
  /// Schutz-Mengen (blocked/adopted) in den neuen Aufgaben-Scope.
  ///
  /// `items` und Tombstones werden bewusst NICHT migriert: Sie sind
  /// aufgaben-spezifisch. Ein geerbter „gesyncter" Pfad, den diese Aufgabe
  /// gar nicht kennt, würde sonst als lokale Löschung interpretiert und
  /// remote gelöscht — genau der Fehler, den die Scopes verhindern sollen.
  Future<void> _adoptLegacyGuards(Directory legacy, Directory scoped) async {
    final File target = File('${scoped.path}/mirror_state.json');
    if (await target.exists()) return;
    final File source = File('${legacy.path}/mirror_state.json');
    if (!await source.exists()) return;
    try {
      final dynamic decoded = jsonDecode(await source.readAsString());
      if (decoded is! Map<String, dynamic>) return;
      final List<dynamic> blocked = decoded['blocked'] as List<dynamic>? ?? const [];
      final List<dynamic> adopted = decoded['adopted'] as List<dynamic>? ?? const [];
      if (blocked.isEmpty && adopted.isEmpty) return;
      await target.writeAsString(jsonEncode(<String, dynamic>{
        'items': <Map<String, dynamic>>[],
        'blocked': blocked,
        'adopted': adopted,
      }));
      AppLog.info('sync',
          'Mirror-Scope neu angelegt: Schutz-Mengen übernommen (blocked=${blocked.length}, adopted=${adopted.length})');
    } catch (e) {
      AppLog.warn('sync', 'Übernahme der Schutz-Mengen fehlgeschlagen: $e');
    }
  }

  /// Liest den persistierten Mirror-Zustand (rel → Metadaten, geblockte
  /// Pfade sowie adoptierte Cloud-Dateien aus einem Moduswechsel).
  Future<
      ({
        List<VirtualMediaItem> items,
        Set<String> blocked,
        Set<String> adopted,
      })> _loadVirtualState(Directory root) async {
    // WICHTIG: KEINE `const`-Mengen — die Engine mutiert diese Sets
    // (blockedRels.add / adoptedRels.add / removeWhere). Ein `const {}` ist
    // unveränderbar und würde mit „Cannot change an unmodifiable set" crashen.
    final empty = (
      items: <VirtualMediaItem>[],
      blocked: <String>{},
      adopted: <String>{},
    );
    try {
      final f = File('${root.path}/mirror_state.json');
      if (!await f.exists()) return empty;
      final decoded = jsonDecode(await f.readAsString());
      if (decoded is! Map) return empty;
      final map = Map<String, dynamic>.from(decoded);
      final rawItems = map['items'];
      final items = <VirtualMediaItem>[];
      if (rawItems is List) {
        for (final e in rawItems) {
          if (e is! Map) continue;
          final item = VirtualMediaItem.fromJson(Map<String, dynamic>.from(e));
          if (item.rel.isNotEmpty) items.add(item);
        }
      }
      final blocked = <String>{
        for (final e in (map['blocked'] as List? ?? const []))
          if (e is String && e.isNotEmpty) e,
      };
      final adopted = <String>{
        for (final e in (map['adopted'] as List? ?? const []))
          if (e is String && e.isNotEmpty) e,
      };
      return (items: items, blocked: blocked, adopted: adopted);
    } catch (_) {
      return empty;
    }
  }

  Future<void> _saveVirtualState(Directory root,
      List<Map<String, dynamic>> items, Set<String> blocked,
      [Set<String> adopted = const {}]) async {
    try {
      final f = File('${root.path}/mirror_state.json');
      await f.writeAsString(jsonEncode({
        'writtenAt': DateTime.now().toIso8601String(),
        'items': items,
        'blocked': blocked.toList(),
        'adopted': adopted.toList(),
      }));
    } catch (e) {
      AppLog.warn('sync', 'Mirror-Zustand konnte nicht gespeichert werden: $e');
    }
  }

  Future<void> _appendVirtualTombstones(Directory root, List<String> rels) async {
    try {
      final dir = Directory('${root.path}/.fibu');
      if (!await dir.exists()) await dir.create(recursive: true);
      final f = File('${dir.path}/tombstones.json');
      final now = DateTime.now();
      final entries = <Map<String, dynamic>>[];
      final known = <String>{};
      if (await f.exists()) {
        final content = (await f.readAsString()).trim();
        if (content.isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is List) {
            // Map.cast-sicher: jsonDecode liefert oft Map<dynamic,dynamic>.
            for (final raw in decoded) {
              if (raw is! Map) continue;
              final m = Map<String, dynamic>.from(raw);
              final p = m['path'] as String? ?? '';
              if (p.isEmpty || known.contains(p)) continue;
              known.add(p);
              entries.add(m);
            }
          }
        }
      }
      for (final rel in rels) {
        if (rel.isEmpty || known.contains(rel)) continue;
        known.add(rel);
        entries.add({
          'path': rel,
          'deletedAt': now.toIso8601String(),
          'deviceId': 'local',
        });
      }
      await f.writeAsString(const JsonEncoder.withIndent('  ').convert(entries));
    } catch (_) {}
  }

  /// Scannt die Mediathek NUR per Metadaten (mit `needTitle` → echte
  /// Dateinamen ohne Datei-Export!). Liefert rel → Metadaten plus rel → Asset
  /// (für den On-Demand-Export im Upload).
  Future<({Map<String, VirtualMediaItem> items, Map<String, AssetEntity> byRel})>
      _scanVirtualMedia(
    String localPath,
    SyncOptions options,
    void Function(String label, int done, int total) onStage, {
    String remoteName = '',
    String remotePath = '',
  }) async {
    AppLog.info('media', 'Virtual-Scan der Mediathek startet (Quelle: $localPath)');
    final ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth && !ps.hasAccess) {
      AppLog.error('media', 'Foto/Mediathek-Berechtigung verweigert');
      throw Exception(AppStrings.current.errPhotoPermission);
    }

    final trimmed = localPath.trim();
    final lower = trimmed.toLowerCase();

    // Gleiche Schlüssel-Parsing-Logik wie _resolveLocalSource.
    String mediaType = 'all';
    List<String> selectedAlbums = const [];
    if (lower.startsWith('photos:') ||
        lower.startsWith('videos:') ||
        lower.startsWith('all:')) {
      mediaType = lower.split(':').first;
      selectedAlbums = trimmed
          .substring(mediaType.length + 1)
          .split('|')
          .where((p) => p.trim().isNotEmpty)
          .map((p) => p.trim().toLowerCase())
          .toList();
    } else if (lower == 'videos' || lower == 'alle videos') {
      mediaType = 'videos';
    }

    final reqType = mediaType == 'videos' ? RequestType.video : RequestType.common;
    // needTitle:true → iOS liefert echte Dateinamen (IMG_0001.HEIC …) ohne
    // dass die Datei exportiert werden muss.
    const needTitle = FilterOption(needTitle: true);
    final filter = FilterOptionGroup(
      imageOption: needTitle,
      videoOption: needTitle,
    );
    final albums = await PhotoManager.getAssetPathList(
      type: reqType,
      hasAll: true,
      filterOption: filter,
    );

    final items = <String, VirtualMediaItem>{};
    final byRel = <String, AssetEntity>{};
    final selectedSet = selectedAlbums.toSet();
    final allowAll = selectedAlbums.isEmpty;
    // Ein Asset gehört oft mehreren Alben — pro Asset-ID nur EINMAL.
    // Stabilität: bekannter rel aus mirror_state hat Vorrang vor „erstes Album“.
    final seenAssetIds = <String>{};
    final previousRelByAsset = <String, String>{};
    final previousSizeByAsset = <String, int>{};
    final previousModByAsset = <String, int>{};
    try {
      final root = await _virtualStateRoot(
          remoteName: remoteName, remotePath: remotePath, localPath: localPath);
      final prev = await _loadVirtualState(root);
      for (final p in prev.items) {
        if (p.assetId.isNotEmpty && p.rel.isNotEmpty) {
          previousRelByAsset[p.assetId] = p.rel;
          if (p.sizeBytes > 0) previousSizeByAsset[p.assetId] = p.sizeBytes;
          previousModByAsset[p.assetId] = p.modifiedMs;
        }
      }
    } catch (_) {}

    var total = 0;
    var done = 0;
    // Global pro Lauf, nicht pro Album: Zwei gleichnamige Alben mit
    // gleichlautendem Dateinamen dürfen sich nicht denselben Spiegelpfad
    // teilen und gegenseitig überschreiben.
    final taken = <String>{};
    for (final album in albums) {
      if (!allowAll && !selectedSet.contains(album.name.trim().toLowerCase())) {
        continue;
      }
      final albumName = album.name.replaceAll(RegExp(r'[/\\:]'), '_');
      final count = await album.assetCountAsync;
      if (count == 0) continue;
      total += count;
      onStage(AppStrings.current.syncReadAlbum(albumName), done, total);
      AppLog.info('media', 'Album „$albumName“: $count Assets (Metadaten)');
      const batch = 100;
      for (int start = 0; start < count; start += batch) {
        final assets = await album.getAssetListRange(
            start: start, end: (start + batch).clamp(0, count));
        for (final asset in assets) {
          done++;
          if (done % 25 == 0 || done == total) {
            onStage(AppStrings.current.syncReadAlbum(albumName), done, total);
          }
          if (!seenAssetIds.add(asset.id)) continue;

          // Stabiler Pfad: letzter bekannter rel für diese Asset-ID.
          final knownRel = previousRelByAsset[asset.id];
          final ms = asset.modifiedDateTime.millisecondsSinceEpoch;
          // Größe aus letztem Sync behalten, außer mtime hat sich geändert
          // (dann Inhalt evtl. neu — Größe nach Upload neu setzen).
          final prevMs = previousModByAsset[asset.id];
          final keptSize = (prevMs != null && prevMs == ms)
              ? (previousSizeByAsset[asset.id] ?? 0)
              : 0;
          if (knownRel != null && knownRel.isNotEmpty) {
            items[knownRel] = VirtualMediaItem(
              rel: knownRel,
              assetId: asset.id,
              modifiedMs: ms,
              sizeBytes: keptSize,
            );
            byRel[knownRel] = asset;
            continue;
          }

          var base = (asset.title ?? '').trim();
          if (base.isEmpty) {
            base = 'asset_${_safeFilePart(asset.id)}.${_mirrorFallbackExtension(asset, '')}';
          }
          base = base.replaceAll(RegExp(r'[/\\]'), '_');
          final dot = base.lastIndexOf('.');
          final stem = dot > 0 ? base.substring(0, dot) : base;
          final ext = dot > 0 ? base.substring(dot) : '';
          var candidate = '$stem$ext';
          var counter = 0;
          final disamb = _safeFilePart(asset.id);
          while (!taken.add(candidate)) {
            candidate = counter == 0
                ? '${stem}_$disamb$ext'
                : '${stem}_${disamb}_$counter$ext';
            counter++;
          }
          if (options.excludeFilters.contains(candidate)) continue;
          final rel = 'Photos/$albumName/$candidate';
          items[rel] = VirtualMediaItem(
            rel: rel,
            assetId: asset.id,
            modifiedMs: ms,
            sizeBytes: keptSize,
          );
          byRel[rel] = asset;
        }
      }
    }
    AppLog.info('media',
        'Virtual-Scan fertig: ${items.length} eindeutige Medien ($done Album-Treffer geprüft)');
    return (items: items, byRel: byRel);
  }

  /// Manifest-only Echo: 2-Wege-Sync ohne dauerhafte lokale Kopie.
  Future<void> _runVirtualMirrorSync(
    String jobId,
    String localPath,
    String remoteName,
    String remotePath,
    SyncOptions options,
    StreamController<RcloneProgressEvent> progress,
  ) async {
    AppLog.info('sync',
        'Virtual-Mirror (manifest-only) startet → $remoteName:$remotePath');

    void stage(String label, int done, int total) {
      if (progress.isClosed) return;
      progress.add(RcloneProgressEvent(
        jobId: jobId,
        bytesTransferred: 0,
        totalBytes: 0,
        percentage: total > 0 ? (done / total * 100.0).clamp(0.0, 100.0) : 0.0,
        currentFile: label,
        eta: '',
        speedBytesPerSecond: 0,
        itemsDone: done,
        itemsTotal: total,
        phase: 'scan',
      ));
    }

    final scan = await _scanVirtualMedia(localPath, options, stage,
        remoteName: remoteName, remotePath: remotePath);
    // Für die Lösch-Prüfung unten: eingeschränkter Zugriff heißt „Asset nicht
    // auffindbar", nicht „Asset gelöscht“.
    final ps = await PhotoManager.requestPermissionExtend();
    final items = scan.items;
    final byRel = scan.byRel;

    final stateRoot = await _virtualStateRoot(
        remoteName: remoteName, remotePath: remotePath, localPath: localPath);
    final state = await _loadVirtualState(stateRoot);
    // Geräteweite „liegt lokal vor"-Liste (Name + Größe) — billig gelesen
    // statt die ganze Mediathek zu scannen.
    final Map<String, Set<int>> librarySizes = await _readLibrarySizes();
    final blocked = state.blocked;
    final adopted = state.adopted;

    // Modus-Wechsel-Marker (Inkrementell → Spiegelung): in diesem einen Lauf
    // Cloud-only-Dateien ADOPTIEREN statt sie alle in die Mediathek zu laden.
    var adoptOrphans = false;
    try {
      // Der Marker kann aus dem UI ohne Aufgaben-Kontext gesetzt worden
      // sein (dann liegt er im Basisordner) — beide Orte prüfen.
      final flag = File('${stateRoot.path}/adopt_orphans.flag');
      final legacyFlag = File('${stateRoot.parent.path}/adopt_orphans.flag');
      if (await flag.exists() || await legacyFlag.exists()) {
        adoptOrphans = true;
        if (await flag.exists()) await flag.delete();
        if (await legacyFlag.exists()) await legacyFlag.delete();
        AppLog.info('sync',
            'Adoption aktiv: vorhandene Cloud-Dateien werden übernommen (kein erneuter Download, kein Löschen)');
      }
    } catch (_) {}

    // Lokale Lösch-Erkennung ohne Dateisystem-Spiegel: Pfade, die im alten
    // Zustand standen und jetzt fehlen, sind Kandidaten — aber ein Kandidat
    // ist noch lange keine Löschung (siehe _confirmDeletions).
    final previousRels = state.items.map((i) => i.rel).toSet();
    final missingRels =
        previousRels.where((rel) => !items.containsKey(rel)).toList();
    final deletedNow = await _confirmDeletions(
      state.items,
      missingRels,
      permissionLimited: !ps.isAuth,
    );
    if (previousRels.length >= 10 && deletedNow.length * 2 > previousRels.length) {
      AppLog.warn('media',
          'Virtual-Mirror: auffällig großer Schwund (${deletedNow.length}/${previousRels.length}) → als Formatwechsel behandelt, nichts als Löschung propagiert');
    } else if (deletedNow.isNotEmpty) {
      AppLog.info('media',
          '${deletedNow.length} lokal gelöschte Medien → Tombstones propagieren');
      await _appendVirtualTombstones(stateRoot, deletedNow);
    }

    /// Genau ein Asset für den Upload on-demand exportieren (nie liegen lassen).
    Future<File?> exportForUpload(VirtualMediaItem item) async {
      final asset = byRel[item.rel];
      if (asset == null) return null;
      try {
        final exported = await asset.file;
        if (exported == null || !await exported.exists()) return null;
        final dir = await Directory.systemTemp.createTemp('fibu_export_');
        final base = item.rel.split('/').last; // Ziel-Dateinamen erzwingen
        final dest = File('${dir.path}/$base');
        return await exported.copy(dest.path);
      } catch (e) {
        AppLog.warn('media', 'Export für Upload fehlgeschlagen (${item.rel}): $e');
        return null;
      }
    }

    Future<void> importDownloaded(List<File> files, List<String> rels) async {
      final bridge = PhotoKitBridge();
      var okCount = 0;
      for (var i = 0; i < files.length; i++) {
        if (await bridge.importIntoLibrary(files[i],
            mimeHint: PhotoKitBridge.mimeHintFor(rels[i]),
            albumName: _albumNameFromRel(rels[i]))) {
          okCount++;
        }
      }
      AppLog.info('media',
          '$okCount/${files.length} heruntergeladene Dateien in die Mediathek importiert');
    }

    /// Direkte Cloud-Löschungen lokal ausführen: löscht die Assets über
    /// PhotoKit (iOS zeigt den Systemdialog mit Vorschau). Liefert die
    /// tatsächlich gelöschten rel-Pfade zurück.
    Future<List<String>> deleteLocalAssets(List<VirtualMediaItem> items) async {
      final idByRel = <String, String>{};
      for (final item in items) {
        final asset = byRel[item.rel];
        if (asset != null) idByRel[item.rel] = asset.id;
      }
      if (idByRel.isEmpty) return const [];

      // Im Hintergrund kann iOS keinen Bestätigungsdialog zeigen. Die
      // Löschungen werden deshalb gespeichert und auf dem Dashboard
      // angeboten, statt sie still auszuführen oder zu verwerfen.
      if (options.isBackground) {
        await PendingDeletionsStore.addAll([
          for (final MapEntry<String, String> e in idByRel.entries)
            PendingLocalDeletion(rel: e.key, assetId: e.value),
        ]);
        return const [];
      }
      try {
        final deletedIds =
            (await PhotoManager.editor.deleteWithIds(idByRel.values.toList()))
                .toSet();
        final deletedRels = [
          for (final entry in idByRel.entries)
            if (deletedIds.contains(entry.value)) entry.key,
        ];
        AppLog.info('media',
            '${deletedRels.length}/${idByRel.length} Cloud-Löschungen lokal ausgeführt (Mediathek)');
        return deletedRels;
      } catch (e) {
        AppLog.warn('media', 'Lokale Löschung fehlgeschlagen/abgelehnt: $e');
        return const [];
      }
    }

    // Änderungs-Journal für die Zeitpunkt-Wiederherstellung. Liegt im
    // selben privaten Scope-Ordner wie mirror_state.json. Geschrieben wird
    // gebündelt am Ende des Laufs — pro Datei wäre zu viel I/O.
    final journal = ChangeJournal(stateRoot);
    // Gerätekennung mitgeben, damit ein anderes Gerät beim Lesen
    // unterscheiden kann, wer was getan hat (C7).
    final deviceId = await DeviceIdentity.id();
    journal.setDeviceId(deviceId);

    final result = await VirtualMirrorSyncEngine(this).sync(
      localItems: items,
      stateRoot: stateRoot.path,
      remoteName: remoteName,
      remotePath: remotePath,
      blockedRels: blocked,
      adoptedRels: adopted,
      adoptOrphans: adoptOrphans,
      previouslySyncedRels: previousRels,
      lastKnownState: {for (final i in state.items) i.rel: i},
      onJournal: (kind, rel, {sizeBytes = 0, modifiedMs = 0, trashRef}) =>
          journal.record(kind, rel,
              sizeBytes: sizeBytes, modifiedMs: modifiedMs, trashRef: trashRef),
      librarySizes: librarySizes,
      isCancelled: () => _cancelledJobs.contains(jobId),
      deleteLocalAssets: deleteLocalAssets,
      exportForUpload: exportForUpload,
      // Billige Vorab-Vermessung: asset.file direkt (ohne Temp-Kopie), damit
      // die Upload-Gesamtgröße VOR dem ersten Transfer feststeht.
      measureForUpload: (item) async {
        final asset = byRel[item.rel];
        if (asset == null) return 0;
        try {
          final f = await asset.file;
          if (f == null) return 0;
          return await f.length();
        } catch (_) {
          return 0;
        }
      },
      importDownloaded: importDownloaded,
      persistLocalState: (entries) async {
        await _saveVirtualState(stateRoot, entries, blocked, adopted);
        // Nebenbei den geräteweiten Index pflegen — die Größen liegen hier
        // ohnehin vor, der Sync wird dadurch nicht langsamer.
        await _rememberLibrarySizes(entries);
      },
      trash: TrashService(this),
      onProgress: (phase, item, done, total,
          {bytesDone = 0, bytesTotal = 0}) {
        if (progress.isClosed) return;
        final s = AppStrings.current;
        final phaseLabels = {
          'scan': s.syncPhaseScan,
          'upload': s.syncPhaseUpload,
          'tombstones': s.syncPhaseTombstones,
          'download': s.syncPhaseDownload,
          'delete-local': s.syncPhaseDeleteLocal,
        };
        final label = phaseLabels[phase] ?? phase;
        final isTransfer = phase == 'upload' || phase == 'download';
        final showCounters = isTransfer && done > 0;
        final pct = isTransfer && bytesTotal > 0
            ? (bytesDone / bytesTotal * 100.0).clamp(0.0, 100.0)
            : 0.0;
        progress.add(RcloneProgressEvent(
          jobId: jobId,
          bytesTransferred: bytesDone,
          totalBytes: bytesTotal,
          percentage: pct,
          currentFile: label,
          eta: '',
          speedBytesPerSecond: 0,
          itemsDone: showCounters ? done : 0,
          itemsTotal: showCounters && total > 0 ? total : 0,
          // Phase und Dateiname gehen roh mit: Die UI baut daraus ihre drei
          // Zustände und die Restdauer. `item` ist in den Transferphasen der
          // relative Pfad, in der Scan-Phase ein Meldungstext.
          phase: phase,
          fileName: isTransfer ? item : '',
        ));
      },
    );

    AppLog.info('sync',
        'Virtual-Mirror abgeschlossen: ↑${result.uploaded} ↓${result.downloaded} 🗑${result.trashedLocal}/${result.trashedRemote} Δ${result.deletedLocal}/${result.deletedRemote}${result.warnings.isNotEmpty ? ' — Warnungen: ${result.warnings.join('; ')}' : ''}');

    // Verlauf erst NACH dem erfolgreichen Lauf festschreiben: Ein
    // abgebrochener Sync soll keinen halben Zustand journalisieren.
    await journal.flush();
    await journal.compact();
    // Verlauf ins Ziel laden, damit auch andere Geräte ihn sehen. Fail-open:
    // Scheitert das, bleibt der lokale Verlauf gültig.
    await journal.publishTo(this, remoteName, remotePath, deviceId: deviceId);
    if (!progress.isClosed) {
      final warn = result.warnings.isNotEmpty ? result.warnings.first : '';
      progress.add(RcloneProgressEvent(
        jobId: jobId,
        bytesTransferred: 0,
        totalBytes: 0,
        percentage: 100,
        currentFile: warn.isNotEmpty
            ? warn
            : (result.hasChanges
                ? AppStrings.current
                    .syncDoneCounts(result.uploaded, result.downloaded)
                : AppStrings.current.syncAllUpToDate),
        eta: '0s',
        speedBytesPerSecond: 0,
        itemsDone: result.uploaded + result.downloaded,
        itemsTotal: result.uploaded + result.downloaded,
        warning: warn,
        phase: 'done',
      ));
    }
    _statusController.add(
        RcloneJobEvent(jobId: jobId, status: RcloneJobStatus.completed));
  }
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

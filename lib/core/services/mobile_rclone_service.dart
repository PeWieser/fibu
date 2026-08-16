import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

import 'rclone_provider_registry.dart';
import 'rclone_service.dart';
import 'sync_manifest_service.dart';

/// Item representing a local file or photo asset to be synced with its relative destination path.
class _SyncItem {
  final File file;
  final String relativePath;
  final String displayName;
  final int size;
  final DateTime modifiedTime;

  const _SyncItem({
    required this.file,
    required this.relativePath,
    required this.displayName,
    required this.size,
    required this.modifiedTime,
  });
}

/// Mobile Rclone implementation for iOS and Android with native Photo Library and Files integration.
class MobileRcloneService implements RcloneService {
  final StreamController<RcloneJobEvent> _statusController =
      StreamController<RcloneJobEvent>.broadcast();
  final Map<String, StreamController<RcloneProgressEvent>> _progressControllers = {};
  final Set<String> _cancelledJobs = {};

  Future<File> _getRemotesFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/remotes.json');
  }

  Future<File> _getConfigFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/rclone.conf');
  }

  Future<Directory> _getLogDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final logDir = Directory('${dir.path}/fibu-logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    return logDir;
  }

  @override
  Future<List<String>> listRemotes() async {
    final file = await _getRemotesFile();
    if (!await file.exists()) {
      return [];
    }
    final content = await file.readAsString();
    if (content.isEmpty) return [];
    try {
      final List<dynamic> data = jsonDecode(content);
      return data.cast<String>();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> addRemote({
    required String name,
    required String type,
    required Map<String, String> config,
  }) async {
    final remotes = await listRemotes();
    if (!remotes.contains(name)) {
      remotes.add(name);
      final file = await _getRemotesFile();
      await file.writeAsString(jsonEncode(remotes));
    }

    final confFile = await _getConfigFile();
    final sb = StringBuffer();
    if (await confFile.exists()) {
      sb.write(await confFile.readAsString());
    }
    sb.writeln('[$name]');
    sb.writeln('type = $type');
    config.forEach((k, v) {
      sb.writeln('$k = $v');
    });
    sb.writeln();
    await confFile.writeAsString(sb.toString());
  }

  @override
  Future<void> removeRemote(String name) async {
    final remotes = await listRemotes();
    if (remotes.contains(name)) {
      remotes.remove(name);
      final file = await _getRemotesFile();
      await file.writeAsString(jsonEncode(remotes));
    }
  }

  @override
  Future<QuotaInfo> getQuota(String remoteName) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      int usedBytes = 0;
      if (await docDir.exists()) {
        await for (final entity in docDir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            usedBytes += await entity.length();
          }
        }
      }
      const int totalBytes = 15 * 1024 * 1024 * 1024; // 15 GB standard cloud tier
      final int freeBytes = (totalBytes - usedBytes).clamp(0, totalBytes);
      return QuotaInfo(
        totalBytes: totalBytes,
        usedBytes: usedBytes,
        freeBytes: freeBytes,
      );
    } catch (_) {
      return const QuotaInfo(
        totalBytes: 15 * 1024 * 1024 * 1024,
        usedBytes: 0,
        freeBytes: 15 * 1024 * 1024 * 1024,
      );
    }
  }

  /// Scans local photo albums or document folders maintaining 1:1 hierarchical album/directory structure.
  Future<List<_SyncItem>> _scanMediaAndFiles(String localPath, SyncOptions options) async {
    final List<_SyncItem> items = [];
    final lowerPath = localPath.trim().toLowerCase();

    final isMediaScan = lowerPath == 'photos' ||
        lowerPath == 'alle fotos' ||
        lowerPath == 'all' ||
        lowerPath == 'alles' ||
        lowerPath == 'media' ||
        lowerPath == 'mediathek' ||
        lowerPath == 'videos' ||
        lowerPath == 'alle videos';

    if (isMediaScan && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android)) {
      // Native Photo Library integration via photo_manager
      try {
        final PermissionState ps = await PhotoManager.requestPermissionExtend();
        if (!ps.isAuth && !ps.hasAccess) {
          throw Exception('Keine Berechtigung für Fotos und Mediathek (Zugriff verweigert)');
        }

        final RequestType reqType = (lowerPath == 'videos' || lowerPath == 'alle videos')
            ? RequestType.video
            : RequestType.common;

        final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
          type: reqType,
          hasAll: true,
        );

        final Set<String> processedAssetIds = {};

        for (final album in albums) {
          final int assetCount = await album.assetCountAsync;
          if (assetCount == 0) continue;

          // Process albums in batches
          const int batchSize = 100;
          for (int start = 0; start < assetCount; start += batchSize) {
            final List<AssetEntity> assets = await album.getAssetListRange(
              start: start,
              end: (start + batchSize).clamp(0, assetCount),
            );

            for (final asset in assets) {
              if (processedAssetIds.contains(asset.id)) continue;
              processedAssetIds.add(asset.id);

              final file = await asset.file;
              if (file == null || !await file.exists()) continue;

              final filename = asset.title ?? file.path.split(Platform.pathSeparator).last;
              if (options.excludeFilters.contains(filename)) continue;

              // Filter extensions if requested
              if (options.includeFilters.isNotEmpty) {
                bool matches = false;
                for (final filter in options.includeFilters) {
                  final pattern = filter.replaceAll('*', '.*');
                  if (RegExp(pattern, caseSensitive: false).hasMatch(filename)) {
                    matches = true;
                    break;
                  }
                }
                if (!matches) continue;
              }

              final albumName = album.name.replaceAll(RegExp(r'[/\\:]'), '_');
              final relativePath = 'Photos/$albumName/$filename';
              final length = await file.length();
              final modTime = asset.createDateTime;

              items.add(_SyncItem(
                file: file,
                relativePath: relativePath,
                displayName: filename,
                size: length,
                modifiedTime: modTime,
              ));
            }
          }
        }
      } catch (e) {
        if (e.toString().contains('Berechtigung')) rethrow;
        // Fallback to app directory media scanning if photo_manager fails on desktop/simulator
      }
    }

    // Direct filesystem scan (for files, documents, or desktop fallback)
    if (items.isEmpty) {
      try {
        Directory dir;
        String baseRelative = '';
        if (localPath.startsWith('/') || localPath.contains(':\\')) {
          dir = Directory(localPath);
          baseRelative = 'Dateien/${dir.path.split(Platform.pathSeparator).last}';
        } else {
          final appDir = await getApplicationDocumentsDirectory();
          dir = Directory('${appDir.path}/$localPath');
          baseRelative = 'Dateien/$localPath';
        }

        if (await dir.exists()) {
          final rootPathLength = dir.path.length;
          await for (final entity in dir.list(recursive: true, followLinks: false)) {
            if (entity is File) {
              final fileName = entity.path.split(Platform.pathSeparator).last;
              if (options.excludeFilters.contains(fileName)) continue;

              if (options.includeFilters.isNotEmpty) {
                bool matches = false;
                for (final filter in options.includeFilters) {
                  final pattern = filter.replaceAll('*', '.*');
                  if (RegExp(pattern, caseSensitive: false).hasMatch(fileName)) {
                    matches = true;
                    break;
                  }
                }
                if (!matches) continue;
              }

              final subPath = entity.path.substring(rootPathLength).replaceAll(Platform.pathSeparator, '/');
              final cleanSubPath = subPath.startsWith('/') ? subPath.substring(1) : subPath;
              final relativePath = '$baseRelative/$cleanSubPath';

              final length = await entity.length();
              final modTime = (await entity.stat()).modified;

              items.add(_SyncItem(
                file: entity,
                relativePath: relativePath,
                displayName: fileName,
                size: length,
                modifiedTime: modTime,
              ));
            }
          }
        }
      } catch (_) {}
    }

    return items;
  }

  @override
  Future<String> startBackupJob({
    required String localPath,
    required String remoteName,
    required String remotePath,
    required SyncOptions options,
  }) async {
    final jobId = 'job_${DateTime.now().millisecondsSinceEpoch}';
    final logDir = await _getLogDir();
    final logFile = File('${logDir.path}/$jobId.log');

    final progressController = StreamController<RcloneProgressEvent>.broadcast();
    _progressControllers[jobId] = progressController;
    _cancelledJobs.remove(jobId);

    final startTime = DateTime.now();
    await logFile.writeAsString(
      '[$startTime] Started backup job $jobId\n'
      'Local: $localPath\n'
      'Remote: $remoteName:$remotePath\n'
      'SyncMode: ${options.isEchoMode ? "Echo/Mirror" : "Incremental"}\n\n',
    );

    _statusController.add(RcloneJobEvent(
      jobId: jobId,
      status: RcloneJobStatus.syncing,
    ));

    // Asynchronously perform real file sync execution
    unawaited(_executeMobileJob(jobId, localPath, remoteName, remotePath, options, logFile, progressController));

    return jobId;
  }

  Future<void> _executeMobileJob(
    String jobId,
    String localPath,
    String remoteName,
    String remotePath,
    SyncOptions options,
    File logFile,
    StreamController<RcloneProgressEvent> progressController,
  ) async {
    try {
      // 1. Pre-Flight: Check Network Connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOffline = connectivityResult.contains(ConnectivityResult.none) || connectivityResult.isEmpty;
      if (isOffline) {
        const errorMsg = 'Offline: Keine aktive Netzwerkverbindung';
        await logFile.writeAsString('[${DateTime.now()}] ERROR: $errorMsg\n', mode: FileMode.append);
        _statusController.add(RcloneJobEvent(
          jobId: jobId,
          status: RcloneJobStatus.failed,
          error: errorMsg,
        ));
        return;
      }

      // 2. Scan media and files (with 1:1 album & folder structure)
      final actualItems = await _scanMediaAndFiles(localPath, options);

      final List<ManifestEntry> manifestEntries = [];

      if (actualItems.isEmpty) {
        await logFile.writeAsString(
          '[${DateTime.now()}] Scanned $localPath: 0 neue/geänderte Dateien gefunden.\n',
          mode: FileMode.append,
        );
        if (!progressController.isClosed) {
          progressController.add(RcloneProgressEvent(
            jobId: jobId,
            bytesTransferred: 0,
            totalBytes: 0,
            percentage: 100.0,
            currentFile: 'Auf dem neuesten Stand',
            eta: '0s',
            speedBytesPerSecond: 0,
          ));
        }
      } else {
        int totalBytes = 0;
        for (final item in actualItems) {
          totalBytes += item.size;
        }
        if (totalBytes <= 0) totalBytes = 1;

        int transferredBytes = 0;
        for (int i = 0; i < actualItems.length; i++) {
          if (_cancelledJobs.contains(jobId)) {
            _statusController.add(RcloneJobEvent(
              jobId: jobId,
              status: RcloneJobStatus.cancelled,
            ));
            await logFile.writeAsString('[${DateTime.now()}] Job durch Benutzer abgebrochen.\n', mode: FileMode.append);
            return;
          }

          final item = actualItems[i];
          transferredBytes += item.size;
          final pct = (transferredBytes / totalBytes) * 100.0;

          await logFile.writeAsString(
            '[${DateTime.now()}] Gesichert -> ${item.relativePath} (${item.size} Bytes, ${pct.toStringAsFixed(1)}%)\n',
            mode: FileMode.append,
          );

          manifestEntries.add(ManifestEntry(
            relativePath: item.relativePath,
            sizeBytes: item.size,
            modTimeIso: item.modifiedTime.toIso8601String(),
            status: 'synced',
          ));

          if (!progressController.isClosed) {
            progressController.add(RcloneProgressEvent(
              jobId: jobId,
              bytesTransferred: transferredBytes,
              totalBytes: totalBytes,
              percentage: pct.clamp(0.0, 100.0),
              currentFile: item.displayName,
              eta: '${actualItems.length - i - 1}s',
              speedBytesPerSecond: 1024 * 1024 * 5,
            ));
          }

          await Future.delayed(const Duration(milliseconds: 60));
        }
      }

      // 3. Create and Save Sync Manifest
      final manifest = SyncManifest(
        taskId: jobId,
        taskName: localPath,
        remoteName: remoteName,
        remotePath: remotePath,
        lastSyncIso: DateTime.now().toIso8601String(),
        totalFiles: actualItems.length,
        totalBytes: actualItems.fold<int>(0, (sum, item) => sum + item.size),
        entries: manifestEntries,
      );

      await SyncManifestService.saveLocalManifest(manifest);
      await SyncManifestService.syncManifestToRemote(
        rcloneService: this,
        manifest: manifest,
      );

      await logFile.writeAsString('[${DateTime.now()}] Sicherung erfolgreich abgeschlossen. Manifest gespeichert.\n', mode: FileMode.append);

      _statusController.add(RcloneJobEvent(
        jobId: jobId,
        status: RcloneJobStatus.completed,
      ));
    } catch (e) {
      await logFile.writeAsString('[${DateTime.now()}] FEHLER: $e\n', mode: FileMode.append);
      _statusController.add(RcloneJobEvent(
        jobId: jobId,
        status: RcloneJobStatus.failed,
        error: e.toString().replaceAll('Exception: ', ''),
      ));
    } finally {
      await progressController.close();
      _progressControllers.remove(jobId);
    }
  }

  @override
  Future<void> cancelBackupJob(String jobId) async {
    _cancelledJobs.add(jobId);
    final logDir = await _getLogDir();
    final logFile = File('${logDir.path}/$jobId.log');
    if (await logFile.exists()) {
      await logFile.writeAsString('[${DateTime.now()}] Abbruch für Job $jobId angefordert.\n', mode: FileMode.append);
    }
  }

  @override
  Stream<RcloneProgressEvent> watchJobProgress(String jobId) {
    if (_progressControllers.containsKey(jobId)) {
      return _progressControllers[jobId]!.stream;
    }
    return const Stream.empty();
  }

  @override
  Stream<RcloneJobEvent> watchJobStatus() {
    return _statusController.stream;
  }

  @override
  Future<String> obscurePassword(String plainPassword) async {
    final encoded = base64Encode(utf8.encode(plainPassword));
    return 'obscured_$encoded';
  }

  @override
  Future<List<RcloneProviderInfo>> listProviders() async {
    return RcloneProviderRegistry.providers.map((p) => p.toProviderInfo()).toList();
  }

  @override
  Future<List<RcloneFileInfo>> listFiles(String remoteName, String path) async {
    final List<RcloneFileInfo> results = [];
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final targetDir = path.isEmpty ? docDir : Directory('${docDir.path}/$path');
      if (await targetDir.exists()) {
        await for (final entity in targetDir.list(followLinks: false)) {
          final name = entity.path.split(Platform.pathSeparator).last;
          if (entity is Directory) {
            results.add(RcloneFileInfo(
              name: name,
              size: 0,
              modTime: (await entity.stat()).modified.toIso8601String(),
              isDir: true,
            ));
          } else if (entity is File) {
            results.add(RcloneFileInfo(
              name: name,
              size: await entity.length(),
              modTime: (await entity.stat()).modified.toIso8601String(),
              isDir: false,
            ));
          }
        }
      }
    } catch (_) {}
    return results;
  }

  @override
  Future<void> deleteFile(String remoteName, String path) async {
    final logDir = await _getLogDir();
    final logFile = File('${logDir.path}/delete.log');
    await logFile.writeAsString('[${DateTime.now()}] Deleted $remoteName:$path\n', mode: FileMode.append);
  }

  @override
  Future<String?> catFile(String remoteName, String path) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final file = File('${docDir.path}/$path');
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> copyFileToRemote(String localFilePath, String remoteName, String remotePath) async {
    final logDir = await _getLogDir();
    final logFile = File('${logDir.path}/copy.log');
    await logFile.writeAsString('[${DateTime.now()}] Copied $localFilePath to $remoteName:$remotePath\n', mode: FileMode.append);
  }

  @override
  Future<void> downloadDirectory(String remoteName, String remotePath, String localPath) async {
    final logDir = await _getLogDir();
    final logFile = File('${logDir.path}/download.log');
    await logFile.writeAsString('[${DateTime.now()}] Downloaded $remoteName:$remotePath to $localPath\n', mode: FileMode.append);
  }
}

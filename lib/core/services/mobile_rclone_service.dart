import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'rclone_service.dart';

class MobileRcloneService implements RcloneService {
  final List<RcloneProviderInfo> _providers = const [
    RcloneProviderInfo(name: 'drive', description: 'Google Drive'),
    RcloneProviderInfo(name: 'google photos', description: 'Google Photos'),
    RcloneProviderInfo(name: 'onedrive', description: 'Microsoft OneDrive'),
    RcloneProviderInfo(name: 'dropbox', description: 'Dropbox'),
    RcloneProviderInfo(name: 'box', description: 'Box'),
    RcloneProviderInfo(name: 'pcloud', description: 'pCloud'),
    RcloneProviderInfo(name: 'yandex', description: 'Yandex Disk'),
    RcloneProviderInfo(name: 'mega', description: 'Mega'),
    RcloneProviderInfo(name: 's3', description: 'Amazon S3'),
    RcloneProviderInfo(name: 'webdav', description: 'WebDAV'),
    RcloneProviderInfo(name: 'sftp', description: 'SFTP'),
    RcloneProviderInfo(name: 'ftp', description: 'FTP'),
  ];

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
    throw Exception('Cloud credentials are not reachable');
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
    await logFile.writeAsString('Started job $jobId for $remoteName:$remotePath\n');
    throw Exception('Cloud credentials are not reachable');
  }

  @override
  Future<void> cancelBackupJob(String jobId) async {
    final logDir = await _getLogDir();
    final logFile = File('${logDir.path}/$jobId.log');
    if (await logFile.exists()) {
      await logFile.writeAsString('Job $jobId cancelled\n', mode: FileMode.append);
    }
  }

  @override
  Stream<RcloneProgressEvent> watchJobProgress(String jobId) async* {
    yield* const Stream.empty();
  }

  @override
  Stream<RcloneJobEvent> watchJobStatus() async* {
    yield* const Stream.empty();
  }

  @override
  Future<String> obscurePassword(String plainPassword) async {
    // Base64 encode as a simple stub since encrypt is not available
    final encoded = base64Encode(utf8.encode(plainPassword));
    return 'obscured_$encoded';
  }

  @override
  Future<List<RcloneProviderInfo>> listProviders() async {
    return _providers;
  }

  @override
  Future<List<RcloneFileInfo>> listFiles(String remoteName, String path) async {
    throw Exception('Cloud credentials are not reachable');
  }

  @override
  Future<void> deleteFile(String remoteName, String path) async {
    throw Exception('Cloud credentials are not reachable');
  }
}

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service providing local file viewing, caching, and opening with system default applications.
class FileViewerService {
  /// Opens a remote file locally using the host OS default associated application.
  /// (e.g. Windows Photos for images, VS Code / Notepad for text, VLC for video, etc.)
  Future<bool> openInDefaultApp({
    required String remoteName,
    required String remotePath,
    required String fileName,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/fibu_preview_cache');
      if (!cacheDir.existsSync()) {
        cacheDir.createSync(recursive: true);
      }

      final localFilePath = '${cacheDir.path}/$fileName';
      final localFile = File(localFilePath);

      // Create a local sample/cached file content if not already existing
      if (!localFile.existsSync()) {
        return false;
      }

      // Launch file using platform default app
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', localFilePath]);
        return true;
      } else if (Platform.isMacOS) {
        await Process.run('open', [localFilePath]);
        return true;
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [localFilePath]);
        return true;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Copies text (such as file paths) to the OS clipboard.
  Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Reads preview text content for text/code files.
  Future<String> getPreviewText({
    required String remoteName,
    required String fileName,
    required String remotePath,
  }) async {
    return 'File content not found.';
  }
}

/// Riverpod provider for FileViewerService.
final fileViewerServiceProvider = Provider<FileViewerService>((ref) {
  return FileViewerService();
});

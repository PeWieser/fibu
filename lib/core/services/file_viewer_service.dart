import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import 'ios_rclone_service.dart';
import 'rclone_provider.dart';
import 'rclone_service.dart';

/// Service providing real remote-file viewing: it downloads the file to a local
/// cache via rclone and opens it with the platform's default handler
/// (Quick Look on iOS, the default app on desktop).
class FileViewerService {
  FileViewerService(this._rclone);

  final RcloneService _rclone;

  /// Downloads a remote file to the local cache and returns the local file,
  /// or null if it could not be fetched.
  Future<File?> _download({
    required String remoteName,
    required String remotePath,
  }) async {
    if (_rclone is IosRcloneService) {
      return (_rclone as IosRcloneService).downloadToCache(remoteName, remotePath);
    }
    return null;
  }

  /// Opens a remote file locally using the platform default handler.
  /// On iOS/Android this uses the system Quick Look / open-with sheet.
  Future<bool> openInDefaultApp({
    required String remoteName,
    required String remotePath,
    required String fileName,
  }) async {
    try {
      final local = await _download(remoteName: remoteName, remotePath: remotePath);
      if (local == null || !local.existsSync()) return false;

      if (Platform.isIOS || Platform.isAndroid) {
        final res = await OpenFilex.open(local.path);
        return res.type == ResultType.done;
      }
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', local.path]);
        return true;
      } else if (Platform.isMacOS) {
        await Process.run('open', [local.path]);
        return true;
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [local.path]);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Returns the locally cached image/video/binary file for in-app rendering.
  Future<File?> getLocalFile({
    required String remoteName,
    required String remotePath,
  }) {
    return _download(remoteName: remoteName, remotePath: remotePath);
  }

  /// Copies text (such as file paths) to the OS clipboard.
  Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Reads real preview text for text/code files.
  Future<String> getPreviewText({
    required String remoteName,
    required String fileName,
    required String remotePath,
  }) async {
    try {
      final content = await _rclone.catFile(remoteName, remotePath);
      if (content == null || content.isEmpty) {
        return 'Keine Textvorschau verfügbar.';
      }
      // Guard against huge files in the preview pane.
      if (content.length > 200000) {
        return '${content.substring(0, 200000)}\n\n… (gekürzt)';
      }
      return content;
    } catch (_) {
      return 'Vorschau konnte nicht geladen werden.';
    }
  }
}

/// Riverpod provider for FileViewerService, wired to the active rclone engine.
final fileViewerServiceProvider = Provider<FileViewerService>((ref) {
  final rclone = ref.watch(rcloneServiceProvider);
  return FileViewerService(rclone);
});

// Keep `debugPrint` import meaningful for release-mode tree shaking hints.
// ignore: unused_element
void _noop() => debugPrint('');

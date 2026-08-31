import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'rclone_service.dart';

/// Eigener, sync-fähiger Papierkorb (nicht Apples „Zuletzt gelöscht", das Apps
/// nicht lesen können).
///
/// Löschungen gehen nie sofort hart — sie werden in einen Papierkorb gelegt
/// (lokal unter `<Spiegel>/.fibu/Trash`, remote unter `<Remote>/.fibu-trash`),
/// mit Zeitstempel versehen und nach Ablauf der [retention] endgültig
/// bereinigt (purge). So bleiben versehentliche Löschungen wiederherstellbar.
class TrashService {
  final RcloneService _rclone;
  final Duration retention;

  TrashService(this._rclone, {this.retention = const Duration(days: 30)});

  static const String localTrashSub = '.fibu/Trash';

  // -------------------------------------------------------------------------
  // Lokaler Papierkorb
  // -------------------------------------------------------------------------

  Directory _localTrashDir(String localRoot) =>
      Directory('$localRoot${Platform.pathSeparator}$localTrashSub');

  /// Verschiebt eine lokale Datei (relativ [rel], mit '/') in den lokalen
  /// Papierkorb. Gibt den Zielpfad zurück oder '' bei Fehler.
  Future<String> moveToLocalTrash(String localRoot, String rel) async {
    try {
      final trash = _localTrashDir(localRoot);
      if (!await trash.exists()) await trash.create(recursive: true);
      final src = File('$localRoot${Platform.pathSeparator}${rel.replaceAll('/', Platform.pathSeparator)}');
      if (!await src.exists()) return '';
      final name =
          '${DateTime.now().millisecondsSinceEpoch}_${rel.replaceAll(RegExp(r'[/\\]'), '__')}';
      final dest = File('${trash.path}${Platform.pathSeparator}$name');
      if (await dest.exists()) {
        await dest.delete();
      }
      await src.rename(dest.path);
      return dest.path;
    } catch (_) {
      return '';
    }
  }

  /// Listet die lokalen Papierkorb-Einträge mit ihrem Lösch-Zeitpunkt.
  Future<List<FileSystemEntity>> listLocalTrash(String localRoot) async {
    final trash = _localTrashDir(localRoot);
    if (!await trash.exists()) return [];
    return await trash.list(followLinks: false).toList();
  }

  // -------------------------------------------------------------------------
  // Remote-Papierkorb (außerhalb des Sync-Ordners, damit er nicht neu
  // heruntergeladen wird)
  // -------------------------------------------------------------------------

  /// Name des Papierkorb-Ordners auf dem Laufwerk. Öffentlich, damit der
  /// Verlauf einen stabilen Bezug auf eine verschobene Datei notieren kann.
  static const String remoteTrashName = '.fibu-trash';

  /// Papierkorb-Bezug einer Datei, wie ihn der Verlauf speichert:
  /// `<Papierkorb-Ordner>/<relativer Pfad>`.
  String remoteTrashRef(String remotePath, String rel) =>
      '${_remoteTrashPath(remotePath)}/$rel';

  String _remoteTrashPath(String remotePath) {
    final seg = remotePath.split('/').where((s) => s.isNotEmpty).toList();
    final parent = seg.length > 1 ? seg.sublist(0, seg.length - 1).join('/') : '';
    return parent.isEmpty ? remoteTrashName : '$parent/$remoteTrashName';
  }

  /// Legt eine entfernte Datei in den Remote-Papierkorb und löscht dann das
  /// Original (Download → Upload in Papierkorb → Delete), damit nichts verloren
  /// geht.
  Future<bool> moveToRemoteTrash({
    required String remoteName,
    required String remotePath,
    required String rel,
  }) async {
    try {
      final trashDir = _remoteTrashPath(remotePath);
      final tmp = await getTemporaryDirectory();
      final tmpFile = File('${tmp.path}${Platform.pathSeparator}fibu_trash_${DateTime.now().millisecondsSinceEpoch}_${rel.replaceAll(RegExp(r'[/\\]'), '__')}');
      final remoteSrc = remotePath.isEmpty ? rel : '$remotePath/$rel';
      final remoteDst = '$trashDir/$rel';

      // Bevorzugt Server-seitig kopieren (1 Call; Drive/MEGA/S3 u.a.
      // unterstützen das ohne Geräte-Bandbreite) — hält die „Aufräumen"-
      // Phase auch bei vielen Tombstones schnell. Fallback: Download+Upload.
      var copied = await _rclone.copyRemoteFile(remoteName, remoteSrc, remoteDst);
      if (!copied) {
        await _rclone.downloadFile(remoteName, remoteSrc, tmpFile.path);
        await _rclone.copyFileToRemote(tmpFile.path, remoteName, remoteDst);
      }
      await _rclone.deleteFile(remoteName, remoteSrc);
      if (await tmpFile.exists()) await tmpFile.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // Bereinigung (Purge) nach Ablauf der Aufbewahrungsfrist
  // -------------------------------------------------------------------------

  Future<int> purgeLocal(String localRoot) async {
    int removed = 0;
    final trash = _localTrashDir(localRoot);
    if (!await trash.exists()) return 0;
    final cutoff = DateTime.now().subtract(retention);
    await for (final e in trash.list(followLinks: false)) {
      if (e is File) {
        try {
          final mtime = await e.stat();
          if (mtime.modified.isBefore(cutoff)) {
            await e.delete();
            removed++;
          }
        } catch (_) {}
      }
    }
    return removed;
  }
}

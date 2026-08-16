import 'package:flutter_test/flutter_test.dart';
import 'package:fibu/core/services/rclone_provider_registry.dart';
import 'package:fibu/core/services/sync_manifest_service.dart';

void main() {
  group('RcloneProviderRegistry Tests', () {
    test('contains over 30 complete rclone provider descriptors', () {
      expect(RcloneProviderRegistry.providers.length, greaterThanOrEqualTo(30));
    });

    test('correctly queries popular providers', () {
      final popular = RcloneProviderRegistry.getPopular();
      expect(popular.isNotEmpty, isTrue);
      final names = popular.map((p) => p.name).toList();
      expect(names.contains('Google Drive'), isTrue);
      expect(names.contains('Dropbox'), isTrue);
      expect(names.contains('Microsoft OneDrive'), isTrue);
      expect(names.contains('Mega'), isTrue);
    });

    test('correctly queries by category', () {
      final s3List = RcloneProviderRegistry.getByCategory(ProviderCategory.s3Compatible);
      expect(s3List.isNotEmpty, isTrue);
      expect(s3List.any((p) => p.id == 's3'), isTrue);

      final protoList = RcloneProviderRegistry.getByCategory(ProviderCategory.protocols);
      expect(protoList.any((p) => p.id == 'sftp'), isTrue);
      expect(protoList.any((p) => p.id == 'webdav'), isTrue);
    });

    test('findById performs exact and fallback lookup', () {
      final drive = RcloneProviderRegistry.findById('drive');
      expect(drive, isNotNull);
      expect(drive!.name, 'Google Drive');

      final sftp = RcloneProviderRegistry.findById('SFTP (SSH File Transfer)');
      expect(sftp, isNotNull);
      expect(sftp!.id, 'sftp');

      final mega = RcloneProviderRegistry.findById('mega');
      expect(mega, isNotNull);
      expect(mega!.authType, AuthType.credentials);
    });
  });

  group('SyncManifest Serialization Tests', () {
    test('SyncManifest toJson and fromJson round-trip correctly', () {
      final now = DateTime.now().toIso8601String();
      final manifest = SyncManifest(
        version: '1.0.0',
        taskId: 'test_task_123',
        taskName: 'Photos',
        remoteName: 'myDrive',
        remotePath: 'fibu-backup/Photos',
        lastSyncIso: now,
        totalFiles: 2,
        totalBytes: 2048,
        entries: const [
          ManifestEntry(
            relativePath: 'Photos/Camera Roll/IMG_001.JPG',
            sizeBytes: 1024,
            modTimeIso: '2026-08-16T12:00:00Z',
            hash: 'hash1',
            status: 'synced',
          ),
          ManifestEntry(
            relativePath: 'Photos/WhatsApp/IMG_002.PNG',
            sizeBytes: 1024,
            modTimeIso: '2026-08-16T12:05:00Z',
            hash: 'hash2',
            status: 'synced',
          ),
        ],
      );

      final json = manifest.toJson();
      expect(json['taskId'], 'test_task_123');
      expect(json['totalFiles'], 2);
      expect(json['totalBytes'], 2048);

      final reconstructed = SyncManifest.fromJson(json);
      expect(reconstructed.taskId, 'test_task_123');
      expect(reconstructed.entries.length, 2);
      expect(reconstructed.entries[0].relativePath, 'Photos/Camera Roll/IMG_001.JPG');
      expect(reconstructed.entries[1].relativePath, 'Photos/WhatsApp/IMG_002.PNG');
    });
  });
}

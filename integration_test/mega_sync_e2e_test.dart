import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fibu/core/services/rclone_service.dart';
import 'package:fibu/core/services/rclone_service_impl.dart';
import 'package:fibu/core/services/sync_config_service.dart';
import 'package:fibu/features/tasks/presentation/tasks_controller.dart';

void main() {
  group('Mega Cloud E2E Integration & 2-Way Mirroring Tests', () {
    late WindowsRcloneService rcloneService;
    late SyncConfigService syncConfigService;
    late Directory tempLocalDir;
    late Directory tempRestoreDir;
    const String remoteName = 'mega_test';
    const String testRemoteFolder = 'fibu_e2e_test';

    bool isMegaAvailable = false;

    setUpAll(() async {
      const rclonePath = 'd:\\code gemini\\fibu win\\rclone.exe';
      expect(File(rclonePath).existsSync(), isTrue, reason: 'rclone.exe must exist in workspace');
      rcloneService = WindowsRcloneService(customExecutablePath: rclonePath);
      syncConfigService = SyncConfigService(rcloneService);

      final remotes = await rcloneService.listRemotes();
      if (remotes.contains(remoteName)) {
        try {
          await rcloneService.listFiles(remoteName, '');
          isMegaAvailable = true;
        } catch (_) {
          isMegaAvailable = false;
        }
      }

      tempLocalDir = await Directory.systemTemp.createTemp('fibu_e2e_local_');
      tempRestoreDir = await Directory.systemTemp.createTemp('fibu_e2e_restore_');
    });

    tearDownAll(() async {
      // Clean up remote test folder on Mega
      try {
        await Process.run('d:\\code gemini\\fibu win\\rclone.exe', ['purge', '$remoteName:$testRemoteFolder']);
      } catch (_) {}

      // Clean up local temp folders
      if (tempLocalDir.existsSync()) {
        tempLocalDir.deleteSync(recursive: true);
      }
      if (tempRestoreDir.existsSync()) {
        tempRestoreDir.deleteSync(recursive: true);
      }
    });

    test('1. Setup local test media files (photos, videos, docs)', () async {
      final photo1 = File('${tempLocalDir.path}/photo1.jpg');
      await photo1.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46]);

      final photo2 = File('${tempLocalDir.path}/photo2.png');
      await photo2.writeAsBytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

      final video1 = File('${tempLocalDir.path}/video1.mp4');
      await video1.writeAsBytes([0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x6D, 0x70, 0x34, 0x32]);

      final doc1 = File('${tempLocalDir.path}/document.txt');
      await doc1.writeAsString('Fibu E2E Cloud Backup Verification Test Document');

      expect(photo1.existsSync(), isTrue);
      expect(photo2.existsSync(), isTrue);
      expect(video1.existsSync(), isTrue);
      expect(doc1.existsSync(), isTrue);
    });

    test('2. Multi-Option Task: Photos-only Filter Sync to Mega Cloud', () async {
      if (!isMegaAvailable) return;
      final jobId = await rcloneService.startBackupJob(
        localPath: tempLocalDir.path,
        remoteName: remoteName,
        remotePath: testRemoteFolder,
        options: const SyncOptions(
          isEchoMode: false,
          includeFilters: ['*.jpg', '*.png'],
        ),
      );

      expect(jobId, startsWith('job_'));

      // Wait for completion event
      await rcloneService.watchJobStatus().firstWhere(
        (event) => event.jobId == jobId && (event.status == RcloneJobStatus.completed || event.status == RcloneJobStatus.failed),
      );

      final remoteFiles = await rcloneService.listFiles(remoteName, testRemoteFolder);
      final remoteFileNames = remoteFiles.map((f) => f.name).toList();

      expect(remoteFileNames, contains('photo1.jpg'));
      expect(remoteFileNames, contains('photo2.png'));
      expect(remoteFileNames, isNot(contains('video1.mp4')), reason: 'video1.mp4 must be excluded by photo filter');
      expect(remoteFileNames, isNot(contains('document.txt')), reason: 'document.txt must be excluded by photo filter');
    });

    test('3. Multi-Option Task: Incremental Sync for All Media Files', () async {
      if (!isMegaAvailable) return;
      final jobId = await rcloneService.startBackupJob(
        localPath: tempLocalDir.path,
        remoteName: remoteName,
        remotePath: testRemoteFolder,
        options: const SyncOptions(
          isEchoMode: false,
          includeFilters: [],
        ),
      );

      await rcloneService.watchJobStatus().firstWhere(
        (event) => event.jobId == jobId && (event.status == RcloneJobStatus.completed || event.status == RcloneJobStatus.failed),
      );

      final remoteFiles = await rcloneService.listFiles(remoteName, testRemoteFolder);
      final remoteFileNames = remoteFiles.map((f) => f.name).toList();

      expect(remoteFileNames, contains('photo1.jpg'));
      expect(remoteFileNames, contains('photo2.png'));
      expect(remoteFileNames, contains('video1.mp4'));
      expect(remoteFileNames, contains('document.txt'));
    });

    test('4. Mirror Mode (2-Way Echo): Local deletion mirrored to Mega Remote', () async {
      if (!isMegaAvailable) return;
      // Delete photo2.png locally
      final photo2 = File('${tempLocalDir.path}/photo2.png');
      expect(photo2.existsSync(), isTrue);
      photo2.deleteSync();
      expect(photo2.existsSync(), isFalse);

      // Execute Echo / Mirror sync
      final jobId = await rcloneService.startBackupJob(
        localPath: tempLocalDir.path,
        remoteName: remoteName,
        remotePath: testRemoteFolder,
        options: const SyncOptions(
          isEchoMode: true, // Mirror mode
        ),
      );

      await rcloneService.watchJobStatus().firstWhere(
        (event) => event.jobId == jobId && (event.status == RcloneJobStatus.completed || event.status == RcloneJobStatus.failed),
      );

      final remoteFiles = await rcloneService.listFiles(remoteName, testRemoteFolder);
      final remoteFileNames = remoteFiles.map((f) => f.name).toList();

      expect(remoteFileNames, contains('photo1.jpg'));
      expect(remoteFileNames, isNot(contains('photo2.png')), reason: 'photo2.png was deleted locally and must be deleted on Mega remote in Echo mode');
      expect(remoteFileNames, contains('video1.mp4'));
      expect(remoteFileNames, contains('document.txt'));
    });

    test('5. Remote Config writing & Discovery after App Restart', () async {
      if (!isMegaAvailable) return;
      final sampleTask = BackupTask(
        id: 'task_mega_e2e',
        name: 'Mega E2E Mirror Backup',
        sourcePath: tempLocalDir.path,
        targetRemotes: [remoteName],
        schedule: 'Daily at 14:00',
        scheduleDay: 'Daily',
        scheduleTime: '14:00',
        isActive: true,
        syncMode: SyncMode.mirror,
        distributionStrategy: DistributionStrategy.mirrorAll,
        targetFolderMode: TargetFolderMode.custom,
        targetFolderName: testRemoteFolder,
      );

      // Write config to Mega remote
      await syncConfigService.writeConfigToRemote(remoteName, [sampleTask], testRemoteFolder);

      // Verify remote config exists on Mega
      final hasConfig = await syncConfigService.checkRemoteForConfig(remoteName, testRemoteFolder);
      expect(hasConfig, isTrue, reason: 'Remote config must be found on Mega');

      // Read and parse remote config
      final remoteConfig = await syncConfigService.readRemoteConfig(remoteName, testRemoteFolder);
      expect(remoteConfig, isNotNull);
      expect(remoteConfig!.tasks, isNotEmpty);
      expect(remoteConfig.tasks.first.name, equals('Mega E2E Mirror Backup'));
      expect(remoteConfig.tasks.first.syncMode, equals('mirror'));
      expect(remoteConfig.tasks.first.targetFolder, equals(testRemoteFolder));
    });

    test('6. Remote-to-Local Restore: Downloading files from Mega to new folder', () async {
      if (!isMegaAvailable) return;
      final remoteConfig = await syncConfigService.readRemoteConfig(remoteName, testRemoteFolder);
      expect(remoteConfig, isNotNull);

      final importedTasks = syncConfigService.convertConfigToTasks(
        remoteConfig!,
        remoteName,
        tempRestoreDir.path,
      );
      expect(importedTasks, isNotEmpty);
      expect(importedTasks.first.sourcePath, equals(tempRestoreDir.path));

      // Download remote files to fresh local folder
      await syncConfigService.downloadRemoteFiles(
        remoteName,
        testRemoteFolder,
        tempRestoreDir.path,
      );

      final restoredPhoto1 = File('${tempRestoreDir.path}/photo1.jpg');
      final restoredVideo1 = File('${tempRestoreDir.path}/video1.mp4');
      final restoredDoc1 = File('${tempRestoreDir.path}/document.txt');
      final deletedPhoto2 = File('${tempRestoreDir.path}/photo2.png');

      expect(restoredPhoto1.existsSync(), isTrue, reason: 'photo1.jpg must be restored from Mega');
      expect(restoredVideo1.existsSync(), isTrue, reason: 'video1.mp4 must be restored from Mega');
      expect(restoredDoc1.existsSync(), isTrue, reason: 'document.txt must be restored from Mega');
      expect(deletedPhoto2.existsSync(), isFalse, reason: 'photo2.png was deleted in Echo mode and must not exist');
    });
  });
}

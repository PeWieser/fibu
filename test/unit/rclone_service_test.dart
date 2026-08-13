import 'package:flutter_test/flutter_test.dart';
import 'package:fibu/core/services/rclone_service.dart';
import 'package:fibu/core/services/mock_rclone_service.dart';

void main() {
  group('MockRcloneService Tests', () {
    late MockRcloneService service;

    setUp(() {
      service = MockRcloneService();
    });

    tearDown(() {
      service.dispose();
    });

    test('listRemotes returns default remotes list', () async {
      final remotes = await service.listRemotes();
      expect(remotes, contains('Google Drive (Mock)'));
      expect(remotes, contains('OneDrive (Mock)'));
      expect(remotes, contains('Dropbox (Mock)'));
      expect(remotes.length, equals(3));
    });

    test('addRemote appends new remote config successfully', () async {
      await service.addRemote(name: 'Box (Mock)', type: 'box', config: {});
      final remotes = await service.listRemotes();
      expect(remotes, contains('Box (Mock)'));
      expect(remotes.length, equals(4));
    });

    test('addRemote throws exception if remote already exists', () async {
      expect(
        () => service.addRemote(name: 'OneDrive (Mock)', type: 'onedrive', config: {}),
        throwsA(isA<Exception>()),
      );
    });

    test('removeRemote deletes configuration correctly', () async {
      await service.removeRemote('Dropbox (Mock)');
      final remotes = await service.listRemotes();
      expect(remotes, isNot(contains('Dropbox (Mock)')));
      expect(remotes.length, equals(2));
    });

    test('removeRemote throws exception if remote not found', () async {
      expect(
        () => service.removeRemote('UnknownRemote'),
        throwsA(isA<Exception>()),
      );
    });

    test('getQuota returns correct information based on provider name', () async {
      final googleQuota = await service.getQuota('Google Drive (Mock)');
      expect(googleQuota.totalBytes, equals(15 * 1024 * 1024 * 1024));
      expect(googleQuota.usedBytes, equals(9 * 1024 * 1024 * 1024));
      expect(googleQuota.usedPercentage, equals(60.0));

      final otherQuota = await service.getQuota('Dropbox (Mock)');
      expect(otherQuota.totalBytes, equals(2 * 1024 * 1024 * 1024));
      expect(otherQuota.usedBytes, equals(512 * 1024 * 1024));
      expect(otherQuota.usedPercentage, equals(25.0));
    });

    test('Job progress simulation cycles through pending -> syncing -> completed', () async {
      final statusEvents = <RcloneJobStatus>[];
      final statusSub = service.watchJobStatus().listen((event) {
        statusEvents.add(event.status);
      });

      final jobId = await service.startBackupJob(
        localPath: 'local',
        remoteName: 'Google Drive (Mock)',
        remotePath: 'remote',
        options: const SyncOptions(),
      );

      expect(jobId, startsWith('job_'));

      // Wait for progress simulation to finish (40 MB total / 4 MB steps * 150ms per step = ~1.5 seconds)
      // Allow slightly extra time for safety.
      await Future.delayed(const Duration(milliseconds: 2000));

      expect(statusEvents, contains(RcloneJobStatus.pending));
      expect(statusEvents, contains(RcloneJobStatus.syncing));
      expect(statusEvents, contains(RcloneJobStatus.completed));

      await statusSub.cancel();
    });

    test('Job progress stream emits percentage values up to 100%', () async {
      final jobId = await service.startBackupJob(
        localPath: 'local',
        remoteName: 'Google Drive (Mock)',
        remotePath: 'remote',
        options: const SyncOptions(),
      );

      final percentages = <double>[];
      final progressSub = service.watchJobProgress(jobId).listen((event) {
        percentages.add(event.percentage);
      });

      await Future.delayed(const Duration(milliseconds: 2000));

      expect(percentages, isNotEmpty);
      expect(percentages.last, equals(100.0));
      expect(percentages.first, lessThan(100.0));

      await progressSub.cancel();
    });

    test('Job cancel terminates simulation and emits cancelled status', () async {
      final statusEvents = <RcloneJobStatus>[];
      final statusSub = service.watchJobStatus().listen((event) {
        statusEvents.add(event.status);
      });

      final jobId = await service.startBackupJob(
        localPath: 'local',
        remoteName: 'Google Drive (Mock)',
        remotePath: 'remote',
        options: const SyncOptions(),
      );

      // Let it run for 1 tick, then cancel
      await Future.delayed(const Duration(milliseconds: 200));
      await service.cancelBackupJob(jobId);

      // Wait for any remaining asynchronous callbacks
      await Future.delayed(const Duration(milliseconds: 100));

      expect(statusEvents, contains(RcloneJobStatus.cancelled));
      expect(statusEvents, isNot(contains(RcloneJobStatus.completed)));

      await statusSub.cancel();
    });
  });
}

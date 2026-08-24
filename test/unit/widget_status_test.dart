import 'package:flutter_test/flutter_test.dart';
import 'package:fibu/core/services/widget_status_service.dart';

void main() {
  group('WidgetStatusData needsSync semantics', () {
    test('fromJson/toJson round-trip preserves needsSync', () {
      const data = WidgetStatusData(
        lastSyncIso: '2026-08-24T10:00:00Z',
        needsSync: true,
        lastError: '',
        activeTaskCount: 1,
        tasks: [
          WidgetTaskState(
            taskId: 't1',
            name: 'Photos',
            status: 'pending',
            lastSyncIso: '2026-08-23T10:00:00Z',
            mediaCountAtLastSync: 12,
          ),
        ],
      );
      final json = data.toJson();
      expect(json['needsSync'], isTrue);
      final back = WidgetStatusData.fromJson(json);
      expect(back.needsSync, isTrue);
      expect(back.tasks.single.status, 'pending');
    });

    test('pending and never statuses imply sync needed', () {
      // Spiegel der Logik in recomputeAndPush / reportTaskRun:
      // Jeder Status außer „ok“ hält needsSync auf true.
      bool stillNeeds(List<WidgetTaskState> tasks) => tasks.any((t) =>
          t.status == 'never' ||
          t.status == 'pending' ||
          t.status == 'error');

      expect(
        stillNeeds(const [
          WidgetTaskState(
            taskId: 'a',
            name: 'A',
            status: 'ok',
            lastSyncIso: 'x',
            mediaCountAtLastSync: 5,
          ),
        ]),
        isFalse,
      );
      expect(
        stillNeeds(const [
          WidgetTaskState(
            taskId: 'a',
            name: 'A',
            status: 'pending',
            lastSyncIso: 'x',
            mediaCountAtLastSync: 5,
          ),
        ]),
        isTrue,
      );
      expect(
        stillNeeds(const [
          WidgetTaskState(
            taskId: 'a',
            name: 'A',
            status: 'never',
            lastSyncIso: '',
            mediaCountAtLastSync: 0,
          ),
        ]),
        isTrue,
      );
      expect(
        stillNeeds(const [
          WidgetTaskState(
            taskId: 'a',
            name: 'A',
            status: 'ok',
            lastSyncIso: 'x',
            mediaCountAtLastSync: 5,
          ),
          WidgetTaskState(
            taskId: 'b',
            name: 'B',
            status: 'error',
            lastSyncIso: 'y',
            mediaCountAtLastSync: 3,
          ),
        ]),
        isTrue,
      );
    });
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fibu/core/services/change_journal_service.dart';

void main() {
  late Directory tmp;
  late ChangeJournal journal;

  // Feste Zeitpunkte, damit die Tests nicht von der Systemuhr abhängen.
  final t1 = DateTime.utc(2026, 9, 20, 10);
  final t2 = DateTime.utc(2026, 9, 23, 14);
  final t3 = DateTime.utc(2026, 9, 25, 9);
  final t4 = DateTime.utc(2026, 9, 28, 18);

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('fibu_journal_test_');
    journal = ChangeJournal(tmp, retention: const Duration(days: 90));
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('round-trip: geschriebene Einträge kommen unverändert zurück', () async {
    journal.record(ChangeKind.added, 'Photos/A/IMG_1.HEIC',
        sizeBytes: 1234, modifiedMs: 999, at: t1);
    journal.record(ChangeKind.deleted, 'Photos/A/IMG_2.HEIC',
        sizeBytes: 4321, modifiedMs: 888, trashRef: '.fibu-trash/x_IMG_2.HEIC',
        at: t2);
    await journal.flush();

    final all = await journal.readAll();
    expect(all, hasLength(2));
    expect(all[0].kind, ChangeKind.added);
    expect(all[0].rel, 'Photos/A/IMG_1.HEIC');
    expect(all[0].sizeBytes, 1234);
    expect(all[0].modifiedMs, 999);
    expect(all[0].trashRef, isNull);
    expect(all[1].kind, ChangeKind.deleted);
    expect(all[1].trashRef, '.fibu-trash/x_IMG_2.HEIC');
  });

  test('flush ohne Einträge legt keine Datei an', () async {
    await journal.flush();
    expect(await File('${tmp.path}/${ChangeJournal.fileName}').exists(), isFalse);
  });

  test('stateAt: Zwischendurch gelöschte Datei fehlt am Stichtag', () async {
    // Am 20.09. gelöscht, am 25.09. neu angelegt → am 23.09. NICHT vorhanden.
    journal.record(ChangeKind.added, 'IMG_X.JPG', at: t1);
    journal.record(ChangeKind.deleted, 'IMG_X.JPG', at: t1.add(const Duration(hours: 1)));
    journal.record(ChangeKind.added, 'IMG_X.JPG', at: t3);
    await journal.flush();

    final before = await journal.stateAt(t2);
    expect(before.present.containsKey('IMG_X.JPG'), isFalse,
        reason: 'Die Datei war am 23.09. gelöscht und erst am 25.09. wieder da');
    expect(before.deleted.containsKey('IMG_X.JPG'), isTrue);

    final after = await journal.stateAt(t3);
    expect(after.present.containsKey('IMG_X.JPG'), isTrue);
    expect(after.deleted.containsKey('IMG_X.JPG'), isFalse,
        reason: 'Nach dem erneuten Hinzufügen ist sie kein Löschfall mehr');
  });

  test('stateAt: spätere Änderungen sind am Stichtag noch nicht sichtbar', () async {
    journal.record(ChangeKind.added, 'IMG_1.HEIC', sizeBytes: 100, at: t1);
    journal.record(ChangeKind.modified, 'IMG_1.HEIC', sizeBytes: 200, at: t4);
    await journal.flush();

    final snap = await journal.stateAt(t2);
    expect(snap.present['IMG_1.HEIC']?.sizeBytes, 100,
        reason: 'Am 23.09. gab es nur die Fassung vom 20.09.');
    expect(snap.present['IMG_1.HEIC']?.lastKind, ChangeKind.added);

    final later = await journal.stateAt(t4);
    expect(later.present['IMG_1.HEIC']?.sizeBytes, 200);
    expect(later.present['IMG_1.HEIC']?.lastKind, ChangeKind.modified);
  });

  test('stateAt: Löschungen mit Papierkorb-Bezug bleiben auffindbar', () async {
    journal.record(ChangeKind.added, 'IMG_9.JPG', sizeBytes: 500, at: t1);
    journal.record(ChangeKind.deleted, 'IMG_9.JPG',
        sizeBytes: 500, trashRef: '.fibu-trash/1758_IMG_9.JPG', at: t2);
    await journal.flush();

    final snap = await journal.stateAt(t3);
    expect(snap.present, isEmpty);
    expect(snap.deleted['IMG_9.JPG']?.trashRef, '.fibu-trash/1758_IMG_9.JPG',
        reason: 'Ohne diesen Bezug ist keine Wiederherstellung möglich');
  });

  test('stateAt ist unempfindlich gegen eine verstellte Geräteuhr', () async {
    // Absichtlich durcheinander geschrieben; readAll() sortiert aufsteigend.
    journal.record(ChangeKind.modified, 'IMG_1.HEIC', sizeBytes: 200, at: t3);
    journal.record(ChangeKind.added, 'IMG_1.HEIC', sizeBytes: 100, at: t1);
    await journal.flush();

    final snap = await journal.stateAt(t4);
    expect(snap.present['IMG_1.HEIC']?.sizeBytes, 200,
        reason: 'Die jüngere Änderung muss gewinnen, egal in welcher '
          'Reihenfolge die Zeilen auf der Platte stehen');
  });

  test('changesBetween liefert nur das halboffene Intervall', () async {
    journal.record(ChangeKind.added, 'a', at: t1);
    journal.record(ChangeKind.added, 'b', at: t2);
    journal.record(ChangeKind.added, 'c', at: t3);
    await journal.flush();

    final window = await journal.changesBetween(t2, t3);
    expect(window.map((e) => e.rel), ['b', 'c']);
  });

  test('days zählt je Änderungsart und sortiert absteigend', () async {
    journal.record(ChangeKind.added, 'a', at: t1);
    journal.record(ChangeKind.added, 'b', at: t1);
    journal.record(ChangeKind.deleted, 'a', at: t2);
    journal.record(ChangeKind.restored, 'a', at: t3);
    await journal.flush();

    final days = await journal.days();
    expect(days, hasLength(3));
    expect(days.first.date, DateTime(2026, 9, 25));
    expect(days.first.restored, 1);
    final day20 = days.firstWhere((d) => d.date == DateTime(2026, 9, 20));
    expect(day20.added, 2);
    expect(day20.total, 2);
  });

  test('latestPerPath liefert je Pfad den letzten Eintrag', () async {
    journal.record(ChangeKind.added, 'a', at: t1);
    journal.record(ChangeKind.deleted, 'a', trashRef: 't1', at: t2);
    journal.record(ChangeKind.added, 'b', at: t3);
    await journal.flush();

    final latest = await journal.latestPerPath();
    expect(latest['a']?.kind, ChangeKind.deleted);
    expect(latest['a']?.trashRef, 't1');
    expect(latest['b']?.kind, ChangeKind.added);
  });

  test('compact fasst Presence-Folgen zusammen und behält del-Einträge', () async {
    journal.record(ChangeKind.added, 'a', sizeBytes: 1, at: t1);
    journal.record(ChangeKind.modified, 'a', sizeBytes: 2, at: t2);
    journal.record(ChangeKind.modified, 'a', sizeBytes: 3, at: t3);
    journal.record(ChangeKind.deleted, 'a', trashRef: 'trash-a', at: t3);
    journal.record(ChangeKind.added, 'a', sizeBytes: 4, at: t4);
    journal.record(ChangeKind.added, 'b', sizeBytes: 9, at: t4);
    await journal.flush();

    expect(await journal.readAll(), hasLength(6));
    final removed = await journal.compact();
    expect(removed, 2, reason: 'zwei überflüssige Presence-Zeilen für „a"');

    final after = await journal.readAll();
    expect(after, hasLength(4));
    // Die verdichtete Folge darf den Zustand nicht verändern.
    final snap = await journal.stateAt(DateTime.utc(2026, 12, 31));
    expect(snap.present['a']?.sizeBytes, 4);
    expect(snap.present['b']?.sizeBytes, 9);
    // Der Lösch-Eintrag mit Papierkorb-Bezug muss erhalten bleiben.
    expect(after.where((e) => e.kind == ChangeKind.deleted), hasLength(1));
    expect(after.firstWhere((e) => e.kind == ChangeKind.deleted).trashRef,
        'trash-a');
  });

  test('compact verwirft Einträge jenseits der Aufbewahrung', () async {
    final alt = DateTime.now().toUtc().subtract(const Duration(days: 200));
    journal = ChangeJournal(tmp, retention: const Duration(days: 90));
    journal.record(ChangeKind.added, 'uralt', at: alt);
    journal.record(ChangeKind.added, 'neu', at: DateTime.now().toUtc());
    await journal.flush();

    final removed = await journal.compact();
    expect(removed, 1);
    final rels = (await journal.readAll()).map((e) => e.rel).toList();
    expect(rels, ['neu']);
  });

  test('eine kaputte Zeile verwirft sich selbst, nicht das ganze Journal', () async {
    final f = File('${tmp.path}/${ChangeJournal.fileName}');
    await f.writeAsString(
      '{"v":1,"at":"2026-09-20T10:00:00.000Z","k":"add","rel":"gut","size":1,"mt":1}\n'
      'das ist kein json\n'
      '{"v":1,"at":"kaputt","k":"add","rel":"auch-kaputt"}\n'
      '{"v":1,"at":"2026-09-21T10:00:00.000Z","k":"del","rel":"weg","size":2,"mt":2}\n',
    );
    final all = await journal.readAll();
    expect(all.map((e) => e.rel), ['gut', 'weg']);
  });

  test('leerer Pfad wird nicht journalisiert', () async {
    journal.record(ChangeKind.added, '', at: t1);
    await journal.flush();
    expect(await journal.readAll(), isEmpty);
  });
}

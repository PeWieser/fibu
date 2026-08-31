import 'dart:convert';
import 'dart:io';

import 'app_log_service.dart';

/// Art einer beobachteten Änderung.
enum ChangeKind {
  added,
  modified,
  deleted,

  /// Eine Datei wurde aus einem früheren Stand zurückgeholt.
  restored;

  String get wire {
    switch (this) {
      case ChangeKind.added:
        return 'add';
      case ChangeKind.modified:
        return 'mod';
      case ChangeKind.deleted:
        return 'del';
      case ChangeKind.restored:
        return 'restore';
    }
  }

  static ChangeKind? fromWire(String? value) {
    switch (value) {
      case 'add':
        return ChangeKind.added;
      case 'mod':
        return ChangeKind.modified;
      case 'del':
        return ChangeKind.deleted;
      case 'restore':
        return ChangeKind.restored;
      default:
        return null;
    }
  }

  /// `add`, `mod` und `restore` beschreiben alle „diese Datei ist da".
  bool get isPresence => this != ChangeKind.deleted;
}

/// Eine Zeile im Verlauf: eine beobachtete Änderung an genau einem Pfad.
class JournalEntry {
  final int version;
  final DateTime at;
  final ChangeKind kind;

  /// Relativer Pfad im Spiegel, z. B. `Photos/Camera Roll/IMG_0001.HEIC`.
  final String rel;

  final int sizeBytes;
  final int modifiedMs;

  /// Nur bei [ChangeKind.deleted]: Ziel im Fibu-Papierkorb, falls die Datei
  /// dorthin verschoben wurde. Ohne Wert ist die Datei endgültig weg.
  final String? trashRef;

  const JournalEntry({
    this.version = 1,
    required this.at,
    required this.kind,
    required this.rel,
    this.sizeBytes = 0,
    this.modifiedMs = 0,
    this.trashRef,
  });

  Map<String, dynamic> toJson() => {
        'v': version,
        'at': at.toUtc().toIso8601String(),
        'k': kind.wire,
        'rel': rel,
        'size': sizeBytes,
        'mt': modifiedMs,
        if (trashRef != null && trashRef!.isNotEmpty) 'trash': trashRef,
      };

  static JournalEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final rel = m['rel'] as String? ?? '';
    final kind = ChangeKind.fromWire(m['k'] as String?);
    final at = DateTime.tryParse(m['at'] as String? ?? '');
    if (rel.isEmpty || kind == null || at == null) return null;
    return JournalEntry(
      version: (m['v'] as num?)?.toInt() ?? 1,
      at: at.toUtc(),
      kind: kind,
      rel: rel,
      sizeBytes: (m['size'] as num?)?.toInt() ?? 0,
      modifiedMs: (m['mt'] as num?)?.toInt() ?? 0,
      trashRef: m['trash'] as String?,
    );
  }
}

/// Zustand eines Pfads zu einem bestimmten Zeitpunkt.
class FileStateAt {
  final String rel;
  final int sizeBytes;
  final int modifiedMs;

  /// Zeitpunkt der letzten Änderung an diesem Pfad vor dem Stichtag.
  final DateTime lastChange;
  final ChangeKind lastKind;

  const FileStateAt({
    required this.rel,
    required this.sizeBytes,
    required this.modifiedMs,
    required this.lastChange,
    required this.lastKind,
  });
}

/// Ergebnis einer Zustandsrekonstruktion zu einem Stichtag.
class SnapshotAt {
  final DateTime at;

  /// Pfade, die zum Stichtag vorhanden waren.
  final Map<String, FileStateAt> present;

  /// Pfade, die zum Stichtag oder davor gelöscht wurden — mit dem letzten
  /// Lösch-Eintrag, damit der Papierkorb-Bezug verfügbar bleibt.
  final Map<String, JournalEntry> deleted;

  const SnapshotAt({
    required this.at,
    required this.present,
    required this.deleted,
  });
}

/// Fortschreibbares Änderungs-Journal für einen Sync-Scope.
///
/// **Format:** append-only JSONL, eine JSON-Zeile pro Änderung. Bewusst keine
/// SQLite — `sqflite` steht auf Apples Liste der SDKs, die ein eigenes Privacy
/// Manifest und eine Signatur brauchen. Anhängen ist für ein inkrementelles
/// Journal ohnehin die natürlichere Operation.
///
/// **Ort:** `Library/Application Support/fibu_state/<scope>/`, also neben
/// `mirror_state.json`. Privater Ordner, nicht über die Dateien-App sichtbar —
/// das Journal enthält Dateinamen und Albennamen (Art. 4 Nr. 1 DSGVO).
///
/// **Ehrliche Grenze:** Das Journal weiß, *was* es zu einem Zeitpunkt gab.
/// Ob die Bytes noch da sind, entscheidet die Cloud bzw. der Papierkorb.
class ChangeJournal {
  ChangeJournal(this.scopeRoot, {this.retention = const Duration(days: 90)});

  final Directory scopeRoot;

  /// Wie lange Einträge höchstens aufbewahrt werden.
  final Duration retention;

  static const String fileName = 'change_journal.jsonl';

  /// Puffer für einen laufenden Sync — geschrieben wird einmal am Ende,
  /// nicht pro Datei.
  final List<JournalEntry> _pending = [];

  File get _file => File('${scopeRoot.path}/$fileName');

  /// Merkt eine Änderung vor; auf Platte geht sie erst mit [flush].
  void record(
    ChangeKind kind,
    String rel, {
    int sizeBytes = 0,
    int modifiedMs = 0,
    String? trashRef,
    DateTime? at,
  }) {
    if (rel.isEmpty) return;
    _pending.add(JournalEntry(
      at: (at ?? DateTime.now()).toUtc(),
      kind: kind,
      rel: rel,
      sizeBytes: sizeBytes,
      modifiedMs: modifiedMs,
      trashRef: trashRef,
    ));
  }

  /// Schreibt den Puffer an. Ein Journal-Fehler darf nie einen Sync kippen —
  /// der Verlauf ist ein Zusatz, die Sicherung ist die Hauptsache.
  Future<void> flush() async {
    if (_pending.isEmpty) return;
    final batch = List<JournalEntry>.of(_pending);
    _pending.clear();
    try {
      if (!await scopeRoot.exists()) await scopeRoot.create(recursive: true);
      final sink = _file.openWrite(mode: FileMode.append);
      try {
        for (final e in batch) {
          sink.writeln(jsonEncode(e.toJson()));
        }
      } finally {
        await sink.close();
      }
      AppLog.info('journal', '${batch.length} Verlaufseinträge geschrieben');
    } catch (e) {
      AppLog.warn('journal', 'Verlauf konnte nicht geschrieben werden: $e');
    }
  }

  /// Liest alle Einträge, aufsteigend nach Zeitpunkt sortiert.
  ///
  /// Sortiert statt „append-Reihenfolge vertrauen": Die Geräteuhr kann
  /// verstellt werden (siehe `docs/STRESSTEST_DAU.md`, K4).
  Future<List<JournalEntry>> readAll() async {
    final f = _file;
    if (!await f.exists()) return const [];
    final out = <JournalEntry>[];
    try {
      final lines = await f.readAsLines();
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        try {
          final entry = JournalEntry.fromJson(jsonDecode(trimmed));
          if (entry != null) out.add(entry);
        } catch (_) {
          // Eine kaputte Zeile verwirft sich selbst, nicht das ganze Journal.
        }
      }
    } catch (e) {
      AppLog.warn('journal', 'Verlauf nicht lesbar: $e');
      return const [];
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }

  /// Rekonstruiert den Stand zum Zeitpunkt [at].
  ///
  /// `add`/`mod`/`restore` setzen den Pfad, `del` entfernt ihn. Damit ist
  /// automatisch korrekt, dass eine zwischendurch gelöschte und später neu
  /// angelegte Datei am Stichtag nicht existierte.
  Future<SnapshotAt> stateAt(DateTime at) async {
    final limit = at.toUtc();
    final present = <String, FileStateAt>{};
    final deleted = <String, JournalEntry>{};
    for (final e in await readAll()) {
      if (e.at.isAfter(limit)) continue;
      if (e.kind.isPresence) {
        present[e.rel] = FileStateAt(
          rel: e.rel,
          sizeBytes: e.sizeBytes,
          modifiedMs: e.modifiedMs,
          lastChange: e.at,
          lastKind: e.kind,
        );
        deleted.remove(e.rel);
      } else {
        present.remove(e.rel);
        deleted[e.rel] = e;
      }
    }
    return SnapshotAt(at: limit, present: present, deleted: deleted);
  }

  /// Änderungen im halboffenen Intervall `[from, to]`.
  Future<List<JournalEntry>> changesBetween(DateTime from, DateTime to) async {
    final lo = from.toUtc();
    final hi = to.toUtc();
    final all = await readAll();
    return all
        .where((e) => !e.at.isBefore(lo) && !e.at.isAfter(hi))
        .toList(growable: false);
  }

  /// Alle Tage, an denen etwas passiert ist, absteigend — mit Zählern.
  /// Grundlage für die Verlaufs-Ansicht.
  Future<List<JournalDay>> days() async {
    final byDay = <String, JournalDay>{};
    for (final e in await readAll()) {
      final key = '${e.at.year.toString().padLeft(4, '0')}-'
          '${e.at.month.toString().padLeft(2, '0')}-'
          '${e.at.day.toString().padLeft(2, '0')}';
      final day = byDay.putIfAbsent(
          key, () => JournalDay(date: DateTime(e.at.year, e.at.month, e.at.day)));
      switch (e.kind) {
        case ChangeKind.added:
          day.added++;
        case ChangeKind.modified:
          day.modified++;
        case ChangeKind.deleted:
          day.deleted++;
        case ChangeKind.restored:
          day.restored++;
      }
      day.lastAt = e.at;
    }
    final list = byDay.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Der letzte Eintrag pro Pfad — für die Papierkorb-Zuordnung beim
  /// Wiederherstellen.
  Future<Map<String, JournalEntry>> latestPerPath() async {
    final out = <String, JournalEntry>{};
    for (final e in await readAll()) {
      out[e.rel] = e; // aufsteigend sortiert → der letzte gewinnt
    }
    return out;
  }

  /// Entfernt Einträge älter als [retention] und fasst `add`/`mod`-Folgen
  /// ohne dazwischenliegendes `del` auf die jüngste Zeile pro Pfad zusammen.
  ///
  /// `del`-Einträge bleiben bis zum Ablauf der Aufbewahrung stehen, sonst
  /// ginge die Papierkorb-Zuordnung verloren.
  ///
  /// Liefert die Anzahl entfernter Zeilen.
  Future<int> compact() async {
    final all = await readAll();
    if (all.isEmpty) return 0;
    final cutoff = DateTime.now().toUtc().subtract(retention);

    // Jüngste Presence-Zeile pro Pfad, solange kein `del` dazwischenliegt.
    // `lastPos` merkt sich dafür den Index in `keep`; ein `del` löscht die
    // Zuordnung, damit eine spätere Presence-Zeile wieder neu angehängt wird.
    final keep = <JournalEntry>[];
    final lastPos = <String, int>{};
    for (final e in all) {
      if (e.kind.isPresence) {
        final prev = lastPos[e.rel];
        if (prev != null) {
          keep[prev] = e;
        } else {
          lastPos[e.rel] = keep.length;
          keep.add(e);
        }
      } else {
        lastPos.remove(e.rel);
        keep.add(e);
      }
    }

    final survivors =
        keep.where((e) => !e.at.isBefore(cutoff)).toList(growable: false);
    final removed = all.length - survivors.length;
    if (removed <= 0) return 0;

    try {
      final buffer = StringBuffer();
      for (final e in survivors) {
        buffer.writeln(jsonEncode(e.toJson()));
      }
      await _file.writeAsString(buffer.toString());
      AppLog.info('journal',
          'Verlauf verdichtet: $removed Einträge entfernt, ${survivors.length} behalten');
    } catch (e) {
      AppLog.warn('journal', 'Verdichten fehlgeschlagen: $e');
      return 0;
    }
    return removed;
  }
}

/// Ein Tag im Verlauf, mit Zählern je Änderungsart.
class JournalDay {
  final DateTime date;
  int added = 0;
  int modified = 0;
  int deleted = 0;
  int restored = 0;
  DateTime? lastAt;

  JournalDay({required this.date});

  int get total => added + modified + deleted + restored;
}

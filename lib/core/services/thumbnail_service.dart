import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Woher ein Vorschaubild kommt.
enum ThumbSource {
  /// Die Aufnahme liegt noch auf dem Gerät — daraus wird das Vorschaubild
  /// erzeugt. Kein Netz, sofort, volle Qualität.
  local,

  /// Nur in der Cloud: `.fibu/thumbs/<hash>.jpg` laden.
  cloud,

  /// Weder noch: die Kachel zeigt Name und Größe.
  none,
}

/// Eine Aufnahme, für die noch ein Vorschaubild in der Cloud fehlt.
class ThumbBackfillItem {
  final String rel;

  /// `true`: die Aufnahme liegt lokal, das Vorschaubild wird daraus erzeugt
  /// und hochgeladen — der billige Weg.
  /// `false`: es gibt sie nur in der Cloud, sie muss erst geladen werden.
  final bool fromLocalFile;

  const ThumbBackfillItem(this.rel, {required this.fromLocalFile});
}

/// Namen, Auflösung und Nachzieh-Liste für Vorschaubilder.
///
/// **Lokal vor Cloud** ist der Grundsatz (siehe
/// `docs/PHASE5_FOTOS_NIVEAU.md`, §2.1): Was noch auf dem Gerät liegt, wird
/// nicht aus der Cloud geholt — weder für die Kachel noch für die
/// Vollbild-Ansicht. Die Vorschaubilder in der Cloud dienen den *anderen*
/// Geräten und Aufnahmen, die es nur dort gibt.
///
/// Alles hier ist reine Logik ohne UI und ohne rclone — damit es sich testen
/// lässt, ohne ein Gerät zu brauchen.
class ThumbnailService {
  const ThumbnailService._();

  /// Ordner in der Cloud. Liegt bewusst unter `.fibu/`: Das wird von keinem
  /// Spiegel zurückgespielt (`virtual_mirror_sync.dart:769`,
  /// `filesystem_mirror_source.dart:54`, `rclone_service_impl.dart:231`).
  static const String cloudFolder = '.fibu/thumbs';

  /// Kantenlänge und Qualität der Vorschaubilder → 15–30 KB pro Aufnahme.
  static const int edge = 256;
  static const int quality = 70;

  /// Dateiname für eine Aufnahme: erste 32 Hex-Zeichen von SHA-256 über den
  /// normierten Spiegel-Pfad, plus `.jpg`.
  ///
  /// Deterministisch — zwei Geräte, dieselbe Aufnahme, derselbe Name. Ein
  /// zweiter Lauf lädt also nicht noch einmal hoch, und ein Duplikat kann es
  /// nicht geben.
  static Future<String> fileNameFor(String rel) async {
    final digest = await Sha256().hash(utf8.encode(normalize(rel)));
    final hex = digest.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 32)}.jpg';
  }

  /// Pfad des Vorschaubilds in der Cloud.
  static Future<String> cloudPath(String rel) async =>
      '$cloudFolder/${await fileNameFor(rel)}';

  /// Vereinheitlicht Pfadtrenner und entfernt führende Trenner.
  ///
  /// Ohne das bekämen „Photos/A.jpg" und „/Photos/A.jpg" verschiedene Namen —
  /// und dieselbe Aufnahme läge zweimal in der Cloud.
  static String normalize(String rel) {
    var r = rel.replaceAll('\\', '/');
    while (r.startsWith('/')) {
      r = r.substring(1);
    }
    return r;
  }

  /// Woher das Vorschaubild für eine Aufnahme kommt.
  static ThumbSource resolveSource({
    required bool existsLocally,
    required bool hasCloudThumb,
  }) {
    if (existsLocally) return ThumbSource.local;
    if (hasCloudThumb) return ThumbSource.cloud;
    return ThumbSource.none;
  }

  /// Welche Aufnahmen brauchen noch ein Vorschaubild in der Cloud?
  ///
  /// [cloudFileNames] sind die Dateinamen, die bereits in `.fibu/thumbs/`
  /// liegen — eine einzige Auflistung des Ordners, kein Index und keine
  /// Datenbank.
  ///
  /// Lokal vorhandene Aufnahmen kommen **zuerst** ([ThumbBackfillItem] mit
  /// `fromLocalFile: true`): Ihr Vorschaubild entsteht aus der lokalen Datei,
  /// ohne Download. Was es nur in der Cloud gibt, kommt danach — das ist der
  /// teure Weg, und er soll den billigen nicht ausbremsen.
  static Future<List<ThumbBackfillItem>> backfillList({
    required Iterable<String> rels,
    required Set<String> cloudFileNames,
    required bool Function(String rel) existsLocally,
  }) async {
    final local = <ThumbBackfillItem>[];
    final cloudOnly = <ThumbBackfillItem>[];
    for (final rel in rels) {
      final name = await fileNameFor(rel);
      if (cloudFileNames.contains(name)) continue;
      if (existsLocally(rel)) {
        local.add(ThumbBackfillItem(rel, fromLocalFile: true));
      } else {
        cloudOnly.add(ThumbBackfillItem(rel, fromLocalFile: false));
      }
    }
    return [...local, ...cloudOnly];
  }

  /// Vorschaubilder in der Cloud, zu denen keine Aufnahme mehr gehört.
  ///
  /// Der Nachzieh-Lauf räumt sie mit auf (ein Vergleich pro Durchlauf), sonst
  /// blieben sie liegen, bis die ganze Sicherung gelöscht wird.
  static Future<List<String>> orphanCloudThumbs({
    required Iterable<String> rels,
    required Set<String> cloudFileNames,
  }) async {
    final known = <String>{};
    for (final rel in rels) {
      known.add(await fileNameFor(rel));
    }
    return cloudFileNames.where((name) => !known.contains(name)).toList();
  }
}

/// Vorschaubilder auf dem Gerät.
///
/// Wegwerfbar: Alles hier ist aus der lokalen Aufnahme oder aus der Cloud
/// wiederherstellbar. Der Cache existsiert nur, damit Scrollen kein Netzwerk
/// braucht.
class ThumbnailCache {
  ThumbnailCache(this.root, {this.maxBytes = defaultMaxBytes});

  /// Weiche Grenze. Darüber wird das älteste Drittel gelöscht — kein
  /// LRU-Buch, eine Ordnerliste reicht bei ein paar tausend Dateien.
  static const int defaultMaxBytes = 200 * 1024 * 1024;

  final Directory root;
  final int maxBytes;

  Future<File> fileFor(String rel) async =>
      File('${root.path}/${await ThumbnailService.fileNameFor(rel)}');

  Future<Uint8List?> read(String rel) async {
    final file = await fileFor(rel);
    if (!await file.exists()) return null;
    try {
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String rel, List<int> bytes) async {
    final file = await fileFor(rel);
    await file.create(recursive: true);
    await file.writeAsBytes(bytes, flush: false);
  }

  /// Aktuelle Größe des Cache in Bytes.
  Future<int> totalBytes() async {
    if (!await root.exists()) return 0;
    var total = 0;
    await for (final entity in root.list(followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {}
      }
    }
    return total;
  }

  /// Bringt den Cache unter [maxBytes], indem das älteste Drittel gelöscht
  /// wird — wiederholt, bis die Grenze unterschritten ist. Liefert die Zahl
  /// der gelöschten Dateien.
  ///
  /// Wiederholt deshalb, weil ein Durchlauf nicht reichen muss: Wer die
  /// Grenze später herabsetzt, läge sonst dauerhaft darüber.
  Future<int> prune() async {
    var removed = 0;
    while (true) {
      if (!await root.exists()) return removed;
      final files = <File>[];
      await for (final entity in root.list(followLinks: false)) {
        if (entity is File) files.add(entity);
      }
      if (files.isEmpty) return removed;

      var total = 0;
      final stamps = <File, int>{};
      for (final file in files) {
        try {
          total += await file.length();
          stamps[file] = (await file.lastModified()).millisecondsSinceEpoch;
        } catch (_) {}
      }
      if (total <= maxBytes) return removed;

      files.sort((a, b) => (stamps[a] ?? 0).compareTo(stamps[b] ?? 0));
      final dropCount = (files.length / 3).ceil();
      var droppedThisPass = 0;
      for (var i = 0; i < dropCount && i < files.length; i++) {
        try {
          await files[i].delete();
          droppedThisPass++;
        } catch (_) {}
      }
      if (droppedThisPass == 0) return removed; // nichts löschbar → aufgeben
      removed += droppedThisPass;
    }
  }
}

/// Warteschlange mit zwei Eigenschaften, die der Explorer braucht:
///
///  * **Höchstens [maxConcurrent] gleichzeitig** — ein Scroll-Schub soll die
///    Verbindung nicht zusammenbrechen lassen.
///  * **Kein Doppel-Download** — dieselbe Kachel darf bei schnellem Scrollen
///    nicht zweimal laufen.
class ThumbnailQueue {
  ThumbnailQueue({this.maxConcurrent = 4})
      : assert(maxConcurrent > 0, 'maxConcurrent muss positiv sein');

  final int maxConcurrent;
  final Map<String, Future<Object?>> _inFlight = {};
  final List<Completer<void>> _waiting = [];
  int _active = 0;

  /// Lädt [key]. Läuft für denselben Schlüssel schon etwas, hängt sich der
  /// Aufrufer an denselben Lauf — statt ein zweites Mal zu laden.
  ///
  /// Der Wert wird über `then` weitergereicht und nicht als
  /// `Future<Object?> as Future<T>` gecastet: Dart-Generics sind kovariant,
  /// eine Abwärts-Konvertierung wäre ein `TypeError` zur Laufzeit.
  Future<T> run<T>(String key, Future<T> Function() task) {
    final existing = _inFlight[key];
    if (existing != null) return existing.then((value) => value as T);

    final future = _execute(key, task);
    _inFlight[key] = future;
    return future;
  }

  /// Wie viele Aufgaben gerade laufen — für Tests und Fortschritt.
  int get activeCount => _active;

  Future<T> _execute<T>(String key, Future<T> Function() task) async {
    await _acquire();
    try {
      return await task();
    } finally {
      _inFlight.remove(key);
      _release();
    }
  }

  Future<void> _acquire() async {
    if (_active < maxConcurrent) {
      _active++;
      return;
    }
    final slot = Completer<void>();
    _waiting.add(slot);
    await slot.future;
  }

  void _release() {
    if (_waiting.isNotEmpty) {
      // Der Platz wandert direkt weiter — _active bleibt unverändert.
      _waiting.removeAt(0).complete();
      return;
    }
    _active--;
  }
}

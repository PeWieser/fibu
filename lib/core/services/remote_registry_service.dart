import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/app_paths.dart';
import 'app_log_service.dart';
import 'rclone_provider.dart';
import 'rclone_service.dart';

/// Ein verbundener Cloud-Speicher aus Fibu-Sicht.
///
/// WICHTIG (Design-Entscheid): Die Identität ist die stabile, technische
/// [id] – sie ist zugleich der Sektionsname in der rclone.conf und ändert
/// sich NIE nach dem Anlegen. Der vom Nutzer vergebene [name] ist ein reiner
/// Anzeigename, der nur in dieser App-Registry (Application Support)
/// gespeichert wird und jederzeit ohne rclone-Aufruf umbenannt werden kann.
/// Aufgaben referenzieren Remotes deshalb über die [id] – ein Umbenennen
/// kann Aufgaben nicht mehr „verlieren" (früher hing alles am frei
/// wählbaren Sektionsnamen in der rclone.conf).
///
/// [type] ist der echte rclone-Backend-Typ (`mega`, `drive`, `dropbox`, …).
/// Er wird beim Anlegen gespeichert und bei „adoptierten" Alt-Sektionen per
/// `config/get` aus der rclone.conf gelesen – die App rät den Provider nicht
/// mehr anhand des Namens.
class RemoteEntry {
  final String id;
  final String name;
  final String type;
  final int createdAtMs;

  const RemoteEntry({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAtMs,
  });

  RemoteEntry copyWith({String? name, String? type}) => RemoteEntry(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        createdAtMs: createdAtMs,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'createdAtMs': createdAtMs,
      };

  factory RemoteEntry.fromJson(Map<String, dynamic> json) => RemoteEntry(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        type: json['type'] as String? ?? '',
        createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      );

  /// Menschenlesbares Provider-Label aus dem rclone-Backend-Typ.
  static String prettyType(String type) {
    switch (type.trim().toLowerCase()) {
      case 'mega':
        return 'MEGA';
      case 'drive':
        return 'Google Drive';
      case 'google photos':
      case 'googlephotos':
        return 'Google Photos';
      case 'dropbox':
        return 'Dropbox';
      case 'onedrive':
        return 'OneDrive';
      case 'sharepoint':
        return 'SharePoint';
      case 'pcloud':
        return 'pCloud';
      case 'box':
        return 'Box';
      case 'yandex':
        return 'Yandex Disk';
      case 's3':
        return 'S3-kompatibel';
      case 'b2':
        return 'Backblaze B2';
      case 'webdav':
        return 'WebDAV';
      case 'sftp':
        return 'SFTP';
      case 'ftp':
        return 'FTP';
      case 'protondrive':
        return 'Proton Drive';
      case 'jottacloud':
        return 'Jottacloud';
      case 'koofr':
        return 'Koofr';
      case 'azureblob':
        return 'Azure Blob';
      case 'gcs':
      case 'google cloud storage':
        return 'Google Cloud Storage';
      case '':
        return 'Cloud';
      default:
        final t = type.trim();
        if (t.isEmpty) return 'Cloud';
        return t[0].toUpperCase() + t.substring(1);
    }
  }
}

/// Verwaltet die Remote-Registry (`remotes.json` im privaten
/// App-Support-Ordner) und hält sie mit der rclone.conf synchron:
///
///  * Neue Sektionen in der rclone.conf, die hier nicht bekannt sind, werden
///    adoptiert (Anzeigename = Sektionsname, Typ aus `config/get`).
///  * Registry-Einträge ohne passende Sektion (extern gelöscht) werden
///    verworfen.
class RemoteRegistryService {
  RemoteRegistryService(this._rclone);

  final RcloneService _rclone;

  List<RemoteEntry>? _cache;

  /// Lädt die Registry (einmalig) und gleicht sie mit rclone ab.
  Future<List<RemoteEntry>> entries({bool forceReload = false}) async {
    if (_cache != null && !forceReload) return _cache!;
    List<String> sections;
    try {
      sections = await _rclone.listRemotes();
    } catch (e) {
      // rclone vorübergehend nicht erreichbar → lieber gespeicherte
      // Registry liefern als gar keine Remotes (bleibt UI stabil).
      AppLog.warn('remote', 'Remote-Liste nicht lesbar ($e) – nutze gespeicherte Registry');
      final stored = await _readStored();
      _cache = stored;
      return stored;
    }

    final stored = await _readStored();
    final byId = {for (final e in stored) e.id: e};
    final result = <RemoteEntry>[];
    var changed = false;
    for (final section in sections) {
      final existing = byId.remove(section);
      if (existing != null) {
        result.add(existing);
        continue;
      }
      // Unbekannte Sektion (Alt-Installation oder extern angelegt) adoptieren.
      String type = '';
      try {
        type = await _rclone.remoteType(section) ?? '';
      } catch (_) {}
      result.add(RemoteEntry(
        id: section,
        name: section,
        type: type,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      ));
      changed = true;
      AppLog.info('remote',
          'Bestehendes Remote „$section" übernommen (Typ: ${type.isEmpty ? 'unbekannt' : type})');
    }
    if (byId.isNotEmpty) {
      changed = true;
      AppLog.info('remote',
          'Registry bereinigt: ${byId.keys.join(', ')} existiert nicht mehr in rclone');
    }
    if (changed) await _persist(result);
    _cache = result;
    return result;
  }

  /// Legt ein Remote in rclone an (Sektionsname = frisch generierte [id])
  /// und registriert es. [displayName] ist reiner Anzeigename; er landet
  /// bewusst NICHT als Sektionsname in der rclone.conf.
  Future<RemoteEntry> createRemote({
    required String displayName,
    required String type,
    required Map<String, String> config,
  }) async {
    final current = await entries();
    final taken = current.map((e) => e.id).toSet();
    String id;
    final rand = Random.secure();
    do {
      final hex = List.generate(
          4, (_) => rand.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      id = 'fibu-$hex';
    } while (taken.contains(id));

    await _rclone.addRemote(name: id, type: type, config: config);

    final trimmedName = displayName.trim();
    final entry = RemoteEntry(
      id: id,
      name: trimmedName.isEmpty ? RemoteEntry.prettyType(type) : trimmedName,
      type: type,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    final updated = [...current, entry];
    await _persist(updated);
    _cache = updated;
    AppLog.info('remote',
        'Remote „${entry.name}" angelegt (Typ: $type, interne Kennung: $id)');
    return entry;
  }

  /// Benennt NUR den Anzeigenamen um – rclone.conf und referenzierende
  /// Aufgaben bleiben unberührt (Identity = [id]).
  Future<void> rename(String id, String newName) async {
    final name = newName.trim();
    if (name.isEmpty) return;
    final current = await entries();
    final idx = current.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final updated = [...current];
    final previous = updated[idx];
    updated[idx] = previous.copyWith(name: name);
    await _persist(updated);
    _cache = updated;
    AppLog.info('remote',
        'Remote „${previous.name}" umbenannt zu „$name" (nur Anzeigename)');
  }

  /// Entfernt einen Registry-Eintrag (nachdem die rclone-Sektion gelöscht
  /// wurde). rclone-seitig passiert hier nichts mehr.
  Future<void> unregister(String id) async {
    final current = _cache ?? await _readStored();
    final updated = current.where((e) => e.id != id).toList();
    await _persist(updated);
    _cache = updated;
  }

  /// Nachschlagen aus dem Cache (null, wenn noch nicht geladen/unbekannt).
  RemoteEntry? byId(String id) {
    final cache = _cache;
    if (cache == null) return null;
    for (final e in cache) {
      if (e.id == id) return e;
    }
    return null;
  }

  Future<List<RemoteEntry>> _readStored() async {
    try {
      final file = await privateAppFile('remotes.json');
      if (!await file.exists()) return const [];
      final raw = (await file.readAsString()).trim();
      if (raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const [];
      final list = decoded['remotes'];
      if (list is! List) return const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(RemoteEntry.fromJson)
          .where((e) => e.id.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persist(List<RemoteEntry> entries) async {
    try {
      final file = await privateAppFile('remotes.json');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert({
        'version': 1,
        'remotes': entries.map((e) => e.toJson()).toList(),
      }));
    } catch (e) {
      AppLog.warn('remote', 'Registry konnte nicht gespeichert werden: $e');
    }
  }
}

/// Provider für den Registry-Service (Singleton-Charakter via Provider).
final remoteRegistryServiceProvider = Provider<RemoteRegistryService>((ref) {
  return RemoteRegistryService(ref.watch(rcloneServiceProvider));
});

/// Alle bekannten Remotes (mit Anzeigename + echtem Provider-Typ).
final remoteEntriesProvider = FutureProvider<List<RemoteEntry>>((ref) {
  return ref.watch(remoteRegistryServiceProvider).entries();
});

/// Anzeigename einer Remote-ID (Fallback: die ID selbst).
final remoteDisplayNameProvider =
    Provider.family<String, String>((ref, String id) {
  final entries = ref.watch(remoteEntriesProvider).valueOrNull ?? const [];
  for (final e in entries) {
    if (e.id == id) return e.name;
  }
  return id;
});

/// Kompletter Eintrag einer Remote-ID (null, wenn nicht vorhanden).
final remoteEntryProvider =
    Provider.family<RemoteEntry?, String>((ref, String id) {
  final entries = ref.watch(remoteEntriesProvider).valueOrNull ?? const [];
  for (final e in entries) {
    if (e.id == id) return e;
  }
  return null;
});

/// true, wenn die ID aktuell als rclone-Sektion existiert.
final remoteExistsProvider = Provider.family<bool, String>((ref, String id) {
  final entries = ref.watch(remoteEntriesProvider).valueOrNull ?? const [];
  return entries.any((e) => e.id == id);
});

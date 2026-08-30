import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app_log_service.dart';

/// Eine im Hintergrund erkannte, aber noch nicht ausgeführte lokale Löschung.
///
/// Cloud-seitig gelöschte Dateien sollen auch lokal verschwinden. iOS verlangt
/// dafür einen Bestätigungsdialog, der in einem Hintergrundtask nicht
/// angezeigt werden kann. Deshalb wird die Löschung gespeichert und dem
/// Nutzer auf dem Dashboard angeboten.
class PendingLocalDeletion {
  final String rel;
  final String assetId;

  const PendingLocalDeletion({required this.rel, required this.assetId});

  Map<String, dynamic> toJson() => {'rel': rel, 'assetId': assetId};

  factory PendingLocalDeletion.fromJson(Map<String, dynamic> json) =>
      PendingLocalDeletion(
        rel: json['rel'] as String? ?? '',
        assetId: json['assetId'] as String? ?? '',
      );
}

/// Speicher für ausstehende lokale Löschungen.
///
/// Liegt im privaten App-Support-Ordner, damit Nutzer die Datei nicht in der
/// Dateien-App sehen und nicht versehentlich löschen können.
class PendingDeletionsStore {
  static const String fileName = 'pending_deletions.json';

  static Future<File> _file() async {
    final Directory dir = await getApplicationSupportDirectory();
    final Directory root = Directory('${dir.path}/fibu_state');
    if (!await root.exists()) await root.create(recursive: true);
    return File('${root.path}/$fileName');
  }

  static Future<List<PendingLocalDeletion>> load() async {
    try {
      final File f = await _file();
      if (!await f.exists()) return const <PendingLocalDeletion>[];
      final dynamic decoded = jsonDecode(await f.readAsString());
      if (decoded is! List) return const <PendingLocalDeletion>[];
      return <PendingLocalDeletion>[
        for (final dynamic raw in decoded)
          if (raw is Map)
            PendingLocalDeletion.fromJson(Map<String, dynamic>.from(raw)),
      ].where((PendingLocalDeletion d) => d.assetId.isNotEmpty).toList();
    } catch (e) {
      AppLog.warn('sync', 'Ausstehende Löschungen nicht lesbar: $e');
      return const <PendingLocalDeletion>[];
    }
  }

  /// Fügt Löschungen hinzu, ohne Duplikate anzulegen.
  static Future<void> addAll(List<PendingLocalDeletion> items) async {
    if (items.isEmpty) return;
    final List<PendingLocalDeletion> existing = await load();
    final Set<String> known =
        existing.map((PendingLocalDeletion d) => d.assetId).toSet();
    final List<PendingLocalDeletion> merged = <PendingLocalDeletion>[
      ...existing,
      ...items.where((PendingLocalDeletion d) => known.add(d.assetId)),
    ];
    await _write(merged);
    AppLog.info('sync',
        '${items.length} lokale Löschungen als ausstehend gespeichert (gesamt ${merged.length})');
  }

  /// Entfernt die übergebenen Löschungen (nach erfolgreicher Ausführung).
  static Future<void> removeAll(Iterable<String> assetIds) async {
    final Set<String> ids = assetIds.toSet();
    if (ids.isEmpty) return;
    final List<PendingLocalDeletion> remaining = (await load())
        .where((PendingLocalDeletion d) => !ids.contains(d.assetId))
        .toList();
    await _write(remaining);
  }

  static Future<void> _write(List<PendingLocalDeletion> items) async {
    try {
      final File f = await _file();
      await f.writeAsString(
          jsonEncode(items.map((PendingLocalDeletion d) => d.toJson()).toList()));
    } catch (e) {
      AppLog.warn('sync', 'Ausstehende Löschungen nicht schreibbar: $e');
    }
  }
}

/// Ausstehende lokale Löschungen für das Dashboard.
final pendingDeletionsProvider =
    FutureProvider<List<PendingLocalDeletion>>((ref) async {
  return PendingDeletionsStore.load();
});

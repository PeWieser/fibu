import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/app_paths.dart';
// Bewusste Ausnahme von der Schichtung (core → features): Der Provider braucht
// das Ziel der Sicherung, und das liegt im Aufgaben-Zustand. Die Alternative
// wäre ein Datei-Lesevorgang in einem Provider — genau das hat ihn in den
// Tests langsamer gemacht als das Zeitfenster, in dem die Oberfläche baut.
import '../../features/tasks/presentation/tasks_controller.dart';
import 'rclone_provider.dart';
import 'rclone_service.dart';
import 'remote_registry_service.dart';

/// Welche Cloud „die eine" ist — und wie viel Platz sie hat.
///
/// Modell seit dem Umbau „eine Cloud, eine Sicherung": Die App sichert auf
/// genau ein Ziel. Das kann ein gewöhnliches Laufwerk sein oder ein
/// virtuelles (Union, Combine, Crypt, Chunker), das im Einrichtungs-Assistent
/// aus mehreren Laufwerken gebündelt wurde.
class ActiveCloud {
  const ActiveCloud._();

  /// Bestimmt die eine Cloud und hält sie in der Registry fest.
  ///
  /// Reihenfolge — jede Stufe nur, wenn die vorherige nichts ergibt:
  ///  1. die gespeicherte Wahl, solange das Laufwerk noch existiert
  ///  2. das Ziel der vorhandenen Sicherung (sonst würde eine bestehende
  ///     Sicherung nach einem Update auf ein anderes Laufwerk zeigen)
  ///  3. das erste Laufwerk, das nicht Bestandteil eines Pools ist — ein
  ///     Bestandteil allein ist kein Sicherungsziel
  ///  4. das erste Laufwerk überhaupt
  ///
  /// [persist] ist für Tests abschaltbar.
  static Future<String?> resolve(
    RemoteRegistryService registry, {
    bool persist = true,
  }) async {
    return resolveFrom(await registry.entries(), registry, persist: persist);
  }

  /// Dasselbe wie [resolve], aber mit einer schon geladenen Laufwerksliste —
  /// die Provider-Schicht liefert sie aus `remoteEntriesProvider`, damit
  /// Overrides (z. B. in Tests) wirken.
  ///
  /// [preferredTarget] übergibt das Ziel der Sicherung aus dem Speicher. Wer
  /// es hat, setzt außerdem [lookupBackupTarget] auf false — dann liest diese
  /// Methode **keine Datei**, und der Provider bleibt billig.
  ///
  /// [persist] schreibt die Wahl in die Registry. Der Provider tut das
  /// bewusst nicht: Er würde bei jedem Neuaufbau in die Datei schreiben.
  /// Gespeichert wird, wenn eine Cloud verbunden oder ersetzt wird.
  static Future<String?> resolveFrom(
    List<RemoteEntry> entries,
    RemoteRegistryService registry, {
    String? preferredTarget,
    bool lookupBackupTarget = true,
    bool persist = true,
  }) async {
    if (entries.isEmpty) return null;

    final stored = registry.activeRemoteId;
    if (stored.isNotEmpty && entries.any((e) => e.id == stored)) return stored;

    final memberIds = <String>{
      for (final e in entries) ...registry.poolMembersOf(e.id),
    };

    String? chosen;
    // Nicht `backupTarget` nennen: Die lokale Variable würde die
    // gleichnamige Methode verdecken und sich damit selbst meinen.
    final target =
        preferredTarget ?? (lookupBackupTarget ? await backupTarget() : null);
    if (target != null && entries.any((e) => e.id == target)) {
      chosen = target;
    }
    chosen ??= entries.firstWhere(
      (e) => !memberIds.contains(e.id),
      orElse: () => entries.first,
    ).id;

    if (persist) await registry.setActiveRemote(chosen);
    return chosen;
  }

  /// Ziel-Laufwerk der Sicherung aus dem geladenen Zustand — ohne Datei-IO.
  static String? targetOfTasks(List<BackupTask> tasks) {
    if (tasks.isEmpty) return null;
    for (final t in tasks) {
      if (t.isActive && t.targetRemote.isNotEmpty) return t.targetRemote;
    }
    for (final t in tasks) {
      if (t.targetRemote.isNotEmpty) return t.targetRemote;
    }
    return null;
  }

  /// Ziel-Laufwerk der vorhandenen Sicherung, direkt aus `tasks.json`.
  ///
  /// Bewusst kein Provider: `tasks_controller` hängt selbst an
  /// `rclone_provider` — ein Provider hier würde einen Import-Kreis bauen.
  /// Einmal lesen beim Auflösen ist billiger als diese Kopplung.
  static Future<String?> backupTarget() async {
    try {
      final file = await privateAppFile('tasks.json');
      if (!await file.exists()) return null;
      final raw = (await file.readAsString()).trim();
      if (raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      String? first;
      for (final item in decoded) {
        if (item is! Map) continue;
        final target = _targetOf(item);
        if (target == null) continue;
        first ??= target;
        // Eine aktive Sicherung zählt mehr als eine pausierte.
        if (item['isActive'] == true) return target;
      }
      return first;
    } catch (_) {
      return null;
    }
  }

  static String? _targetOf(Map<dynamic, dynamic> task) {
    final single = task['targetRemote'];
    if (single is String && single.isNotEmpty) return single.split(':').first;
    final list = task['targetRemotes'];
    if (list is List) {
      for (final e in list) {
        if (e is String && e.isNotEmpty) return e.split(':').first;
      }
    }
    return null;
  }

  /// Speicherplatz einer Cloud.
  ///
  /// **Bei einem Pool die Summe der Bestandteile.** rclone liefert `about`
  /// für Union/Combine je nach Backend gar nicht oder nur für ein einzelnes
  /// Mitglied — die Speicherzeile soll aber nie leer bleiben. Antworten
  /// Bestandteile, gewinnt ihre Summe; antwortet keiner, gilt die Antwort des
  /// virtuellen Laufwerks selbst (falls es eine gab).
  static Future<QuotaInfo?> quota(
    RcloneService service,
    RemoteRegistryService registry,
    String remoteId,
  ) async {
    final members = registry.poolMembersOf(remoteId);

    QuotaInfo? own;
    try {
      own = await service.getQuota(remoteId);
    } catch (_) {
      own = null;
    }
    if (members.isEmpty) return own;

    var total = 0;
    var used = 0;
    var free = 0;
    var answered = 0;
    for (final member in members) {
      try {
        final q = await service.getQuota(member);
        if (q.totalBytes > 0) {
          total += q.totalBytes;
          used += q.usedBytes;
          free += q.freeBytes;
          answered++;
        }
      } catch (_) {
        // Ein Bestandteil ohne `about`-Unterstützung fehlt in der Summe —
        // besser eine kleinere Zahl als gar keine.
      }
    }
    if (answered == 0) return own;
    return QuotaInfo(totalBytes: total, usedBytes: used, freeBytes: free);
  }
}

/// Kennung der einen Cloud (rclone-Sektionsname), oder null, wenn keine
/// verbunden ist.
final activeRemoteIdProvider = FutureProvider<String?>((ref) async {
  // Alles Synchrone zuerst: Nach einem await darf `ref` nicht mehr benutzt
  // werden. Und genau deshalb kommt das Sicherungsziel hier aus dem Zustand
  // statt aus tasks.json — Datei-IO in diesem Provider hat ihn in den Tests
  // langsamer gemacht als das Zeitfenster, in dem die Oberfläche baut.
  final registry = ref.watch(remoteRegistryServiceProvider);
  final tasks = ref.watch(tasksListProvider);
  final preferred = ActiveCloud.targetOfTasks(tasks);
  final entries = await ref.watch(remoteEntriesProvider.future);
  return ActiveCloud.resolveFrom(
    entries,
    registry,
    preferredTarget: preferred,
    lookupBackupTarget: false,
    persist: false,
  );
});

/// Eintrag der einen Cloud (Name, Typ) — null, wenn keine verbunden ist.
final activeRemoteProvider = FutureProvider<RemoteEntry?>((ref) async {
  final id = await ref.watch(activeRemoteIdProvider.future);
  if (id == null) return null;
  final entries = await ref.watch(remoteEntriesProvider.future);
  for (final e in entries) {
    if (e.id == id) return e;
  }
  return null;
});

/// Bestandteile der einen Cloud — leer bei einer gewöhnlichen Cloud.
final activeCloudMembersProvider = FutureProvider<List<String>>((ref) async {
  final id = await ref.watch(activeRemoteIdProvider.future);
  if (id == null) return const <String>[];
  return ref.watch(remoteRegistryServiceProvider).poolMembersOf(id);
});

/// Belegter und freier Platz der einen Cloud (bei Pools die Summe).
final activeCloudQuotaProvider = FutureProvider<QuotaInfo?>((ref) async {
  final id = await ref.watch(activeRemoteIdProvider.future);
  if (id == null) return null;
  return ActiveCloud.quota(
    ref.watch(rcloneServiceProvider),
    ref.watch(remoteRegistryServiceProvider),
    id,
  );
});

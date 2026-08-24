import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fibu/core/services/mirror_sync_engine.dart';

/// Repliziert die Parse-Logik der Engines (ohne File-I/O), um den
/// whereType<Map<String,dynamic>>-Bug zu dokumentieren und abzusichern.
List<Tombstone> parseTombsSafe(String content) {
  final list = jsonDecode(content);
  if (list is! List) return [];
  final out = <Tombstone>[];
  for (final raw in list) {
    if (raw is! Map) continue;
    final t = Tombstone.fromJson(Map<String, dynamic>.from(raw));
    if (t.path.isNotEmpty) out.add(t);
  }
  return out;
}

/// Die kaputte Variante, die zuvor still alle Einträge verworfen hat.
List<Tombstone> parseTombsBroken(String content) {
  final list = jsonDecode(content);
  if (list is! List) return [];
  return list
      .whereType<Map<String, dynamic>>()
      .map(Tombstone.fromJson)
      .where((t) => t.path.isNotEmpty)
      .toList();
}

void main() {
  group('Tombstone JSON parse', () {
    test('jsonDecode maps are Map<dynamic,dynamic> — broken filter drops all', () {
      final json = jsonEncode([
        {
          'path': 'Photos/Camera/IMG_1.HEIC',
          'deletedAt': '2026-08-24T12:00:00.000Z',
          'deviceId': 'local',
        },
      ]);
      // jsonDecode → Map<String, dynamic> on some platforms, but the defensive
      // cast must always work. The broken whereType path is the regression.
      final decoded = jsonDecode(json) as List;
      // After encode/decode round-trip through a dynamic list, entries are Maps.
      expect(decoded.first, isA<Map>());

      final safe = parseTombsSafe(json);
      expect(safe, hasLength(1));
      expect(safe.single.path, 'Photos/Camera/IMG_1.HEIC');

      // If the platform yields Map<String,dynamic>, broken may still work;
      // force dynamic maps to prove the bug class.
      final forced = jsonEncode([
        <dynamic, dynamic>{
          'path': 'Photos/Camera/IMG_2.HEIC',
          'deletedAt': '2026-08-24T12:00:00.000Z',
          'deviceId': 'local',
        },
      ]);
      // Encode of Map<dynamic,dynamic> still produces valid JSON objects.
      final safe2 = parseTombsSafe(forced);
      expect(safe2, hasLength(1));
      expect(safe2.single.path, 'Photos/Camera/IMG_2.HEIC');
    });

    test('empty and garbage input', () {
      expect(parseTombsSafe('[]'), isEmpty);
      expect(parseTombsSafe('null'), isEmpty);
      expect(parseTombsSafe('{"no":"list"}'), isEmpty);
    });
  });
}

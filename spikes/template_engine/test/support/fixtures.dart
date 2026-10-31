import 'dart:convert';
import 'dart:io';

import 'package:template_engine/template_engine.dart';
import 'package:test/test.dart';

/// `dart test` runs from the package root.
const fixtureDir = 'test/fixtures';

String readFixture(String name) => File('$fixtureDir/$name').readAsStringSync();

Map<String, Object?> jsonFixture(String name) =>
    jsonDecode(readFixture(name)) as Map<String, Object?>;

Map<String, Object?> fullContext() => jsonFixture('context-full.json');

/// Fails with a readable line diff unless [actual] is byte-identical.
void expectSameBytes(String actual, String expected, {String reason = ''}) {
  final diff = describeDifference(expected, actual);
  if (diff != null) fail('$reason\n$diff');
}

/// The context as a Dart SQLite read would type it: the five REAL columns
/// (classes.resource_multiplier, class_stat_growth.value,
/// class_metadata_fields.value, abilities.resource_cost, abilities.cooldown)
/// arrive as doubles even when integral. JSON.parse cannot show this.
Map<String, Object?> sqliteTypedContext() {
  final c = fullContext();
  double d(Object? v) => (v as num).toDouble();
  for (final cls in (c['classes'] as List).cast<Map<String, Object?>>()) {
    cls['resource_multiplier'] = d(cls['resource_multiplier']);
    for (final g in (cls['stat_growth'] as List).cast<Map<String, Object?>>()) {
      g['value'] = d(g['value']);
    }
    (cls['metadata'] as Map<String, Object?>).updateAll(
      (k, v) => v is num ? v.toDouble() : v,
    );
  }
  for (final a in (c['abilities'] as List).cast<Map<String, Object?>>()) {
    a['resource_cost'] = d(a['resource_cost']);
    a['cooldown'] = d(a['cooldown']);
  }
  return c;
}

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../db/support/fixture_copy.dart' show fixturesDir;
import 'text_diff.dart';

/// A fixture shared with the database tests (`test/fixtures/<name>`).
String readFixture(String name) =>
    File(p.join(fixturesDir, name)).readAsStringSync();

/// An export-only fixture (`test/fixtures/export/<name>`).
String readExportFixture(String name) =>
    File(p.join(fixturesDir, 'export', name)).readAsStringSync();

Map<String, Object?> jsonFixture(String name) =>
    jsonDecode(readFixture(name)) as Map<String, Object?>;

/// The Electron 0.1.6 full export context of `sample-0.1.6.anvil`.
Map<String, Object?> fullContext() => jsonFixture('context-full.json');

/// Fails with a readable line diff unless [actual] is byte-identical.
void expectSameBytes(String actual, String expected, {String reason = ''}) {
  final diff = describeDifference(expected, actual);
  if (diff != null) fail('$reason\n$diff');
}

/// The full context as a Dart SQLite read types it: the five REAL columns
/// (classes.resource_multiplier, class_stat_growth.value,
/// class_metadata_fields.value, abilities.resource_cost, abilities.cooldown)
/// arrive as doubles even when integral. `jsonDecode` cannot show this.
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

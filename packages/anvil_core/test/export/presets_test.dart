// The three built-in presets, byte for byte against Electron 0.1.6
// (test/fixtures/preset-*), for the JSON-decoded context and for a context
// typed the way the Dart SQLite layer types it.
import 'dart:convert';

import 'package:anvil_core/anvil_core.dart';
import 'package:anvil_core/src/export/js_compat.dart' show jsUndefined;
import 'package:anvil_core/src/export/presets.dart' show csvEscape, toCsv;
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  final contexts = {
    'JSON-decoded context': fullContext(),
    'SQLite-typed context (REAL columns as doubles)': sqliteTypedContext(),
  };

  for (final MapEntry(key: label, value: ctx) in contexts.entries) {
    group(label, () {
      test('flat JSON', () {
        expectSameBytes(
          renderFlatJson(ctx),
          readFixture('preset-flat-json.txt'),
        );
      });
      test('nested JSON', () {
        expectSameBytes(
          renderNestedJson(ctx),
          readFixture('preset-nested-json.txt'),
        );
      });
      test('CSV preview and every CSV file', () {
        final csv = renderCsv(ctx);
        expectSameBytes(csv.summary, readFixture('preset-csv.txt'));
        expect(csv.files.map((f) => f.filename), [
          'classes.csv',
          'abilities.csv',
          'items.csv',
          'recipes.csv',
          'npcs.csv',
          'loot_tables.csv',
        ]);
        for (final f in csv.files) {
          expectSameBytes(
            f.content,
            readFixture('preset-csv-${f.filename}'),
            reason: f.filename,
          );
        }
      });
    });
  }

  test('the SQLite-typed context really holds integral doubles', () {
    // Otherwise the group above would prove nothing about `.0` suffixes.
    final ctx = sqliteTypedContext();
    final classes = (ctx['classes'] as List).cast<Map<String, Object?>>();
    final growth = (classes.first['stat_growth'] as List)
        .cast<Map<String, Object?>>();
    final abilities = (ctx['abilities'] as List).cast<Map<String, Object?>>();
    final reals = [
      for (final c in classes) c['resource_multiplier'],
      for (final g in growth) g['value'],
      for (final a in abilities) ...[a['resource_cost'], a['cooldown']],
    ];
    expect(reals, everyElement(isA<double>()));
    expect(
      reals.whereType<double>().where((d) => d == d.truncateToDouble()),
      isNotEmpty,
    );
    // dart:convert would print them with `.0`; the presets above did not.
    expect(jsonEncode(growth.first['value']), endsWith('.0'));
  });

  test('flat JSON, selection scope (items only)', () {
    expectSameBytes(
      renderFlatJson(
        jsonFixture('context-selection-items.json'),
        fullScope: false,
      ),
      readFixture('preset-flat-json-selection.txt'),
    );
  });

  test('nested JSON, selection scope keeps only the non-empty domains', () {
    final out = jsonDecode(
      renderNestedJson(
        jsonFixture('context-selection-items.json'),
        fullScope: false,
      ),
    ) as Map<String, Object?>;
    expect(out.keys, ['items']);
  });

  group('CSV escaping', () {
    test('matches Electron csvEscape', () {
      expect(csvEscape(null), '');
      expect(csvEscape(jsUndefined), '');
      expect(csvEscape('a,b'), '"a,b"');
      expect(csvEscape('say "hi"'), '"say ""hi"""');
      expect(csvEscape('line\nbreak'), '"line\nbreak"');
      expect(csvEscape('cr\ronly'), 'cr\ronly'); // a lone CR is not quoted
      expect(csvEscape(12.0), '12');
      expect(csvEscape(true), 'true');
    });
    test('toCsv: header from the first row, LF, no final newline', () {
      expect(
        toCsv([
          {'a': 1, 'b': null},
          {'a': 2.5, 'b': 'x'},
        ]),
        'a,b\n1,\n2.5,x',
      );
    });
  });
}

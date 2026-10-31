// Preset port probe: the built-in presets are code, not templates. Ported
// to Dart over the export context and compared byte for byte.
import 'dart:convert';

import 'package:template_engine/template_engine.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  final contexts = {
    'JSON-decoded context': fullContext(),
    'SQLite-typed context (REAL columns as doubles)': sqliteTypedContext(),
  };

  for (final MapEntry(key: label, value: ctx) in contexts.entries) {
    group('JS-compatible serialisation, $label', () {
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

  test('flat JSON, selection scope (items only)', () {
    expectSameBytes(
      renderFlatJson(
        jsonFixture('context-selection-items.json'),
        fullScope: false,
      ),
      readFixture('preset-flat-json-selection.txt'),
    );
  });

  // Documented, accepted differences: what a naive port (dart:convert and
  // Object.toString) prints. Every difference is an integral double printed
  // with `.0`; there are none on a JSON-decoded context, which is why the
  // fixtures alone would not catch it.
  group('naive Dart serialisation', () {
    final dartJson = const JsonEncoder.withIndent('  ').convert;
    String dartCell(Object? v) => v.toString();

    test('is identical on the JSON-decoded context', () {
      final ctx = fullContext();
      expect(
        renderFlatJson(ctx, encode: dartJson),
        readFixture('preset-flat-json.txt'),
      );
      expect(
        renderNestedJson(ctx, encode: dartJson),
        readFixture('preset-nested-json.txt'),
      );
      expect(
        renderCsv(ctx, cell: dartCell).summary,
        readFixture('preset-csv.txt'),
      );
    });

    test('differs only by `.0` on integral REAL values from SQLite', () {
      final ctx = sqliteTypedContext();
      final integralDouble = RegExp(r'(?<=[:,\s])(-?\d+)\.0(?=[,\s]|$)');
      for (final (name, expected, actual, changedLines) in [
        (
          'flat',
          readFixture('preset-flat-json.txt'),
          renderFlatJson(ctx, encode: dartJson),
          70,
        ),
        (
          'nested',
          readFixture('preset-nested-json.txt'),
          renderNestedJson(ctx, encode: dartJson),
          170,
        ),
        (
          'csv',
          readFixture('preset-csv.txt'),
          renderCsv(ctx, cell: dartCell).summary,
          2,
        ),
      ]) {
        expect(
          differingLineCount(expected, actual),
          changedLines * 2,
          reason: name,
        );
        // Stripping the `.0` suffixes gives back the Electron bytes.
        expectSameBytes(
          actual
              .split('\n')
              .map((l) => l.replaceAllMapped(integralDouble, (m) => m[1]!))
              .join('\n'),
          expected,
          reason: name,
        );
      }
    });
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

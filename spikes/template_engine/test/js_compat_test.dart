// The serialisation layer every option and the presets depend on, checked
// against what node printed (test/fixtures/js-values.json,
// tool/js_values_oracle.js).
import 'dart:convert';
import 'dart:typed_data';

import 'package:template_engine/template_engine.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  final oracle = jsonFixture('js-values.json');

  test('jsNumberToString matches String(x) for every sampled double', () {
    final rows = (oracle['numbers'] as List).cast<List<Object?>>();
    var dartToStringDiffers = 0;
    final mismatches = <String>[];
    for (final [hex as String, js as String] in rows) {
      final bits = ByteData(8)
        ..setUint32(0, int.parse(hex.substring(0, 8), radix: 16))
        ..setUint32(4, int.parse(hex.substring(8), radix: 16));
      final value = bits.getFloat64(0);
      if (value.toString() != js) dartToStringDiffers++;
      if (jsNumberToString(value) != js) {
        mismatches.add('$js vs ${jsNumberToString(value)}');
      }
    }
    expect(mismatches, isEmpty);
    // Documented: Dart's own toString differs on every integral double
    // (`12.0`) and on -0.0, roughly a third of this sample.
    expect(dartToStringDiffers, greaterThan(rows.length ~/ 4));
    printOnFailure('Dart toString differed on $dartToStringDiffers values');
  });

  group('jsJsonStringify matches JSON.stringify', () {
    final expected = (oracle['json'] as Map<String, Object?>).map(
      (k, v) => MapEntry(k, (v as List).cast<String>()),
    );
    final keyOrder = <String, Object?>{
      for (final k in ['b', '2', '10', 'a', '01', '4294967295', '4294967294'])
        k: k,
      '-1': '-1',
      '1.5': '1.5',
    };
    final cases = <String, List<String?>>{
      'numbers': [
        jsJsonStringify([
          1,
          1.5,
          0.8,
          1.25,
          -0.0,
          1e21,
          1e-7,
          100.0,
          0.1 + 0.2,
          12.0,
        ]),
      ],
      'non_finite': [
        jsJsonStringify([double.nan, double.infinity, double.negativeInfinity]),
      ],
      'escapes': [
        jsJsonStringify(
          '\u0000\u0001\b\t\n\u000b\f\r\u001f "\\/ é    \u007f 😀',
        ),
      ],
      'lone_surrogates': [jsJsonStringify('a\ud800b\udc00c\ud83d')],
      'key_order': [jsJsonStringify(keyOrder)],
      'nested_empty_2': [
        jsJsonStringify({
          'a': <Object?>[],
          'b': <String, Object?>{},
          'c': [<Object?>[]],
          'd': [<String, Object?>{}],
          'e': {
            'f': [
              1,
              {'g': null},
            ],
          },
        }, 2),
      ],
      'undefined_members': [
        jsJsonStringify({
          'a': jsUndefined,
          'b': 1,
          'c': [jsUndefined, null],
        }),
      ],
      'indents': [
        for (final s in <Object?>[
          0,
          1,
          4,
          10,
          11,
          -3,
          2.7,
          '\t',
          'abcdefghijkl',
          null,
          true,
        ])
          jsJsonStringify({
            'k': [1, 'x'],
          }, s),
      ],
    };
    for (final MapEntry(:key, :value) in cases.entries) {
      test(key, () => expect(value, expected[key]));
    }
  });

  test('jsToString matches String(x)', () {
    final expected = oracle['toString'] as Map<String, Object?>;
    expect({
      'list_mixed': jsToString([1, 2, 'a']),
      'list_nullish': jsToString([null, jsUndefined, 1]),
      'list_nested': jsToString([
        [1, 2],
        [3],
      ]),
      'object': jsToString(<String, Object?>{}),
      'bools': jsToString(true) + jsToString(false),
      'number_integral': jsToString(1.0),
      'number_negative_zero': jsToString(-0.0),
      'number_float': jsToString(0.8),
    }, expected);
  });

  // Documented differences of dart:convert, i.e. what a naive port of the
  // `json` filter or the presets would print. These are not bugs in the
  // spike; they are the pitfalls ANVL-147 must avoid.
  group('dart:convert JsonEncoder differs from JSON.stringify', () {
    test('integral doubles and -0.0 keep their .0', () {
      expect(json.encode([1.0, -0.0, 100.0]), '[1.0,-0.0,100.0]');
      expect(jsJsonStringify([1.0, -0.0, 100.0]), '[1,0,100]');
    });
    test('withIndent("") is not compact, so json(0) cannot map to it', () {
      expect(const JsonEncoder.withIndent('').convert([1, 2]), '[\n1,\n2\n]');
      expect(anvilJson([1, 2], 0), '[1,2]');
    });
    test('integer-like keys keep insertion order', () {
      final m = {'b': 1, '2': 2, '10': 3};
      expect(json.encode(m), '{"b":1,"2":2,"10":3}');
      expect(jsJsonStringify(m), '{"2":2,"10":3,"b":1}');
    });
    test('NaN and Infinity throw instead of printing null', () {
      expect(
        () => json.encode(double.nan),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
      expect(jsJsonStringify(double.nan), 'null');
    });
    test('string escaping is identical (control chars, lone surrogates)', () {
      for (final s in ['\u0000\u001f\b\f\u000b "\\/ ', 'a\ud800b\udc00c']) {
        expect(json.encode(s), jsJsonStringify(s));
      }
    });
  });
}

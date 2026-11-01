// The JavaScript value layer the presets and the template renderer share,
// checked against what node printed (test/fixtures/export/js-values.json,
// written by test/fixtures/export/tool/js_values_oracle.js).
import 'dart:convert';
import 'dart:typed_data';

import 'package:anvil_core/src/export/js_compat.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  final oracle =
      jsonDecode(readExportFixture('js-values.json')) as Map<String, Object?>;

  test('jsNumberString matches String(x) for every sampled double', () {
    final rows = (oracle['numbers'] as List).cast<List<Object?>>();
    var dartToStringDiffers = 0;
    final mismatches = <String>[];
    for (final [hex as String, js as String] in rows) {
      final bits = ByteData(8)
        ..setUint32(0, int.parse(hex.substring(0, 8), radix: 16))
        ..setUint32(4, int.parse(hex.substring(8), radix: 16));
      final value = bits.getFloat64(0);
      if (value.toString() != js) dartToStringDiffers++;
      if (jsNumberString(value) != js) {
        mismatches.add('$js vs ${jsNumberString(value)}');
      }
    }
    expect(mismatches, isEmpty);
    // Documented: Dart's own toString differs on every integral double
    // (`12.0`) and on -0.0, roughly a third of this sample.
    expect(dartToStringDiffers, greaterThan(rows.length ~/ 4));
    printOnFailure('Dart toString differed on $dartToStringDiffers values');
  });

  group('jsonStringify matches JSON.stringify', () {
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
        jsonStringify([
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
        jsonStringify([double.nan, double.infinity, double.negativeInfinity]),
      ],
      'escapes': [
        jsonStringify('\u0000\u0001\b\t\n\u000b\f\r\u001f "\\/ é    \u007f 😀'),
      ],
      'lone_surrogates': [jsonStringify('a\ud800b\udc00c\ud83d')],
      'key_order': [jsonStringify(keyOrder)],
      'nested_empty_2': [
        jsonStringify({
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
        }, indent: 2),
      ],
      'undefined_members': [
        jsonStringify({
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
          jsonStringify({
            'k': [1, 'x'],
          }, indent: s),
      ],
    };
    for (final MapEntry(:key, :value) in cases.entries) {
      test(key, () => expect(value, expected[key]));
    }
  });

  test('jsString matches String(x)', () {
    final expected = oracle['toString'] as Map<String, Object?>;
    expect({
      'list_mixed': jsString([1, 2, 'a']),
      'list_nullish': jsString([null, jsUndefined, 1]),
      'list_nested': jsString([
        [1, 2],
        [3],
      ]),
      'object': jsString(<String, Object?>{}),
      'bools': jsString(true) + jsString(false),
      'number_integral': jsString(1.0),
      'number_negative_zero': jsString(-0.0),
      'number_float': jsString(0.8),
    }, expected);
  });

  test('every oracle case is covered', () {
    expect(oracle.keys.toSet(), {'numbers', 'json', 'toString'});
    expect((oracle['numbers'] as List).length, 3025);
    expect((oracle['json'] as Map).length, 8);
    expect((oracle['toString'] as Map).length, 8);
  });

  group('JS operators', () {
    test('truthiness: empty lists and maps are truthy', () {
      for (final v in <Object?>[[], <String, Object?>{}, 'a', 1, -0.5, true]) {
        expect(jsTruthy(v), isTrue, reason: '$v');
      }
      for (final v in <Object?>['', 0, 0.0, double.nan, null, jsUndefined]) {
        expect(jsTruthy(v), isFalse, reason: '$v');
      }
    });
    test('loose and strict equality', () {
      expect(jsLooseEquals(1, '1'), isTrue);
      expect(jsLooseEquals(null, jsUndefined), isTrue);
      expect(jsLooseEquals(0, null), isFalse);
      expect(jsLooseEquals(true, 1.0), isTrue);
      expect(jsLooseEquals([1, 2], '1,2'), isTrue);
      expect(jsStrictEquals(1, 1.0), isTrue);
      expect(jsStrictEquals(1, '1'), isFalse);
      expect(jsStrictEquals(double.nan, double.nan), isFalse);
    });
    test('+ concatenates strings, other arithmetic is double-based', () {
      expect(jsAdd('a', 1), 'a1');
      expect(jsAdd(1, 2), 3.0);
      expect(jsAdd([1], 2), '12');
      expect(jsArithmetic(-7, '%', 3), -1.0);
      expect(jsArithmetic(7, '//', 2), 3.0);
      expect(jsString(jsArithmetic(1e18, '*', 1000)), '1e+21');
      expect(jsString(jsArithmetic('a', '-', 1)), 'NaN');
    });
    test('ToNumber of strings, including hex beyond 64 bits', () {
      expect(jsToNumber(' 12 '), 12.0);
      expect(jsToNumber(''), 0.0);
      expect(jsToNumber('0x10'), 16.0);
      expect(jsToNumber('0xffffffffffffffffffff'), 1.2089258196146292e24);
      expect(jsToNumber('1e3'), 1000.0);
      expect(jsToNumber('12px').isNaN, isTrue);
    });
    test('relational comparison of strings is by code unit', () {
      expect(jsCompare('B', '<', 'a'), isTrue);
      expect(jsCompare('10', '<', '9'), isTrue);
      expect(jsCompare(10, '<', '9'), isFalse);
      expect(jsCompare(jsUndefined, '<', 1), isFalse);
    });
  });

  // Documented differences of dart:convert, i.e. what a naive port of the
  // `json` filter or the presets would print: the pitfalls this layer
  // exists to avoid.
  group('dart:convert JsonEncoder differs from JSON.stringify', () {
    test('integral doubles and -0.0 keep their .0', () {
      expect(json.encode([1.0, -0.0, 100.0]), '[1.0,-0.0,100.0]');
      expect(jsonStringify([1.0, -0.0, 100.0]), '[1,0,100]');
    });
    test('withIndent("") is not compact, so json(0) cannot map to it', () {
      expect(const JsonEncoder.withIndent('').convert([1, 2]), '[\n1,\n2\n]');
      expect(jsonStringify([1, 2], indent: 0), '[1,2]');
    });
    test('integer-like keys keep insertion order', () {
      final m = {'b': 1, '2': 2, '10': 3};
      expect(json.encode(m), '{"b":1,"2":2,"10":3}');
      expect(jsonStringify(m), '{"2":2,"10":3,"b":1}');
    });
    test('NaN and Infinity throw instead of printing null', () {
      expect(
        () => json.encode(double.nan),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
      expect(jsonStringify(double.nan), 'null');
    });
    test('string escaping is identical (control chars, lone surrogates)', () {
      for (final s in ['\u0000\u001f\b\f\u000b "\\/ ', 'a\ud800b\udc00c']) {
        expect(json.encode(s), jsonStringify(s));
      }
    });
  });
}

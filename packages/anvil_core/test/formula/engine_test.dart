import 'package:anvil_core/anvil_core.dart';
import 'package:anvil_core/src/formula/evaluator.dart' show maxFormulaTreeDepth;
import 'package:anvil_core/src/formula/lexer.dart';
import 'package:test/test.dart';

void main() {
  group('errors', () {
    test('carry their message', () {
      expect(
        const FormulaSyntaxError('Unexpected end of formula').message,
        'Unexpected end of formula',
      );
      expect(
        const FormulaRuntimeError('Division by zero').toString(),
        'FormulaRuntimeError: Division by zero',
      );
    });

    test('the public functions never throw them', () {
      expect(evaluateFormula('1 +', {}).error, 'Unexpected end of formula');
      expect(evaluateFormula('x', {}).error, "Unknown variable 'x'");
      expect(validateFormula(')'), "Unexpected ')' at position 0");
      expect(extractVariableNames('min(x'), isEmpty);
    });

    test('every Electron message has a test', () {
      // The corpus covers all of these except 'Invalid number', which the
      // lexer makes unreachable (a number token always starts with a digit
      // or '.digit'); parseFloatPrefix is what would produce the NaN.
      expect(parseFloatPrefix('.'), isNaN);
      expect(parseFloatPrefix('1.2.3'), 1.2);
      expect(parseFloatPrefix('5.'), 5);
      expect(parseFloatPrefix('.5.'), 0.5);
      expect(parseFloatPrefix('1..2'), 1);
    });
  });

  group('JavaScript whitespace', () {
    test('NEL is not whitespace, NBSP and BOM are', () {
      expect(isBlankFormula(' ﻿ '), isTrue);
      expect(isBlankFormula('\u0085'), isFalse);
      expect(
        evaluateFormula('\u0085', {}).error,
        "Unexpected character '\u0085' at position 0",
      );
    });
  });

  group('nesting limit', () {
    String parens(int depth) => '${'(' * depth}1${')' * depth}';
    String negations(int depth) => '${'-' * depth}1';

    for (final (kind, build) in [
      ('parentheses', parens),
      ('unary minus', negations),
    ]) {
      test('$kind: maxFormulaNestingDepth parses and evaluates', () {
        final formula = build(maxFormulaNestingDepth);
        expect(validateFormula(formula), isNull);
        expect(evaluateFormula(formula, {}).value, isNotNull);
      });

      test('$kind: one level deeper is an invalid formula', () {
        final formula = build(maxFormulaNestingDepth + 1);
        expect(validateFormula(formula), 'Invalid formula');
        final result = evaluateFormula(formula, {});
        expect(result.error, 'Formula evaluation failed');
        expect(result.isSyntaxError, isFalse);
        expect(extractVariableNames(formula), isEmpty);
      });
    }

    test('a long flat chain parses; past the tree bound it fails', () {
      final fits = List.filled(maxFormulaTreeDepth + 1, 'x').join('+');
      expect(evaluateFormula(fits, {'x': 1}).value, maxFormulaTreeDepth + 1);
      expect(extractVariableNames(fits), ['x']);
      final deeper = List.filled(maxFormulaTreeDepth + 2, 'x').join('+');
      expect(validateFormula(deeper), isNull);
      final result = evaluateFormula(deeper, {'x': 1});
      expect(result.error, 'Formula evaluation failed');
      expect(extractVariableNames(deeper), isEmpty);
    });
  });

  group('FormulaEngine caches', () {
    test('a second evaluation hits both caches', () {
      final engine = FormulaEngine();
      final first = engine.evaluate('floor(a + b)', {'a': 1.5, 'b': 2});
      final second = engine.evaluate('floor(a + b)', {'b': 2, 'a': 1.5});
      expect(second, same(first));
      expect(engine.parseCount, 1);
      expect(engine.evaluationCount, 1);
    });

    test('new bindings evaluate again but reuse the parse', () {
      final engine = FormulaEngine();
      engine.evaluate('a * 2', {'a': 1});
      expect(engine.evaluate('a * 2', {'a': 2}).value, 4);
      expect(engine.evaluate('a * 2', {'a': 2, 'b': 0}).value, 4);
      expect(engine.parseCount, 1);
      expect(engine.evaluationCount, 3);
    });

    test('validate and extractVariableNames share the parse cache', () {
      final engine = FormulaEngine();
      engine.evaluate('max(x, y)', {'x': 1, 'y': 2});
      expect(engine.validate('max(x, y)'), isNull);
      expect(engine.extractVariableNames('max(x, y)'), ['x', 'y']);
      expect(engine.parseCount, 1);
    });

    test('syntax errors are cached too', () {
      final engine = FormulaEngine();
      for (var i = 0; i < 3; i++) {
        final r = engine.evaluate('min(1', {'x': i.toDouble()});
        expect(r.error, "Expected RPAREN but found '' at position 5");
        expect(r.isSyntaxError, isTrue);
      }
      expect(engine.validate('min(1'), isNotNull);
      expect(engine.parseCount, 1);
    });

    test('NaN bindings hit, and -0 and 0 are different keys', () {
      final engine = FormulaEngine();
      engine.evaluate('x', {'x': double.nan});
      engine.evaluate('x', {'x': double.nan});
      expect(engine.evaluationCount, 1);
      final negative = engine.evaluate('min(x, 1)', {'x': -0.0});
      final positive = engine.evaluate('min(x, 1)', {'x': 0.0});
      expect(negative.value!.isNegative, isTrue);
      expect(positive.value!.isNegative, isFalse);
      expect(engine.evaluationCount, 3);
    });

    test('changing the caller\'s map later does not corrupt the cache', () {
      final engine = FormulaEngine();
      final bindings = {'x': 1.0};
      expect(engine.evaluate('x + 1', bindings).value, 2);
      bindings['x'] = 10;
      expect(engine.evaluate('x + 1', bindings).value, 11);
      expect(engine.evaluate('x + 1', {'x': 1}).value, 2);
      expect(engine.evaluationCount, 2);
    });

    test('clear empties both caches', () {
      final engine = FormulaEngine();
      engine.evaluate('1 + 1', {});
      engine.clear();
      engine.evaluate('1 + 1', {});
      expect(engine.parseCount, 2);
      expect(engine.evaluationCount, 2);
    });
  });

  test('the top-level functions are stateless', () {
    expect(evaluateFormula('x', {'x': 1}).value, 1);
    expect(evaluateFormula('x', {'x': 2}).value, 2);
  });
}

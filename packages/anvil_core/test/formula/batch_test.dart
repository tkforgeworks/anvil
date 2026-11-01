import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

List<Map<String, double>> _levels(int count) => [
  for (var level = 1; level <= count; level++)
    {'level': level.toDouble(), 'base_hp': 50, 'hp_growth': 7.3},
];

void _expectSame(
  List<FormulaEvalResult> batch,
  String formula,
  List<Map<String, double>> bindingsList,
) {
  expect(batch, hasLength(bindingsList.length));
  for (final (i, bindings) in bindingsList.indexed) {
    final single = evaluateFormula(formula, bindings);
    expect(batch[i].value, single.value, reason: 'entry $i');
    expect(batch[i].error, single.error, reason: 'entry $i');
    expect(batch[i].isSyntaxError, single.isSyntaxError, reason: 'entry $i');
  }
}

void main() {
  const formula = 'floor(base_hp + level * hp_growth)';

  test('the threshold is the benchmarked constant', () {
    expect(isolateThreshold, 10000);
  });

  test('below the threshold, results match evaluateFormula', () async {
    final bindings = _levels(50);
    _expectSame(await evaluateBatch(formula, bindings), formula, bindings);
  });

  test('at the threshold, via Isolate.run, results match', () async {
    final bindings = _levels(isolateThreshold);
    _expectSame(await evaluateBatch(formula, bindings), formula, bindings);
  });

  test('a lowered threshold sends a small batch to an isolate', () async {
    final bindings = _levels(20);
    _expectSame(
      await evaluateBatch(formula, bindings, threshold: 1),
      formula,
      bindings,
    );
  });

  test('runtime errors are per entry, in order', () async {
    final bindings = [
      for (final x in [2.0, 0.0, -0.0, 4.0]) {'x': x},
    ];
    for (final threshold in [isolateThreshold, 1]) {
      final results = await evaluateBatch(
        '8 / x',
        bindings,
        threshold: threshold,
      );
      expect([for (final r in results) r.value], [4, null, null, 2]);
      expect(results[1].error, 'Division by zero');
      expect(results[2].isSyntaxError, isFalse);
    }
  });

  test('a syntax error is returned for every entry', () async {
    final results = await evaluateBatch('min(level', _levels(5000));
    expect(results, hasLength(5000));
    expect(results.every((r) => r.isSyntaxError), isTrue);
    expect(results.first.error, "Expected RPAREN but found '' at position 9");
  });

  test('an empty batch is empty', () async {
    expect(await evaluateBatch(formula, []), isEmpty);
  });

  test('FormulaEngine.evaluateBatch parses once across batches', () async {
    final engine = FormulaEngine();
    final bindings = _levels(30);
    _expectSame(
      await engine.evaluateBatch(formula, bindings),
      formula,
      bindings,
    );
    _expectSame(
      await engine.evaluateBatch(formula, bindings, threshold: 1),
      formula,
      bindings,
    );
    expect(engine.parseCount, 1);
    expect(engine.evaluationCount, 0);
  });
}

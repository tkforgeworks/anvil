import 'package:anvil/app/domains/classes/classes_growth_fill.dart';
import 'package:anvil_core/anvil_core.dart' show validateFormula;
import 'package:flutter_test/flutter_test.dart';

FillResult fill(
  FillShape shape, {
  int from = 1,
  int to = 5,
  double start = 0,
  int maxLevel = 10,
}) => computeFormulaFill(
  shape: shape,
  fromLevel: from,
  toLevel: to,
  start: start,
  maxLevel: maxLevel,
);

void main() {
  group('Step', () {
    test('writes the start at From lvl and adds the increment per level', () {
      final r = fill(const StepFill(2), from: 1, to: 4, start: 10);
      expect(r.error, isNull);
      expect(r.values, {1: 10, 2: 12, 3: 14, 4: 16});
    });

    test('a negative increment goes down', () {
      expect(fill(const StepFill(-1.5), to: 3, start: 5).values, {
        1: 5,
        2: 3.5,
        3: 2,
      });
    });

    test('chains: a second range seeded from the first one\'s last value '
        'continues it', () {
      final first = fill(const StepFill(2), from: 1, to: 10, start: 10);
      expect(first.values[10], 28);
      final second = fill(
        const StepFill(3),
        from: 10,
        to: 20,
        start: first.values[10]!,
        maxLevel: 50,
      );
      expect(second.values[10], 28);
      expect(second.values[11], 31);
      expect(second.values[20], 58);
    });
  });

  group('Multiply with cap', () {
    test('multiplies the previous value and clamps at the cap', () {
      final r = fill(const MultiplyFill(2, 50), to: 6, start: 5);
      expect(r.values, {1: 5, 2: 10, 3: 20, 4: 40, 5: 50, 6: 50});
    });

    test('never exceeds the cap', () {
      final r = fill(
        const MultiplyFill(1.37, 100),
        to: 15,
        start: 3,
        maxLevel: 20,
      );
      expect(r.values.values, everyElement(lessThanOrEqualTo(100)));
      expect(r.values[15], 100);
    });
  });

  group('Approach limit', () {
    test('closes the rate of the remaining gap each level', () {
      final r = fill(const ApproachFill(100, 0.5), to: 4, start: 0);
      expect(r.values, {1: 0, 2: 50, 3: 75, 4: 87.5});
    });

    test('never exceeds the limit, and a rate of 1 reaches it at once', () {
      final r = fill(const ApproachFill(80, 0.3), to: 10, start: 10);
      expect(r.values.values, everyElement(lessThanOrEqualTo(80)));
      expect(fill(const ApproachFill(80, 1), to: 3, start: 10).values, {
        1: 10,
        2: 80,
        3: 80,
      });
    });

    test('a rate outside (0, 1] is refused with no values', () {
      for (final rate in [0.0, -0.1, 1.01]) {
        final r = fill(ApproachFill(80, rate));
        expect(r.error, fillRateMessage);
        expect(r.values, isEmpty);
      }
    });
  });

  group('Expression', () {
    test('binds level, max_level and prev; prev is the start at From lvl', () {
      final r = fill(
        const ExpressionFill('prev + level'),
        from: 2,
        to: 4,
        start: 10,
      );
      // L2 = 10 + 2, L3 = 12 + 3, L4 = 15 + 4.
      expect(r.values, {2: 12, 3: 15, 4: 19});
      expect(fill(const ExpressionFill('max_level - level'), to: 2).values, {
        1: 9,
        2: 8,
      });
    });

    test('a syntax error stops the fill with the engine message', () {
      final r = fill(const ExpressionFill('prev *'));
      expect(r.values, isEmpty);
      expect(r.error, isNotNull);
      expect(r.error, validateFormula('prev *'));
    });

    test('a runtime error stops the fill with no values', () {
      final unknown = fill(const ExpressionFill('prev + speed'));
      expect(unknown.values, isEmpty);
      expect(unknown.error, contains('speed'));
      final divide = fill(const ExpressionFill('prev / (level - 3)'), start: 1);
      expect(divide.values, isEmpty);
      expect(divide.error, isNotNull);
    });
  });

  test('rounds every value to three decimals and carries the rounded value '
      'as prev', () {
    final r = fill(const StepFill(1 / 3), to: 4, start: 0);
    expect(r.values, {1: 0, 2: 0.333, 3: 0.666, 4: 0.999});
    expect(
      fill(const ExpressionFill('prev + 0.0006'), to: 2, start: 1).values,
      {1: 1.001, 2: 1.002},
    );
  });

  test('From lvl above To lvl is an error with no values', () {
    final r = fill(const StepFill(1), from: 5, to: 2);
    expect(r.error, fillRangeReversedMessage);
    expect(r.values, isEmpty);
  });

  test('a single level writes only the start', () {
    expect(fill(const StepFill(4), from: 3, to: 3, start: 7).values, {3: 7});
  });

  test('the range is limited to 1..max level', () {
    final r = fill(const StepFill(1), from: -2, to: 20, start: 1, maxLevel: 4);
    expect(r.values, {1: 1, 2: 2, 3: 3, 4: 4});
    final outside = fill(const StepFill(1), from: 12, to: 20, maxLevel: 10);
    expect(outside.values, isEmpty);
    expect(outside.error, fillRangeOutsideMessage(10));
  });

  test('a value that is not finite stops the fill', () {
    final r = fill(
      const MultiplyFill(1e200, double.infinity),
      to: 4,
      start: 1e200,
    );
    expect(r.values, isEmpty);
    expect(r.error, fillNotFiniteMessage(2));
  });
}

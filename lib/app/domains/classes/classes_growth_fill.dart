/// The pure rules behind the Stat Growth tab's `Formula fill:` helper
/// (ANVL-140): the values a growth shape gives over a level range, which
/// the helper previews and then bakes into the manual grid.
library;

import 'dart:math' as math;

import 'package:anvil_core/anvil_core.dart';

import 'classes_growth_math.dart';

/// How a Formula fill grows a stat from one level to the next.
sealed class FillShape {
  const FillShape();
}

/// Starts at the start value and adds [increment] per level.
final class StepFill extends FillShape {
  const StepFill(this.increment);

  final double increment;
}

/// Multiplies the previous level's value by [factor], clamped at [cap].
final class MultiplyFill extends FillShape {
  const MultiplyFill(this.factor, this.cap);

  final double factor;
  final double cap;
}

/// Each level closes the fraction [rate] (in (0, 1]) of the remaining gap
/// to [limit], so the value approaches the limit and never crosses it.
final class ApproachFill extends FillShape {
  const ApproachFill(this.limit, this.rate);

  final double limit;
  final double rate;
}

/// A formula over `level`, `max_level` and `prev`, the previous level's
/// value in the range (the start value at the first level).
final class ExpressionFill extends FillShape {
  const ExpressionFill(this.formula);

  final String formula;
}

/// The values a fill gives by level, or the [error] that stopped it (then
/// [values] is empty).
typedef FillResult = ({Map<int, double> values, String? error});

/// The message for a range whose first level is above its last.
const fillRangeReversedMessage = 'From level must not be above To level.';

/// The message for a range with no level inside 1..max level.
String fillRangeOutsideMessage(int maxLevel) =>
    'The range has no level between 1 and $maxLevel.';

/// The message for an Approach limit rate outside (0, 1].
const fillRateMessage = 'Rate must be greater than 0 and at most 1.';

/// The message for a value that is NaN or infinite at [level].
String fillNotFiniteMessage(int level) =>
    'Level $level does not give a finite number.';

/// Walks [fromLevel]..[toLevel], limited to 1..[maxLevel], and returns the
/// value [shape] gives at each level, every value rounded to three
/// decimals with `Math.round` as [interpolateLevels] does. The rounded
/// value is what the next level sees as `prev`, so the values match what a
/// second fill seeded from the grid would continue from.
///
/// Step, Multiply with cap and Approach limit write [start] at the first
/// level and grow from there; Expression evaluates its formula at every
/// level, the first one included, with `prev` bound to [start] there.
/// Stops at the first error (a reversed or empty range, a rate outside
/// (0, 1], a formula's syntax or runtime error, a value that is not
/// finite) and returns it with no values.
FillResult computeFormulaFill({
  required FillShape shape,
  required int fromLevel,
  required int toLevel,
  required double start,
  required int maxLevel,
}) {
  FillResult failed(String error) => (values: const {}, error: error);
  if (fromLevel > toLevel) return failed(fillRangeReversedMessage);
  final first = math.max(fromLevel, 1);
  final last = math.min(toLevel, maxLevel);
  if (first > last) return failed(fillRangeOutsideMessage(maxLevel));
  if (shape is ApproachFill && !(shape.rate > 0 && shape.rate <= 1)) {
    return failed(fillRateMessage);
  }

  final values = <int, double>{};
  var prev = start;
  for (var level = first; level <= last; level++) {
    final double raw;
    if (shape is ExpressionFill) {
      final result = evaluateFormula(shape.formula, {
        ...growthBindings(level, maxLevel),
        'prev': prev,
      });
      final error = result.error;
      if (error != null) return failed(error);
      raw = result.value!;
    } else if (level == first) {
      raw = start;
    } else {
      raw = switch (shape) {
        StepFill(:final increment) => prev + increment,
        MultiplyFill(:final factor, :final cap) => math.min(prev * factor, cap),
        ApproachFill(:final limit, :final rate) => prev + (limit - prev) * rate,
        ExpressionFill() => throw StateError('unreachable'),
      };
    }
    if (!raw.isFinite) return failed(fillNotFiniteMessage(level));
    final value = jsRound(raw * 1000) / 1000;
    values[level] = value;
    prev = value;
  }
  return (values: values, error: null);
}

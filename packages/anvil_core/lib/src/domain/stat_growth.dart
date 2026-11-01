import '../formula/formula_engine.dart' show evaluateFormula;
import 'class_types.dart';

/// A class's stat growth as the NPC stat block, the derived stat previews and
/// the export see it; ports 0.1.6 `ClassRepository.getStatGrowthWithFormulas`.
///
/// Manual entries for a stat that has a formula are dropped. Each formula is
/// evaluated for levels 1 to [maxLevel] with the bindings `level` and
/// `max_level`; a level whose evaluation fails gets 0, as 0.1.6's
/// `result.value ?? 0` did (a NaN result stays NaN, as in JavaScript).
///
/// The result holds the kept manual entries in [manual]'s order, then each
/// formula's levels in [formulas]' order, as 0.1.6's `entries` array.
Map<StatGrowthKey, double> resolveStatGrowth({
  required Map<StatGrowthKey, double> manual,
  required Map<String, String> formulas,
  required int maxLevel,
}) {
  final resolved = <StatGrowthKey, double>{
    for (final entry in manual.entries)
      if (!formulas.containsKey(entry.key.statId)) entry.key: entry.value,
  };
  for (final formula in formulas.entries) {
    for (var level = 1; level <= maxLevel; level++) {
      final result = evaluateFormula(formula.value, {
        'level': level.toDouble(),
        'max_level': maxLevel.toDouble(),
      });
      resolved[StatGrowthKey(formula.key, level)] = result.value ?? 0;
    }
  }
  return Map.unmodifiable(resolved);
}

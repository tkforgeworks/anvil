/// The pure rules behind the Stat Growth and Derived Stats tabs, ported
/// from 0.1.6's `StatGrowthEditor.tsx` and `DerivedStatsEditor.tsx`.
library;

import 'package:anvil_core/anvil_core.dart';

/// JavaScript's `Math.round`: halves round towards positive infinity
/// (`-2.5` → `-2`), where Dart's `round` rounds them away from zero.
double jsRound(double x) {
  if (!x.isFinite) return x;
  final floor = x.floorToDouble();
  return x - floor >= 0.5 ? floor + 1 : floor;
}

/// The bindings a stat growth formula sees at [level] (0.1.6 `level`,
/// `max_level`).
Map<String, double> growthBindings(int level, int maxLevel) => {
  'level': level.toDouble(),
  'max_level': maxLevel.toDouble(),
};

/// The bindings for levels 1 to [maxLevel], one map per level.
List<Map<String, double>> growthBindingsList(int maxLevel) => [
  for (var level = 1; level <= maxLevel; level++)
    growthBindings(level, maxLevel),
];

/// One formula stat's computed values: [values] by level (index 0 is level
/// 1), null until an evaluation succeeded at level 1; [error] the message
/// of the first level that failed, null when every level evaluated.
final class GrowthPreview {
  const GrowthPreview({this.values, this.error});

  final List<double>? values;
  final String? error;

  /// The value at [level], or null when there is none.
  double? at(int level) {
    final v = values;
    if (v == null || level < 1 || level > v.length) return null;
    return v[level - 1];
  }

  @override
  bool operator ==(Object other) =>
      other is GrowthPreview &&
      other.error == error &&
      _sameValues(other.values, values);

  @override
  int get hashCode =>
      Object.hash(error, values == null ? null : Object.hashAll(values!));

  static bool _sameValues(List<double>? a, List<double>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i] && !(a[i].isNaN && b[i].isNaN)) return false;
    }
    return true;
  }

  @override
  String toString() => 'GrowthPreview($values, $error)';
}

/// The preview a batch of [results] (levels 1 to N, in order) gives,
/// following 0.1.6's `handleFormulaChange`: a failure at level 1 shows
/// that error and keeps the [previous] values on screen; otherwise every
/// level gets its value (`value ?? 0`) and the first later failure, if
/// any, is the error.
GrowthPreview growthPreviewFrom(
  List<FormulaEvalResult> results, {
  GrowthPreview? previous,
}) {
  if (results.isEmpty) return const GrowthPreview(values: []);
  final first = results.first.error;
  if (first != null) {
    return GrowthPreview(values: previous?.values, error: first);
  }
  String? error;
  for (final r in results) {
    if (r.error != null) {
      error = r.error;
      break;
    }
  }
  return GrowthPreview(
    values: List.unmodifiable([for (final r in results) r.value ?? 0]),
    error: error,
  );
}

/// The values Keep Values bakes for a stat with [formula]: its values for
/// levels 1 to [maxLevel], evaluated now so they match the formula even
/// inside the preview's debounce; when it fails at level 1, [onScreen]
/// (what the grid shows), else null.
List<double>? bakedGrowthValues(
  String formula,
  int maxLevel, {
  List<double>? onScreen,
}) => growthPreviewFrom([
  for (final b in growthBindingsList(maxLevel)) evaluateFormula(formula, b),
], previous: GrowthPreview(values: onScreen)).values;

/// The value the grid, the chart and the derived stat previews show for
/// [statId] at [level]: a formula stat's computed value once there is one,
/// else (a manual stat, or a formula stat never computed) the draft's
/// manual entry, as 0.1.6's grid kept the manual values until the first
/// evaluation replaced them. Null for an empty cell.
double? displayedGrowth(
  ClassDraft draft,
  Map<String, GrowthPreview> previews,
  String statId,
  int level,
) {
  if (draft.statGrowthFormulas.containsKey(statId)) {
    final computed = previews[statId]?.at(level);
    if (computed != null) return computed;
  }
  return draft.statGrowth[StatGrowthKey(statId, level)];
}

/// 0.1.6's interpolation: for each level from [fromLevel] to [toLevel]
/// (limited to 1..[maxLevel]), the straight line between the two values,
/// rounded to three decimals with `Math.round`. Empty unless
/// `fromLevel < toLevel`, the condition 0.1.6 enabled Apply on.
Map<int, double> interpolateLevels({
  required int fromLevel,
  required double fromValue,
  required int toLevel,
  required double toValue,
  required int maxLevel,
}) {
  if (fromLevel >= toLevel) return const {};
  final range = toLevel - fromLevel;
  return {
    for (var level = fromLevel; level <= toLevel; level++)
      if (level >= 1 && level <= maxLevel)
        level:
            jsRound(
              (fromValue +
                      (level - fromLevel) / range * (toValue - fromValue)) *
                  1000,
            ) /
            1000,
  };
}

/// 0.1.6 `defaultBreakpointLevels`: every level up to 5, else six points
/// spread over 0 %, 20 % … 100 % of [maxLevel], deduplicated and sorted.
List<int> defaultBreakpointLevels(int maxLevel) {
  if (maxLevel <= 5) return [for (var i = 1; i <= maxLevel; i++) i];
  final levels = <int>{
    for (final p in const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
      jsRound(p * maxLevel).toInt().clamp(1, maxLevel),
  }.toList()..sort();
  return levels;
}

/// 0.1.6 `applyOutputConfig`: an integer stat is floored or rounded as its
/// rounding mode says; a float stat is left as it is.
double applyOutputConfig(DerivedStatDefinition def, double value) {
  if (def.outputType == DerivedStatOutputType.float) return value;
  return switch (def.roundingMode) {
    RoundingMode.floor => value.floorToDouble(),
    RoundingMode.round => jsRound(value),
    RoundingMode.none => value,
  };
}

/// 0.1.6 `formatResult` over [applyOutputConfig]: an integer stat as its
/// rounded whole number, a float stat with up to three decimals.
String formatDerivedValue(DerivedStatDefinition def, double raw) {
  final value = applyOutputConfig(def, raw);
  if (!value.isFinite) return _jsNonFinite(value);
  if (def.outputType == DerivedStatOutputType.integer) {
    return _wholeNumber(jsRound(value));
  }
  final fixed = value.toStringAsFixed(3);
  // JavaScript's `.replace(/\.?0+$/, '')`.
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

String _wholeNumber(double value) =>
    value.abs() < 1e21 ? value.toInt().toString() : value.toString();

String _jsNonFinite(double value) => value.isNaN
    ? 'NaN'
    : value > 0
    ? 'Infinity'
    : '-Infinity';

/// The bindings a derived stat formula of class [draft] sees at [level],
/// as 0.1.6's `DerivedStatsEditor` built them: every stat's export key
/// bound to its [growthAt] value at that level (0 when empty), then
/// `resource_multiplier`, then the metadata fields with a non-empty key
/// (overwriting).
///
/// The validation engine's `buildClassLevel1Bindings` binds the same
/// names at level 1 but puts `resource_multiplier` last; the two differ
/// only for a metadata field named `resource_multiplier`.
Map<String, double> derivedBaseBindings({
  required List<MetaStat> stats,
  required ClassDraft draft,
  required double? Function(String statId) growthAt,
}) => {
  for (final stat in stats) stat.exportKey: growthAt(stat.id) ?? 0,
  'resource_multiplier': draft.resourceMultiplier,
  for (final field in draft.metadataFields)
    if (field.fieldKey.isNotEmpty) field.fieldKey: field.value,
};

/// The formula [def] uses for a class with [overrides]: the override when
/// there is one, else the project's.
String effectiveFormula(
  DerivedStatDefinition def,
  Map<String, String> overrides,
) => overrides[def.id] ?? def.formula;

/// The derived stats in a cycle once [overrides] replace their formulas
/// ([findDerivedStatCycle], the validation engine's check), as ids.
Set<String> derivedCycleIds(
  List<DerivedStatDefinition> defs,
  Map<String, String> overrides,
) {
  final cycle = findDerivedStatCycle([
    for (final d in defs)
      DerivedStatFormula(
        id: d.id,
        displayName: d.displayName,
        exportKey: d.exportKey,
        formula: d.formula,
      ),
  ], overrides: overrides);
  return cycle == null ? const {} : cycle.ids.toSet();
}

/// 0.1.6 `evaluateAllAtLevel`: evaluates every definition not in
/// [cyclicIds] in passes, each pass taking the definitions whose
/// derived-stat variables already have values. A definition's value is
/// bound under its export key with [applyOutputConfig] applied; one that
/// fails, or depends on one that failed or sits in a cycle, binds
/// nothing, so its dependents are never evaluated and have no result.
Map<String, FormulaEvalResult> evaluateDerivedAtLevel({
  required List<DerivedStatDefinition> defs,
  required Map<String, String> overrides,
  required Set<String> cyclicIds,
  required Map<String, double> baseBindings,
  required FormulaEngine engine,
}) {
  final results = <String, FormulaEvalResult>{};
  final bound = {...baseBindings};
  final derivedKeys = {for (final d in defs) d.exportKey};
  final remaining = [
    for (final d in defs)
      if (!cyclicIds.contains(d.id)) d,
  ];
  // A pass over the remaining definitions in order, as 0.1.6's batch.
  for (var pass = 0; remaining.isNotEmpty && pass <= defs.length; pass++) {
    final ready = [
      for (final d in remaining)
        if (engine
            .extractVariableNames(effectiveFormula(d, overrides))
            .every((v) => !derivedKeys.contains(v) || bound.containsKey(v)))
          d,
    ];
    if (ready.isEmpty) break;
    final snapshot = Map<String, double>.unmodifiable(bound);
    for (final d in ready) {
      final result = engine.evaluate(effectiveFormula(d, overrides), snapshot);
      results[d.id] = result;
      if (result.value case final value?) {
        bound[d.exportKey] = applyOutputConfig(d, value);
      }
      remaining.remove(d);
    }
  }
  return results;
}

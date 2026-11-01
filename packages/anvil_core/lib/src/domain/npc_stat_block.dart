/// The NPC stat block: inherited, override and effective value per stat.
///
/// Ported from `computeInherited` and the row arithmetic of 0.1.6's
/// `src/renderer/src/components/NpcStatBlockPanel.tsx`, moved into the core
/// as a pure function.
library;

import 'class_types.dart';
import 'meta.dart';
import 'npc_types.dart';

/// One row of the stat block.
class NpcStatBlockRow {
  const NpcStatBlockRow({
    required this.statId,
    required this.inherited,
    required this.overrideValue,
    required this.effective,
  });

  final String statId;

  /// Sum over the class assignments of each class's growth at its level.
  final double inherited;

  /// The NPC's combat stat override, or `null` when there is none.
  final double? overrideValue;

  /// [overrideValue] when set, otherwise [inherited] (0.1.6 "Final").
  final double effective;

  /// Whether an override replaces the inherited value.
  bool get hasOverride => overrideValue != null;

  @override
  bool operator ==(Object other) =>
      other is NpcStatBlockRow &&
      other.statId == statId &&
      other.inherited == inherited &&
      other.overrideValue == overrideValue &&
      other.effective == effective;

  @override
  int get hashCode => Object.hash(statId, inherited, overrideValue, effective);

  @override
  String toString() =>
      'NpcStatBlockRow($statId, inherited: $inherited, '
      'override: $overrideValue, effective: $effective)';
}

/// Computes the stat block of an NPC, one row per stat in [stats] ordered by
/// `sortOrder` (ties keep their order in [stats], as JavaScript's stable
/// sort does).
///
/// [growthByClass] maps a class id to that class's resolved stat growth:
/// for a stat in formula mode the caller supplies the evaluated values
/// (0.1.6 `classes:get-stat-growth` evaluates each level and uses 0 for an
/// error), for a manual stat the stored entries.
///
/// As in 0.1.6:
/// - the inherited value starts at 0 and adds, in assignment order, the
///   growth of each assigned class at its assigned level;
/// - an assignment whose class has no growth in [growthByClass], or whose
///   class has no entry for that stat at that level, adds nothing;
/// - an override applies when [combatStats] maps the stat to a non-null
///   value; a missing key or a `null` value means no override;
/// - the effective value is the override when there is one, else the
///   inherited value.
List<NpcStatBlockRow> computeNpcStatBlock({
  required List<MetaStat> stats,
  required List<NpcClassAssignment> classAssignments,
  required Map<String, Map<StatGrowthKey, double>> growthByClass,
  required Map<String, double?> combatStats,
}) {
  final indexed = [for (var i = 0; i < stats.length; i++) (i, stats[i])];
  indexed.sort((a, b) {
    final bySortOrder = a.$2.sortOrder.compareTo(b.$2.sortOrder);
    return bySortOrder != 0 ? bySortOrder : a.$1.compareTo(b.$1);
  });

  return [
    for (final (_, stat) in indexed)
      _row(stat.id, classAssignments, growthByClass, combatStats),
  ];
}

NpcStatBlockRow _row(
  String statId,
  List<NpcClassAssignment> classAssignments,
  Map<String, Map<StatGrowthKey, double>> growthByClass,
  Map<String, double?> combatStats,
) {
  var inherited = 0.0;
  for (final assignment in classAssignments) {
    final growth = growthByClass[assignment.classId];
    if (growth == null) continue;
    final value = growth[StatGrowthKey(statId, assignment.level)];
    if (value != null) inherited += value;
  }
  final overrideValue = combatStats[statId];
  return NpcStatBlockRow(
    statId: statId,
    inherited: inherited,
    overrideValue: overrideValue,
    effective: overrideValue ?? inherited,
  );
}

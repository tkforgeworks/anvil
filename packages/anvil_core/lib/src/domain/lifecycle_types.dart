/// Cross-domain lifecycle vocabulary: the domain keys of 0.1.6's
/// `lifecycle:*` channels and the delete impact summary.
///
/// Ported from `LifecycleDomain`, `DeleteImpactReference` and
/// `DeleteImpactSummary` in 0.1.6's `src/shared/domain-types.ts`.
library;

import 'package:meta/meta.dart';

import '../db/save_descriptions.dart';
import 'equality.dart';

/// The six record domains as 0.1.6's `LifecycleDomain` names them, with
/// the table each one lives in and its save history labels.
enum LifecycleDomain {
  classes('classes', 'classes', SaveDomain.classes),
  abilities('abilities', 'abilities', SaveDomain.abilities),
  items('items', 'items', SaveDomain.items),
  recipes('recipes', 'recipes', SaveDomain.recipes),
  npcs('npcs', 'npcs', SaveDomain.npcs),
  lootTables('loot-tables', 'loot_tables', SaveDomain.lootTables);

  const LifecycleDomain(this.value, this.table, this.saveDomain);

  /// The 0.1.6 string (`loot-tables` for loot tables).
  final String value;

  /// The domain's table, for the core's own SQL.
  @internal
  final String table;

  /// The labels the save history uses for this domain.
  final SaveDomain saveDomain;

  /// The domain whose [value] is [value]; throws [ArgumentError] otherwise.
  static LifecycleDomain fromValue(String value) {
    for (final d in values) {
      if (d.value == value) return d;
    }
    throw ArgumentError.value(value, 'value', 'Unknown lifecycle domain');
  }
}

/// One kind of active record that references the records about to be
/// deleted; ports 0.1.6 `DeleteImpactReference`.
class DeleteImpactReference {
  const DeleteImpactReference({
    required this.domain,
    required this.field,
    required this.recordCount,
    required this.description,
  });

  /// The domain of the referencing records.
  final LifecycleDomain domain;

  /// The referencing column (`output_item_id`, `loot_table_id`) or junction
  /// table (`npc_class_assignments`, ...).
  final String field;

  /// Distinct active referencing records.
  final int recordCount;

  /// 0.1.6's text, such as `recipe ingredients`.
  final String description;

  @override
  bool operator ==(Object other) =>
      other is DeleteImpactReference &&
      other.domain == domain &&
      other.field == field &&
      other.recordCount == recordCount &&
      other.description == description;

  @override
  int get hashCode => Object.hash(domain, field, recordCount, description);

  @override
  String toString() =>
      'DeleteImpactReference(${domain.value}, $field, $recordCount, '
      '$description)';
}

/// What deleting a set of records would affect; ports 0.1.6
/// `DeleteImpactSummary`.
class DeleteImpact {
  DeleteImpact({
    required this.recordCount,
    required List<DeleteImpactReference> references,
  }) : references = List.unmodifiable(references);

  /// The number of ids asked about, as 0.1.6's `ids.length`.
  final int recordCount;

  /// One entry per reverse reference with at least one active referencing
  /// record, in 0.1.6's order.
  final List<DeleteImpactReference> references;

  @override
  bool operator ==(Object other) =>
      other is DeleteImpact &&
      other.recordCount == recordCount &&
      listEquals(other.references, references);

  @override
  int get hashCode => Object.hash(recordCount, listHash(references));

  @override
  String toString() => 'DeleteImpact($recordCount, $references)';
}

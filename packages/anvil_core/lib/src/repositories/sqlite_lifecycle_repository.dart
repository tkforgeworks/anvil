import '../db/project_database.dart';
import '../db/save_descriptions.dart';
import '../domain/lifecycle_types.dart';
import '../project/project_metadata.dart';
import 'lifecycle_repository.dart';

/// What 0.1.6 recorded for an empty trash: one change per domain with no
/// name, which `generateSaveDescription` summarised as "Changes across 6
/// domains" whatever the trash held.
const String _emptyTrashDescription = 'Changes across 6 domains';

/// The domains whose records own `custom_field_values` rows (the
/// `domain` column holds [LifecycleDomain.value]).
const Set<LifecycleDomain> _withCustomFields = {
  LifecycleDomain.items,
  LifecycleDomain.npcs,
};

/// One reverse reference of 0.1.6's `REVERSE_REFS`: a direct foreign key
/// column on [affected], or a junction table owned by [affected].
final class _ReverseRef {
  const _ReverseRef.direct(this.affected, this.field, this.description)
    : targetFk = null,
      ownerFk = null;

  const _ReverseRef.junction(
    this.affected,
    this.field,
    String this.targetFk,
    String this.ownerFk,
    this.description,
  );

  final LifecycleDomain affected;

  /// The foreign key column (direct) or the junction table.
  final String field;
  final String? targetFk;
  final String? ownerFk;
  final String description;
}

/// 0.1.6 `impact.ts` `REVERSE_REFS`, in its order.
const Map<LifecycleDomain, List<_ReverseRef>> _reverseRefs = {
  LifecycleDomain.classes: [
    _ReverseRef.junction(
      LifecycleDomain.npcs,
      'npc_class_assignments',
      'class_id',
      'npc_id',
      'NPC class assignments',
    ),
  ],
  LifecycleDomain.abilities: [
    _ReverseRef.junction(
      LifecycleDomain.classes,
      'class_ability_assignments',
      'ability_id',
      'class_id',
      'class ability assignments',
    ),
    _ReverseRef.junction(
      LifecycleDomain.npcs,
      'npc_ability_assignments',
      'ability_id',
      'npc_id',
      'NPC ability assignments',
    ),
  ],
  LifecycleDomain.items: [
    _ReverseRef.direct(
      LifecycleDomain.recipes,
      'output_item_id',
      'recipe output items',
    ),
    _ReverseRef.junction(
      LifecycleDomain.recipes,
      'recipe_ingredients',
      'item_id',
      'recipe_id',
      'recipe ingredients',
    ),
    _ReverseRef.junction(
      LifecycleDomain.lootTables,
      'loot_table_entries',
      'item_id',
      'loot_table_id',
      'loot table entries',
    ),
  ],
  LifecycleDomain.recipes: [],
  LifecycleDomain.npcs: [],
  LifecycleDomain.lootTables: [
    _ReverseRef.direct(
      LifecycleDomain.npcs,
      'loot_table_id',
      'NPC loot table references',
    ),
  ],
};

String _placeholders(int n) => List.filled(n, '?').join(', ');

/// `RecordCounts` from one value per domain.
RecordCounts _counts(int Function(LifecycleDomain) count) => RecordCounts(
  classes: count(LifecycleDomain.classes),
  abilities: count(LifecycleDomain.abilities),
  items: count(LifecycleDomain.items),
  recipes: count(LifecycleDomain.recipes),
  npcs: count(LifecycleDomain.npcs),
  lootTables: count(LifecycleDomain.lootTables),
);

/// A bulk operation's history text: 0.1.6 recorded one nameless change per
/// id, which `generateSaveDescription` described as `Item deleted` for one
/// record and `3 items deleted` for several.
String _bulkDescription(LifecycleDomain domain, int count, SaveAction action) {
  if (count != 1) return bulkChanged(domain.saveDomain, count, action);
  return switch (action) {
    SaveAction.deleted => recordDeleted(domain.saveDomain, ''),
    SaveAction.restored => recordRestored(domain.saveDomain, ''),
    SaveAction.hardDeleted => recordHardDeleted(domain.saveDomain, ''),
    _ => throw ArgumentError.value(action, 'action'),
  };
}

/// `LifecycleRepository` on a [ProjectDatabase], porting 0.1.6's
/// `lifecycle.handlers.ts`, `impact.ts` and `getWeeklyDeltas`.
final class SqliteLifecycleRepository implements LifecycleRepository {
  SqliteLifecycleRepository(this._db);

  final ProjectDatabase _db;

  @override
  Future<RecordCounts> countDeleted() async => _db.read(
    (tx) => _counts(
      (d) =>
          tx
                  .select(
                    'SELECT COUNT(*) AS cnt FROM ${d.table} '
                    'WHERE deleted_at IS NOT NULL',
                  )
                  .single['cnt']
              as int,
    ),
  );

  @override
  Future<int> bulkSoftDelete(LifecycleDomain domain, List<String> ids) async =>
      _bulk(
        domain,
        ids,
        SaveAction.deleted,
        'deleted_at IS NULL',
        (tx, table, where, ids) => tx.execute(
          'UPDATE $table '
          "SET deleted_at = COALESCE(deleted_at, datetime('now')), "
          "updated_at = datetime('now') WHERE $where",
          ids,
        ),
      );

  @override
  Future<int> bulkRestore(LifecycleDomain domain, List<String> ids) async =>
      _bulk(
        domain,
        ids,
        SaveAction.restored,
        'deleted_at IS NOT NULL',
        (tx, table, where, ids) => tx.execute(
          "UPDATE $table SET deleted_at = NULL, updated_at = datetime('now') "
          'WHERE $where',
          ids,
        ),
      );

  @override
  Future<int> bulkHardDelete(LifecycleDomain domain, List<String> ids) async =>
      _bulk(domain, ids, SaveAction.hardDeleted, null, (tx, table, where, ids) {
        // `custom_field_values` has no foreign key to its record; 0.1.6's
        // bulk delete left the rows behind, its per-record delete did not.
        if (_withCustomFields.contains(domain)) {
          tx.execute(
            'DELETE FROM custom_field_values WHERE domain = ? '
            'AND record_id IN (${_placeholders(ids.length)})',
            [domain.value, ...ids],
          );
        }
        tx.execute('DELETE FROM $table WHERE $where', ids);
      });

  /// Finds the ids among [ids] that exist and match [state], then, when
  /// there are any, runs [write] on exactly those in one save transaction
  /// described with their count.
  int _bulk(
    LifecycleDomain domain,
    List<String> ids,
    SaveAction action,
    String? state,
    void Function(SaveScope tx, String table, String where, List<String> ids)
    write,
  ) {
    final distinct = ids.toSet().toList();
    if (distinct.isEmpty) return 0;
    final table = domain.table;
    final where = [
      'id IN (${_placeholders(distinct.length)})',
      ?state,
    ].join(' AND ');
    final matched = _db.read(
      (tx) => [
        for (final r in tx.select('SELECT id FROM $table WHERE $where', [
          ...distinct,
        ]))
          r['id'] as String,
      ],
    );
    if (matched.isEmpty) return 0;
    _db.saveTransaction(_bulkDescription(domain, matched.length, action), (tx) {
      write(tx, table, 'id IN (${_placeholders(matched.length)})', matched);
    });
    return matched.length;
  }

  @override
  Future<int> emptyTrash() async {
    final deleted = await countDeleted();
    final total =
        deleted.classes +
        deleted.abilities +
        deleted.items +
        deleted.recipes +
        deleted.npcs +
        deleted.lootTables;
    if (total == 0) return 0;
    _db.saveTransaction(_emptyTrashDescription, (tx) {
      // 0.1.6's `DOMAIN_TABLES` order.
      for (final domain in LifecycleDomain.values) {
        if (_withCustomFields.contains(domain)) {
          tx.execute(
            'DELETE FROM custom_field_values WHERE domain = ? '
            'AND record_id IN (SELECT id FROM ${domain.table} '
            'WHERE deleted_at IS NOT NULL)',
            [domain.value],
          );
        }
        tx.execute('DELETE FROM ${domain.table} WHERE deleted_at IS NOT NULL');
      }
    });
    return total;
  }

  @override
  Future<DeleteImpact> computeDeleteImpact(
    LifecycleDomain domain,
    List<String> ids,
  ) async {
    if (ids.isEmpty) return DeleteImpact(recordCount: 0, references: []);
    final placeholders = _placeholders(ids.length);
    return _db.read((tx) {
      final references = <DeleteImpactReference>[];
      for (final ref in _reverseRefs[domain]!) {
        final affectedTable = ref.affected.table;
        final sql = ref.ownerFk == null
            ? 'SELECT COUNT(DISTINCT id) AS cnt FROM $affectedTable '
                  'WHERE ${ref.field} IN ($placeholders) '
                  'AND deleted_at IS NULL'
            : 'SELECT COUNT(DISTINCT j.${ref.ownerFk}) AS cnt '
                  'FROM ${ref.field} j '
                  'JOIN $affectedTable o ON o.id = j.${ref.ownerFk} '
                  'WHERE j.${ref.targetFk} IN ($placeholders) '
                  'AND o.deleted_at IS NULL';
        final count = tx.select(sql, ids).single['cnt'] as int;
        if (count > 0) {
          references.add(
            DeleteImpactReference(
              domain: ref.affected,
              field: ref.field,
              recordCount: count,
              description: ref.description,
            ),
          );
        }
      }
      return DeleteImpact(recordCount: ids.length, references: references);
    });
  }

  @override
  Future<RecordCounts> weeklyDeltas() async => _db.read((tx) {
    int count(String sql) => tx.select(sql).single['cnt'] as int;
    return _counts(
      (d) =>
          count(
            'SELECT COUNT(*) AS cnt FROM ${d.table} '
            "WHERE created_at >= datetime('now', '-7 days') "
            'AND deleted_at IS NULL',
          ) -
          count(
            'SELECT COUNT(*) AS cnt FROM ${d.table} '
            "WHERE deleted_at >= datetime('now', '-7 days')",
          ),
    );
  });
}

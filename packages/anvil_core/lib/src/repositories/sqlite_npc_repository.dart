import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../db/errors.dart';
import '../db/project_database.dart';
import '../db/save_descriptions.dart';
import '../domain/class_types.dart';
import '../domain/meta.dart';
import '../domain/npc_save_blockers.dart';
import '../domain/npc_stat_block.dart';
import '../domain/npc_types.dart';
import '../domain/record_list_mode.dart';
import '../domain/stat_growth.dart';
import '../export/js_compat.dart' show jsonStringify;
import 'npc_repository.dart';
import 'record_helpers.dart';
import 'record_id.dart';

/// `SELECT` through a [ReadScope] or a [SaveScope].
typedef _Select = ResultSet Function(String sql, [List<Object?> parameters]);

const String _table = 'npcs';

/// 0.1.6 `npc.repository.ts` `SELECT_COLS`.
const String _columns =
    'id, display_name, export_key, description, npc_type_id, loot_table_id, '
    'combat_stats_json, created_at, updated_at, deleted_at';

const String _insert =
    'INSERT INTO $_table (id, display_name, export_key, description, '
    'npc_type_id, loot_table_id, combat_stats_json) '
    'VALUES (?, ?, ?, ?, ?, ?, ?)';

/// 0.1.6 `DomainRepository.list`'s three `WHERE` clauses.
String _where(RecordListMode mode) => switch (mode) {
  RecordListMode.active => 'WHERE deleted_at IS NULL',
  RecordListMode.all => '',
  RecordListMode.deletedOnly => 'WHERE deleted_at IS NOT NULL',
};

/// `JSON.parse(combat_stats_json)`, keeping the stored key order. A `null`
/// value is kept; anything else that is not a number is skipped, since the
/// draft holds numbers only.
Map<String, double?> _decodeCombatStats(String json) => {
  for (final e in (jsonDecode(json) as Map<String, Object?>).entries)
    if (e.value == null)
      e.key: null
    else if (e.value case final num value)
      e.key: value.toDouble(),
};

/// `JSON.stringify(combatStats)`: JavaScript key order and number
/// formatting, so `{"hp":35,"armor":2}` round-trips byte for byte.
String _encodeCombatStats(Map<String, double?> combatStats) =>
    jsonStringify(combatStats)!;

NpcRecord _record(Row r) => NpcRecord(
  id: r['id'] as String,
  displayName: r['display_name'] as String,
  exportKey: r['export_key'] as String,
  description: r['description'] as String,
  npcTypeId: r['npc_type_id'] as String,
  lootTableId: r['loot_table_id'] as String?,
  combatStats: _decodeCombatStats(r['combat_stats_json'] as String),
  createdAt: r['created_at'] as String,
  updatedAt: r['updated_at'] as String,
  deletedAt: r['deleted_at'] as String?,
);

NpcRecord _get(_Select select, String id) {
  final rows = select('SELECT $_columns FROM $_table WHERE id = ?', [id]);
  if (rows.isEmpty) throw RecordNotFound(_table, id);
  return _record(rows.single);
}

/// 0.1.6 `getClassAssignments`.
List<NpcClassAssignment> _classAssignments(_Select select, String id) => [
  for (final r in select(
    'SELECT class_id, level FROM npc_class_assignments '
    'WHERE npc_id = ? ORDER BY sort_order',
    [id],
  ))
    NpcClassAssignment(
      classId: r['class_id'] as String,
      level: r['level'] as int,
    ),
];

/// 0.1.6 `getAbilityAssignments`.
List<String> _abilityIds(_Select select, String id) => [
  for (final r in select(
    'SELECT ability_id FROM npc_ability_assignments '
    'WHERE npc_id = ? ORDER BY sort_order',
    [id],
  ))
    r['ability_id'] as String,
];

/// Every value row of the NPC, as 0.1.6's `getCustomFieldValues`.
Map<String, String?> _values(_Select select, String id) => {
  for (final r in select(
    'SELECT field_definition_id, value FROM custom_field_values '
    "WHERE domain = 'npcs' AND record_id = ?",
    [id],
  ))
    r['field_definition_id'] as String: r['value'] as String?,
};

NpcDraft _draft(_Select select, String id) {
  final record = _get(select, id);
  return NpcDraft(
    displayName: record.displayName,
    exportKey: record.exportKey,
    description: record.description,
    npcTypeId: record.npcTypeId,
    lootTableId: record.lootTableId,
    combatStats: record.combatStats,
    classAssignments: _classAssignments(select, id),
    abilityIds: _abilityIds(select, id),
    customFieldValues: _values(select, id),
  );
}

void _checkExportKey(SaveScope tx, String exportKey, String id) {
  final clash = tx.select(
    'SELECT 1 FROM $_table WHERE export_key = ? AND id != ?',
    [exportKey, id],
  );
  if (clash.isNotEmpty) throw DuplicateExportKey(exportKey);
}

/// 0.1.6 `setClassAssignments` and `setAbilityAssignments` without the
/// delete: `sort_order` = list index.
void _insertAssignments(
  SaveScope tx,
  String npcId,
  List<NpcClassAssignment> classAssignments,
  List<String> abilityIds,
) {
  for (final (i, a) in classAssignments.indexed) {
    tx.execute(
      'INSERT INTO npc_class_assignments (npc_id, class_id, level, '
      'sort_order) VALUES (?, ?, ?, ?)',
      [npcId, a.classId, a.level, i],
    );
  }
  for (final (i, abilityId) in abilityIds.indexed) {
    tx.execute(
      'INSERT INTO npc_ability_assignments (npc_id, ability_id, sort_order) '
      'VALUES (?, ?, ?)',
      [npcId, abilityId, i],
    );
  }
}

void _insertValue(SaveScope tx, String npcId, String fieldId, String? value) {
  tx.execute(
    'INSERT INTO custom_field_values '
    '(domain, record_id, field_definition_id, value) '
    "VALUES ('npcs', ?, ?, ?)",
    [npcId, fieldId, value],
  );
}

/// `NpcRepository` on a [ProjectDatabase], porting 0.1.6's
/// `npc.repository.ts` and the NPC side of `custom-fields.handlers.ts`,
/// with the get/set pairs folded into [load] and [save].
final class SqliteNpcRepository implements NpcRepository {
  SqliteNpcRepository(this._db);

  final ProjectDatabase _db;

  @override
  Future<List<NpcRecord>> list({
    RecordListMode mode = RecordListMode.active,
  }) async => _db.read(
    (tx) => [
      for (final r in tx.select(
        'SELECT $_columns FROM $_table ${_where(mode)} '
        'ORDER BY display_name COLLATE NOCASE',
      ))
        _record(r),
    ],
  );

  @override
  Future<int> countActive() async => _db.read(
    (tx) =>
        tx
                .select(
                  'SELECT COUNT(*) AS count FROM $_table '
                  'WHERE deleted_at IS NULL',
                )
                .single['count']
            as int,
  );

  @override
  Future<NpcRecord> get(String id) async =>
      _db.read((tx) => _get(tx.select, id));

  @override
  Future<NpcDraft> load(String id) async =>
      _db.read((tx) => _draft(tx.select, id));

  @override
  Future<NpcRecord> create(CreateNpcInput input) async => _db.saveTransaction(
    recordCreated(SaveDomain.npcs, input.displayName),
    (tx) {
      final id = newRecordId();
      _checkExportKey(tx, input.exportKey, id);
      tx.execute(_insert, [
        id,
        input.displayName,
        input.exportKey,
        input.description,
        input.npcTypeId,
        input.lootTableId,
        _encodeCombatStats(input.combatStats),
      ]);
      return _get(tx.select, id);
    },
  );

  @override
  Future<NpcDraft> save(String id, NpcDraft draft) async => _db.saveTransaction(
    recordChanged(SaveDomain.npcs, draft.displayName),
    (tx) {
      final blockers = npcSaveBlockers(draft);
      if (blockers.isNotEmpty) {
        throw SaveBlocked([for (final b in blockers) b.message]);
      }
      _checkExportKey(tx, draft.exportKey, id);

      final current = tx.select(
        'SELECT npc_type_id FROM $_table WHERE id = ? AND deleted_at IS NULL',
        [id],
      );
      if (current.isEmpty) throw RecordNotFound(_table, id);
      final previousTypeId = current.single['npc_type_id'] as String;

      tx.execute(
        'UPDATE $_table SET display_name = ?, export_key = ?, '
        'description = ?, npc_type_id = ?, loot_table_id = ?, '
        "combat_stats_json = ?, updated_at = datetime('now') "
        'WHERE id = ? AND deleted_at IS NULL',
        [
          draft.displayName,
          draft.exportKey,
          draft.description,
          draft.npcTypeId,
          draft.lootTableId,
          _encodeCombatStats(draft.combatStats),
          id,
        ],
      );
      if (tx.changes != 1) throw RecordNotFound(_table, id);

      tx.execute('DELETE FROM npc_class_assignments WHERE npc_id = ?', [id]);
      tx.execute('DELETE FROM npc_ability_assignments WHERE npc_id = ?', [id]);
      _insertAssignments(tx, id, draft.classAssignments, draft.abilityIds);

      // 0.1.6 `setCustomFieldValues`: delete every row, insert the given
      // values as they are (null included).
      tx.execute(
        "DELETE FROM custom_field_values WHERE domain = 'npcs' "
        'AND record_id = ?',
        [id],
      );
      for (final MapEntry(:key, :value) in draft.customFieldValues.entries) {
        _insertValue(tx, id, key, value);
      }
      // 0.1.6 `update`: a type change drops the values of fields not scoped
      // to the new type.
      if (draft.npcTypeId != previousTypeId) {
        tx.execute(
          "DELETE FROM custom_field_values WHERE domain = 'npcs' "
          'AND record_id = ? AND field_definition_id NOT IN ('
          'SELECT id FROM custom_field_definitions '
          "WHERE scope_type = 'npc_type' AND scope_id = ?)",
          [id, draft.npcTypeId],
        );
      }
      return _draft(tx.select, id);
    },
  );

  @override
  Future<NpcRecord> duplicate(String id) async {
    final source = _db.read((tx) => _get(tx.select, id));
    final name = copyDisplayName(source.displayName);
    return _db.saveTransaction(recordDuplicated(SaveDomain.npcs, name), (tx) {
      final source = _get(tx.select, id);
      final newId = newRecordId();
      // 0.1.6 used the plain slug here; 0.2.0 adds the UUID suffix as the
      // other domains did (design §7).
      final exportKey = copyExportKey(name);
      _checkExportKey(tx, exportKey, newId);
      tx.execute(_insert, [
        newId,
        name,
        exportKey,
        source.description,
        source.npcTypeId,
        source.lootTableId,
        _encodeCombatStats(source.combatStats),
      ]);
      _insertAssignments(
        tx,
        newId,
        _classAssignments(tx.select, id),
        _abilityIds(tx.select, id),
      );
      // As items: only the values of fields scoped to the source's type are
      // copied (0.1.6's NPC duplicate copied every value row).
      for (final r in tx.select(
        'SELECT cfv.field_definition_id, cfv.value '
        'FROM custom_field_values cfv '
        'JOIN custom_field_definitions cfd ON cfd.id = cfv.field_definition_id '
        "WHERE cfv.domain = 'npcs' AND cfv.record_id = ? "
        "AND cfd.scope_type = 'npc_type' AND cfd.scope_id = ?",
        [id, source.npcTypeId],
      )) {
        _insertValue(
          tx,
          newId,
          r['field_definition_id'] as String,
          r['value'] as String?,
        );
      }
      return _get(tx.select, newId);
    });
  }

  @override
  Future<void> softDelete(String id) async {
    final name = _db.read((tx) => _get(tx.select, id)).displayName;
    _db.saveTransaction(recordDeleted(SaveDomain.npcs, name), (tx) {
      tx.execute(
        'UPDATE $_table SET deleted_at = COALESCE(deleted_at, '
        "datetime('now')), updated_at = datetime('now') WHERE id = ?",
        [id],
      );
      if (tx.changes != 1) throw RecordNotFound(_table, id);
    });
  }

  @override
  Future<void> restore(String id) async {
    final name = _db.read((tx) => _get(tx.select, id)).displayName;
    _db.saveTransaction(recordRestored(SaveDomain.npcs, name), (tx) {
      tx.execute(
        "UPDATE $_table SET deleted_at = NULL, updated_at = datetime('now') "
        'WHERE id = ?',
        [id],
      );
      if (tx.changes != 1) throw RecordNotFound(_table, id);
    });
  }

  @override
  Future<void> hardDelete(String id) async {
    final name = _db.read((tx) => _get(tx.select, id)).displayName;
    _db.saveTransaction(recordHardDeleted(SaveDomain.npcs, name), (tx) {
      // `custom_field_values` has no foreign key to its record, so 0.1.6
      // deleted the rows itself; the assignments cascade.
      tx.execute(
        "DELETE FROM custom_field_values WHERE domain = 'npcs' "
        'AND record_id = ?',
        [id],
      );
      tx.execute('DELETE FROM $_table WHERE id = ?', [id]);
      if (tx.changes != 1) throw RecordNotFound(_table, id);
    });
  }

  @override
  Future<Map<String, double>> inheritedStatBlock(String id) async {
    final (record, assignments, stats, growth, maxLevel) = _db.read((tx) {
      final record = _get(tx.select, id);
      final assignments = _classAssignments(tx.select, id);
      // `MetaRepository.listStats`'s order.
      final stats = [
        for (final r in tx.select(
          'SELECT id, display_name, export_key, sort_order FROM stats '
          'ORDER BY sort_order',
        ))
          MetaStat(
            id: r['id'] as String,
            displayName: r['display_name'] as String,
            exportKey: r['export_key'] as String,
            sortOrder: r['sort_order'] as int,
          ),
      ];
      // The stat growth reads of `SqliteClassRepository.resolvedStatGrowth`.
      final growth = {
        for (final classId in {for (final a in assignments) a.classId})
          classId: (
            manual: {
              for (final r in tx.select(
                'SELECT stat_id, level, value FROM class_stat_growth '
                'WHERE class_id = ? ORDER BY stat_id, level',
                [classId],
              ))
                StatGrowthKey(r['stat_id'] as String, r['level'] as int):
                    (r['value'] as num).toDouble(),
            },
            formulas: {
              for (final r in tx.select(
                'SELECT stat_id, formula FROM class_stat_growth_formulas '
                'WHERE class_id = ? ORDER BY stat_id',
                [classId],
              ))
                r['stat_id'] as String: r['formula'] as String,
            },
          ),
      };
      final maxLevel =
          tx
                  .select('SELECT max_level FROM project_info LIMIT 1')
                  .single['max_level']
              as int;
      return (record, assignments, stats, growth, maxLevel);
    });
    final rows = computeNpcStatBlock(
      stats: stats,
      classAssignments: assignments,
      growthByClass: {
        for (final MapEntry(:key, :value) in growth.entries)
          key: resolveStatGrowth(
            manual: value.manual,
            formulas: value.formulas,
            maxLevel: maxLevel,
          ),
      },
      combatStats: record.combatStats,
    );
    return Map.unmodifiable({
      for (final row in rows) row.statId: row.inherited,
    });
  }
}

import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../db/errors.dart';
import '../db/project_database.dart';
import '../db/save_descriptions.dart';
import '../domain/ability_save_blockers.dart';
import '../domain/ability_types.dart';
import '../domain/record_list_mode.dart';
import '../domain/used_by.dart';
import '../export/js_compat.dart' show jsonStringify;
import 'ability_repository.dart';
import 'record_helpers.dart';
import 'record_id.dart';

/// `SELECT` through a [ReadScope] or a [SaveScope].
typedef _Select = ResultSet Function(String sql, [List<Object?> parameters]);

const String _table = 'abilities';

/// 0.1.6 `ability.repository.ts` `SELECT_COLS`.
const String _columns =
    'id, display_name, export_key, description, '
    'ability_type, resource_type, resource_cost, cooldown, '
    'stat_modifiers_json, created_at, updated_at, deleted_at';

const String _insert =
    'INSERT INTO $_table '
    '(id, display_name, export_key, description, '
    'ability_type, resource_type, resource_cost, cooldown, '
    'stat_modifiers_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)';

/// `JSON.parse(stat_modifiers_json)`. Entries whose value is not a number
/// (JavaScript wrote `null` for NaN and the infinities) are skipped, since
/// the draft holds numbers only.
Map<String, double> _decodeModifiers(String json) => {
  for (final e in (jsonDecode(json) as Map<String, Object?>).entries)
    if (e.value case final num value) e.key: value.toDouble(),
};

/// `JSON.stringify(statModifiers)`: JavaScript key order and number
/// formatting, so `{"strength":2}` round-trips byte for byte.
String _encodeModifiers(Map<String, double> modifiers) =>
    jsonStringify(modifiers)!;

AbilityRecord _record(Row r) => AbilityRecord(
  id: r['id'] as String,
  displayName: r['display_name'] as String,
  exportKey: r['export_key'] as String,
  description: r['description'] as String,
  abilityType: r['ability_type'] as String,
  resourceType: r['resource_type'] as String,
  resourceCost: (r['resource_cost'] as num).toDouble(),
  cooldown: (r['cooldown'] as num).toDouble(),
  statModifiers: _decodeModifiers(r['stat_modifiers_json'] as String),
  createdAt: r['created_at'] as String,
  updatedAt: r['updated_at'] as String,
  deletedAt: r['deleted_at'] as String?,
);

AbilityDraft _draft(AbilityRecord r) => AbilityDraft(
  displayName: r.displayName,
  exportKey: r.exportKey,
  description: r.description,
  abilityType: r.abilityType,
  resourceType: r.resourceType,
  resourceCost: r.resourceCost,
  cooldown: r.cooldown,
  statModifiers: r.statModifiers,
);

/// The `WHERE` clause of 0.1.6's `list(includeDeleted, deletedOnly)`.
String _where(RecordListMode mode) => switch (mode) {
  RecordListMode.active => 'WHERE deleted_at IS NULL',
  RecordListMode.all => '',
  RecordListMode.deletedOnly => 'WHERE deleted_at IS NOT NULL',
};

/// `AbilityRepository` on a [ProjectDatabase], porting 0.1.6's
/// `ability.repository.ts` and `domain-repository.ts`.
final class SqliteAbilityRepository implements AbilityRepository {
  SqliteAbilityRepository(this._db);

  final ProjectDatabase _db;

  // ─── Reads ────────────────────────────────────────────────────────────────

  @override
  Future<List<AbilityRecord>> list({
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
  Future<AbilityRecord> get(String id) async =>
      _db.read((tx) => _requireRecord(tx.select, id));

  @override
  Future<AbilityDraft> load(String id) async =>
      _draft(_db.read((tx) => _requireRecord(tx.select, id)));

  @override
  Future<AbilityUsedBy> usedBy(String id) async => _db.read(
    (tx) => AbilityUsedBy(
      classes: [
        for (final r in tx.select(
          'SELECT c.id, c.display_name AS displayName '
          'FROM class_ability_assignments caa '
          'JOIN classes c ON c.id = caa.class_id '
          'WHERE caa.ability_id = ? AND c.deleted_at IS NULL '
          'ORDER BY c.display_name COLLATE NOCASE',
          [id],
        ))
          UsedByRef(r['id'] as String, r['displayName'] as String),
      ],
      npcs: [
        for (final r in tx.select(
          'SELECT n.id, n.display_name AS displayName '
          'FROM npc_ability_assignments naa '
          'JOIN npcs n ON n.id = naa.npc_id '
          'WHERE naa.ability_id = ? AND n.deleted_at IS NULL '
          'ORDER BY n.display_name COLLATE NOCASE',
          [id],
        ))
          UsedByRef(r['id'] as String, r['displayName'] as String),
      ],
    ),
  );

  // ─── Writes ───────────────────────────────────────────────────────────────

  @override
  Future<AbilityRecord> create(CreateAbilityInput input) async =>
      _db.saveTransaction(
        recordCreated(SaveDomain.abilities, input.displayName),
        (tx) {
          final id = newRecordId();
          _checkExportKey(tx, input.exportKey, id);
          tx.execute(_insert, [
            id,
            input.displayName,
            input.exportKey,
            input.description,
            input.abilityType,
            input.resourceType,
            input.resourceCost,
            input.cooldown,
            _encodeModifiers(input.statModifiers),
          ]);
          return _requireRecord(tx.select, id);
        },
      );

  @override
  Future<AbilityDraft> save(String id, AbilityDraft draft) async =>
      _db.saveTransaction(
        recordChanged(SaveDomain.abilities, draft.displayName),
        (tx) {
          final blockers = abilitySaveBlockers(draft);
          if (blockers.isNotEmpty) {
            throw SaveBlocked([for (final b in blockers) b.message]);
          }
          _checkExportKey(tx, draft.exportKey, id);
          tx.execute(
            'UPDATE $_table SET display_name = ?, export_key = ?, '
            'description = ?, ability_type = ?, resource_type = ?, '
            'resource_cost = ?, cooldown = ?, stat_modifiers_json = ?, '
            "updated_at = datetime('now') "
            'WHERE id = ? AND deleted_at IS NULL',
            [
              draft.displayName,
              draft.exportKey,
              draft.description,
              draft.abilityType,
              draft.resourceType,
              draft.resourceCost,
              draft.cooldown,
              _encodeModifiers(draft.statModifiers),
              id,
            ],
          );
          if (tx.changes != 1) throw RecordNotFound(_table, id);
          return _draft(_requireRecord(tx.select, id));
        },
      );

  @override
  Future<AbilityRecord> duplicate(String id) async {
    final source = await get(id);
    final name = copyDisplayName(source.displayName);
    return _db.saveTransaction(recordDuplicated(SaveDomain.abilities, name), (
      tx,
    ) {
      final newId = newRecordId();
      tx.execute(_insert, [
        newId,
        name,
        copyExportKey(name),
        source.description,
        source.abilityType,
        source.resourceType,
        source.resourceCost,
        source.cooldown,
        _encodeModifiers(source.statModifiers),
      ]);
      return _requireRecord(tx.select, newId);
    });
  }

  @override
  Future<void> softDelete(String id) async => _mutate(
    id,
    recordDeleted,
    'UPDATE $_table '
    "SET deleted_at = COALESCE(deleted_at, datetime('now')), "
    "updated_at = datetime('now') WHERE id = ?",
  );

  @override
  Future<void> restore(String id) async => _mutate(
    id,
    recordRestored,
    'UPDATE $_table '
    "SET deleted_at = NULL, updated_at = datetime('now') WHERE id = ?",
  );

  @override
  Future<void> hardDelete(String id) async =>
      _mutate(id, recordHardDeleted, 'DELETE FROM $_table WHERE id = ?');

  /// Runs [sql] (one `?` for the id) as its own save transaction, described
  /// with the record's current display name.
  void _mutate(
    String id,
    String Function(SaveDomain, String) describe,
    String sql,
  ) {
    final record = _db.read((tx) => _requireRecord(tx.select, id));
    _db.saveTransaction(describe(SaveDomain.abilities, record.displayName), (
      tx,
    ) {
      tx.execute(sql, [id]);
      if (tx.changes != 1) throw RecordNotFound(_table, id);
    });
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static AbilityRecord _requireRecord(_Select select, String id) {
    final rows = select('SELECT $_columns FROM $_table WHERE id = ?', [id]);
    if (rows.isEmpty) throw RecordNotFound(_table, id);
    return _record(rows.single);
  }

  /// Refuses [exportKey] when another ability holds it, before the `UNIQUE`
  /// constraint would, so the error can name the key.
  static void _checkExportKey(SaveScope tx, String exportKey, String id) {
    final clash = tx.select(
      'SELECT 1 FROM $_table WHERE export_key = ? AND id != ?',
      [exportKey, id],
    );
    if (clash.isNotEmpty) throw DuplicateExportKey(exportKey);
  }
}

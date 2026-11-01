import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../db/errors.dart';
import '../db/project_database.dart';
import '../db/save_descriptions.dart';
import '../domain/loot_table_save_blockers.dart';
import '../domain/loot_table_types.dart';
import '../domain/record_list_mode.dart';
import '../domain/used_by.dart';
import 'loot_table_repository.dart';
import 'record_helpers.dart';
import 'record_id.dart';

/// `SELECT` through a [ReadScope] or a [SaveScope].
typedef _Select = ResultSet Function(String sql, [List<Object?> parameters]);

const String _table = 'loot_tables';
const String _columns =
    'id, display_name, export_key, description, created_at, updated_at, '
    'deleted_at';

/// 0.1.6 `DomainRepository.list`'s three `WHERE` clauses.
String _where(RecordListMode mode) => switch (mode) {
  RecordListMode.active => 'WHERE deleted_at IS NULL',
  RecordListMode.all => '',
  RecordListMode.deletedOnly => 'WHERE deleted_at IS NOT NULL',
};

LootTableRecord _record(Row r) => LootTableRecord(
  id: r['id'] as String,
  displayName: r['display_name'] as String,
  exportKey: r['export_key'] as String,
  description: r['description'] as String,
  createdAt: r['created_at'] as String,
  updatedAt: r['updated_at'] as String,
  deletedAt: r['deleted_at'] as String?,
);

LootTableRecord _get(_Select select, String id) {
  final rows = select('SELECT $_columns FROM $_table WHERE id = ?', [id]);
  if (rows.isEmpty) throw RecordNotFound(_table, id);
  return _record(rows.single);
}

/// 0.1.6 `getEntries`, with `conditional_flags` decoded as `JSON.parse` did.
List<LootTableEntryDraft> _entries(_Select select, String id) => [
  for (final r in select(
    'SELECT item_id, weight, quantity_min, quantity_max, conditional_flags '
    'FROM loot_table_entries WHERE loot_table_id = ? ORDER BY sort_order',
    [id],
  ))
    LootTableEntryDraft(
      itemId: r['item_id'] as String,
      weight: r['weight'] as int,
      quantityMin: r['quantity_min'] as int,
      quantityMax: r['quantity_max'] as int,
      conditionalFlags:
          jsonDecode(r['conditional_flags'] as String) as Map<String, Object?>,
    ),
];

LootTableDraft _draft(_Select select, String id) {
  final record = _get(select, id);
  return LootTableDraft(
    displayName: record.displayName,
    exportKey: record.exportKey,
    description: record.description,
    entries: _entries(select, id),
  );
}

void _checkExportKey(SaveScope tx, String exportKey, String id) {
  final clash = tx.select(
    'SELECT 1 FROM $_table WHERE export_key = ? AND id != ?',
    [exportKey, id],
  );
  if (clash.isNotEmpty) throw DuplicateExportKey(exportKey);
}

void _insert(
  SaveScope tx,
  String id,
  String displayName,
  String exportKey,
  String description,
) {
  tx.execute(
    'INSERT INTO $_table (id, display_name, export_key, description) '
    'VALUES (?, ?, ?, ?)',
    [id, displayName, exportKey, description],
  );
}

/// 0.1.6 `setEntries` without the delete and without its clamping (the
/// blockers refuse those values instead): a new id per entry,
/// `sort_order` = index, `conditional_flags` as JSON text.
void _insertEntries(
  SaveScope tx,
  String lootTableId,
  List<LootTableEntryDraft> entries,
) {
  for (final (i, entry) in entries.indexed) {
    tx.execute(
      'INSERT INTO loot_table_entries (id, loot_table_id, item_id, weight, '
      'quantity_min, quantity_max, conditional_flags, sort_order) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [
        newRecordId(),
        lootTableId,
        entry.itemId,
        entry.weight,
        entry.quantityMin,
        entry.quantityMax,
        jsonEncode(entry.conditionalFlags),
        i,
      ],
    );
  }
}

/// `LootTableRepository` on a [ProjectDatabase], porting 0.1.6's
/// `loot-table.repository.ts`.
final class SqliteLootTableRepository implements LootTableRepository {
  SqliteLootTableRepository(this._db);

  final ProjectDatabase _db;

  @override
  Future<List<LootTableRecord>> list({
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
  Future<LootTableRecord> get(String id) async =>
      _db.read((tx) => _get(tx.select, id));

  @override
  Future<LootTableDraft> load(String id) async =>
      _db.read((tx) => _draft(tx.select, id));

  @override
  Future<LootTableRecord> create(CreateLootTableInput input) async =>
      _db.saveTransaction(
        recordCreated(SaveDomain.lootTables, input.displayName),
        (tx) {
          final id = newRecordId();
          _checkExportKey(tx, input.exportKey, id);
          _insert(
            tx,
            id,
            input.displayName,
            input.exportKey,
            input.description,
          );
          return _get(tx.select, id);
        },
      );

  @override
  Future<LootTableDraft> save(String id, LootTableDraft draft) async =>
      _db.saveTransaction(
        recordChanged(SaveDomain.lootTables, draft.displayName),
        (tx) {
          final blockers = lootTableSaveBlockers(draft);
          if (blockers.isNotEmpty) {
            throw SaveBlocked([for (final b in blockers) b.message]);
          }
          _checkExportKey(tx, draft.exportKey, id);

          tx.execute(
            'UPDATE $_table SET display_name = ?, export_key = ?, '
            "description = ?, updated_at = datetime('now') "
            'WHERE id = ? AND deleted_at IS NULL',
            [draft.displayName, draft.exportKey, draft.description, id],
          );
          if (tx.changes != 1) throw RecordNotFound(_table, id);

          tx.execute('DELETE FROM loot_table_entries WHERE loot_table_id = ?', [
            id,
          ]);
          _insertEntries(tx, id, draft.entries);
          return _draft(tx.select, id);
        },
      );

  @override
  Future<LootTableRecord> duplicate(String id) async {
    final source = _db.read((tx) => _get(tx.select, id));
    final name = copyDisplayName(source.displayName);
    return _db.saveTransaction(recordDuplicated(SaveDomain.lootTables, name), (
      tx,
    ) {
      final source = _get(tx.select, id);
      final newId = newRecordId();
      // 0.1.6 used the plain slug here; 0.2.0 adds the UUID suffix as the
      // other domains did (design §7).
      final exportKey = copyExportKey(name);
      _checkExportKey(tx, exportKey, newId);
      _insert(tx, newId, name, exportKey, source.description);
      _insertEntries(tx, newId, _entries(tx.select, id));
      return _get(tx.select, newId);
    });
  }

  @override
  Future<void> softDelete(String id) async {
    final name = _db.read((tx) => _get(tx.select, id)).displayName;
    _db.saveTransaction(recordDeleted(SaveDomain.lootTables, name), (tx) {
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
    _db.saveTransaction(recordRestored(SaveDomain.lootTables, name), (tx) {
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
    _db.saveTransaction(recordHardDeleted(SaveDomain.lootTables, name), (tx) {
      // `loot_table_entries` cascades on the loot table.
      tx.execute('DELETE FROM $_table WHERE id = ?', [id]);
      if (tx.changes != 1) throw RecordNotFound(_table, id);
    });
  }

  @override
  Future<List<UsedByRef>> usedBy(String id) async => _db.read(
    (tx) => [
      for (final r in tx.select(
        'SELECT id, display_name FROM npcs '
        'WHERE loot_table_id = ? AND deleted_at IS NULL '
        'ORDER BY display_name COLLATE NOCASE',
        [id],
      ))
        UsedByRef(r['id'] as String, r['display_name'] as String),
    ],
  );
}

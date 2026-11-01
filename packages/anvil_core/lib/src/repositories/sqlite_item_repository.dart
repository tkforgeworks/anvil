import 'package:sqlite3/sqlite3.dart';

import '../db/errors.dart';
import '../db/project_database.dart';
import '../db/save_descriptions.dart';
import '../domain/item_save_blockers.dart';
import '../domain/item_types.dart';
import '../domain/record_list_mode.dart';
import '../domain/used_by.dart';
import 'item_repository.dart';
import 'record_helpers.dart';
import 'record_id.dart';

/// `SELECT` through a [ReadScope] or a [SaveScope].
typedef _Select = ResultSet Function(String sql, [List<Object?> parameters]);

const String _table = 'items';
const String _columns =
    'id, display_name, export_key, description, item_category_id, '
    'rarity_id, created_at, updated_at, deleted_at';

/// 0.1.6 `DomainRepository.list`'s three `WHERE` clauses.
String _where(RecordListMode mode) => switch (mode) {
  RecordListMode.active => 'WHERE deleted_at IS NULL',
  RecordListMode.all => '',
  RecordListMode.deletedOnly => 'WHERE deleted_at IS NOT NULL',
};

ItemRecord _record(Row r) => ItemRecord(
  id: r['id'] as String,
  displayName: r['display_name'] as String,
  exportKey: r['export_key'] as String,
  description: r['description'] as String,
  itemCategoryId: r['item_category_id'] as String,
  rarityId: r['rarity_id'] as String,
  createdAt: r['created_at'] as String,
  updatedAt: r['updated_at'] as String,
  deletedAt: r['deleted_at'] as String?,
);

ItemRecord _get(_Select select, String id) {
  final rows = select('SELECT $_columns FROM $_table WHERE id = ?', [id]);
  if (rows.isEmpty) throw RecordNotFound(_table, id);
  return _record(rows.single);
}

/// Every value row of the item, as 0.1.6's `getCustomFieldValues`.
Map<String, String?> _values(_Select select, String id) => {
  for (final r in select(
    'SELECT field_definition_id, value FROM custom_field_values '
    "WHERE domain = 'items' AND record_id = ?",
    [id],
  ))
    r['field_definition_id'] as String: r['value'] as String?,
};

ItemDraft _draft(_Select select, String id) {
  final record = _get(select, id);
  return ItemDraft(
    displayName: record.displayName,
    exportKey: record.exportKey,
    description: record.description,
    itemCategoryId: record.itemCategoryId,
    rarityId: record.rarityId,
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

void _insertValue(SaveScope tx, String itemId, String fieldId, String? value) {
  tx.execute(
    'INSERT INTO custom_field_values '
    '(domain, record_id, field_definition_id, value) '
    "VALUES ('items', ?, ?, ?)",
    [itemId, fieldId, value],
  );
}

/// `ItemRepository` on a [ProjectDatabase], porting 0.1.6's
/// `item.repository.ts` and the item side of `custom-fields.handlers.ts`.
final class SqliteItemRepository implements ItemRepository {
  SqliteItemRepository(this._db);

  final ProjectDatabase _db;

  @override
  Future<List<ItemRecord>> list({
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
  Future<ItemRecord> get(String id) async =>
      _db.read((tx) => _get(tx.select, id));

  @override
  Future<ItemDraft> load(String id) async =>
      _db.read((tx) => _draft(tx.select, id));

  @override
  Future<ItemRecord> create(CreateItemInput input) async => _db.saveTransaction(
    recordCreated(SaveDomain.items, input.displayName),
    (tx) {
      final id = newRecordId();
      _checkExportKey(tx, input.exportKey, id);
      tx.execute(
        'INSERT INTO $_table (id, display_name, export_key, description, '
        'item_category_id, rarity_id) VALUES (?, ?, ?, ?, ?, ?)',
        [
          id,
          input.displayName,
          input.exportKey,
          input.description,
          input.itemCategoryId,
          input.rarityId,
        ],
      );
      return _get(tx.select, id);
    },
  );

  @override
  Future<ItemDraft> save(String id, ItemDraft draft) async =>
      _db.saveTransaction(recordChanged(SaveDomain.items, draft.displayName), (
        tx,
      ) {
        final blockers = itemSaveBlockers(draft);
        if (blockers.isNotEmpty) {
          throw SaveBlocked([for (final b in blockers) b.message]);
        }
        _checkExportKey(tx, draft.exportKey, id);

        final current = tx.select(
          'SELECT item_category_id FROM $_table '
          'WHERE id = ? AND deleted_at IS NULL',
          [id],
        );
        if (current.isEmpty) throw RecordNotFound(_table, id);
        final previousCategoryId = current.single['item_category_id'] as String;

        tx.execute(
          'UPDATE $_table SET display_name = ?, export_key = ?, '
          'description = ?, item_category_id = ?, rarity_id = ?, '
          "updated_at = datetime('now') WHERE id = ? AND deleted_at IS NULL",
          [
            draft.displayName,
            draft.exportKey,
            draft.description,
            draft.itemCategoryId,
            draft.rarityId,
            id,
          ],
        );
        if (tx.changes != 1) throw RecordNotFound(_table, id);

        // 0.1.6 `setCustomFieldValues`: delete every row, insert the given
        // values as they are (null included).
        tx.execute(
          "DELETE FROM custom_field_values WHERE domain = 'items' "
          'AND record_id = ?',
          [id],
        );
        for (final MapEntry(:key, :value) in draft.customFieldValues.entries) {
          _insertValue(tx, id, key, value);
        }
        // 0.1.6 `update`: a category change drops the values of fields not
        // scoped to the new category.
        if (draft.itemCategoryId != previousCategoryId) {
          tx.execute(
            "DELETE FROM custom_field_values WHERE domain = 'items' "
            'AND record_id = ? AND field_definition_id NOT IN ('
            'SELECT id FROM custom_field_definitions '
            "WHERE scope_type = 'item_category' AND scope_id = ?)",
            [id, draft.itemCategoryId],
          );
        }
        return _draft(tx.select, id);
      });

  @override
  Future<ItemRecord> duplicate(String id) async {
    final source = _db.read((tx) => _get(tx.select, id));
    final name = copyDisplayName(source.displayName);
    return _db.saveTransaction(recordDuplicated(SaveDomain.items, name), (tx) {
      final source = _get(tx.select, id);
      final newId = newRecordId();
      final exportKey = copyExportKey(name);
      _checkExportKey(tx, exportKey, newId);
      tx.execute(
        'INSERT INTO $_table (id, display_name, export_key, description, '
        'item_category_id, rarity_id) VALUES (?, ?, ?, ?, ?, ?)',
        [
          newId,
          name,
          exportKey,
          source.description,
          source.itemCategoryId,
          source.rarityId,
        ],
      );
      // 0.1.6 `getCustomFieldValuesForCategory`: only the values of fields
      // scoped to the source's category are copied.
      for (final r in tx.select(
        'SELECT cfv.field_definition_id, cfv.value '
        'FROM custom_field_values cfv '
        'JOIN custom_field_definitions cfd ON cfd.id = cfv.field_definition_id '
        "WHERE cfv.domain = 'items' AND cfv.record_id = ? "
        "AND cfd.scope_type = 'item_category' AND cfd.scope_id = ?",
        [id, source.itemCategoryId],
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
    _db.saveTransaction(recordDeleted(SaveDomain.items, name), (tx) {
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
    _db.saveTransaction(recordRestored(SaveDomain.items, name), (tx) {
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
    _db.saveTransaction(recordHardDeleted(SaveDomain.items, name), (tx) {
      // `custom_field_values` has no foreign key to its record, so 0.1.6
      // deleted the rows itself.
      tx.execute(
        "DELETE FROM custom_field_values WHERE domain = 'items' "
        'AND record_id = ?',
        [id],
      );
      tx.execute('DELETE FROM $_table WHERE id = ?', [id]);
      if (tx.changes != 1) throw RecordNotFound(_table, id);
    });
  }

  @override
  Future<ItemUsedBy> usedBy(String id) async => _db.read((tx) {
    List<UsedByRef> refs(String sql, List<Object?> parameters) => [
      for (final r in tx.select(sql, parameters))
        UsedByRef(r['id'] as String, r['display_name'] as String),
    ];
    return ItemUsedBy(
      // 0.1.6 merged "as ingredient" and "as output" and deduplicated by id.
      recipes: refs(
        'SELECT r.id, r.display_name FROM recipes r '
        'WHERE r.deleted_at IS NULL AND (r.output_item_id = ? OR EXISTS ('
        'SELECT 1 FROM recipe_ingredients ri '
        'WHERE ri.recipe_id = r.id AND ri.item_id = ?)) '
        'ORDER BY r.display_name COLLATE NOCASE',
        [id, id],
      ),
      lootTables: refs(
        'SELECT lt.id, lt.display_name FROM loot_tables lt '
        'WHERE lt.deleted_at IS NULL AND EXISTS ('
        'SELECT 1 FROM loot_table_entries lte '
        'WHERE lte.loot_table_id = lt.id AND lte.item_id = ?) '
        'ORDER BY lt.display_name COLLATE NOCASE',
        [id],
      ),
    );
  });
}

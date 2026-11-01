import 'package:sqlite3/sqlite3.dart';

import '../db/errors.dart';
import '../db/project_database.dart';
import '../db/save_descriptions.dart';
import '../domain/meta.dart';
import 'meta_repository.dart';
import 'record_id.dart';

/// `SELECT` through a [ReadScope] or a [SaveScope].
typedef _Select = ResultSet Function(String sql, [List<Object?> parameters]);

/// 0.1.6 wrote meta timestamps with `new Date().toISOString()`; SQLite
/// produces the same `YYYY-MM-DDTHH:MM:SS.sssZ` text.
const String _isoNow = "strftime('%Y-%m-%dT%H:%M:%fZ', 'now')";

const String _byOrder = 'ORDER BY sort_order';
const String _byOrderThenName =
    'ORDER BY sort_order, display_name COLLATE NOCASE';

/// One meta table: its name, the columns read back, the list order and the
/// in-use kind its delete checks.
final class _Table {
  const _Table(this.name, this.columns, this.order, this.kind);

  final String name;
  final String columns;
  final String order;
  final MetaInUseKind kind;

  String get selectAll => 'SELECT $columns FROM $name $order';
  String get selectOne => 'SELECT $columns FROM $name WHERE id = ?';
}

const String _plainColumns =
    'id, display_name, export_key, description, sort_order';

const _Table _stats = _Table(
  'stats',
  'id, display_name, export_key, sort_order',
  _byOrder,
  MetaInUseKind.stat,
);
const _Table _rarities = _Table(
  'rarities',
  'id, display_name, export_key, color_hex, sort_order',
  _byOrderThenName,
  MetaInUseKind.rarity,
);
const _Table _itemCategories = _Table(
  'item_categories',
  _plainColumns,
  _byOrderThenName,
  MetaInUseKind.itemCategory,
);
const _Table _npcTypes = _Table(
  'npc_types',
  _plainColumns,
  _byOrderThenName,
  MetaInUseKind.npcType,
);
const _Table _craftingStations = _Table(
  'crafting_stations',
  _plainColumns,
  _byOrderThenName,
  MetaInUseKind.craftingStation,
);
const _Table _craftingSpecializations = _Table(
  'crafting_specializations',
  _plainColumns,
  _byOrderThenName,
  MetaInUseKind.craftingSpecialization,
);
const _Table _derivedStats = _Table(
  'derived_stat_definitions',
  'id, display_name, export_key, formula, output_type, rounding_mode, '
      'sort_order',
  _byOrder,
  MetaInUseKind.derivedStat,
);

MetaStat _stat(Row r) => MetaStat(
  id: r['id'] as String,
  displayName: r['display_name'] as String,
  exportKey: r['export_key'] as String,
  sortOrder: r['sort_order'] as int,
);

MetaRarity _rarity(Row r) => MetaRarity(
  id: r['id'] as String,
  displayName: r['display_name'] as String,
  exportKey: r['export_key'] as String,
  colorHex: r['color_hex'] as String,
  sortOrder: r['sort_order'] as int,
);

MetaItemCategory _itemCategory(Row r) => MetaItemCategory(
  id: r['id'] as String,
  displayName: r['display_name'] as String,
  exportKey: r['export_key'] as String,
  description: r['description'] as String,
  sortOrder: r['sort_order'] as int,
);

MetaNpcType _npcType(Row r) => MetaNpcType(
  id: r['id'] as String,
  displayName: r['display_name'] as String,
  exportKey: r['export_key'] as String,
  description: r['description'] as String,
  sortOrder: r['sort_order'] as int,
);

MetaCraftingStation _craftingStation(Row r) => MetaCraftingStation(
  id: r['id'] as String,
  displayName: r['display_name'] as String,
  exportKey: r['export_key'] as String,
  description: r['description'] as String,
  sortOrder: r['sort_order'] as int,
);

MetaCraftingSpecialization _craftingSpecialization(Row r) =>
    MetaCraftingSpecialization(
      id: r['id'] as String,
      displayName: r['display_name'] as String,
      exportKey: r['export_key'] as String,
      description: r['description'] as String,
      sortOrder: r['sort_order'] as int,
    );

DerivedStatDefinition _derivedStat(Row r) => DerivedStatDefinition(
  id: r['id'] as String,
  displayName: r['display_name'] as String,
  exportKey: r['export_key'] as String,
  formula: r['formula'] as String,
  outputType: DerivedStatOutputType.fromValue(r['output_type'] as String),
  roundingMode: RoundingMode.fromValue(r['rounding_mode'] as String),
  sortOrder: r['sort_order'] as int,
);

MetaRowDraft _rowDraft(Row r) => MetaRowDraft(
  id: r['id'] as String,
  displayName: r['display_name'] as String,
  exportKey: r['export_key'] as String,
);

RarityRowDraft _rarityDraft(Row r) => RarityRowDraft(
  id: r['id'] as String,
  displayName: r['display_name'] as String,
  exportKey: r['export_key'] as String,
  colorHex: r['color_hex'] as String,
);

DerivedStatRowDraft _derivedStatDraft(Row r) => DerivedStatRowDraft(
  id: r['id'] as String,
  displayName: r['display_name'] as String,
  exportKey: r['export_key'] as String,
  formula: r['formula'] as String,
  outputType: DerivedStatOutputType.fromValue(r['output_type'] as String),
  roundingMode: RoundingMode.fromValue(r['rounding_mode'] as String),
);

/// The editable columns of one row, in SQL column order, for the add,
/// update and change-detection paths shared by every list.
typedef _Fields = Map<String, Object?>;

_Fields _itemFields(String displayName, String exportKey) => {
  'display_name': displayName,
  'export_key': exportKey,
};

_Fields _rarityFields(String displayName, String exportKey, String colorHex) =>
    {
      'display_name': displayName,
      'export_key': exportKey,
      'color_hex': colorHex,
    };

_Fields _derivedStatFields(
  String displayName,
  String exportKey,
  String formula,
  DerivedStatOutputType outputType,
  RoundingMode roundingMode,
) => {
  'display_name': displayName,
  'export_key': exportKey,
  'formula': formula,
  'output_type': outputType.value,
  'rounding_mode': roundingMode.value,
};

/// One reference count behind an in-use refusal.
final class _Usage {
  const _Usage(this.reason, this.countKey, this.count);

  final String reason;
  final String countKey;
  final int count;
}

/// `MetaRepository` on a [ProjectDatabase], porting 0.1.6's
/// `meta.handlers.ts` and the buffered commit of `meta-buffer.ts`.
final class SqliteMetaRepository implements MetaRepository {
  SqliteMetaRepository(this._db);

  final ProjectDatabase _db;

  // ─── Lists ────────────────────────────────────────────────────────────────

  List<T> _list<T>(_Table table, T Function(Row) map) =>
      _db.read((tx) => [for (final r in tx.select(table.selectAll)) map(r)]);

  @override
  Future<List<MetaStat>> listStats() async => _list(_stats, _stat);

  @override
  Future<List<MetaRarity>> listRarities() async => _list(_rarities, _rarity);

  @override
  Future<List<MetaItemCategory>> listItemCategories() async =>
      _list(_itemCategories, _itemCategory);

  @override
  Future<List<MetaNpcType>> listNpcTypes() async => _list(_npcTypes, _npcType);

  @override
  Future<List<MetaCraftingStation>> listCraftingStations() async =>
      _list(_craftingStations, _craftingStation);

  @override
  Future<List<MetaCraftingSpecialization>>
  listCraftingSpecializations() async =>
      _list(_craftingSpecializations, _craftingSpecialization);

  @override
  Future<List<DerivedStatDefinition>> listDerivedStats() async =>
      _list(_derivedStats, _derivedStat);

  // ─── Shared mutations ─────────────────────────────────────────────────────

  T _add<T>(_Table table, _Fields fields, T Function(Row) map) =>
      _db.saveTransaction(projectSettingsChanged, (tx) {
        final id = _insert(tx, table, fields);
        return map(tx.select(table.selectOne, [id]).single);
      });

  T _update<T>(_Table table, String id, _Fields fields, T Function(Row) map) =>
      _db.saveTransaction(projectSettingsChanged, (tx) {
        _updateRow(tx, table, id, fields);
        return map(tx.select(table.selectOne, [id]).single);
      });

  void _delete(_Table table, String id) =>
      _db.saveTransaction(projectSettingsChanged, (tx) {
        _deleteRow(tx, table, id);
      });

  void _reorder(_Table table, List<String> ids) =>
      _db.saveTransaction(projectSettingsChanged, (tx) {
        for (var i = 0; i < ids.length; i++) {
          tx.execute(
            'UPDATE ${table.name} SET sort_order = ?, updated_at = $_isoNow '
            'WHERE id = ?',
            [i, ids[i]],
          );
        }
      });

  /// Inserts a row at `MAX(sort_order) + 1` and returns its new id.
  static String _insert(SaveScope tx, _Table table, _Fields fields) {
    final id = newRecordId();
    final maxOrder =
        tx
                .select(
                  'SELECT COALESCE(MAX(sort_order), 0) AS m FROM ${table.name}',
                )
                .single['m']
            as int;
    // 0.1.6 inserted an empty description into the tables that have one.
    final withDescription = table.columns.contains('description');
    final columns = [
      'id',
      ...fields.keys,
      if (withDescription) 'description',
      'sort_order',
      'created_at',
      'updated_at',
    ];
    final values = [
      '?',
      for (final _ in fields.keys) '?',
      if (withDescription) "''",
      '?',
      _isoNow,
      _isoNow,
    ];
    tx.execute(
      'INSERT INTO ${table.name} (${columns.join(', ')}) '
      'VALUES (${values.join(', ')})',
      [id, ...fields.values, maxOrder + 1],
    );
    return id;
  }

  static void _updateRow(
    SaveScope tx,
    _Table table,
    String id,
    _Fields fields,
  ) {
    final sets = [for (final c in fields.keys) '$c = ?'].join(', ');
    tx.execute(
      'UPDATE ${table.name} SET $sets, updated_at = $_isoNow WHERE id = ?',
      [...fields.values, id],
    );
    if (tx.changes != 1) throw RecordNotFound(table.name, id);
  }

  static void _deleteRow(SaveScope tx, _Table table, String id) {
    final usage = _usage(tx.select, table.kind, id);
    if (usage != null) {
      throw MetaInUse(table.kind.value, {usage.countKey: usage.count});
    }
    tx.execute('DELETE FROM ${table.name} WHERE id = ?', [id]);
    if (tx.changes != 1) throw RecordNotFound(table.name, id);
  }

  // ─── Per-list mutations ───────────────────────────────────────────────────

  @override
  Future<MetaStat> addStat(MetaItemInput input) async =>
      _add(_stats, _itemFields(input.displayName, input.exportKey), _stat);

  @override
  Future<MetaStat> updateStat(String id, MetaItemInput input) async => _update(
    _stats,
    id,
    _itemFields(input.displayName, input.exportKey),
    _stat,
  );

  @override
  Future<void> deleteStat(String id) async => _delete(_stats, id);

  @override
  Future<void> reorderStats(List<String> ids) async => _reorder(_stats, ids);

  @override
  Future<MetaRarity> addRarity(MetaRarityInput input) async => _add(
    _rarities,
    _rarityFields(input.displayName, input.exportKey, input.colorHex),
    _rarity,
  );

  @override
  Future<MetaRarity> updateRarity(String id, MetaRarityInput input) async =>
      _update(
        _rarities,
        id,
        _rarityFields(input.displayName, input.exportKey, input.colorHex),
        _rarity,
      );

  @override
  Future<void> deleteRarity(String id) async => _delete(_rarities, id);

  @override
  Future<void> reorderRarities(List<String> ids) async =>
      _reorder(_rarities, ids);

  @override
  Future<MetaItemCategory> addItemCategory(MetaItemInput input) async => _add(
    _itemCategories,
    _itemFields(input.displayName, input.exportKey),
    _itemCategory,
  );

  @override
  Future<MetaItemCategory> updateItemCategory(
    String id,
    MetaItemInput input,
  ) async => _update(
    _itemCategories,
    id,
    _itemFields(input.displayName, input.exportKey),
    _itemCategory,
  );

  @override
  Future<void> deleteItemCategory(String id) async =>
      _delete(_itemCategories, id);

  @override
  Future<void> reorderItemCategories(List<String> ids) async =>
      _reorder(_itemCategories, ids);

  @override
  Future<MetaNpcType> addNpcType(MetaItemInput input) async => _add(
    _npcTypes,
    _itemFields(input.displayName, input.exportKey),
    _npcType,
  );

  @override
  Future<MetaNpcType> updateNpcType(String id, MetaItemInput input) async =>
      _update(
        _npcTypes,
        id,
        _itemFields(input.displayName, input.exportKey),
        _npcType,
      );

  @override
  Future<void> deleteNpcType(String id) async => _delete(_npcTypes, id);

  @override
  Future<void> reorderNpcTypes(List<String> ids) async =>
      _reorder(_npcTypes, ids);

  @override
  Future<MetaCraftingStation> addCraftingStation(MetaItemInput input) async =>
      _add(
        _craftingStations,
        _itemFields(input.displayName, input.exportKey),
        _craftingStation,
      );

  @override
  Future<MetaCraftingStation> updateCraftingStation(
    String id,
    MetaItemInput input,
  ) async => _update(
    _craftingStations,
    id,
    _itemFields(input.displayName, input.exportKey),
    _craftingStation,
  );

  @override
  Future<void> deleteCraftingStation(String id) async =>
      _delete(_craftingStations, id);

  @override
  Future<void> reorderCraftingStations(List<String> ids) async =>
      _reorder(_craftingStations, ids);

  @override
  Future<MetaCraftingSpecialization> addCraftingSpecialization(
    MetaItemInput input,
  ) async => _add(
    _craftingSpecializations,
    _itemFields(input.displayName, input.exportKey),
    _craftingSpecialization,
  );

  @override
  Future<MetaCraftingSpecialization> updateCraftingSpecialization(
    String id,
    MetaItemInput input,
  ) async => _update(
    _craftingSpecializations,
    id,
    _itemFields(input.displayName, input.exportKey),
    _craftingSpecialization,
  );

  @override
  Future<void> deleteCraftingSpecialization(String id) async =>
      _delete(_craftingSpecializations, id);

  @override
  Future<void> reorderCraftingSpecializations(List<String> ids) async =>
      _reorder(_craftingSpecializations, ids);

  @override
  Future<DerivedStatDefinition> addDerivedStat(DerivedStatInput input) async =>
      _add(
        _derivedStats,
        _derivedStatFields(
          input.displayName,
          input.exportKey,
          input.formula,
          input.outputType,
          input.roundingMode,
        ),
        _derivedStat,
      );

  @override
  Future<DerivedStatDefinition> updateDerivedStat(
    String id,
    DerivedStatInput input,
  ) async => _update(
    _derivedStats,
    id,
    _derivedStatFields(
      input.displayName,
      input.exportKey,
      input.formula,
      input.outputType,
      input.roundingMode,
    ),
    _derivedStat,
  );

  @override
  Future<void> deleteDerivedStat(String id) async => _delete(_derivedStats, id);

  @override
  Future<void> reorderDerivedStats(List<String> ids) async =>
      _reorder(_derivedStats, ids);

  // ─── In-use checks ────────────────────────────────────────────────────────

  @override
  Future<MetaInUseResult> checkInUse(MetaInUseKind kind, String id) async {
    final usage = _db.read((tx) => _usage(tx.select, kind, id));
    return usage == null
        ? const MetaInUseResult.free()
        : MetaInUseResult.used(usage.reason);
  }

  static int _count(_Select select, String sql, String id) =>
      select(sql, [id]).single['c'] as int;

  /// Ports 0.1.6 `checkMetaInUse`: the first reference that blocks a delete
  /// of [id], or null when the row is free.
  static _Usage? _usage(_Select select, MetaInUseKind kind, String id) {
    switch (kind) {
      case MetaInUseKind.stat:
        final c = _count(
          select,
          'SELECT COUNT(DISTINCT csg.class_id) AS c FROM class_stat_growth csg '
          'JOIN classes c ON c.id = csg.class_id '
          'WHERE csg.stat_id = ? AND c.deleted_at IS NULL',
          id,
        );
        return c > 0
            ? _Usage(
                'Stat is used by $c class(es) in stat growth definitions.',
                'classes',
                c,
              )
            : null;
      case MetaInUseKind.rarity:
        final c = _count(
          select,
          'SELECT COUNT(*) AS c FROM items '
          'WHERE rarity_id = ? AND deleted_at IS NULL',
          id,
        );
        return c > 0
            ? _Usage('Rarity is used by $c item(s).', 'items', c)
            : null;
      case MetaInUseKind.itemCategory:
        final c = _count(
          select,
          'SELECT COUNT(*) AS c FROM items '
          'WHERE item_category_id = ? AND deleted_at IS NULL',
          id,
        );
        if (c > 0) {
          return _Usage('Item category is used by $c item(s).', 'items', c);
        }
        final f = _count(
          select,
          'SELECT COUNT(*) AS c FROM custom_field_definitions '
          "WHERE scope_type = 'item_category' AND scope_id = ?",
          id,
        );
        return f > 0
            ? _Usage(
                'Item category has $f custom field definition(s). '
                    'Delete those fields first.',
                'customFieldDefinitions',
                f,
              )
            : null;
      case MetaInUseKind.npcType:
        final c = _count(
          select,
          'SELECT COUNT(*) AS c FROM npcs '
          'WHERE npc_type_id = ? AND deleted_at IS NULL',
          id,
        );
        if (c > 0) return _Usage('NPC type is used by $c NPC(s).', 'npcs', c);
        final f = _count(
          select,
          'SELECT COUNT(*) AS c FROM custom_field_definitions '
          "WHERE scope_type = 'npc_type' AND scope_id = ?",
          id,
        );
        return f > 0
            ? _Usage(
                'NPC type has $f custom field definition(s). '
                    'Delete those fields first.',
                'customFieldDefinitions',
                f,
              )
            : null;
      case MetaInUseKind.craftingStation:
        final c = _count(
          select,
          'SELECT COUNT(*) AS c FROM recipes '
          'WHERE crafting_station_id = ? AND deleted_at IS NULL',
          id,
        );
        return c > 0
            ? _Usage('Station is used by $c recipe(s).', 'recipes', c)
            : null;
      case MetaInUseKind.craftingSpecialization:
        final c = _count(
          select,
          'SELECT COUNT(*) AS c FROM recipes '
          'WHERE crafting_specialization_id = ? AND deleted_at IS NULL',
          id,
        );
        return c > 0
            ? _Usage('Specialization is used by $c recipe(s).', 'recipes', c)
            : null;
      case MetaInUseKind.derivedStat:
        final c = _count(
          select,
          'SELECT COUNT(DISTINCT class_id) AS c '
          'FROM class_derived_stat_overrides WHERE derived_stat_id = ?',
          id,
        );
        return c > 0
            ? _Usage(
                'Derived stat has overrides in $c class(es).',
                'classes',
                c,
              )
            : null;
    }
  }

  // ─── Project settings ─────────────────────────────────────────────────────

  @override
  Future<ProjectSettingsDraft> loadProjectSettings() async =>
      _db.read((tx) => _loadSettings(tx.select));

  static ProjectSettingsDraft _loadSettings(_Select select) {
    final info = select(
      'SELECT game_title, max_level, soft_delete_reference_severity '
      'FROM project_info LIMIT 1',
    ).single;
    List<T> rows<T>(_Table table, T Function(Row) map) => [
      for (final r in select(table.selectAll)) map(r),
    ];
    return ProjectSettingsDraft(
      gameTitle: info['game_title'] as String,
      maxLevel: info['max_level'] as int,
      softDeleteReferenceSeverity: SoftDeleteReferenceSeverity.fromValue(
        info['soft_delete_reference_severity'] as String,
      ),
      stats: rows(_stats, _rowDraft),
      rarities: rows(_rarities, _rarityDraft),
      craftingStations: rows(_craftingStations, _rowDraft),
      craftingSpecializations: rows(_craftingSpecializations, _rowDraft),
      derivedStats: rows(_derivedStats, _derivedStatDraft),
    );
  }

  @override
  Future<ProjectSettingsDraft> saveProjectSettings(
    ProjectSettingsDraft draft,
  ) async => _db.saveTransaction(projectSettingsChanged, (tx) {
    tx.execute(
      'UPDATE project_info SET game_title = ?, max_level = ?, '
      'soft_delete_reference_severity = ?',
      [
        draft.gameTitle,
        draft.maxLevel,
        draft.softDeleteReferenceSeverity.value,
      ],
    );
    _commitList(tx, _stats, [
      for (final r in draft.stats)
        (r.id, _itemFields(r.displayName, r.exportKey)),
    ]);
    _commitList(tx, _rarities, [
      for (final r in draft.rarities)
        (r.id, _rarityFields(r.displayName, r.exportKey, r.colorHex)),
    ]);
    _commitList(tx, _craftingStations, [
      for (final r in draft.craftingStations)
        (r.id, _itemFields(r.displayName, r.exportKey)),
    ]);
    _commitList(tx, _craftingSpecializations, [
      for (final r in draft.craftingSpecializations)
        (r.id, _itemFields(r.displayName, r.exportKey)),
    ]);
    _commitList(tx, _derivedStats, [
      for (final r in draft.derivedStats)
        (
          r.id,
          _derivedStatFields(
            r.displayName,
            r.exportKey,
            r.formula,
            r.outputType,
            r.roundingMode,
          ),
        ),
    ]);
    return _loadSettings(tx.select);
  });

  /// Ports `commitMetaList`: deletes, then updates of changed rows, then
  /// adds (each at `MAX(sort_order) + 1`), then one renumbering to the
  /// draft order if the stored order differs from it (or has ties).
  static void _commitList(
    SaveScope tx,
    _Table table,
    List<(String, _Fields)> draft,
  ) {
    final stored = {
      for (final r in tx.select(table.selectAll)) r['id'] as String: r,
    };
    final draftIds = {for (final (id, _) in draft) id};

    for (final id in stored.keys) {
      if (!draftIds.contains(id)) _deleteRow(tx, table, id);
    }

    for (final (id, fields) in draft) {
      if (isNewMetaId(id)) continue;
      final row = stored[id];
      if (row == null) throw RecordNotFound(table.name, id);
      final changed = fields.entries.any((e) => row[e.key] != e.value);
      if (changed) _updateRow(tx, table, id, fields);
    }

    final finalIds = [
      for (final (id, fields) in draft)
        isNewMetaId(id) ? _insert(tx, table, fields) : id,
    ];

    final after = tx.select(
      'SELECT id, sort_order FROM ${table.name} '
      '${table.order}',
    );
    final orders = {for (final r in after) r['sort_order'] as int};
    final inOrder = [for (final r in after) r['id'] as String];
    final sameOrder =
        inOrder.length == finalIds.length &&
        Iterable<int>.generate(finalIds.length)
            .every((i) => inOrder[i] == finalIds[i]);
    if (sameOrder && orders.length == after.length) return;
    for (var i = 0; i < finalIds.length; i++) {
      tx.execute(
        'UPDATE ${table.name} SET sort_order = ?, updated_at = $_isoNow '
        'WHERE id = ?',
        [i, finalIds[i]],
      );
    }
  }
}

import 'package:sqlite3/sqlite3.dart';

import '../db/errors.dart';
import '../db/project_database.dart';
import '../db/save_descriptions.dart';
import '../domain/class_save_blockers.dart';
import '../domain/class_types.dart';
import '../domain/record_list_mode.dart';
import '../domain/stat_growth.dart';
import '../domain/used_by.dart';
import 'class_repository.dart';
import 'record_helpers.dart';
import 'record_id.dart';

/// `SELECT` through a [ReadScope] or a [SaveScope].
typedef _Select = ResultSet Function(String sql, [List<Object?> parameters]);

const String _table = 'classes';

/// 0.1.6 `class.repository.ts` `SELECT_COLS`.
const String _columns =
    'id, display_name, export_key, description, resource_multiplier, '
    'created_at, updated_at, deleted_at';

ClassRecord _record(Row r) => ClassRecord(
  id: r['id'] as String,
  displayName: r['display_name'] as String,
  exportKey: r['export_key'] as String,
  description: r['description'] as String,
  resourceMultiplier: (r['resource_multiplier'] as num).toDouble(),
  createdAt: r['created_at'] as String,
  updatedAt: r['updated_at'] as String,
  deletedAt: r['deleted_at'] as String?,
);

/// The `WHERE` clause of 0.1.6's `list(includeDeleted, deletedOnly)`.
String _where(RecordListMode mode) => switch (mode) {
  RecordListMode.active => 'WHERE deleted_at IS NULL',
  RecordListMode.all => '',
  RecordListMode.deletedOnly => 'WHERE deleted_at IS NOT NULL',
};

/// `ClassRepository` on a [ProjectDatabase], porting 0.1.6's
/// `class.repository.ts` and `domain-repository.ts`, with the five junction
/// get/set pairs folded into [load] and [save].
final class SqliteClassRepository implements ClassRepository {
  SqliteClassRepository(this._db);

  final ProjectDatabase _db;

  // ─── Reads ────────────────────────────────────────────────────────────────

  @override
  Future<List<ClassRecord>> list({
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
  Future<ClassRecord> get(String id) async =>
      _db.read((tx) => _requireRecord(tx.select, id));

  @override
  Future<ClassDraft> load(String id) async =>
      _db.read((tx) => _readDraft(tx.select, id));

  @override
  Future<List<UsedByRef>> usedBy(String id) async => _db.read(
    (tx) => [
      for (final r in tx.select(
        'SELECT DISTINCT n.id, n.display_name AS displayName '
        'FROM npc_class_assignments nca '
        'JOIN npcs n ON n.id = nca.npc_id '
        'WHERE nca.class_id = ? AND n.deleted_at IS NULL '
        'ORDER BY n.display_name COLLATE NOCASE',
        [id],
      ))
        UsedByRef(r['id'] as String, r['displayName'] as String),
    ],
  );

  @override
  Future<Map<StatGrowthKey, double>> resolvedStatGrowth(String id) async {
    final (draft, maxLevel) = _db.read((tx) {
      final draft = _readDraft(tx.select, id);
      final maxLevel =
          tx
                  .select('SELECT max_level FROM project_info LIMIT 1')
                  .single['max_level']
              as int;
      return (draft, maxLevel);
    });
    return resolveStatGrowth(
      manual: draft.statGrowth,
      formulas: draft.statGrowthFormulas,
      maxLevel: maxLevel,
    );
  }

  // ─── Writes ───────────────────────────────────────────────────────────────

  @override
  Future<ClassRecord> create(CreateClassInput input) async =>
      _db.saveTransaction(
        recordCreated(SaveDomain.classes, input.displayName),
        (tx) {
          final id = newRecordId();
          _checkExportKey(tx, input.exportKey, id);
          tx.execute(
            'INSERT INTO $_table '
            '(id, display_name, export_key, description, resource_multiplier) '
            'VALUES (?, ?, ?, ?, ?)',
            [
              id,
              input.displayName,
              input.exportKey,
              input.description,
              input.resourceMultiplier,
            ],
          );
          return _requireRecord(tx.select, id);
        },
      );

  @override
  Future<ClassDraft> save(String id, ClassDraft draft) async =>
      _db.saveTransaction(
        recordChanged(SaveDomain.classes, draft.displayName),
        (tx) {
          final blockers = classSaveBlockers(draft);
          if (blockers.isNotEmpty) {
            throw SaveBlocked([for (final b in blockers) b.message]);
          }
          _checkExportKey(tx, draft.exportKey, id);
          tx.execute(
            'UPDATE $_table SET display_name = ?, export_key = ?, '
            'description = ?, resource_multiplier = ?, '
            "updated_at = datetime('now') "
            'WHERE id = ? AND deleted_at IS NULL',
            [
              draft.displayName,
              draft.exportKey,
              draft.description,
              draft.resourceMultiplier,
              id,
            ],
          );
          if (tx.changes != 1) throw RecordNotFound(_table, id);
          _writeJunctions(tx, id, draft);
          return _readDraft(tx.select, id);
        },
      );

  @override
  Future<ClassRecord> duplicate(String id) async {
    final source = await get(id);
    final name = copyDisplayName(source.displayName);
    return _db.saveTransaction(recordDuplicated(SaveDomain.classes, name), (
      tx,
    ) {
      final newId = newRecordId();
      tx.execute(
        'INSERT INTO $_table '
        '(id, display_name, export_key, description, resource_multiplier) '
        'VALUES (?, ?, ?, ?, ?)',
        [
          newId,
          name,
          copyExportKey(name),
          source.description,
          source.resourceMultiplier,
        ],
      );
      _writeJunctions(tx, newId, _readDraft(tx.select, id));
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
    _db.saveTransaction(describe(SaveDomain.classes, record.displayName), (tx) {
      tx.execute(sql, [id]);
      if (tx.changes != 1) throw RecordNotFound(_table, id);
    });
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static ClassRecord _requireRecord(_Select select, String id) {
    final rows = select('SELECT $_columns FROM $_table WHERE id = ?', [id]);
    if (rows.isEmpty) throw RecordNotFound(_table, id);
    return _record(rows.single);
  }

  /// Refuses [exportKey] when another class holds it, before the `UNIQUE`
  /// constraint would, so the error can name the key.
  static void _checkExportKey(SaveScope tx, String exportKey, String id) {
    final clash = tx.select(
      'SELECT 1 FROM $_table WHERE export_key = ? AND id != ?',
      [exportKey, id],
    );
    if (clash.isNotEmpty) throw DuplicateExportKey(exportKey);
  }

  /// The class row and its junction lists in 0.1.6's read order. Formulas
  /// and overrides, which 0.1.6 read unordered, are ordered by key so the
  /// maps iterate the same way on every load.
  static ClassDraft _readDraft(_Select select, String id) {
    final record = _requireRecord(select, id);
    return ClassDraft(
      displayName: record.displayName,
      exportKey: record.exportKey,
      description: record.description,
      resourceMultiplier: record.resourceMultiplier,
      statGrowth: {
        for (final r in select(
          'SELECT stat_id, level, value FROM class_stat_growth '
          'WHERE class_id = ? ORDER BY stat_id, level',
          [id],
        ))
          StatGrowthKey(r['stat_id'] as String, r['level'] as int):
              (r['value'] as num).toDouble(),
      },
      statGrowthFormulas: {
        for (final r in select(
          'SELECT stat_id, formula FROM class_stat_growth_formulas '
          'WHERE class_id = ? ORDER BY stat_id',
          [id],
        ))
          r['stat_id'] as String: r['formula'] as String,
      },
      abilityIds: [
        for (final r in select(
          'SELECT ability_id FROM class_ability_assignments '
          'WHERE class_id = ? ORDER BY sort_order',
          [id],
        ))
          r['ability_id'] as String,
      ],
      derivedStatOverrides: {
        for (final r in select(
          'SELECT derived_stat_id, formula FROM class_derived_stat_overrides '
          'WHERE class_id = ? ORDER BY derived_stat_id',
          [id],
        ))
          r['derived_stat_id'] as String: r['formula'] as String,
      },
      metadataFields: [
        for (final r in select(
          'SELECT field_key, value FROM class_metadata_fields '
          'WHERE class_id = ? ORDER BY field_key',
          [id],
        ))
          ClassMetadataField(
            fieldKey: r['field_key'] as String,
            value: (r['value'] as num).toDouble(),
          ),
      ],
    );
  }

  /// Replaces the five junction lists of class [id] with [draft]'s, deleting
  /// then inserting as 0.1.6's `setX` methods did.
  static void _writeJunctions(SaveScope tx, String id, ClassDraft draft) {
    tx.execute('DELETE FROM class_stat_growth WHERE class_id = ?', [id]);
    for (final e in draft.statGrowth.entries) {
      tx.execute(
        'INSERT INTO class_stat_growth (class_id, stat_id, level, value) '
        'VALUES (?, ?, ?, ?)',
        [id, e.key.statId, e.key.level, e.value],
      );
    }

    tx.execute('DELETE FROM class_stat_growth_formulas WHERE class_id = ?', [
      id,
    ]);
    for (final f in draft.statGrowthFormulas.entries) {
      tx.execute(
        'INSERT INTO class_stat_growth_formulas (class_id, stat_id, formula) '
        'VALUES (?, ?, ?)',
        [id, f.key, f.value],
      );
    }

    tx.execute('DELETE FROM class_ability_assignments WHERE class_id = ?', [
      id,
    ]);
    for (var i = 0; i < draft.abilityIds.length; i++) {
      tx.execute(
        'INSERT INTO class_ability_assignments '
        '(class_id, ability_id, sort_order) VALUES (?, ?, ?)',
        [id, draft.abilityIds[i], i],
      );
    }

    tx.execute('DELETE FROM class_derived_stat_overrides WHERE class_id = ?', [
      id,
    ]);
    for (final o in draft.derivedStatOverrides.entries) {
      tx.execute(
        'INSERT INTO class_derived_stat_overrides '
        '(class_id, derived_stat_id, formula) VALUES (?, ?, ?)',
        [id, o.key, o.value],
      );
    }

    tx.execute('DELETE FROM class_metadata_fields WHERE class_id = ?', [id]);
    for (final f in draft.metadataFields) {
      tx.execute(
        'INSERT INTO class_metadata_fields (class_id, field_key, value) '
        'VALUES (?, ?, ?)',
        [id, f.fieldKey, f.value],
      );
    }
  }
}

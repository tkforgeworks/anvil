import 'package:sqlite3/sqlite3.dart';

import '../db/errors.dart';
import '../db/project_database.dart';
import '../db/save_descriptions.dart';
import '../domain/recipe_save_blockers.dart';
import '../domain/recipe_types.dart';
import '../domain/record_list_mode.dart';
import 'recipe_repository.dart';
import 'record_helpers.dart';
import 'record_id.dart';

/// `SELECT` through a [ReadScope] or a [SaveScope].
typedef _Select = ResultSet Function(String sql, [List<Object?> parameters]);

const String _table = 'recipes';
const String _columns =
    'id, display_name, export_key, description, output_item_id, '
    'output_quantity, crafting_station_id, crafting_specialization_id, '
    'created_at, updated_at, deleted_at';

/// 0.1.6 `DomainRepository.list`'s three `WHERE` clauses.
String _where(RecordListMode mode) => switch (mode) {
  RecordListMode.active => 'WHERE deleted_at IS NULL',
  RecordListMode.all => '',
  RecordListMode.deletedOnly => 'WHERE deleted_at IS NOT NULL',
};

RecipeRecord _record(Row r) => RecipeRecord(
  id: r['id'] as String,
  displayName: r['display_name'] as String,
  exportKey: r['export_key'] as String,
  description: r['description'] as String,
  outputItemId: r['output_item_id'] as String,
  outputQuantity: r['output_quantity'] as int,
  craftingStationId: r['crafting_station_id'] as String?,
  craftingSpecializationId: r['crafting_specialization_id'] as String?,
  createdAt: r['created_at'] as String,
  updatedAt: r['updated_at'] as String,
  deletedAt: r['deleted_at'] as String?,
);

RecipeRecord _get(_Select select, String id) {
  final rows = select('SELECT $_columns FROM $_table WHERE id = ?', [id]);
  if (rows.isEmpty) throw RecordNotFound(_table, id);
  return _record(rows.single);
}

/// 0.1.6 `getIngredients`.
List<RecipeIngredient> _ingredients(_Select select, String id) => [
  for (final r in select(
    'SELECT item_id, quantity FROM recipe_ingredients WHERE recipe_id = ? '
    'ORDER BY sort_order',
    [id],
  ))
    RecipeIngredient(
      itemId: r['item_id'] as String,
      quantity: r['quantity'] as int,
    ),
];

RecipeDraft _draft(_Select select, String id) {
  final record = _get(select, id);
  return RecipeDraft(
    displayName: record.displayName,
    exportKey: record.exportKey,
    description: record.description,
    outputItemId: record.outputItemId,
    outputQuantity: record.outputQuantity,
    craftingStationId: record.craftingStationId,
    craftingSpecializationId: record.craftingSpecializationId,
    ingredients: _ingredients(select, id),
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
  String id, {
  required String displayName,
  required String exportKey,
  required String description,
  required String outputItemId,
  required int outputQuantity,
  required String? craftingStationId,
  required String? craftingSpecializationId,
}) {
  tx.execute(
    'INSERT INTO $_table (id, display_name, export_key, description, '
    'output_item_id, output_quantity, crafting_station_id, '
    'crafting_specialization_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    [
      id,
      displayName,
      exportKey,
      description,
      outputItemId,
      outputQuantity,
      craftingStationId,
      craftingSpecializationId,
    ],
  );
}

/// 0.1.6 `setIngredients` without the delete: `sort_order` is the index.
void _insertIngredients(
  SaveScope tx,
  String recipeId,
  List<RecipeIngredient> ingredients,
) {
  for (final (i, ingredient) in ingredients.indexed) {
    tx.execute(
      'INSERT INTO recipe_ingredients (recipe_id, item_id, quantity, '
      'sort_order) VALUES (?, ?, ?, ?)',
      [recipeId, ingredient.itemId, ingredient.quantity, i],
    );
  }
}

/// `RecipeRepository` on a [ProjectDatabase], porting 0.1.6's
/// `recipe.repository.ts`.
final class SqliteRecipeRepository implements RecipeRepository {
  SqliteRecipeRepository(this._db);

  final ProjectDatabase _db;

  @override
  Future<List<RecipeRecord>> list({
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
  Future<RecipeRecord> get(String id) async =>
      _db.read((tx) => _get(tx.select, id));

  @override
  Future<RecipeDraft> load(String id) async =>
      _db.read((tx) => _draft(tx.select, id));

  @override
  Future<RecipeRecord> create(CreateRecipeInput input) async =>
      _db.saveTransaction(
        recordCreated(SaveDomain.recipes, input.displayName),
        (tx) {
          final id = newRecordId();
          _checkExportKey(tx, input.exportKey, id);
          _insert(
            tx,
            id,
            displayName: input.displayName,
            exportKey: input.exportKey,
            description: input.description,
            outputItemId: input.outputItemId,
            outputQuantity: input.outputQuantity,
            craftingStationId: input.craftingStationId,
            craftingSpecializationId: input.craftingSpecializationId,
          );
          return _get(tx.select, id);
        },
      );

  @override
  Future<RecipeDraft> save(String id, RecipeDraft draft) async => _db
      .saveTransaction(recordChanged(SaveDomain.recipes, draft.displayName), (
        tx,
      ) {
        final blockers = recipeSaveBlockers(draft);
        if (blockers.isNotEmpty) {
          throw SaveBlocked([for (final b in blockers) b.message]);
        }
        _checkExportKey(tx, draft.exportKey, id);

        tx.execute(
          'UPDATE $_table SET display_name = ?, export_key = ?, '
          'description = ?, output_item_id = ?, output_quantity = ?, '
          'crafting_station_id = ?, crafting_specialization_id = ?, '
          "updated_at = datetime('now') WHERE id = ? AND deleted_at IS NULL",
          [
            draft.displayName,
            draft.exportKey,
            draft.description,
            draft.outputItemId,
            draft.outputQuantity,
            draft.craftingStationId,
            draft.craftingSpecializationId,
            id,
          ],
        );
        if (tx.changes != 1) throw RecordNotFound(_table, id);

        tx.execute('DELETE FROM recipe_ingredients WHERE recipe_id = ?', [id]);
        _insertIngredients(tx, id, draft.ingredients);
        return _draft(tx.select, id);
      });

  @override
  Future<RecipeRecord> duplicate(String id) async {
    final source = _db.read((tx) => _get(tx.select, id));
    final name = copyDisplayName(source.displayName);
    return _db.saveTransaction(recordDuplicated(SaveDomain.recipes, name), (
      tx,
    ) {
      final source = _get(tx.select, id);
      final newId = newRecordId();
      final exportKey = copyExportKey(name);
      _checkExportKey(tx, exportKey, newId);
      _insert(
        tx,
        newId,
        displayName: name,
        exportKey: exportKey,
        description: source.description,
        outputItemId: source.outputItemId,
        outputQuantity: source.outputQuantity,
        craftingStationId: source.craftingStationId,
        craftingSpecializationId: source.craftingSpecializationId,
      );
      _insertIngredients(tx, newId, _ingredients(tx.select, id));
      return _get(tx.select, newId);
    });
  }

  @override
  Future<void> softDelete(String id) async {
    final name = _db.read((tx) => _get(tx.select, id)).displayName;
    _db.saveTransaction(recordDeleted(SaveDomain.recipes, name), (tx) {
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
    _db.saveTransaction(recordRestored(SaveDomain.recipes, name), (tx) {
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
    _db.saveTransaction(recordHardDeleted(SaveDomain.recipes, name), (tx) {
      // `recipe_ingredients` cascades on the recipe.
      tx.execute('DELETE FROM $_table WHERE id = ?', [id]);
      if (tx.changes != 1) throw RecordNotFound(_table, id);
    });
  }
}

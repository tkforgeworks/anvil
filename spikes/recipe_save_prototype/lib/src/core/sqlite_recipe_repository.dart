/// Raw-SQL recipe repository over a [ProjectDatabase]. Mirrors the Electron
/// `recipe.repository.ts`, except that the header update and the ingredient
/// replacement are one save instead of two IPC calls.
library;

import 'package:sqlite3/sqlite3.dart';

import 'project_database.dart';
import 'recipe_draft.dart';
import 'recipe_repository.dart';
import 'recipe_rules.dart';

final class SqliteRecipeRepository implements RecipeRepository {
  SqliteRecipeRepository(this._project);

  final ProjectDatabase _project;
  Database get _db => _project.db;

  @override
  Future<List<RecipeSummary>> listRecipes() async {
    final rows = _db.select(
      'SELECT id, display_name, export_key FROM recipes '
      'WHERE deleted_at IS NULL ORDER BY display_name COLLATE NOCASE',
    );
    return [
      for (final row in rows)
        RecipeSummary(
          id: row['id'] as String,
          displayName: row['display_name'] as String,
          exportKey: row['export_key'] as String,
        ),
    ];
  }

  @override
  Future<RecipeDraft> loadRecipe(String id) async => _load(id);

  RecipeDraft _load(String id) {
    final rows = _db.select(
      'SELECT id, display_name, export_key, description, output_item_id, '
      'output_quantity, crafting_station_id, crafting_specialization_id '
      'FROM recipes WHERE id = ? AND deleted_at IS NULL',
      [id],
    );
    if (rows.isEmpty) {
      throw RecipeNotFound(id);
    }
    final row = rows.first;
    final ingredients = _db.select(
      'SELECT item_id, quantity FROM recipe_ingredients '
      'WHERE recipe_id = ? ORDER BY sort_order, rowid',
      [id],
    );
    return RecipeDraft(
      id: row['id'] as String,
      displayName: row['display_name'] as String,
      exportKey: row['export_key'] as String,
      description: row['description'] as String,
      outputItemId: row['output_item_id'] as String,
      outputQuantity: row['output_quantity'] as int,
      craftingStationId: row['crafting_station_id'] as String?,
      craftingSpecializationId: row['crafting_specialization_id'] as String?,
      ingredients: [
        for (final line in ingredients)
          IngredientLine(
            itemId: line['item_id'] as String,
            quantity: line['quantity'] as int,
          ),
      ],
    );
  }

  @override
  Future<RecipeLookups> loadLookups() async {
    List<LookupOption> options(String sql) => [
      for (final row in _db.select(sql))
        LookupOption(
          id: row['id'] as String,
          displayName: row['display_name'] as String,
          archived: row['archived'] == 1,
        ),
    ];
    return RecipeLookups(
      items: options(
        'SELECT id, display_name, deleted_at IS NOT NULL AS archived '
        'FROM items ORDER BY display_name COLLATE NOCASE',
      ),
      stations: options(
        'SELECT id, display_name, 0 AS archived FROM crafting_stations '
        'ORDER BY sort_order, display_name',
      ),
      specializations: options(
        'SELECT id, display_name, 0 AS archived FROM crafting_specializations '
        'ORDER BY sort_order, display_name',
      ),
    );
  }

  @override
  Future<RecipeDraft> saveRecipe(RecipeDraft draft) async {
    final blockers = recipeBlockers(draft);
    if (blockers.isNotEmpty) {
      throw RecipeSaveBlocked(blockers);
    }
    return _project.saveTransaction(
      "Recipe '${draft.displayName}' changed",
      () {
        _db.execute(
          'UPDATE recipes SET display_name = ?, export_key = ?, '
          'description = ?, output_item_id = ?, output_quantity = ?, '
          'crafting_station_id = ?, crafting_specialization_id = ?, '
          "updated_at = datetime('now') "
          'WHERE id = ? AND deleted_at IS NULL',
          [
            draft.displayName,
            draft.exportKey,
            draft.description,
            draft.outputItemId,
            draft.outputQuantity,
            draft.craftingStationId,
            draft.craftingSpecializationId,
            draft.id,
          ],
        );
        if (_db.updatedRows != 1) {
          throw RecipeNotFound(draft.id);
        }
        _db.execute('DELETE FROM recipe_ingredients WHERE recipe_id = ?', [
          draft.id,
        ]);
        final insert = _db.prepare(
          'INSERT INTO recipe_ingredients '
          '(recipe_id, item_id, quantity, sort_order) VALUES (?, ?, ?, ?)',
        );
        try {
          for (var i = 0; i < draft.ingredients.length; i++) {
            final line = draft.ingredients[i];
            insert.execute([draft.id, line.itemId, line.quantity, i]);
          }
        } finally {
          insert.close();
        }
        return _load(draft.id);
      },
    );
  }
}

import '../domain/record_list_mode.dart';
import '../domain/recipe_types.dart';

/// The crafting recipes domain: replaces 0.1.6's `recipes:*` channels.
///
/// Every mutation is one save transaction with one save history row.
///
/// Errors: [get], [load], [save], [duplicate], [softDelete], [restore] and
/// [hardDelete] throw `RecordNotFound('recipes', id)` for an unknown id;
/// [save] also throws it for a soft-deleted recipe. [save] throws
/// `SaveBlocked` when `recipeSaveBlockers` reports anything, before any
/// write. [create] and [save] throw `DuplicateExportKey(key)` when another
/// recipe (soft-deleted ones included) has the export key. Any other SQLite
/// failure is `SaveFailed`.
abstract interface class RecipeRepository {
  /// Ordered by display name ignoring case.
  Future<List<RecipeRecord>> list({
    RecordListMode mode = RecordListMode.active,
  });

  /// Recipes that are not soft-deleted.
  Future<int> countActive();

  /// The row, soft-deleted or not.
  Future<RecipeRecord> get(String id);

  /// The draft of any existing recipe, soft-deleted or not, with its
  /// ingredients in `sort_order`.
  Future<RecipeDraft> load(String id);

  /// Inserts a recipe with no ingredients; recorded as
  /// `<name> - Recipe created`.
  Future<RecipeRecord> create(CreateRecipeInput input);

  /// Writes [draft] to the active recipe [id], replacing its ingredients
  /// with `sort_order` set to the list index, and returns it as read back;
  /// recorded as `<name> - Recipe changed`.
  Future<RecipeDraft> save(String id, RecipeDraft draft);

  /// Copies the recipe and its ingredients as `<name> (Copy)` with a fresh
  /// export key; recorded as `<name> (Copy) - Recipe duplicated`.
  Future<RecipeRecord> duplicate(String id);

  /// Recorded as `<name> - Recipe deleted`; an already deleted recipe keeps
  /// its `deleted_at`.
  Future<void> softDelete(String id);

  /// Recorded as `<name> - Recipe restored`.
  Future<void> restore(String id);

  /// Deletes the recipe; its ingredients cascade. Recorded as
  /// `<name> - Recipe permanently deleted`.
  Future<void> hardDelete(String id);
}

/// What the recipe editor is allowed to know about storage.
///
/// No SQL, no sqlite3 types, no transactions: the editor loads a draft,
/// edits it, and hands the whole draft back to [RecipeRepository.saveRecipe].
/// The implementation owns the transaction and the save-history row, so a
/// later storage change (background isolate, cloud-backup sync, a different
/// SQLite package) does not touch editor code.
library;

import 'recipe_draft.dart';
import 'recipe_rules.dart';

final class RecipeSummary {
  const RecipeSummary({
    required this.id,
    required this.displayName,
    required this.exportKey,
  });

  final String id;
  final String displayName;
  final String exportKey;
}

/// A pickable reference (item, station, specialization).
final class LookupOption {
  const LookupOption({
    required this.id,
    required this.displayName,
    this.archived = false,
  });

  final String id;
  final String displayName;

  /// Soft-deleted; shown only when the draft already references it.
  final bool archived;
}

final class RecipeLookups {
  const RecipeLookups({
    required this.items,
    required this.stations,
    required this.specializations,
  });

  final List<LookupOption> items;
  final List<LookupOption> stations;
  final List<LookupOption> specializations;

  String itemName(String id) => _name(items, id);
  String _name(List<LookupOption> options, String id) {
    for (final option in options) {
      if (option.id == id) return option.displayName;
    }
    return id;
  }
}

final class SaveHistoryEntry {
  const SaveHistoryEntry({
    required this.id,
    required this.savedAt,
    required this.description,
    required this.isAutoSave,
  });

  final int id;
  final String savedAt;
  final String description;
  final bool isAutoSave;
}

abstract interface class RecipeRepository {
  Future<List<RecipeSummary>> listRecipes();

  /// Throws [RecipeNotFound] for a missing or soft-deleted recipe.
  Future<RecipeDraft> loadRecipe(String id);

  Future<RecipeLookups> loadLookups();

  /// Writes the recipe row, replaces its ingredients and records one
  /// save-history row, all in one transaction, and returns the recipe as
  /// read back inside that transaction.
  ///
  /// Throws [RecipeSaveBlocked] (nothing written) when [recipeBlockers]
  /// finds a problem. Any other failure rolls the whole save back.
  Future<RecipeDraft> saveRecipe(RecipeDraft draft);
}

abstract interface class SaveHistoryReader {
  Future<List<SaveHistoryEntry>> recentSaves({int limit = 5});
}

final class RecipeNotFound implements Exception {
  const RecipeNotFound(this.id);
  final String id;
  @override
  String toString() => 'Recipe $id not found (missing or archived).';
}

final class RecipeSaveBlocked implements Exception {
  const RecipeSaveBlocked(this.blockers);
  final List<RecipeBlocker> blockers;
  @override
  String toString() => 'Save blocked: $blockers';
}

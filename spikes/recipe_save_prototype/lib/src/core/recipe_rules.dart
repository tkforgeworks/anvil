/// Save-blocking rules for a recipe draft.
///
/// Evaluated in the editor (to disable Save and show the message) and again
/// inside the repository's save, so no path (button, Ctrl+S, leave dialog,
/// a future caller) can write a blocked draft.
library;

import 'recipe_draft.dart';

enum RecipeBlockerKind {
  /// The output item is also one of the ingredients.
  outputUsedAsIngredient,

  /// The same item appears twice; `recipe_ingredients` has
  /// PRIMARY KEY (recipe_id, item_id), so the insert would fail.
  duplicateIngredient,

  /// `CHECK (quantity > 0)` on both quantities.
  nonPositiveQuantity,
}

final class RecipeBlocker {
  const RecipeBlocker(this.kind, {this.itemId});

  final RecipeBlockerKind kind;

  /// The item the blocker is about, where there is one.
  final String? itemId;

  @override
  bool operator ==(Object other) =>
      other is RecipeBlocker && other.kind == kind && other.itemId == itemId;

  @override
  int get hashCode => Object.hash(kind, itemId);

  @override
  String toString() => 'RecipeBlocker($kind, $itemId)';
}

List<RecipeBlocker> recipeBlockers(RecipeDraft draft) {
  final blockers = <RecipeBlocker>[];
  if (draft.ingredients.any((line) => line.itemId == draft.outputItemId)) {
    blockers.add(
      RecipeBlocker(
        RecipeBlockerKind.outputUsedAsIngredient,
        itemId: draft.outputItemId,
      ),
    );
  }
  final seen = <String>{};
  for (final line in draft.ingredients) {
    if (!seen.add(line.itemId) && line.itemId != draft.outputItemId) {
      blockers.add(
        RecipeBlocker(
          RecipeBlockerKind.duplicateIngredient,
          itemId: line.itemId,
        ),
      );
    }
  }
  if (draft.outputQuantity < 1 ||
      draft.ingredients.any((line) => line.quantity < 1)) {
    blockers.add(const RecipeBlocker(RecipeBlockerKind.nonPositiveQuantity));
  }
  return blockers;
}

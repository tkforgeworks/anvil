import 'recipe_types.dart';
import 'save_blocker.dart';

/// 0.1.6's `assertOutputIsNotIngredient` message, verbatim
/// (`recipe.repository.ts`, also shown by `RecipeEditorPage.tsx`).
const String outputIsIngredientMessage =
    'A recipe ingredient cannot be the same item as the output item.';

/// The rules that refuse a recipe save (design §8.6): an empty display name
/// or export key (after trimming), an empty output item, an output quantity
/// below 1, an ingredient quantity below 1, an item listed twice as an
/// ingredient (the `recipe_ingredients` primary key), and the output item
/// listed as an ingredient.
///
/// Ingredient rules carry the path `ingredients[i].quantity` or
/// `ingredients[i].itemId`; the duplicate rule is reported on the second
/// and later occurrences. An item id that no longer exists is not a
/// blocker; it is a validation issue.
List<SaveBlocker> recipeSaveBlockers(RecipeDraft draft) {
  final blockers = <SaveBlocker>[
    if (draft.displayName.trim().isEmpty)
      const SaveBlocker('displayName', 'Display name is required.'),
    if (draft.exportKey.trim().isEmpty)
      const SaveBlocker('exportKey', 'Export key is required.'),
    if (draft.outputItemId.isEmpty)
      const SaveBlocker('outputItemId', 'Output item is required.'),
    if (draft.outputQuantity < 1)
      const SaveBlocker(
        'outputQuantity',
        'Output quantity must be at least 1.',
      ),
  ];
  final seen = <String>{};
  for (final (i, ingredient) in draft.ingredients.indexed) {
    final number = i + 1;
    if (ingredient.quantity < 1) {
      blockers.add(
        SaveBlocker(
          'ingredients[$i].quantity',
          'Ingredient $number: quantity must be at least 1.',
        ),
      );
    }
    if (!seen.add(ingredient.itemId)) {
      blockers.add(
        SaveBlocker(
          'ingredients[$i].itemId',
          'Ingredient $number: the item is already an ingredient.',
        ),
      );
    }
    if (draft.outputItemId.isNotEmpty &&
        ingredient.itemId == draft.outputItemId) {
      blockers.add(
        SaveBlocker('ingredients[$i].itemId', outputIsIngredientMessage),
      );
    }
  }
  return blockers;
}

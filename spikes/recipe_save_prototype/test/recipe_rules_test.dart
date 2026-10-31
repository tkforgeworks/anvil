import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_save_prototype/src/core/recipe_draft.dart';
import 'package:recipe_save_prototype/src/core/recipe_rules.dart';

void main() {
  RecipeDraft draft({String output = 'sword', List<IngredientLine>? lines}) =>
      RecipeDraft(
        id: 'r1',
        displayName: 'Forge',
        exportKey: 'forge',
        description: '',
        outputItemId: output,
        outputQuantity: 1,
        craftingStationId: null,
        craftingSpecializationId: null,
        ingredients:
            lines ?? const [IngredientLine(itemId: 'ingot', quantity: 2)],
      );

  test('a valid draft has no blockers', () {
    expect(recipeBlockers(draft()), isEmpty);
  });

  test('AC7: output used as ingredient is a blocker', () {
    expect(
      recipeBlockers(
        draft(
          lines: const [
            IngredientLine(itemId: 'ingot', quantity: 2),
            IngredientLine(itemId: 'sword', quantity: 1),
          ],
        ),
      ),
      [
        const RecipeBlocker(
          RecipeBlockerKind.outputUsedAsIngredient,
          itemId: 'sword',
        ),
      ],
    );
  });

  test('a duplicate ingredient (would break the PK) is a blocker', () {
    expect(
      recipeBlockers(
        draft(
          lines: const [
            IngredientLine(itemId: 'ingot', quantity: 2),
            IngredientLine(itemId: 'ingot', quantity: 1),
          ],
        ),
      ).single.kind,
      RecipeBlockerKind.duplicateIngredient,
    );
  });

  test('draft value equality covers the ingredient list and its order', () {
    const a = IngredientLine(itemId: 'a', quantity: 1);
    const b = IngredientLine(itemId: 'b', quantity: 1);
    expect(draft(lines: [a, b]), draft(lines: [a, b]));
    expect(draft(lines: [a, b]), isNot(draft(lines: [b, a])));
    expect(
      draft()
          .copyWith(craftingStationId: 'forge')
          .copyWith(craftingStationId: null),
      draft(),
    );
  });
}

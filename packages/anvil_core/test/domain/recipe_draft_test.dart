import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

import 'support/draft_laws.dart';

RecipeDraft _build() => RecipeDraft(
  displayName: 'Forge Sword',
  exportKey: 'forge_sword',
  description: 'Hammer time',
  outputItemId: 'item-sword',
  outputQuantity: 2,
  craftingStationId: 'station-anvil',
  craftingSpecializationId: 'spec-smith',
  ingredients: [
    const RecipeIngredient(itemId: 'item-iron', quantity: 3),
    const RecipeIngredient(itemId: 'item-wood', quantity: 1),
  ],
);

void main() {
  draftLaws<RecipeDraft>(
    build: _build,
    // No keyed collections: the same build stands in.
    buildInOtherOrder: _build,
    copyWithNoArgs: (d) => d.copyWith(),
    changes: {
      'displayName': (d) => d.copyWith(displayName: 'Forge Axe'),
      'exportKey': (d) => d.copyWith(exportKey: 'forge_axe'),
      'description': (d) => d.copyWith(description: ''),
      'outputItemId': (d) => d.copyWith(outputItemId: 'item-axe'),
      'outputQuantity': (d) => d.copyWith(outputQuantity: 1),
      'craftingStationId': (d) => d.copyWith(craftingStationId: 'station-x'),
      'craftingStationId cleared': (d) => d.copyWith(craftingStationId: null),
      'craftingSpecializationId': (d) =>
          d.copyWith(craftingSpecializationId: 'spec-x'),
      'craftingSpecializationId cleared': (d) =>
          d.copyWith(craftingSpecializationId: null),
      'ingredient quantity': (d) => d.copyWith(
        ingredients: [d.ingredients[0].copyWith(quantity: 4), d.ingredients[1]],
      ),
      'ingredient item': (d) => d.copyWith(
        ingredients: [
          d.ingredients[0].copyWith(itemId: 'item-steel'),
          d.ingredients[1],
        ],
      ),
      'ingredient removed': (d) => d.copyWith(ingredients: [d.ingredients[0]]),
    },
    reorders: {
      'ingredients': (d) =>
          d.copyWith(ingredients: swapFirstTwo(d.ingredients)),
    },
    mutations: {'ingredients': (d) => d.ingredients.clear()},
  );

  test('copyWith keeps nullable references when they are omitted', () {
    final draft = _build().copyWith(displayName: 'Other');
    expect(draft.craftingStationId, 'station-anvil');
    expect(draft.craftingSpecializationId, 'spec-smith');
    expect(draft.copyWith(craftingStationId: null).craftingStationId, isNull);
  });

  test('create defaults match 0.1.6', () {
    const input = CreateRecipeInput(
      displayName: 'R',
      exportKey: 'r',
      outputItemId: 'item-x',
    );
    expect(input.description, '');
    expect(input.outputQuantity, 1);
    expect(input.craftingStationId, isNull);
    expect(input.craftingSpecializationId, isNull);
  });
}

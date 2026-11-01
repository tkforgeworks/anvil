import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

RecipeDraft _valid() => RecipeDraft(
  displayName: 'Forge Iron Sword',
  exportKey: 'forge_iron_sword',
  outputItemId: 'sword',
  outputQuantity: 1,
  ingredients: const [
    RecipeIngredient(itemId: 'ingot', quantity: 2),
    RecipeIngredient(itemId: 'strip', quantity: 1),
  ],
);

List<RecipeIngredient> _with(int index, RecipeIngredient ingredient) {
  final list = [..._valid().ingredients];
  list[index] = ingredient;
  return list;
}

void main() {
  test('a complete draft has no blockers', () {
    expect(recipeSaveBlockers(_valid()), isEmpty);
    expect(recipeSaveBlockers(_valid().copyWith(ingredients: [])), isEmpty);
  });

  test('an empty or blank display name blocks', () {
    expect(recipeSaveBlockers(_valid().copyWith(displayName: ' ')), [
      const SaveBlocker('displayName', 'Display name is required.'),
    ]);
  });

  test('an empty or blank export key blocks', () {
    expect(recipeSaveBlockers(_valid().copyWith(exportKey: '')), [
      const SaveBlocker('exportKey', 'Export key is required.'),
    ]);
  });

  test('an empty output item blocks', () {
    expect(recipeSaveBlockers(_valid().copyWith(outputItemId: '')), [
      const SaveBlocker('outputItemId', 'Output item is required.'),
    ]);
  });

  test('an output quantity below 1 blocks', () {
    for (final q in [0, -3]) {
      expect(recipeSaveBlockers(_valid().copyWith(outputQuantity: q)), [
        const SaveBlocker(
          'outputQuantity',
          'Output quantity must be at least 1.',
        ),
      ]);
    }
  });

  test('an ingredient quantity below 1 blocks with its index', () {
    final draft = _valid().copyWith(
      ingredients: _with(
        1,
        const RecipeIngredient(itemId: 'strip', quantity: 0),
      ),
    );
    expect(recipeSaveBlockers(draft), [
      const SaveBlocker(
        'ingredients[1].quantity',
        'Ingredient 2: quantity must be at least 1.',
      ),
    ]);
  });

  test('an item listed twice blocks on the second occurrence', () {
    final draft = _valid().copyWith(
      ingredients: [
        ..._valid().ingredients,
        const RecipeIngredient(itemId: 'ingot', quantity: 5),
      ],
    );
    expect(recipeSaveBlockers(draft), [
      const SaveBlocker(
        'ingredients[2].itemId',
        'Ingredient 3: the item is already an ingredient.',
      ),
    ]);
  });

  test('the output item as an ingredient blocks with the 0.1.6 message', () {
    final draft = _valid().copyWith(
      ingredients: _with(
        0,
        const RecipeIngredient(itemId: 'sword', quantity: 2),
      ),
    );
    expect(recipeSaveBlockers(draft), [
      const SaveBlocker(
        'ingredients[0].itemId',
        'A recipe ingredient cannot be the same item as the output item.',
      ),
    ]);
    expect(
      outputIsIngredientMessage,
      'A recipe ingredient cannot be the same item as the output item.',
    );
  });

  test('every broken rule is reported', () {
    final draft = RecipeDraft(
      displayName: '',
      exportKey: '',
      outputItemId: '',
      outputQuantity: 0,
      ingredients: const [
        RecipeIngredient(itemId: 'a', quantity: 0),
        RecipeIngredient(itemId: 'a', quantity: 1),
      ],
    );
    expect(
      [for (final b in recipeSaveBlockers(draft)) b.field],
      [
        'displayName',
        'exportKey',
        'outputItemId',
        'outputQuantity',
        'ingredients[0].quantity',
        'ingredients[1].itemId',
      ],
    );
  });

  test('an unknown item id is not a blocker', () {
    final draft = _valid().copyWith(outputItemId: 'no-such-item');
    expect(recipeSaveBlockers(draft), isEmpty);
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_save_prototype/src/app/providers.dart';
import 'package:recipe_save_prototype/src/app/recipe_editor_controller.dart';
import 'package:recipe_save_prototype/src/core/recipe_draft.dart';
import 'package:recipe_save_prototype/src/core/sqlite_recipe_repository.dart';

import 'support/fixture.dart';

void main() {
  late FixtureCopy fixture;
  late ProviderContainer container;
  late DateTime now;

  final editor = recipeEditorProvider(forgeIronSwordId);
  RecipeEditorController controller() => container.read(editor.notifier);
  RecipeEditorState state() => container.read(editor).requireValue;
  void wait(int ms) => now = now.add(Duration(milliseconds: ms));

  setUp(() async {
    fixture = FixtureCopy.open();
    now = DateTime(2026, 10, 31, 12);
    container = ProviderContainer.test(
      overrides: [
        projectDatabaseProvider.overrideWithValue(fixture.project),
        clockProvider.overrideWithValue(() => now),
      ],
      retry: (_, _) => null,
    );
    // Keep the autoDispose family alive for the whole test.
    container.listen(editor, (_, _) {});
    await container.read(editor.future);
  });

  tearDown(() => fixture.close());

  test('AC1: loads Forge Iron Sword and its two ingredients', () {
    expect(state().draft.displayName, 'Forge Iron Sword');
    expect(state().draft.ingredients.map((l) => l.itemId), [
      ironIngotId,
      leatherStripId,
    ]);
    expect(state().isDirty, isFalse);
  });

  test('AC2: dirty on edit, clean when typed back to the baseline', () {
    controller().setDisplayName('Forge Iron Swor');
    expect(state().isDirty, isTrue);
    wait(2000);
    controller().setDisplayName('Forge Iron Sword');
    expect(state().isDirty, isFalse);
  });

  test('AC2/AC3: undo steps back through ingredients and header to clean', () {
    controller().setDisplayName('Forge Steel Sword');
    wait(1000);
    controller().setIngredientQuantity(1, 4);
    controller().moveIngredient(1, 0);
    controller().addIngredient(moonpetalHerbId);
    controller().setStation(null);
    expect(state().history.past, hasLength(5));

    controller().undo(); // station back
    expect(state().draft.craftingStationId, 'crafting-station-forge');
    controller().undo(); // added line gone
    expect(state().draft.ingredients, hasLength(2));
    controller().undo(); // order back
    expect(state().draft.ingredients.first.itemId, ironIngotId);
    controller().undo(); // quantity back
    expect(state().draft.ingredients[1].quantity, 1);
    expect(state().isDirty, isTrue);
    controller().undo(); // name back
    expect(state().draft.displayName, 'Forge Iron Sword');
    expect(state().isDirty, isFalse);

    controller().redo();
    expect(state().draft.displayName, 'Forge Steel Sword');
  });

  test('typing a word quickly is one undo step', () {
    for (final ch in ' Mk2'.split('')) {
      controller().setDisplayName('${state().draft.displayName}$ch');
      wait(150);
    }
    expect(state().draft.displayName, 'Forge Iron Sword Mk2');
    expect(state().history.past, hasLength(1));
    controller().undo();
    expect(state().isDirty, isFalse);
  });

  test('AC6: save commits and rebases the draft to clean', () async {
    final historyBefore = fixture.historyCount();
    controller().setDisplayName('Forge Steel Sword');
    controller().removeIngredient(1);

    expect(await controller().save(), SaveOutcome.saved);

    expect(state().isDirty, isFalse);
    expect(state().baseline.displayName, 'Forge Steel Sword');
    expect(fixture.historyCount(), historyBefore + 1);
    final stored = await SqliteRecipeRepository(fixture.project)
        .loadRecipe(forgeIronSwordId);
    expect(stored, state().draft);
    expect(stored.ingredients, hasLength(1));
  });

  test(
    'AC6: a forced failure keeps the draft dirty and writes nothing',
    () async {
      final before = fixture.snapshot(forgeIronSwordId);
      container.read(forceSaveFailureProvider.notifier).set(true);
      controller().setDisplayName('Never Written');
      controller().setIngredientQuantity(0, 7);
      final draftBefore = state().draft;

      expect(await controller().save(), SaveOutcome.failed);

      expect(fixture.snapshot(forgeIronSwordId), before);
      expect(state().isDirty, isTrue);
      expect(state().draft, draftBefore);
      expect(state().saveError, contains('Forced save failure'));
      expect(state().canUndo, isTrue);

      // Turning the toggle off did not rebuild the editor (draft survives),
      // and the retry succeeds.
      container.read(forceSaveFailureProvider.notifier).set(false);
      expect(state().draft, draftBefore);
      expect(await controller().save(), SaveOutcome.saved);
      expect(fixture.historyCount(), (before['historyCount'] as int) + 1);
    },
  );

  test('AC7: output used as ingredient blocks the save path itself', () async {
    final before = fixture.snapshot(forgeIronSwordId);
    controller().setIngredientItem(0, ironSwordId);

    expect(state().blockers, isNotEmpty);
    expect(state().canSave, isFalse);
    expect(await controller().save(), SaveOutcome.blocked);
    expect(fixture.snapshot(forgeIronSwordId), before);
    expect(state().isDirty, isTrue);
  });

  test('IngredientLine edits compare by value', () {
    controller().setIngredientQuantity(0, 3);
    controller().setIngredientQuantity(0, 2);
    expect(
      state().draft.ingredients.first,
      const IngredientLine(itemId: ironIngotId, quantity: 2),
    );
    expect(state().isDirty, isFalse);
  });
}

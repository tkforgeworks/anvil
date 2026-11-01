import 'package:anvil/app/domains/recipes/recipes_editor_controller.dart';
import 'package:anvil/app/editor/clock.dart';
import 'package:anvil/app/editor/dirty_editors.dart';
import 'package:anvil/app/editor/editor_state.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../dialogs/fakes.dart' show copyFixture;
import 'fakes.dart';

void main() {
  group('over the fake repository', () {
    late RecipeTestHarness h;
    late DateTime now;
    final editor = recipeEditorProvider(swordId);
    RecipeEditorController c() => h.container.read(editor.notifier);
    EditorState<RecipeDraft> s() => h.container.read(editor).requireValue;
    void wait(int ms) => now = now.add(Duration(milliseconds: ms));

    setUp(() async {
      h = RecipeTestHarness();
      now = DateTime(2026, 11, 1, 12);
      h.build(overrides: [clockProvider.overrideWithValue(() => now)]);
      h.container.listen(editor, (_, _) {});
      await h.container.read(editor.future);
    });

    test('loads the record through the repository as a clean draft', () {
      expect(s().draft, swordDraft());
      expect(s().isDirty, isFalse);
      expect(s().blockers, isEmpty);
      expect(h.recipes.calls, ['load $swordId']);
    });

    test('every structural intent is one undo step', () {
      final steps = <void Function()>[
        () => c().setOutputItem(potionItemId),
        () => c().setStation(null),
        () => c().setSpecialization('spec-alchemy'),
        () => c().addIngredient(herbId),
        () => c().setIngredientItem(2, potionItemId),
        () => c().removeIngredient(0),
        () => c().moveIngredient(1, 0),
      ];
      final seen = <RecipeDraft>[s().draft];
      for (final step in steps) {
        step();
        expect(s().draft, isNot(seen.last));
        seen.add(s().draft);
      }
      final last = s().draft;
      expect(last.outputItemId, potionItemId);
      expect(last.craftingStationId, isNull);
      expect(last.craftingSpecializationId, 'spec-alchemy');
      expect(last.ingredients, const [
        RecipeIngredient(itemId: potionItemId, quantity: 1),
        RecipeIngredient(itemId: stripId, quantity: 1),
      ]);
      for (final expected in seen.reversed.skip(1)) {
        c().undo();
        expect(s().draft, expected);
      }
      expect(s().isDirty, isFalse);
      expect(s().canUndo, isFalse);
    });

    test('a reorder is one undo step and redoes', () {
      c().moveIngredient(0, 1);
      expect(s().draft.ingredients.map((i) => i.itemId), [stripId, ingotId]);
      c().undo();
      expect(s().draft, swordDraft());
      c().redo();
      expect(s().draft.ingredients.map((i) => i.itemId), [stripId, ingotId]);
    });

    test('out-of-range moves and edits change nothing', () {
      c().moveIngredient(0, 0);
      c().moveIngredient(0, 5);
      c().moveIngredient(-1, 0);
      c().removeIngredient(9);
      c().setIngredientQuantity(9, 4);
      expect(s().isDirty, isFalse);
      expect(s().canUndo, isFalse);
    });

    test('typing coalesces per field', () {
      c().setDescription('A');
      wait(100);
      c().setDescription('AB');
      wait(100);
      c().setExportKey('forge-iron-sword-2');
      wait(100);
      c().setOutputQuantity(1);
      wait(100);
      c().setOutputQuantity(12);
      wait(100);
      c().setIngredientQuantity(0, 3);
      wait(100);
      c().setIngredientQuantity(0, 30);
      c().undo();
      expect(s().draft.ingredients.first.quantity, 2);
      expect(s().draft.outputQuantity, 12);
      c().undo();
      expect(s().draft.outputQuantity, 1);
      c().undo();
      expect(s().draft.exportKey, 'forge-iron-sword');
      c().undo();
      expect(s().draft.description, '');
      expect(s().isDirty, isFalse);
    });

    test('the output as an ingredient blocks with the core message', () async {
      c().setIngredientItem(0, swordItemId);
      expect(s().blockers, [
        const SaveBlocker('ingredients[0].itemId', outputIsIngredientMessage),
      ]);
      expect(s().canSave, isFalse);
      expect(await c().save(), SaveOutcome.blocked);
      expect(h.recipes.calls, isNot(contains('save $swordId')));
    });

    test('a quantity below 1 blocks', () {
      c().setOutputQuantity(0);
      c().setIngredientQuantity(1, 0);
      expect(s().blockers.map((b) => b.field), [
        'outputQuantity',
        'ingredients[1].quantity',
      ]);
      expect(s().canSave, isFalse);
    });

    test(
      'save trims the text fields, rebases and bumps the epoch once',
      () async {
        c().setDisplayName('  Forge Iron Sword II ');
        c().setDescription(' Hot work. ');
        final before = h.epoch;
        expect(await c().save(), SaveOutcome.saved);
        expect(h.epoch, before + 1);
        final saved = h.recipes.drafts[swordId]!;
        expect(saved.displayName, 'Forge Iron Sword II');
        expect(saved.description, 'Hot work.');
        expect(s().draft, saved);
        expect(s().isDirty, isFalse);
        expect(s().canUndo, isTrue);
      },
    );

    test('a failed save keeps the draft with the message', () async {
      c().setDescription('x');
      h.recipes.failures['save'] = const DuplicateExportKey('forge-iron-sword');
      expect(await c().save(), SaveOutcome.failed);
      expect(s().isDirty, isTrue);
      expect(s().saveError, contains('forge-iron-sword'));
    });

    test('a dirty draft is listed in the dirty registry by name', () {
      c().setDescription('x');
      final entries = h.container.read(dirtyEditorsProvider).entries;
      expect(entries.map((e) => (e.domain, e.recordId, e.displayName)), [
        (SaveDomain.recipes, swordId, 'Forge Iron Sword'),
      ]);
    });
  });

  test('over the real repository, save writes one history row in one '
      'transaction', () async {
    final db = ProjectDatabase.open(copyFixture());
    addTearDown(db.close);
    final repository = SqliteRecipeRepository(db);
    final container = ProviderContainer.test(
      overrides: [recipeRepositoryProvider.overrideWithValue(repository)],
      retry: (_, _) => null,
    );
    final recipe = (await repository.list()).firstWhere(
      (r) => r.displayName == 'Forge Iron Sword',
    );
    final editor = recipeEditorProvider(recipe.id);
    container.listen(editor, (_, _) {});
    await container.read(editor.future);
    final controller = container.read(editor.notifier);
    final before = readRecentSaves(db, limit: 100);

    final original = container.read(editor).requireValue.draft;
    controller.moveIngredient(0, 1);
    controller.setOutputQuantity(2);
    controller.setStation(null);
    expect(await controller.save(), SaveOutcome.saved);

    final after = readRecentSaves(db, limit: 100);
    expect(after.length, before.length + 1);
    expect(
      after.map((e) => e.description),
      contains('Forge Iron Sword - Recipe changed'),
    );
    final stored = await repository.load(recipe.id);
    expect(stored.ingredients, original.ingredients.reversed.toList());
    expect(stored.outputQuantity, 2);
    expect(stored.craftingStationId, isNull);
    expect(container.read(editor).requireValue.draft, stored);
    expect(container.read(writeEpochProvider), 1);
  });
}

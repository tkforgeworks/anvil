import 'dart:async';

import 'package:anvil/app/editor/clock.dart';
import 'package:anvil/app/editor/editor_state.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_recipe_editor.dart';

void main() {
  late FakeRecipeStore store;
  late ProviderContainer container;
  late DateTime now;

  final editor = testRecipeEditorProvider(swordRecipeId);
  RecipeEditorControllerForTest controller() => container.read(editor.notifier);
  EditorState<RecipeDraft> state() => container.read(editor).requireValue;
  void wait(int ms) => now = now.add(Duration(milliseconds: ms));

  setUp(() async {
    store = FakeRecipeStore();
    now = DateTime(2026, 11, 1, 12);
    container = ProviderContainer.test(
      overrides: [
        fakeRecipeStoreProvider.overrideWithValue(store),
        clockProvider.overrideWithValue(() => now),
      ],
      retry: (_, _) => null,
    );
    // Keep the autoDispose family alive for the whole test.
    container.listen(editor, (_, _) {});
    await container.read(editor.future);
  });

  test('loads the record as a clean draft with no blockers', () {
    expect(state().draft, swordRecipe());
    expect(state().baseline, swordRecipe());
    expect(state().isDirty, isFalse);
    expect(state().canUndo || state().canRedo, isFalse);
    expect(state().blockers, isEmpty);
    expect(state().canSave, isFalse);
    expect(state().saving, isFalse);
    expect(state().saveError, isNull);
    expect(store.loads, 1);
  });

  test('a missing record is an error state', () async {
    final missing = testRecipeEditorProvider('nope');
    container.listen(missing, (_, _) {});
    await expectLater(
      container.read(missing.future),
      throwsA(isA<RecordNotFound>()),
    );
  });

  test('dirty on edit, clean when typed back to the baseline', () {
    controller().setDisplayName('Forge Iron Swor');
    expect(state().isDirty, isTrue);
    expect(state().canSave, isTrue);
    wait(2000);
    controller().setDisplayName('Forge Iron Sword');
    expect(state().isDirty, isFalse);
    expect(state().canSave, isFalse);
  });

  test('two edits 100 ms apart are one undo step', () {
    controller().setDisplayName('Forge Iron Sword ');
    wait(100);
    controller().setDisplayName('Forge Iron Sword M');
    expect(state().history.past, hasLength(1));
    controller().undo();
    expect(state().draft, swordRecipe());
  });

  test('two edits 600 ms apart are two undo steps', () {
    controller().setDisplayName('Forge Iron Sword ');
    wait(600);
    controller().setDisplayName('Forge Iron Sword M');
    expect(state().history.past, hasLength(2));
    controller().undo();
    expect(state().draft.displayName, 'Forge Iron Sword ');
  });

  test('a structural edit is its own step, even right after typing', () {
    controller().setDisplayName('Forge Steel Sword');
    controller().addIngredient('item-herb');
    controller().addIngredient('item-gem');
    expect(state().history.past, hasLength(3));
  });

  test('undo steps back to clean and redo replays', () {
    controller().setDisplayName('Forge Steel Sword');
    controller().setOutputQuantity(2);
    controller().addIngredient('item-herb');

    controller().undo();
    expect(state().draft.ingredients, hasLength(2));
    controller().undo();
    expect(state().draft.outputQuantity, 1);
    expect(state().isDirty, isTrue);
    controller().undo();
    expect(state().isDirty, isFalse);
    expect(state().canUndo, isFalse);
    expect(state().canRedo, isTrue);

    controller().redo();
    controller().redo();
    expect(state().draft.displayName, 'Forge Steel Sword');
    expect(state().draft.outputQuantity, 2);
    expect(state().canRedo, isTrue);
  });

  test('discard returns to the baseline with empty stacks', () {
    controller().setDisplayName('Forge Steel Sword');
    controller().addIngredient('item-herb');
    controller().discard();
    expect(state().draft, swordRecipe());
    expect(state().isDirty || state().canUndo || state().canRedo, isFalse);
  });

  test('a save rebases to clean and keeps the undo stack', () async {
    controller().setDisplayName('Forge Steel Sword');
    controller().addIngredient('item-herb');
    expect(container.read(writeEpochProvider), 0);

    expect(await controller().save(), SaveOutcome.saved);

    expect(container.read(writeEpochProvider), 1, reason: 'one bump per save');
    expect(store.saves, [swordRecipeId]);
    expect(store.records[swordRecipeId]!.displayName, 'Forge Steel Sword');
    expect(state().isDirty, isFalse);
    expect(state().baseline, store.records[swordRecipeId]);
    expect(state().history.past, hasLength(2));
    controller().undo();
    expect(state().isDirty, isTrue);
    expect(state().draft.ingredients, hasLength(2));
  });

  test('saving a clean draft writes nothing', () async {
    expect(await controller().save(), SaveOutcome.nothingToSave);
    expect(store.saves, isEmpty);
  });

  test('a failed save keeps the draft dirty and exposes the message', () async {
    store.saveErrors[swordRecipeId] = SaveFailed(
      'database is locked',
      Exception('SQLITE_BUSY'),
    );
    controller().setDisplayName('Never Written');
    final draftBefore = state().draft;

    expect(await controller().save(), SaveOutcome.failed);

    expect(store.records[swordRecipeId], swordRecipe());
    expect(state().isDirty, isTrue);
    expect(state().draft, draftBefore);
    expect(state().canUndo, isTrue);
    expect(state().saving, isFalse);
    expect(state().saveError, 'database is locked');

    // The next edit clears the message; a retry saves.
    controller().addIngredient('item-herb');
    expect(state().saveError, isNull);
    store.saveErrors.clear();
    expect(await controller().save(), SaveOutcome.saved);
    expect(state().isDirty, isFalse);
  });

  test(
    'SaveBlocked from the repository surfaces the joined messages',
    () async {
      store.saveErrors[swordRecipeId] = const SaveBlocked([
        'Export key is required.',
        'Output item is required.',
      ]);
      controller().setDisplayName('Forge Steel Sword');

      expect(await controller().save(), SaveOutcome.blocked);

      expect(
        state().saveError,
        'Export key is required.\nOutput item is required.',
      );
      expect(state().isDirty, isTrue);
    },
  );

  test('a blocked draft cannot save and save returns blocked', () async {
    controller().setIngredientItem(0, 'item-sword');

    expect(
      state().blockers,
      contains(
        const SaveBlocker('ingredients[0].itemId', outputIsIngredientMessage),
      ),
    );
    expect(state().isDirty, isTrue);
    expect(state().canSave, isFalse);
    expect(await controller().save(), SaveOutcome.blocked);
    expect(store.saves, isEmpty);

    controller().undo();
    expect(state().blockers, isEmpty);
  });

  test('edits are ignored while a save is in flight', () async {
    store.gate = Completer<void>();
    controller().setDisplayName('Forge Steel Sword');

    final saving = controller().save();
    expect(state().saving, isTrue);
    expect(state().canSave, isFalse);
    expect(await controller().save(), SaveOutcome.busy);
    controller().setDisplayName('Ignored');
    controller().undo();
    expect(state().draft.displayName, 'Forge Steel Sword');

    store.gate!.complete();
    expect(await saving, SaveOutcome.saved);
    expect(state().saving, isFalse);
    expect(state().isDirty, isFalse);
  });

  test('invalidating the providers it reads keeps the draft', () async {
    controller().setDisplayName('Forge Steel Sword');
    container.invalidate(clockProvider);
    container.invalidate(fakeRecipeStoreProvider);
    await pumpEventQueue();

    expect(state().draft.displayName, 'Forge Steel Sword');
    expect(store.loads, 1);
  });

  group('saveErrorMessage', () {
    test('names the duplicate export key', () {
      expect(
        saveErrorMessage(const DuplicateExportKey('iron_sword')),
        'The export key "iron_sword" is already used by another record.',
      );
      expect(
        saveErrorMessage(const DuplicateExportKey(null)),
        'The export key is already used by another record.',
      );
    });

    test('explains a missing record', () {
      expect(
        saveErrorMessage(const RecordNotFound('recipes', 'x')),
        'This record no longer exists. It may have been deleted.',
      );
    });

    test('falls back to toString', () {
      expect(saveErrorMessage(StateError('boom')), 'Bad state: boom');
    });
  });
}

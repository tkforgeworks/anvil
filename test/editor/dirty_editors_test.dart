import 'dart:async';

import 'package:anvil/app/editor/dirty_editors.dart';
import 'package:anvil/app/editor/editor_state.dart';
import 'package:anvil/app/editor/save_status.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_recipe_editor.dart';

void main() {
  late FakeRecipeStore store;
  late ProviderContainer container;

  final sword = testRecipeEditorProvider(swordRecipeId);
  final shield = testRecipeEditorProvider(shieldRecipeId);

  ProviderContainer newContainer() => ProviderContainer(
    overrides: [fakeRecipeStoreProvider.overrideWithValue(store)],
    retry: (_, _) => null,
  );

  Future<RecipeEditorControllerForTest> open(
    ProviderContainer container,
    String id,
  ) async {
    final provider = testRecipeEditorProvider(id);
    container.listen(provider, (_, _) {});
    await container.read(provider.future);
    return container.read(provider.notifier);
  }

  List<DirtyEditor> entries() => container.read(dirtyEditorsProvider).entries;
  SaveStatus status() => container.read(saveStatusProvider);
  DirtyEditorsNotifier registry() =>
      container.read(dirtyEditorsProvider.notifier);

  setUp(() {
    store = FakeRecipeStore();
    container = ProviderContainer.test(
      overrides: [fakeRecipeStoreProvider.overrideWithValue(store)],
      retry: (_, _) => null,
    );
  });

  test('a dirty editor is listed and leaves the list when saved', () async {
    final editor = await open(container, swordRecipeId);
    expect(container.read(dirtyEditorsProvider).isEmpty, isTrue);

    editor.setDisplayName('Forge Steel Sword');
    expect(entries(), hasLength(1));
    expect(entries().single.domain, SaveDomain.recipes);
    expect(entries().single.recordId, swordRecipeId);
    expect(entries().single.displayName, 'Forge Steel Sword');
    expect(entries().single.saving, isFalse);
    expect(entries().single.saveError, isNull);

    expect(await editor.save(), SaveOutcome.saved);
    expect(entries(), isEmpty);
  });

  test('an editor typed back or undone to clean leaves the list', () async {
    final editor = await open(container, swordRecipeId);
    editor.addIngredient('item-herb');
    expect(entries(), hasLength(1));
    editor.undo();
    expect(entries(), isEmpty);
    editor.redo();
    expect(entries(), hasLength(1));
    editor.discard();
    expect(entries(), isEmpty);
  });

  test('entries keep registration order; updates stay in place', () async {
    final first = await open(container, swordRecipeId);
    final second = await open(container, shieldRecipeId);
    second.setDisplayName('Shield');
    first.setDisplayName('Sword');
    second.setDisplayName('Shield II');
    expect(entries().map((e) => e.displayName), ['Shield II', 'Sword']);
  });

  test('saveAll saves in order and stops at the first failure', () async {
    final first = await open(container, swordRecipeId);
    final second = await open(container, shieldRecipeId);
    second.setDisplayName('Shield');
    first.setDisplayName('Sword');
    store.saveErrors[shieldRecipeId] = SaveFailed('disk full', Object());

    expect(await registry().saveAll(), isFalse);

    expect(store.saves, isEmpty);
    expect(entries().map((e) => e.recordId), [shieldRecipeId, swordRecipeId]);
    expect(entries().first.saveError, 'disk full');
    expect(status(), const SaveError('disk full'));

    store.saveErrors.clear();
    expect(await registry().saveAll(), isTrue);
    expect(store.saves, [shieldRecipeId, swordRecipeId]);
    expect(entries(), isEmpty);
  });

  test('saveAll with nothing dirty succeeds', () async {
    expect(await registry().saveAll(), isTrue);
  });

  test('save status counts dirty editors and is all saved after', () async {
    expect(status(), const AllSaved());
    final first = await open(container, swordRecipeId);
    final second = await open(container, shieldRecipeId);
    first.setDisplayName('Sword');
    expect(status(), const Unsaved(1));
    second.setDisplayName('Shield');
    expect(status(), const Unsaved(2));

    expect(await first.save(), SaveOutcome.saved);
    expect(status(), const Unsaved(1));
    expect(await second.save(), SaveOutcome.saved);
    expect(status(), const AllSaved());
  });

  test('save status shows a save in flight', () async {
    final editor = await open(container, swordRecipeId);
    store.gate = Completer<void>();
    editor.setDisplayName('Sword');

    final saving = editor.save();
    expect(status(), const Saving());
    expect(entries().single.saving, isTrue);

    store.gate!.complete();
    await saving;
    expect(status(), const AllSaved());
  });

  test('an edit after a failure clears the error status', () async {
    final editor = await open(container, swordRecipeId);
    store.saveErrors[swordRecipeId] = SaveFailed('disk full', Object());
    editor.setDisplayName('Sword');
    await editor.save();
    expect(status(), const SaveError('disk full'));

    editor.addIngredient('item-herb');
    expect(status(), const Unsaved(1));
  });

  test('a disposed editor leaves the list', () async {
    final sub = container.listen(sword, (_, _) {});
    await container.read(sword.future);
    container.read(sword.notifier).setDisplayName('Sword');
    await open(container, shieldRecipeId);
    container.read(shield.notifier).setDisplayName('Shield');
    expect(entries(), hasLength(2));

    sub.close();
    await pumpEventQueue();

    expect(container.exists(sword), isFalse);
    expect(entries().map((e) => e.recordId), [shieldRecipeId]);
  });

  test('an invalidated editor reloads clean and leaves the list', () async {
    final editor = await open(container, swordRecipeId);
    editor.setDisplayName('Sword');
    expect(entries(), hasLength(1));

    container.invalidate(sword);
    final reloaded = await container.read(sword.future);
    await pumpEventQueue();

    expect(reloaded.isDirty, isFalse);
    expect(entries(), isEmpty);
  });

  test('disposing the container with dirty editors is clean', () async {
    final own = newContainer();
    final editor = await open(own, swordRecipeId);
    editor.setDisplayName('Sword');
    expect(own.read(dirtyEditorsProvider).entries, hasLength(1));

    // The editor's scheduled removal runs after the registry is gone; an
    // error there would fail this test as an uncaught async error.
    own.dispose();
    await pumpEventQueue();
  });
}

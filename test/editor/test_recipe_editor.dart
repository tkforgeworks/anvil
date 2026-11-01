/// A concrete [RecordEditorController] over an in-memory recipe store, the
/// pattern a domain editor (ANVL-191 to 197) follows, without SQLite.
library;

import 'dart:async';

import 'package:anvil/app/editor/editor_state.dart';
import 'package:anvil/app/editor/record_editor_controller.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const swordRecipeId = 'recipe-sword';
const shieldRecipeId = 'recipe-shield';

RecipeDraft swordRecipe() => RecipeDraft(
  displayName: 'Forge Iron Sword',
  exportKey: 'forge_iron_sword',
  outputItemId: 'item-sword',
  ingredients: const [
    RecipeIngredient(itemId: 'item-ingot', quantity: 2),
    RecipeIngredient(itemId: 'item-strip', quantity: 1),
  ],
);

RecipeDraft shieldRecipe() => RecipeDraft(
  displayName: 'Forge Iron Shield',
  exportKey: 'forge_iron_shield',
  outputItemId: 'item-shield',
  ingredients: const [RecipeIngredient(itemId: 'item-ingot', quantity: 3)],
);

/// The repository stand-in: records by id, the saves it received, scripted
/// errors per id and an optional gate that holds saves in flight.
class FakeRecipeStore {
  FakeRecipeStore()
    : records = {swordRecipeId: swordRecipe(), shieldRecipeId: shieldRecipe()};

  final Map<String, RecipeDraft> records;
  final saves = <String>[];
  var loads = 0;

  /// Thrown by every save of that record id while set.
  final saveErrors = <String, Object>{};

  /// While set, saves wait for it to complete before writing.
  Completer<void>? gate;

  Future<RecipeDraft> load(String id) async {
    loads++;
    return records[id] ?? (throw RecordNotFound('recipes', id));
  }

  Future<RecipeDraft> save(String id, RecipeDraft draft) async {
    await gate?.future;
    if (saveErrors[id] case final error?) throw error;
    saves.add(id);
    // Read back as a repository would: the stored value, not the argument.
    records[id] = draft.copyWith();
    return records[id]!;
  }
}

/// Overridden in every test with a fresh store.
final fakeRecipeStoreProvider = Provider<FakeRecipeStore>(
  (ref) => throw UnimplementedError('fakeRecipeStoreProvider'),
);

final testRecipeEditorProvider = AsyncNotifierProvider.autoDispose
    .family<RecipeEditorControllerForTest, EditorState<RecipeDraft>, String>(
      RecipeEditorControllerForTest.new,
    );

class RecipeEditorControllerForTest
    extends RecordEditorController<RecipeDraft> {
  RecipeEditorControllerForTest(super.recordId);

  FakeRecipeStore get _store => ref.read(fakeRecipeStoreProvider);

  @override
  SaveDomain get domain => SaveDomain.recipes;

  @override
  Future<RecipeDraft> loadDraft() => _store.load(recordId);

  @override
  Future<RecipeDraft> saveDraft(RecipeDraft draft) =>
      _store.save(recordId, draft);

  @override
  List<SaveBlocker> blockersFor(RecipeDraft draft) => recipeSaveBlockers(draft);

  @override
  String displayNameOf(RecipeDraft draft) => draft.displayName;

  void setDisplayName(String value) =>
      edit((d) => d.copyWith(displayName: value), coalesceKey: 'displayName');

  void setOutputQuantity(int quantity) =>
      edit((d) => d.copyWith(outputQuantity: quantity));

  void addIngredient(String itemId) => edit(
    (d) => d.copyWith(
      ingredients: [
        ...d.ingredients,
        RecipeIngredient(itemId: itemId, quantity: 1),
      ],
    ),
  );

  void setIngredientItem(int index, String itemId) => edit((d) {
    final lines = [...d.ingredients];
    lines[index] = lines[index].copyWith(itemId: itemId);
    return d.copyWith(ingredients: lines);
  });
}

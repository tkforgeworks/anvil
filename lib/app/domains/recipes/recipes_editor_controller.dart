/// The recipe editor's controller (design §8.4) over [RecipeRepository].
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../editor/editor_state.dart';
import '../../editor/record_editor_controller.dart';
import '../../shell/shell_providers.dart';

/// One recipe draft per open record id.
final recipeEditorProvider = AsyncNotifierProvider.autoDispose
    .family<RecipeEditorController, EditorState<RecipeDraft>, String>(
      RecipeEditorController.new,
    );

/// Loads and saves through `recipeRepositoryProvider`, read at call time so
/// [build] watches nothing; the blockers are the core's
/// [recipeSaveBlockers].
///
/// Every intent is one undo step, except typing: the text fields and the
/// quantity fields coalesce by field (design §8.3). A reorder is one step.
class RecipeEditorController extends RecordEditorController<RecipeDraft> {
  RecipeEditorController(super.recordId);

  RecipeRepository get _repository => ref.read(recipeRepositoryProvider);

  @override
  SaveDomain get domain => SaveDomain.recipes;

  @override
  Future<RecipeDraft> loadDraft() => _repository.load(recordId);

  /// Trims the display name, export key and description, as 0.1.6's
  /// `handleSave` did; the read-back becomes the baseline and, since it
  /// is what was saved, the draft too.
  @override
  Future<RecipeDraft> saveDraft(RecipeDraft draft) => _repository.save(
    recordId,
    draft.copyWith(
      displayName: draft.displayName.trim(),
      exportKey: draft.exportKey.trim(),
      description: draft.description.trim(),
    ),
  );

  @override
  List<SaveBlocker> blockersFor(RecipeDraft draft) => recipeSaveBlockers(draft);

  @override
  String displayNameOf(RecipeDraft draft) => draft.displayName;

  void setDisplayName(String value) =>
      edit((d) => d.copyWith(displayName: value), coalesceKey: 'displayName');

  void setExportKey(String value) =>
      edit((d) => d.copyWith(exportKey: value), coalesceKey: 'exportKey');

  void setDescription(String value) =>
      edit((d) => d.copyWith(description: value), coalesceKey: 'description');

  void setOutputItem(String itemId) =>
      edit((d) => d.copyWith(outputItemId: itemId));

  /// Typed into a field, so coalesced like text.
  void setOutputQuantity(int quantity) => edit(
    (d) => d.copyWith(outputQuantity: quantity),
    coalesceKey: 'outputQuantity',
  );

  /// Null clears it.
  void setStation(String? stationId) =>
      edit((d) => d.copyWith(craftingStationId: stationId));

  /// Null clears it.
  void setSpecialization(String? specializationId) =>
      edit((d) => d.copyWith(craftingSpecializationId: specializationId));

  /// Appends [itemId] with quantity 1.
  void addIngredient(String itemId) => edit(
    (d) => d.copyWith(
      ingredients: [
        ...d.ingredients,
        RecipeIngredient(itemId: itemId, quantity: 1),
      ],
    ),
  );

  void removeIngredient(int index) =>
      _editIngredients(index, (lines) => lines..removeAt(index));

  void setIngredientItem(int index, String itemId) => _editIngredients(
    index,
    (lines) => lines..[index] = lines[index].copyWith(itemId: itemId),
  );

  /// Typed into a field, so coalesced per ingredient row.
  void setIngredientQuantity(int index, int quantity) => _editIngredients(
    index,
    (lines) => lines..[index] = lines[index].copyWith(quantity: quantity),
    coalesceKey: 'ingredients[$index].quantity',
  );

  /// Moves the ingredient at [from] to [to] (both indexes in the current
  /// list), one undo step; out-of-range or equal indexes do nothing.
  void moveIngredient(int from, int to) {
    final count = state.value?.draft.ingredients.length ?? 0;
    if (from == to || from < 0 || to < 0 || from >= count || to >= count) {
      return;
    }
    edit((d) {
      final lines = [...d.ingredients];
      lines.insert(to, lines.removeAt(from));
      return d.copyWith(ingredients: lines);
    });
  }

  void _editIngredients(
    int index,
    List<RecipeIngredient> Function(List<RecipeIngredient> lines) change, {
    String? coalesceKey,
  }) {
    final count = state.value?.draft.ingredients.length ?? 0;
    if (index < 0 || index >= count) return;
    edit(
      (d) => d.copyWith(ingredients: change([...d.ingredients])),
      coalesceKey: coalesceKey,
    );
  }
}

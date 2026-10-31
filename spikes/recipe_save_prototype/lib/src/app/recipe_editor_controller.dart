/// One draft per open recipe editor, as a Riverpod 3 AsyncNotifier family
/// keyed by recipe ID. The undo/dirty logic lives in [DraftHistory]; this
/// class only maps editor intents onto draft edits and runs the save.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/draft_history.dart';
import '../core/recipe_draft.dart';
import '../core/recipe_repository.dart';
import '../core/recipe_rules.dart';
import 'providers.dart';

final class RecipeEditorState {
  const RecipeEditorState({
    required this.history,
    this.saving = false,
    this.saveError,
  });

  final DraftHistory<RecipeDraft> history;
  final bool saving;

  /// Last save failure, cleared by the next edit or save.
  final String? saveError;

  RecipeDraft get draft => history.current;
  RecipeDraft get baseline => history.baseline;
  bool get isDirty => history.isDirty;
  bool get canUndo => history.canUndo;
  bool get canRedo => history.canRedo;
  List<RecipeBlocker> get blockers => recipeBlockers(draft);
  bool get canSave => isDirty && blockers.isEmpty && !saving;
}

enum SaveOutcome { saved, nothingToSave, blocked, failed, busy }

final recipeEditorProvider = AsyncNotifierProvider.autoDispose
    .family<RecipeEditorController, RecipeEditorState, String>(
      RecipeEditorController.new,
    );

class RecipeEditorController extends AsyncNotifier<RecipeEditorState> {
  RecipeEditorController(this.recipeId);

  final String recipeId;

  @override
  Future<RecipeEditorState> build() async {
    final draft = await ref
        .watch(recipeRepositoryProvider)
        .loadRecipe(recipeId);
    return RecipeEditorState(history: DraftHistory.start(draft));
  }

  // --- Header fields -------------------------------------------------------

  void setDisplayName(String value) =>
      _edit((d) => d.copyWith(displayName: value), coalesceKey: 'displayName');

  void setExportKey(String value) =>
      _edit((d) => d.copyWith(exportKey: value), coalesceKey: 'exportKey');

  void setDescription(String value) =>
      _edit((d) => d.copyWith(description: value), coalesceKey: 'description');

  void setOutputItem(String itemId) =>
      _edit((d) => d.copyWith(outputItemId: itemId));

  void setOutputQuantity(int quantity) =>
      _edit((d) => d.copyWith(outputQuantity: quantity));

  void setStation(String? stationId) =>
      _edit((d) => d.copyWith(craftingStationId: stationId));

  void setSpecialization(String? specializationId) =>
      _edit((d) => d.copyWith(craftingSpecializationId: specializationId));

  // --- Ingredients ---------------------------------------------------------

  void addIngredient(String itemId) => _edit(
    (d) => d.copyWith(
      ingredients: [
        ...d.ingredients,
        IngredientLine(itemId: itemId, quantity: 1),
      ],
    ),
  );

  void removeIngredient(int index) => _edit(
    (d) => d.copyWith(ingredients: [...d.ingredients]..removeAt(index)),
  );

  void moveIngredient(int from, int to) => _edit((d) {
    final lines = [...d.ingredients];
    lines.insert(to, lines.removeAt(from));
    return d.copyWith(ingredients: lines);
  });

  void setIngredientItem(int index, String itemId) => _edit((d) {
    final lines = [...d.ingredients];
    lines[index] = lines[index].copyWith(itemId: itemId);
    return d.copyWith(ingredients: lines);
  });

  void setIngredientQuantity(int index, int quantity) => _edit((d) {
    final lines = [...d.ingredients];
    lines[index] = lines[index].copyWith(quantity: quantity);
    return d.copyWith(ingredients: lines);
  });

  // --- History -------------------------------------------------------------

  void undo() => _replaceHistory((h) => h.undo());
  void redo() => _replaceHistory((h) => h.redo());
  void discard() => _replaceHistory((h) => h.discard());

  // --- Save ----------------------------------------------------------------

  /// The only write path. The blocking rules are checked here (and again in
  /// the repository), so the Save button, Ctrl+S and the leave dialog all
  /// get the same answer.
  Future<SaveOutcome> save() async {
    final current = state.value;
    if (current == null || current.saving) return SaveOutcome.busy;
    if (current.blockers.isNotEmpty) return SaveOutcome.blocked;
    if (!current.isDirty) return SaveOutcome.nothingToSave;

    final snapshot = current.draft;
    state = AsyncData(
      RecipeEditorState(history: current.history, saving: true),
    );
    try {
      final persisted = await ref
          .read(recipeRepositoryProvider)
          .saveRecipe(snapshot);
      if (!ref.mounted) return SaveOutcome.saved;
      final latest = state.requireValue;
      state = AsyncData(
        RecipeEditorState(
          history: latest.history.rebase(saved: snapshot, persisted: persisted),
        ),
      );
      ref.invalidate(recipeListProvider);
      ref.invalidate(saveHistoryProvider);
      return SaveOutcome.saved;
    } catch (error) {
      if (ref.mounted) {
        // The draft is untouched: still dirty, still undoable.
        state = AsyncData(
          RecipeEditorState(
            history: state.requireValue.history,
            saveError: error.toString(),
          ),
        );
      }
      return error is RecipeSaveBlocked
          ? SaveOutcome.blocked
          : SaveOutcome.failed;
    }
  }

  void _edit(RecipeDraft Function(RecipeDraft) change, {String? coalesceKey}) {
    _replaceHistory(
      (h) => h.edit(
        change(h.current),
        coalesceKey: coalesceKey,
        now: ref.read(clockProvider)(),
      ),
    );
  }

  void _replaceHistory(
    DraftHistory<RecipeDraft> Function(DraftHistory<RecipeDraft>) change,
  ) {
    final current = state.value;
    if (current == null || current.saving) return;
    final next = change(current.history);
    if (identical(next, current.history)) return;
    state = AsyncData(RecipeEditorState(history: next));
  }
}

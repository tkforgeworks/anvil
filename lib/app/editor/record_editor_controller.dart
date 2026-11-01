/// The shared base of every record editor's controller (design §8.4,
/// §8.5), generalised from the ANVL-158 spike's recipe controller.
library;

import 'dart:async';

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'clock.dart';
import 'dirty_editors.dart';
import 'editor_state.dart';

/// One draft per open record, held in an
/// `AsyncNotifierProvider.autoDispose.family` keyed by record id. A domain
/// editor subclasses this, implements the five hooks and adds its intent
/// methods (`setDisplayName`, `addIngredient`, ...) on top of [edit]:
///
/// ```dart
/// final recipeEditorProvider = AsyncNotifierProvider.autoDispose
///     .family<RecipeEditorController, EditorState<RecipeDraft>, String>(
///       RecipeEditorController.new,
///     );
///
/// class RecipeEditorController extends RecordEditorController<RecipeDraft> {
///   RecipeEditorController(super.recordId);
///   ...
/// }
/// ```
///
/// [build] watches nothing. The repository reaches a subclass through
/// `ref.read` in its hooks (or its own constructor), never through
/// `ref.watch` in a build: a provider rebuild would rebuild the editor,
/// reload the record from disk and throw the draft away (ANVL-158
/// gotcha 6). The per-domain repository providers (`recipeRepositoryProvider`
/// and the rest) are not defined yet: they read the `ProjectSession`
/// repository fields that ANVL-179 adds and land with ANVL-185.
///
/// The controller keeps its entry in [dirtyEditorsProvider] current: put
/// while the draft is dirty, removed when it is clean, saved or disposed.
abstract class RecordEditorController<T> extends AsyncNotifier<EditorState<T>> {
  RecordEditorController(this.recordId);

  /// The record this editor edits; the family argument.
  final String recordId;

  /// The domain, which groups this editor's entry in the dirty registry.
  SaveDomain get domain;

  /// Loads the record's draft; the baseline of a fresh history.
  @protected
  Future<T> loadDraft();

  /// Writes [draft] through the repository and returns the draft read back
  /// inside the save transaction, which becomes the new baseline. Throws
  /// the core's boundary errors (design §6.5) on failure.
  @protected
  Future<T> saveDraft(T draft);

  /// The save-blocking rules [draft] breaks (the domain's
  /// `xSaveBlockers` function in the core).
  @protected
  List<SaveBlocker> blockersFor(T draft);

  /// The draft's display name, as the dirty registry lists it.
  @protected
  String displayNameOf(T draft);

  late DirtyEditorsNotifier _registry;

  @override
  Future<EditorState<T>> build() async {
    final registry = _registry = ref.read(dirtyEditorsProvider.notifier);
    // Riverpod asserts that no provider is modified inside a life-cycle
    // callback, so the removal runs in a microtask just after the dispose.
    // A rebuild's own load awaits at least one later microtask, so the
    // removal always lands before the new build can turn dirty.
    ref.onDispose(
      () => scheduleMicrotask(() => registry.remove(domain, recordId)),
    );
    final draft = await loadDraft();
    return EditorState(
      history: DraftHistory.start(draft),
      blockers: blockersFor(draft),
    );
  }

  /// Applies [change] to the draft as one history step, or as part of the
  /// current burst when [coalesceKey] names the same field as the previous
  /// edit within 500 ms (typing). Structural edits pass no key. Ignored
  /// while loading or saving. Clears the last save error.
  @protected
  void edit(T Function(T draft) change, {String? coalesceKey}) =>
      _replaceHistory(
        (h) => h.edit(
          change(h.current),
          coalesceKey: coalesceKey,
          now: ref.read(clockProvider)(),
        ),
      );

  void undo() => _replaceHistory((h) => h.undo());

  void redo() => _replaceHistory((h) => h.redo());

  /// Back to the baseline with empty stacks.
  void discard() => _replaceHistory((h) => h.discard());

  /// The only write path, shared by the Save button, Ctrl+S, the leave
  /// prompt and Save all. The blockers are checked here and again in the
  /// repository. On failure the draft is kept, still dirty and undoable,
  /// and [EditorState.saveError] holds the message.
  Future<SaveOutcome> save() async {
    final current = state.value;
    if (current == null || current.saving) return SaveOutcome.busy;
    if (current.blockers.isNotEmpty) return SaveOutcome.blocked;
    if (!current.isDirty) return SaveOutcome.nothingToSave;

    final snapshot = current.draft;
    _emit(current.history, saving: true, blockers: current.blockers);
    try {
      final persisted = await saveDraft(snapshot);
      if (!ref.mounted) return SaveOutcome.saved;
      _emit(
        state.requireValue.history.rebase(
          saved: snapshot,
          persisted: persisted,
        ),
      );
      return SaveOutcome.saved;
    } catch (error) {
      if (ref.mounted) {
        final latest = state.requireValue;
        _emit(
          latest.history,
          blockers: latest.blockers,
          saveError: saveErrorMessage(error),
        );
      }
      return error is SaveBlocked ? SaveOutcome.blocked : SaveOutcome.failed;
    }
  }

  void _replaceHistory(
    DraftHistory<T> Function(DraftHistory<T> history) change,
  ) {
    final current = state.value;
    if (current == null || current.saving) return;
    final next = change(current.history);
    if (identical(next, current.history)) return;
    _emit(
      next,
      blockers: identical(next.current, current.draft)
          ? current.blockers
          : null,
    );
  }

  /// Sets the state and keeps the registry entry current. [blockers] is
  /// passed when the draft is unchanged, to skip recomputing them.
  void _emit(
    DraftHistory<T> history, {
    List<SaveBlocker>? blockers,
    bool saving = false,
    String? saveError,
  }) {
    final next = EditorState(
      history: history,
      blockers: blockers ?? blockersFor(history.current),
      saving: saving,
      saveError: saveError,
    );
    state = AsyncData(next);
    if (next.isDirty) {
      _registry.put(
        DirtyEditor(
          domain: domain,
          recordId: recordId,
          displayName: displayNameOf(next.draft),
          save: save,
          saving: saving,
          saveError: saveError,
        ),
      );
    } else {
      _registry.remove(domain, recordId);
    }
  }
}

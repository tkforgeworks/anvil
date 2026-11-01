/// The state every record editor controller holds (design §8.4) and the
/// outcomes of its save (design §8.5).
library;

import 'package:anvil_core/anvil_core.dart';

/// One open editor's draft, its history, its save blockers and its save
/// status. Built only by `RecordEditorController`; widgets read it and call
/// the controller's intent methods, never the history.
final class EditorState<T> {
  const EditorState({
    required this.history,
    required this.blockers,
    this.saving = false,
    this.saveError,
  });

  /// The baseline, the draft and the undo and redo stacks.
  final DraftHistory<T> history;

  /// The save-blocking rules [draft] breaks (design §8.6), recomputed by the
  /// controller on every change of the draft.
  final List<SaveBlocker> blockers;

  /// A save is in flight; edits are ignored until it ends.
  final bool saving;

  /// The message of the last failed save, cleared by the next edit, undo,
  /// redo, discard or save.
  final String? saveError;

  /// The draft the editor shows.
  T get draft => history.current;

  /// The record as last persisted.
  T get baseline => history.baseline;

  bool get isDirty => history.isDirty;
  bool get canUndo => history.canUndo;
  bool get canRedo => history.canRedo;

  /// Whether Save (the button, Ctrl+S and the leave prompt's Save) is
  /// enabled.
  bool get canSave => isDirty && blockers.isEmpty && !saving;
}

/// What a call to `RecordEditorController.save` did.
enum SaveOutcome {
  /// The draft was written and is the new baseline.
  saved,

  /// The draft equals the baseline; nothing was written.
  nothingToSave,

  /// A save-blocking rule refused the save, in the editor or in the
  /// repository; nothing was written.
  blocked,

  /// The repository failed; nothing was written and the draft is kept.
  failed,

  /// The editor is still loading or another save is in flight.
  busy,
}

/// The message a failed save shows (`EditorState.saveError`): the core's
/// boundary errors (design §6.5) by their content, anything else by its
/// `toString()`.
String saveErrorMessage(Object error) => switch (error) {
  SaveBlocked(:final blockers) => blockers.join('\n'),
  DuplicateExportKey(exportKey: final key?) =>
    'The export key "$key" is already used by another record.',
  DuplicateExportKey() => 'The export key is already used by another record.',
  SaveFailed(:final message) => message,
  RecordNotFound() => 'This record no longer exists. It may have been deleted.',
  _ => error.toString(),
};

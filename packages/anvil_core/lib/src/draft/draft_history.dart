/// Record-level draft with undo/redo, generic over the draft value type
/// (design §8.3), ported unchanged from the ANVL-158 save-model spike.
///
/// Flutter-free and Riverpod-free on purpose: every record editor (classes,
/// abilities, items, recipes, NPCs, loot tables) holds one of these in its
/// controller's state, and the logic is tested with plain unit tests.
///
/// [T] must have value equality (`==` and `hashCode` over every field), as
/// the core's `XDraft` types do. That is what lets [isDirty] be
/// `current != baseline`: typing a value back to what was saved, or undoing
/// back to it, clears the dirty marker without any bookkeeping.
library;

/// The baseline, the current draft and the undo and redo stacks of one
/// record editor. Every operation returns a new value; the stacks are
/// unmodifiable.
final class DraftHistory<T> {
  const DraftHistory._({
    required this.baseline,
    required this.current,
    required this.past,
    required this.future,
    this.burstKey,
    this.burstAt,
  });

  /// A fresh history whose draft equals [baseline] (nothing to undo).
  factory DraftHistory.start(T baseline) => DraftHistory<T>._(
    baseline: baseline,
    current: baseline,
    past: List<T>.unmodifiable(const []),
    future: List<T>.unmodifiable(const []),
  );

  /// Edits to the same field closer together than this are one undo step,
  /// so typing a word is one step (matches the Electron `useUndoRedo` hook).
  static const Duration coalesceWindow = Duration(milliseconds: 500);

  /// Oldest steps are dropped beyond this depth.
  static const int maxDepth = 200;

  /// The last persisted state of the record.
  final T baseline;

  /// The draft the editor shows.
  final T current;

  /// Undo stack, oldest first. `past.last` is what [undo] restores.
  final List<T> past;

  /// Redo stack, oldest first. `future.last` is what [redo] restores.
  final List<T> future;

  /// Coalescing key of the edit burst in progress, if any.
  final String? burstKey;

  /// When the last edit of the burst in progress was made, if any.
  final DateTime? burstAt;

  bool get isDirty => current != baseline;
  bool get canUndo => past.isNotEmpty;
  bool get canRedo => future.isNotEmpty;

  /// Applies an edit.
  ///
  /// [coalesceKey] names the field for typing edits: a run of edits with the
  /// same key, each within [coalesceWindow] of the previous one, collapses
  /// into one undo step. Structural edits (pickers, ingredient rows) pass no
  /// key and always make their own step.
  DraftHistory<T> edit(T next, {String? coalesceKey, required DateTime now}) {
    if (next == current) {
      return this;
    }
    final continuesBurst =
        coalesceKey != null &&
        coalesceKey == burstKey &&
        burstAt != null &&
        now.difference(burstAt!) < coalesceWindow;

    if (continuesBurst) {
      // The step that started this burst already saved the pre-burst draft
      // on `past`. If the burst has come back to it (typed then deleted),
      // drop the step instead of leaving a no-op on the stack.
      if (past.isNotEmpty && next == past.last) {
        return _copy(current: next, past: past.sublist(0, past.length - 1));
      }
      return _copy(current: next, burstKey: coalesceKey, burstAt: now);
    }

    // An edit that lands exactly on the previous snapshot is an undo. This
    // is what happens when a text field's own Ctrl+Z reverts its text and
    // the change flows back into the draft through onChanged.
    if (past.isNotEmpty && next == past.last) {
      return undo();
    }

    return _copy(
      current: next,
      past: _capped([...past, current]),
      future: const [],
      burstKey: coalesceKey,
      burstAt: now,
    );
  }

  DraftHistory<T> undo() {
    if (past.isEmpty) {
      return this;
    }
    return _copy(
      current: past.last,
      past: past.sublist(0, past.length - 1),
      future: [...future, current],
    );
  }

  DraftHistory<T> redo() {
    if (future.isEmpty) {
      return this;
    }
    return _copy(
      current: future.last,
      past: _capped([...past, current]),
      future: future.sublist(0, future.length - 1),
    );
  }

  /// After a successful save: [persisted] (the record as read back inside the
  /// save transaction) becomes the baseline. The undo stack is kept, so the
  /// user can still step back past the save; doing so marks the draft dirty
  /// again, which is correct. If the draft changed while the save was in
  /// flight ([saved] no longer equals [current]) the newer draft is kept.
  DraftHistory<T> rebase({required T saved, required T persisted}) {
    return DraftHistory<T>._(
      baseline: persisted,
      current: current == saved ? persisted : current,
      past: past,
      future: future,
    );
  }

  /// Throws the draft away: back to the baseline with empty stacks.
  DraftHistory<T> discard() => DraftHistory<T>.start(baseline);

  DraftHistory<T> _copy({
    required T current,
    List<T>? past,
    List<T>? future,
    String? burstKey,
    DateTime? burstAt,
  }) {
    return DraftHistory<T>._(
      baseline: baseline,
      current: current,
      past: List<T>.unmodifiable(past ?? this.past),
      future: List<T>.unmodifiable(future ?? this.future),
      // A step that is not part of a burst ends it.
      burstKey: burstKey,
      burstAt: burstAt,
    );
  }

  static List<T> _capped<T>(List<T> stack) =>
      stack.length <= maxDepth ? stack : stack.sublist(stack.length - maxDepth);
}

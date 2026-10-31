import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_save_prototype/src/core/draft_history.dart';

void main() {
  final t0 = DateTime(2026, 10, 31, 12);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  test('starts clean with nothing to undo', () {
    final h = DraftHistory.start('a');
    expect(h.isDirty, isFalse);
    expect(h.canUndo, isFalse);
    expect(h.canRedo, isFalse);
  });

  test('AC2: an edit marks dirty; editing back to the baseline clears it', () {
    final edited = DraftHistory.start('Sword').edit('Sword!', now: at(0));
    expect(edited.isDirty, isTrue);
    // No undo involved: value equality alone clears the marker.
    final back = edited.edit('Sword', coalesceKey: 'name', now: at(5000));
    expect(back.isDirty, isFalse);
  });

  test('AC2: undoing back to the baseline clears dirty', () {
    final h = DraftHistory.start('a')
        .edit('b', now: at(0))
        .edit('c', now: at(1));
    expect(h.undo().isDirty, isTrue);
    expect(h.undo().undo().isDirty, isFalse);
  });

  test('typing within the 500 ms window is one undo step', () {
    var h = DraftHistory.start('');
    for (final (i, text) in ['I', 'Ir', 'Iro', 'Iron'].indexed) {
      h = h.edit(text, coalesceKey: 'name', now: at(i * 200));
    }
    expect(h.past, ['']);
    expect(h.undo().current, '');
  });

  test('a pause longer than the window starts a new step', () {
    final h = DraftHistory.start('')
        .edit('Iron', coalesceKey: 'name', now: at(0))
        .edit('Iron ', coalesceKey: 'name', now: at(100))
        .edit('Iron S', coalesceKey: 'name', now: at(900));
    expect(h.past, ['', 'Iron ']);
  });

  test('different fields and structural edits never coalesce', () {
    final h = DraftHistory.start('0')
        .edit('1', coalesceKey: 'name', now: at(0))
        .edit('2', coalesceKey: 'key', now: at(10))
        .edit('3', now: at(20))
        .edit('4', now: at(30));
    expect(h.past, ['0', '1', '2', '3']);
  });

  test('a burst that returns to its start leaves no step behind', () {
    final h = DraftHistory.start('ab')
        .edit('abc', coalesceKey: 'name', now: at(0))
        .edit('ab', coalesceKey: 'name', now: at(100));
    expect(h.current, 'ab');
    expect(h.canUndo, isFalse);
    expect(h.isDirty, isFalse);
  });

  test('an edit that lands on the previous snapshot acts as undo', () {
    // What a text field's own Ctrl+Z looks like from the draft's side.
    final h = DraftHistory.start('x')
        .edit('y', now: at(0))
        .edit('x', coalesceKey: 'name', now: at(5000));
    expect(h.canUndo, isFalse);
    expect(h.future, ['y']);
  });

  test('redo replays; a new edit clears redo', () {
    final h = DraftHistory.start('a')
        .edit('b', now: at(0))
        .edit('c', now: at(1));
    final undone = h.undo().undo();
    expect(undone.redo().current, 'b');
    expect(undone.redo().redo().current, 'c');
    expect(undone.edit('z', now: at(2)).canRedo, isFalse);
  });

  test('rebase after save keeps undo; undoing past the save is dirty', () {
    final edited = DraftHistory.start('a').edit('b', now: at(0));
    final saved = edited.rebase(saved: 'b', persisted: 'b');
    expect(saved.isDirty, isFalse);
    expect(saved.baseline, 'b');
    expect(saved.undo().current, 'a');
    expect(saved.undo().isDirty, isTrue);
  });

  test('rebase keeps a draft that moved on during the save', () {
    final h = DraftHistory.start('a').edit('c', now: at(0));
    final rebased = h.rebase(saved: 'b', persisted: 'b');
    expect(rebased.current, 'c');
    expect(rebased.isDirty, isTrue);
  });

  test('discard returns to the baseline with empty stacks', () {
    final h = DraftHistory.start('a').edit('b', now: at(0)).discard();
    expect(h.current, 'a');
    expect(h.canUndo || h.canRedo || h.isDirty, isFalse);
  });

  test('the undo stack is capped', () {
    var h = DraftHistory.start(0);
    for (var i = 1; i <= DraftHistory.maxDepth + 50; i++) {
      h = h.edit(i, now: at(i));
    }
    expect(h.past, hasLength(DraftHistory.maxDepth));
    expect(h.past.first, 50);
  });
}

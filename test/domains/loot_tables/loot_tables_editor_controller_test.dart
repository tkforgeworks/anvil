import 'package:anvil/app/domains/loot_tables/loot_tables_editor_controller.dart';
import 'package:anvil/app/editor/clock.dart';
import 'package:anvil/app/editor/editor_state.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late LootTableTestHarness h;
  late DateTime now;
  final editor = lootTableEditorProvider(goblinId);
  LootTableEditorController c() => h.container.read(editor.notifier);
  EditorState<LootTableDraft> s() => h.container.read(editor).requireValue;
  void wait(int ms) => now = now.add(Duration(milliseconds: ms));
  List<String> order() => [for (final e in s().draft.entries) e.itemId];

  setUp(() async {
    h = LootTableTestHarness();
    now = DateTime(2026, 11, 1, 12);
    h.build(overrides: [clockProvider.overrideWithValue(() => now)]);
    h.container.listen(editor, (_, _) {});
    await h.container.read(editor.future);
  });

  test('loads the record through the repository as a clean draft', () {
    expect(s().draft, goblinDraft());
    expect(s().isDirty, isFalse);
    expect(s().blockers, isEmpty);
    expect(h.tables.calls, ['load $goblinId']);
  });

  test('every structural entry intent is one undo step', () {
    final steps = <void Function()>[
      () => c().addEntry(cursedId),
      () => c().setEntryItem(3, potionId),
      () => c().removeEntry(0),
      () => c().moveEntry(2, 0),
    ];
    final seen = <LootTableDraft>[s().draft];
    for (final step in steps) {
      step();
      expect(s().draft, isNot(seen.last));
      seen.add(s().draft);
    }
    expect(order(), [potionId, potionId, swordId]);
    // The added entry starts at weight 1, quantity 1 to 1.
    expect(
      s().draft.entries.first,
      LootTableEntryDraft(itemId: potionId, weight: 1),
    );
    for (final expected in seen.reversed.skip(1)) {
      c().undo();
      expect(s().draft, expected);
    }
    expect(s().isDirty, isFalse);
    expect(s().canUndo, isFalse);
  });

  test('a reorder is one undo step, redoes and keeps the flags', () {
    c().moveEntry(2, 0);
    expect(order(), [swordId, ingotId, potionId]);
    expect(s().draft.entries.first.conditionalFlags, {'boss_only': true});
    c().undo();
    expect(s().draft, goblinDraft());
    c().redo();
    expect(order(), [swordId, ingotId, potionId]);
  });

  test('out-of-range moves and edits change nothing', () {
    c().moveEntry(0, 0);
    c().moveEntry(0, 5);
    c().moveEntry(-1, 0);
    c().removeEntry(9);
    c().setEntryWeight(9, 4);
    c().setEntryItem(-1, potionId);
    expect(s().isDirty, isFalse);
    expect(s().canUndo, isFalse);
  });

  test('typing coalesces per field and per entry row', () {
    c().setDescription('A');
    wait(100);
    c().setDescription('AB');
    wait(100);
    c().setEntryWeight(0, 6);
    wait(100);
    c().setEntryWeight(0, 65);
    wait(100);
    c().setEntryWeight(1, 3);
    wait(100);
    c().setEntryQuantityMin(1, 2);
    wait(100);
    c().setEntryQuantityMax(1, 4);
    wait(100);
    c().setEntryQuantityMax(1, 40);

    c().undo();
    expect(s().draft.entries[1].quantityMax, 1);
    expect(s().draft.entries[1].quantityMin, 2);
    c().undo();
    expect(s().draft.entries[1].quantityMin, 1);
    c().undo();
    expect(s().draft.entries[1].weight, 30);
    expect(s().draft.entries[0].weight, 65);
    c().undo();
    expect(s().draft.entries[0].weight, 60);
    c().undo();
    expect(s().draft.description, 'What goblins carry.');
    expect(s().isDirty, isFalse);
  });

  test('a weight or minimum below 1 and a maximum below the minimum block '
      'Save with the core messages', () async {
    c().setEntryWeight(0, 0);
    c().setEntryQuantityMin(1, 0);
    c().setEntryQuantityMin(2, 3);
    expect(s().blockers, const [
      SaveBlocker('entries[0].weight', 'Entry 1: weight must be at least 1.'),
      SaveBlocker(
        'entries[1].quantityMin',
        'Entry 2: minimum quantity must be at least 1.',
      ),
      SaveBlocker(
        'entries[2].quantityMax',
        'Entry 3: maximum quantity cannot be less than the minimum.',
      ),
    ]);
    expect(s().canSave, isFalse);
    expect(await c().save(), SaveOutcome.blocked);
    expect(h.tables.calls, isNot(contains('save $goblinId')));
  });

  test('save trims the text fields, keeps the flags, rebases and bumps the '
      'epoch once', () async {
    c().setDisplayName('  Goblin Loot  ');
    c().setExportKey(' goblin_loot ');
    c().setDescription('  Pockets.  ');
    c().moveEntry(2, 0);
    final before = h.epoch;

    expect(await c().save(), SaveOutcome.saved);
    final saved = h.tables.drafts[goblinId]!;
    expect(saved.displayName, 'Goblin Loot');
    expect(saved.exportKey, 'goblin_loot');
    expect(saved.description, 'Pockets.');
    expect(saved.entries.first.conditionalFlags, {'boss_only': true});
    expect(s().draft, saved);
    expect(s().isDirty, isFalse);
    expect(h.epoch, before + 1);
  });

  test('duplicate returns the copy and bumps the epoch once', () async {
    final before = h.epoch;
    final copy = await c().duplicate();
    expect(copy.displayName, 'Goblin Drops (Copy)');
    expect(h.tables.drafts[copy.id]!.entries, goblinDraft().entries);
    expect(h.epoch, before + 1);
  });
}

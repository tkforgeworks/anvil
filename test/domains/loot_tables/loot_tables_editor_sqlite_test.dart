import 'package:anvil/app/domains/loot_tables/loot_tables_editor_controller.dart';
import 'package:anvil/app/editor/editor_state.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../dialogs/fakes.dart' show copyFixture;

/// The fixture's Goblin Drops: Iron Ingot (60, 1–3), Healing Potion (30)
/// and Iron Sword (10, `{"boss_only":true}`).
const goblinDrops = '1e11b296-71a9-4976-887b-d0f32e25becb';
const ironIngot = '11a74879-0851-4af7-8ff1-7be63edae9f2';
const healingPotion = 'a4b66c54-05d2-4007-bed7-8f13bee1f087';
const ironSword = '6069c26a-d758-4981-b29b-eed2c95fe6f3';

/// The loot table editor controller over the real repository on a copy of
/// the 0.1.6 fixture.
void main() {
  late ProjectDatabase db;
  late SqliteLootTableRepository tables;
  late SqliteSaveHistoryRepository history;
  late ProviderContainer container;
  final editor = lootTableEditorProvider(goblinDrops);

  setUp(() async {
    db = ProjectDatabase.open(copyFixture());
    addTearDown(db.close);
    tables = SqliteLootTableRepository(db);
    history = SqliteSaveHistoryRepository(db);
    container = ProviderContainer.test(
      overrides: [lootTableRepositoryProvider.overrideWithValue(tables)],
      retry: (_, _) => null,
    );
    container.listen(editor, (_, _) {});
    await container.read(editor.future);
  });

  LootTableEditorController c() => container.read(editor.notifier);
  EditorState<LootTableDraft> s() => container.read(editor).requireValue;

  test('save writes the reordered entries and one save history row in one '
      'transaction', () async {
    expect(
      [for (final e in s().draft.entries) e.itemId],
      [ironIngot, healingPotion, ironSword],
    );
    final before = await history.recent(limit: 50);

    c().moveEntry(2, 0);
    c().setEntryWeight(1, 45);
    expect(await c().save(), SaveOutcome.saved);
    expect(s().saveError, isNull);

    final after = await history.recent(limit: 50);
    expect(after.length, before.length + 1);
    expect(
      after.map((e) => e.description).where((d) => d.contains('Goblin Drops')),
      ['Goblin Drops - Loot Table changed'],
    );

    final stored = await tables.load(goblinDrops);
    expect(
      [for (final e in stored.entries) e.itemId],
      [ironSword, ironIngot, healingPotion],
    );
    expect(stored.entries[0].conditionalFlags, {'boss_only': true});
    expect(stored.entries[1].weight, 45);
    expect(stored.entries[1].quantityMax, 3);
    expect(s().draft, stored);
    expect(s().isDirty, isFalse);
  });

  test('a blocked draft writes nothing', () async {
    final before = await history.recent(limit: 50);
    c().setEntryQuantityMax(0, 0);
    expect(await c().save(), SaveOutcome.blocked);
    expect((await history.recent(limit: 50)).length, before.length);
    expect(await tables.load(goblinDrops), isNot(s().draft));
  });
}

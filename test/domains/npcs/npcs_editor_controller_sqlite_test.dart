import 'package:anvil/app/domains/npcs/npcs_editor_controller.dart';
import 'package:anvil/app/editor/editor_state.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../dialogs/fakes.dart' show copyFixture;

/// The fixture's ids: Goblin Raider is an Enemy with Warrior 3, Slash, the
/// Goblin Drops loot table, `{"hp":35,"armor":2}` combat stats (keyed by
/// names no stat has) and Aggression `hostile`.
const goblin = '9516c484-83f0-488a-a9d5-a7ce0f006d7f';
const warrior = '8cb0cf2e-a3f2-47ad-ad82-158dc9eb3d8a';
const mage = 'a7b87a4c-f898-4ebd-bfca-a8163101fc77';
const slash = 'a41d8d54-0a88-49c8-b53a-0cb21ef14f6a';
const fireball = '4e5b5a67-ba0b-43b2-bdfa-3bd426f83c7e';
const aggression = '3789fc46-bc57-4677-ad44-73d9b334788f';
const merchant = 'npc-type-merchant';

/// The NPC editor controller over the real repositories on a copy of the
/// 0.1.6 fixture.
void main() {
  late ProjectDatabase db;
  late SqliteNpcRepository npcs;
  late SqliteSaveHistoryRepository history;
  late ProviderContainer container;

  setUp(() {
    db = ProjectDatabase.open(copyFixture());
    addTearDown(db.close);
    npcs = SqliteNpcRepository(db);
    history = SqliteSaveHistoryRepository(db);
    container = ProviderContainer.test(
      overrides: [
        npcRepositoryProvider.overrideWithValue(npcs),
        customFieldRepositoryProvider.overrideWithValue(
          SqliteCustomFieldRepository(db),
        ),
        metaRepositoryProvider.overrideWithValue(SqliteMetaRepository(db)),
      ],
      retry: (_, _) => null,
    );
  });

  Future<NpcEditorController> open(String id) async {
    final provider = npcEditorProvider(id);
    container.listen(provider, (_, _) {});
    await container.read(provider.future);
    return container.read(provider.notifier);
  }

  EditorState<NpcDraft> state(String id) =>
      container.read(npcEditorProvider(id)).requireValue;

  test('save writes the assignments, overrides and custom field values with '
      'one save history row', () async {
    final controller = await open(goblin);
    expect(state(goblin).isDirty, isFalse);
    expect(controller.maxLevel, 20);
    final before = await history.recent(limit: 50);

    controller.addClassAssignment(mage);
    controller.setClassLevel(1, 4);
    controller.addAbility(fireball);
    controller.setStatOverride('stat-strength', 9);
    controller.setCustomFieldValue(aggression, 'wary');
    controller.setDescription('  Raids at dusk.  ');
    expect(await controller.save(), SaveOutcome.saved);
    expect(state(goblin).saveError, isNull);

    final after = await history.recent(limit: 50);
    expect(after.length, before.length + 1);
    expect(
      after.map((e) => e.description),
      contains('Goblin Raider - NPC changed'),
    );
    expect(container.read(writeEpochProvider), 1);

    final stored = await npcs.load(goblin);
    expect(stored.description, 'Raids at dusk.');
    expect(stored.classAssignments, const [
      NpcClassAssignment(classId: warrior, level: 3),
      NpcClassAssignment(classId: mage, level: 4),
    ]);
    expect(stored.abilityIds, [slash, fireball]);
    // The fixture's unseen keys survive beside the new override.
    expect(stored.combatStats, {'hp': 35, 'armor': 2, 'stat-strength': 9});
    expect(stored.customFieldValues, {aggression: 'wary'});
    expect(state(goblin).draft, stored);
    expect(state(goblin).isDirty, isFalse);
  });

  test(
    'a type change drops the old type values in the draft and on disk',
    () async {
      final controller = await open(goblin);
      await controller.setNpcType(merchant);
      expect(state(goblin).draft.customFieldValues, isEmpty);
      expect(await controller.save(), SaveOutcome.saved);
      final stored = await npcs.load(goblin);
      expect(stored.npcTypeId, merchant);
      expect(stored.customFieldValues, isEmpty);
    },
  );
}

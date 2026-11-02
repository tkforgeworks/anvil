import 'package:anvil/app/domains/npcs/npcs_editor_controller.dart';
import 'package:anvil/app/editor/clock.dart';
import 'package:anvil/app/editor/editor_state.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'npc_fakes.dart';

void main() {
  late NpcHarness h;
  late DateTime now;
  final editor = npcEditorProvider(goblinId);
  NpcEditorController c() => h.container.read(editor.notifier);
  EditorState<NpcDraft> s() => h.container.read(editor).requireValue;
  void wait(int ms) => now = now.add(Duration(milliseconds: ms));

  Future<void> open() async {
    h.container.listen(editor, (_, _) {});
    await h.container.read(editor.future);
  }

  setUp(() async {
    h = NpcHarness();
    now = DateTime(2026, 11, 1, 12);
    h.containerOnly(extra: [clockProvider.overrideWithValue(() => now)]);
  });

  test('loads the stored NPC as a clean draft with its type defaults kept '
      'out of the way of stored values', () async {
    await open();
    expect(s().isDirty, isFalse);
    expect(s().draft.customFieldValues, {
      'field-aggression': 'wary',
      'field-title': 'Scout',
    });
    expect(c().maxLevel, 20);
  });

  test('class assignments add at level 1, change level, remove, and each '
      'step undoes', () async {
    await open();
    c().addClassAssignment(mage);
    expect(s().draft.classAssignments, const [
      NpcClassAssignment(classId: warrior, level: 3),
      NpcClassAssignment(classId: mage, level: 1),
    ]);
    // An assigned class is not added twice.
    c().addClassAssignment(mage);
    expect(s().draft.classAssignments, hasLength(2));

    wait(1000);
    c().setClassLevel(1, 1);
    c().setClassLevel(1, 12);
    expect(s().draft.classAssignments[1].level, 12);

    wait(1000);
    c().removeClassAssignment(0);
    expect(s().draft.classAssignments, const [
      NpcClassAssignment(classId: mage, level: 12),
    ]);

    c().undo();
    expect(s().draft.classAssignments[0].classId, warrior);
    // The typed levels were one step.
    c().undo();
    expect(s().draft.classAssignments[1].level, 1);
    c().undo();
    expect(s().draft.classAssignments, hasLength(1));
    expect(s().isDirty, isFalse);
  });

  test(
    'a level is clamped to 1 and the project max level, as 0.1.6 did',
    () async {
      h.meta.maxLevel = 15;
      await open();
      expect(c().maxLevel, 15);
      c().setClassLevel(0, 0);
      expect(s().draft.classAssignments[0].level, 1);
      c().setClassLevel(0, 99);
      expect(s().draft.classAssignments[0].level, 15);
      expect(s().blockers, isEmpty);
    },
  );

  test('class assignments reorder as one step', () async {
    await open();
    c().addClassAssignment(mage);
    c().moveClassAssignment(1, 0);
    expect(s().draft.classAssignments.map((a) => a.classId), [mage, warrior]);
    c().moveClassAssignment(0, 5);
    expect(s().draft.classAssignments.map((a) => a.classId), [mage, warrior]);
    c().undo();
    expect(s().draft.classAssignments.map((a) => a.classId), [warrior, mage]);
  });

  test('abilities add, move and remove as single undo steps', () async {
    await open();
    c().addAbility(fireball);
    c().addAbility(fireball);
    expect(s().draft.abilityIds, [slash, fireball]);
    c().moveAbility(1, 0);
    expect(s().draft.abilityIds, [fireball, slash]);
    c().removeAbility(1);
    expect(s().draft.abilityIds, [fireball]);
    c().undo();
    c().undo();
    expect(s().draft.abilityIds, [slash, fireball]);
    c().undo();
    expect(s().isDirty, isFalse);
  });

  test('a stat override is set by typing in one step, an empty value '
      'removes the key and Revert is its own step', () async {
    await open();
    c().setStatOverride(strength, 1);
    c().setStatOverride(strength, 12);
    expect(s().draft.combatStats, {strength: 12});
    c().setStatOverride(strength, null);
    expect(s().draft.combatStats.containsKey(strength), isFalse);
    expect(s().isDirty, isFalse);

    c().setStatOverride(wisdom, 4);
    c().setStatOverride(strength, 7);
    wait(100);
    c().revertStatOverride(wisdom);
    expect(s().draft.combatStats, {strength: 7});
    c().undo();
    expect(s().draft.combatStats, {wisdom: 4, strength: 7});
  });

  test(
    'clearing an override the stored NPC had as null restores the null',
    () async {
      h.npcs.npcs[goblinId]!.draft = h.npcs.npcs[goblinId]!.draft.copyWith(
        combatStats: const {strength: null},
      );
      await open();
      c().setStatOverride(strength, 5);
      expect(s().isDirty, isTrue);
      c().setStatOverride(strength, null);
      expect(s().draft.combatStats, {strength: null});
      expect(s().isDirty, isFalse);
    },
  );

  test('changing the type re-scopes the custom fields: the shared field '
      'keeps its value, the others go, the new defaults fill in, and it '
      'undoes as one step', () async {
    await open();
    await c().setNpcType(merchant);
    expect(s().draft.npcTypeId, merchant);
    expect(s().draft.customFieldValues, {
      'field-title': 'Scout',
      'field-discount': '5',
    });
    c().undo();
    expect(s().draft.npcTypeId, enemy);
    expect(s().draft.customFieldValues, {
      'field-aggression': 'wary',
      'field-title': 'Scout',
    });
    expect(s().isDirty, isFalse);
  });

  test('loot table and custom field values edit and undo', () async {
    await open();
    c().setLootTable(null);
    expect(s().draft.lootTableId, isNull);
    c().setCustomFieldValue('field-title', '', typing: true);
    expect(s().draft.customFieldValues['field-title'], isNull);
    expect(s().draft.customFieldValues.containsKey('field-title'), isTrue);
    c().undo();
    c().undo();
    expect(s().isDirty, isFalse);
  });

  test('save trims the text fields and writes the whole draft once', () async {
    await open();
    c().setDisplayName('  Goblin Chief  ');
    c().setDescription(' Big. ');
    c().addClassAssignment(mage);
    c().addAbility(fireball);
    c().setStatOverride(strength, 9);
    expect(await c().save(), SaveOutcome.saved);
    expect(h.npcs.saved, hasLength(1));
    final saved = h.npcs.saved.single;
    expect(saved.displayName, 'Goblin Chief');
    expect(saved.description, 'Big.');
    expect(saved.classAssignments.map((a) => a.classId), [warrior, mage]);
    expect(saved.abilityIds, [slash, fireball]);
    expect(saved.combatStats, {strength: 9});
    expect(s().isDirty, isFalse);
    expect(h.container.read(writeEpochProvider), 1);
  });

  test('an empty name blocks the save with the core message', () async {
    await open();
    c().setDisplayName(' ');
    expect(s().blockers.map((b) => b.message), ['Display name is required.']);
    expect(await c().save(), SaveOutcome.blocked);
    expect(h.npcs.saved, isEmpty);
  });

  test('duplicate copies the stored NPC and bumps the epoch once', () async {
    await open();
    final copy = await c().duplicate();
    expect(copy.displayName, 'Goblin Raider (Copy)');
    expect(h.container.read(writeEpochProvider), 1);
  });
}

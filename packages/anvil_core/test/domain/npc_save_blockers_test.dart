import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

NpcDraft _valid() => NpcDraft(
  displayName: 'Goblin Raider',
  exportKey: 'goblin_raider',
  npcTypeId: 'npc-type-enemy',
  lootTableId: 'goblin-drops',
  combatStats: const {'hp': 35, 'armor': null},
  classAssignments: const [
    NpcClassAssignment(classId: 'warrior', level: 3),
    NpcClassAssignment(classId: 'mage', level: 1),
  ],
  abilityIds: const ['slash', 'fireball'],
  customFieldValues: const {'aggression': null},
);

void main() {
  test('a valid draft has no blockers', () {
    expect(npcSaveBlockers(_valid()), isEmpty);
  });

  test('an empty or blank display name blocks', () {
    for (final name in ['', '   ']) {
      expect(npcSaveBlockers(_valid().copyWith(displayName: name)), [
        const SaveBlocker('displayName', 'Display name is required.'),
      ]);
    }
  });

  test('an empty or blank export key blocks', () {
    for (final key in ['', ' \t']) {
      expect(npcSaveBlockers(_valid().copyWith(exportKey: key)), [
        const SaveBlocker('exportKey', 'Export key is required.'),
      ]);
    }
  });

  test('an empty NPC type blocks', () {
    expect(npcSaveBlockers(_valid().copyWith(npcTypeId: '')), [
      const SaveBlocker('npcTypeId', 'NPC type is required.'),
    ]);
  });

  test('a class assignment level below 1 blocks at that assignment', () {
    final draft = _valid().copyWith(
      classAssignments: const [
        NpcClassAssignment(classId: 'warrior', level: 1),
        NpcClassAssignment(classId: 'mage', level: 0),
        NpcClassAssignment(classId: 'rogue', level: -2),
      ],
    );
    expect(npcSaveBlockers(draft), [
      const SaveBlocker(
        'classAssignments[1].level',
        'Class assignment 2: level must be at least 1.',
      ),
      const SaveBlocker(
        'classAssignments[2].level',
        'Class assignment 3: level must be at least 1.',
      ),
    ]);
  });

  test('a repeated class blocks at each repeat, whatever the level', () {
    final draft = _valid().copyWith(
      classAssignments: const [
        NpcClassAssignment(classId: 'warrior', level: 3),
        NpcClassAssignment(classId: 'mage', level: 1),
        NpcClassAssignment(classId: 'warrior', level: 5),
        NpcClassAssignment(classId: 'warrior', level: 3),
      ],
    );
    expect(npcSaveBlockers(draft), [
      const SaveBlocker(
        'classAssignments[2].classId',
        'This class is already assigned to the NPC.',
      ),
      const SaveBlocker(
        'classAssignments[3].classId',
        'This class is already assigned to the NPC.',
      ),
    ]);
  });

  test('a repeated ability id blocks at each repeat', () {
    final draft = _valid().copyWith(
      abilityIds: ['slash', 'fireball', 'slash', 'slash'],
    );
    expect(npcSaveBlockers(draft), [
      const SaveBlocker(
        'abilityIds[2]',
        'This ability is already assigned to the NPC.',
      ),
      const SaveBlocker(
        'abilityIds[3]',
        'This ability is already assigned to the NPC.',
      ),
    ]);
  });

  test('every broken rule is reported, in field order', () {
    final draft = NpcDraft(
      displayName: '',
      exportKey: '',
      npcTypeId: '',
      classAssignments: const [
        NpcClassAssignment(classId: 'warrior', level: 0),
        NpcClassAssignment(classId: 'warrior', level: 2),
      ],
      abilityIds: const ['slash', 'slash'],
    );
    expect(
      [for (final b in npcSaveBlockers(draft)) b.field],
      [
        'displayName',
        'exportKey',
        'npcTypeId',
        'classAssignments[0].level',
        'classAssignments[1].classId',
        'abilityIds[1]',
      ],
    );
  });

  test('no loot table, a high level, empty combat stats and unknown ids are '
      'not blockers', () {
    final draft = _valid().copyWith(
      lootTableId: null,
      combatStats: const {},
      classAssignments: const [
        NpcClassAssignment(classId: 'no-such-class', level: 999),
      ],
      abilityIds: const ['no-such-ability'],
      customFieldValues: const {'no-such-field': ''},
    );
    expect(npcSaveBlockers(draft), isEmpty);
  });
}

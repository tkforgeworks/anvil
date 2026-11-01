import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

import 'support/draft_laws.dart';

NpcDraft _build({bool otherOrder = false}) {
  final combat = <(String, double?)>[
    ('stat-strength', 20),
    ('stat-wisdom', null),
    ('stat-dexterity', 7.5),
  ];
  final custom = <(String, String?)>[
    ('cfd-faction', 'goblins'),
    ('cfd-boss', 'false'),
  ];
  return NpcDraft(
    displayName: 'Goblin Chief',
    exportKey: 'goblin_chief',
    description: 'Leads the raid',
    npcTypeId: 'npc-type-humanoid',
    lootTableId: 'loot-goblin',
    combatStats: {
      for (final (k, v) in otherOrder ? combat.reversed : combat) k: v,
    },
    classAssignments: [
      const NpcClassAssignment(classId: 'class-warrior', level: 5),
      const NpcClassAssignment(classId: 'class-rogue', level: 2),
    ],
    abilityIds: ['ability-slash', 'ability-shout'],
    customFieldValues: {
      for (final (k, v) in otherOrder ? custom.reversed : custom) k: v,
    },
  );
}

void main() {
  draftLaws<NpcDraft>(
    build: _build,
    buildInOtherOrder: () => _build(otherOrder: true),
    copyWithNoArgs: (d) => d.copyWith(),
    changes: {
      'displayName': (d) => d.copyWith(displayName: 'Goblin King'),
      'exportKey': (d) => d.copyWith(exportKey: 'goblin_king'),
      'description': (d) => d.copyWith(description: ''),
      'npcTypeId': (d) => d.copyWith(npcTypeId: 'npc-type-beast'),
      'lootTableId': (d) => d.copyWith(lootTableId: 'loot-orc'),
      'lootTableId cleared': (d) => d.copyWith(lootTableId: null),
      'combatStats value': (d) =>
          d.copyWith(combatStats: {...d.combatStats, 'stat-strength': 21}),
      'combatStats null key removed': (d) => d.copyWith(
        combatStats: {
          'stat-strength': d.combatStats['stat-strength'],
          'stat-dexterity': d.combatStats['stat-dexterity'],
        },
      ),
      'class assignment level': (d) => d.copyWith(
        classAssignments: [
          d.classAssignments[0].copyWith(level: 6),
          d.classAssignments[1],
        ],
      ),
      'class assignment class': (d) => d.copyWith(
        classAssignments: [
          d.classAssignments[0].copyWith(classId: 'class-mage'),
          d.classAssignments[1],
        ],
      ),
      'abilityIds': (d) => d.copyWith(abilityIds: ['ability-slash']),
      'customFieldValues': (d) => d.copyWith(
        customFieldValues: {...d.customFieldValues, 'cfd-boss': 'true'},
      ),
    },
    reorders: {
      'classAssignments': (d) =>
          d.copyWith(classAssignments: swapFirstTwo(d.classAssignments)),
      'abilityIds': (d) => d.copyWith(abilityIds: swapFirstTwo(d.abilityIds)),
    },
    mutations: {
      'combatStats': (d) => d.combatStats.remove('stat-strength'),
      'classAssignments': (d) => d.classAssignments.add(
        const NpcClassAssignment(classId: 'class-x', level: 1),
      ),
      'abilityIds': (d) => d.abilityIds.insert(0, 'ability-x'),
      'customFieldValues': (d) => d.customFieldValues['cfd-x'] = null,
    },
  );

  test('copyWith keeps the loot table when it is omitted', () {
    final draft = _build().copyWith(description: 'x');
    expect(draft.lootTableId, 'loot-goblin');
    expect(draft.copyWith(lootTableId: null).lootTableId, isNull);
  });

  test('create defaults match 0.1.6', () {
    final input = CreateNpcInput(
      displayName: 'N',
      exportKey: 'n',
      npcTypeId: 'npc-type-x',
    );
    expect(input.description, '');
    expect(input.lootTableId, isNull);
    expect(input.combatStats, isEmpty);
  });
}

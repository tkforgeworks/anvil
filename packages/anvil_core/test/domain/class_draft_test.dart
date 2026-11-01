import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

import 'support/draft_laws.dart';

ClassDraft _build({bool otherOrder = false}) {
  final growth = [
    (const StatGrowthKey('stat-strength', 1), 10.0),
    (const StatGrowthKey('stat-strength', 2), 12.5),
    (const StatGrowthKey('stat-wisdom', 1), 4.0),
  ];
  final formulas = [('stat-wisdom', 'level * 2'), ('stat-dexterity', '5')];
  final overrides = [('ds-hp', 'con * 12'), ('ds-mp', 'int * 3')];
  return ClassDraft(
    displayName: 'Warrior',
    exportKey: 'warrior',
    description: 'Front line',
    resourceMultiplier: 1.5,
    statGrowth: {
      for (final (k, v) in otherOrder ? growth.reversed : growth) k: v,
    },
    statGrowthFormulas: {
      for (final (k, v) in otherOrder ? formulas.reversed : formulas) k: v,
    },
    abilityIds: ['ability-slash', 'ability-block'],
    derivedStatOverrides: {
      for (final (k, v) in otherOrder ? overrides.reversed : overrides) k: v,
    },
    metadataFields: [
      const ClassMetadataField(fieldKey: 'armor', value: 3),
      const ClassMetadataField(fieldKey: 'rage', value: 0.5),
    ],
  );
}

void main() {
  draftLaws<ClassDraft>(
    build: _build,
    buildInOtherOrder: () => _build(otherOrder: true),
    copyWithNoArgs: (d) => d.copyWith(),
    changes: {
      'displayName': (d) => d.copyWith(displayName: 'Knight'),
      'exportKey': (d) => d.copyWith(exportKey: 'knight'),
      'description': (d) => d.copyWith(description: ''),
      'resourceMultiplier': (d) => d.copyWith(resourceMultiplier: 1),
      'statGrowth value': (d) => d.copyWith(
        statGrowth: {
          ...d.statGrowth,
          const StatGrowthKey('stat-strength', 2): 13,
        },
      ),
      'statGrowth key added': (d) => d.copyWith(
        statGrowth: {
          ...d.statGrowth,
          const StatGrowthKey('stat-strength', 3): 15,
        },
      ),
      'statGrowthFormulas': (d) => d.copyWith(
        statGrowthFormulas: {...d.statGrowthFormulas, 'stat-dexterity': '6'},
      ),
      'abilityIds': (d) => d.copyWith(abilityIds: ['ability-slash']),
      'derivedStatOverrides': (d) => d.copyWith(
        derivedStatOverrides: {...d.derivedStatOverrides, 'ds-hp': 'con'},
      ),
      'metadataFields value': (d) => d.copyWith(
        metadataFields: [
          d.metadataFields[0].copyWith(value: 4),
          d.metadataFields[1],
        ],
      ),
      'metadataFields key': (d) => d.copyWith(
        metadataFields: [
          d.metadataFields[0].copyWith(fieldKey: 'armour'),
          d.metadataFields[1],
        ],
      ),
    },
    reorders: {
      'abilityIds': (d) => d.copyWith(abilityIds: swapFirstTwo(d.abilityIds)),
      'metadataFields': (d) =>
          d.copyWith(metadataFields: swapFirstTwo(d.metadataFields)),
    },
    mutations: {
      'statGrowth': (d) =>
          d.statGrowth[const StatGrowthKey('stat-strength', 9)] = 1,
      'statGrowthFormulas': (d) => d.statGrowthFormulas['x'] = '1',
      'abilityIds': (d) => d.abilityIds.add('ability-x'),
      'derivedStatOverrides': (d) => d.derivedStatOverrides.clear(),
      'metadataFields': (d) => d.metadataFields.removeLast(),
    },
  );

  test('the constructor copies its collections', () {
    final ids = ['ability-slash'];
    final draft = ClassDraft(
      displayName: 'Warrior',
      exportKey: 'warrior',
      abilityIds: ids,
    );
    ids.add('ability-block');
    expect(draft.abilityIds, ['ability-slash']);
  });

  test('defaults match 0.1.6 create defaults', () {
    final draft = ClassDraft(displayName: 'W', exportKey: 'w');
    expect(draft.description, '');
    expect(draft.resourceMultiplier, 1);
    const input = CreateClassInput(displayName: 'W', exportKey: 'w');
    expect(input.description, '');
    expect(input.resourceMultiplier, 1);
  });

  test('StatGrowthKey is a value', () {
    expect(
      const StatGrowthKey('stat-strength', 1),
      equals(StatGrowthKey('stat-strength', int.parse('1'))),
    );
    expect(
      const StatGrowthKey('stat-strength', 1),
      isNot(equals(const StatGrowthKey('stat-strength', 2))),
    );
  });
}

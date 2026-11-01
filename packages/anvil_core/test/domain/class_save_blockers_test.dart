import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

ClassDraft _valid() => ClassDraft(
  displayName: 'Warrior',
  exportKey: 'warrior',
  statGrowth: {const StatGrowthKey('stat-strength', 1): 12},
  statGrowthFormulas: const {'stat-constitution': '12 + level * 3'},
  abilityIds: const ['slash', 'block'],
  derivedStatOverrides: const {'derived-stat-max-hp': 'con * 12'},
  metadataFields: const [
    ClassMetadataField(fieldKey: 'base_speed', value: 4),
    ClassMetadataField(fieldKey: '_rage2', value: 0),
  ],
);

void main() {
  test('a valid draft has no blockers', () {
    expect(classSaveBlockers(_valid()), isEmpty);
  });

  test('an empty or blank display name blocks', () {
    for (final name in ['', '   ']) {
      expect(classSaveBlockers(_valid().copyWith(displayName: name)), [
        const SaveBlocker('displayName', 'Display name is required.'),
      ]);
    }
  });

  test('an empty or blank export key blocks', () {
    for (final key in ['', ' \t']) {
      expect(classSaveBlockers(_valid().copyWith(exportKey: key)), [
        const SaveBlocker('exportKey', 'Export key is required.'),
      ]);
    }
  });

  test('a repeated ability id blocks at each repeat', () {
    final draft = _valid().copyWith(
      abilityIds: ['slash', 'block', 'slash', 'slash'],
    );
    expect(classSaveBlockers(draft), [
      const SaveBlocker(
        'abilityIds[2]',
        'This ability is already assigned to the class.',
      ),
      const SaveBlocker(
        'abilityIds[3]',
        'This ability is already assigned to the class.',
      ),
    ]);
  });

  test('a stat growth level below 1 blocks once', () {
    final draft = _valid().copyWith(
      statGrowth: {
        const StatGrowthKey('stat-strength', 0): 1,
        const StatGrowthKey('stat-strength', -3): 1,
        const StatGrowthKey('stat-strength', 1): 1,
      },
    );
    expect(classSaveBlockers(draft), [
      const SaveBlocker('statGrowth', 'Stat growth levels must be at least 1.'),
    ]);
  });

  test('a stat growth formula with a syntax error blocks with the '
      "engine's message", () {
    final draft = _valid().copyWith(
      statGrowthFormulas: {'ok': '10 + level', 'bad': '1 +'},
    );
    expect(classSaveBlockers(draft), [
      SaveBlocker('statGrowthFormulas.bad', validateFormula('1 +')!),
    ]);
  });

  test('an empty or blank stat growth formula blocks as required', () {
    final draft = _valid().copyWith(statGrowthFormulas: {'a': '', 'b': '  '});
    expect(classSaveBlockers(draft), [
      const SaveBlocker(
        'statGrowthFormulas.a',
        'Stat growth formula is required.',
      ),
      const SaveBlocker(
        'statGrowthFormulas.b',
        'Stat growth formula is required.',
      ),
    ]);
  });

  test('unknown variables and runtime errors in a growth formula do not '
      'block', () {
    final draft = _valid().copyWith(
      statGrowthFormulas: {'a': 'unknown_var * 2', 'b': 'level / 0'},
    );
    expect(classSaveBlockers(draft), isEmpty);
  });

  test('a derived stat override with a syntax error blocks with its '
      'message', () {
    final draft = _valid().copyWith(
      derivedStatOverrides: {'ok': 'con * 2', 'bad': 'con *', 'empty': '  '},
    );
    expect(classSaveBlockers(draft), [
      SaveBlocker('derivedStatOverrides.bad', validateFormula('con *')!),
      const SaveBlocker('derivedStatOverrides.empty', 'Formula is empty'),
    ]);
  });

  test('a runtime-only override error does not block', () {
    final draft = _valid().copyWith(
      derivedStatOverrides: {'x': 'unknown_variable / 0'},
    );
    expect(classSaveBlockers(draft), isEmpty);
  });

  test('a metadata key that is not an identifier blocks', () {
    for (final key in ['1abc', 'with space', 'dash-key', 'é']) {
      final draft = _valid().copyWith(
        metadataFields: [
          const ClassMetadataField(fieldKey: 'fine', value: 1),
          ClassMetadataField(fieldKey: key, value: 1),
        ],
      );
      expect(classSaveBlockers(draft), [
        const SaveBlocker(
          'metadataFields[1].fieldKey',
          'Letters, digits, underscores only. Must start with a letter.',
        ),
      ], reason: key);
    }
  });

  test('an empty metadata key blocks', () {
    final draft = _valid().copyWith(
      metadataFields: [const ClassMetadataField(fieldKey: '', value: 1)],
    );
    expect(classSaveBlockers(draft), [
      const SaveBlocker(
        'metadataFields[0].fieldKey',
        'Metadata field key is required.',
      ),
    ]);
  });

  test('a repeated metadata key blocks at each repeat', () {
    final draft = _valid().copyWith(
      metadataFields: [
        const ClassMetadataField(fieldKey: 'speed', value: 1),
        const ClassMetadataField(fieldKey: 'armor', value: 2),
        const ClassMetadataField(fieldKey: 'speed', value: 3),
      ],
    );
    expect(classSaveBlockers(draft), [
      const SaveBlocker(
        'metadataFields[2].fieldKey',
        'Metadata field key "speed" is used more than once.',
      ),
    ]);
  });

  test('every broken rule is reported, in field order', () {
    final draft = ClassDraft(
      displayName: '',
      exportKey: '',
      statGrowth: {const StatGrowthKey('s', 0): 1},
      statGrowthFormulas: const {'g': '*'},
      abilityIds: const ['a', 'a'],
      derivedStatOverrides: const {'d': '('},
      metadataFields: const [ClassMetadataField(fieldKey: '9', value: 0)],
    );
    expect(classSaveBlockers(draft).map((b) => b.field), [
      'displayName',
      'exportKey',
      'abilityIds[1]',
      'statGrowth',
      'statGrowthFormulas.g',
      'derivedStatOverrides.d',
      'metadataFields[0].fieldKey',
    ]);
  });
}

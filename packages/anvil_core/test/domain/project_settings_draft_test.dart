import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

import 'support/draft_laws.dart';

ProjectSettingsDraft _build() => ProjectSettingsDraft(
  gameTitle: 'Ember Reach',
  maxLevel: 50,
  softDeleteReferenceSeverity: SoftDeleteReferenceSeverity.warning,
  stats: [
    const MetaRowDraft(
      id: 'stat-strength',
      displayName: 'Strength',
      exportKey: 'str',
    ),
    const MetaRowDraft(id: 'new:1', displayName: 'Luck', exportKey: 'luck'),
  ],
  rarities: [
    const RarityRowDraft(
      id: 'rarity-common',
      displayName: 'Common',
      exportKey: 'common',
      colorHex: '#FFFFFF',
    ),
    const RarityRowDraft(
      id: 'rarity-rare',
      displayName: 'Rare',
      exportKey: 'rare',
      colorHex: '#3366FF',
    ),
  ],
  craftingStations: [
    const MetaRowDraft(id: 'st-1', displayName: 'Anvil', exportKey: 'anvil'),
    const MetaRowDraft(id: 'st-2', displayName: 'Loom', exportKey: 'loom'),
  ],
  craftingSpecializations: [
    const MetaRowDraft(id: 'sp-1', displayName: 'Smith', exportKey: 'smith'),
    const MetaRowDraft(id: 'sp-2', displayName: 'Weaver', exportKey: 'weaver'),
  ],
  derivedStats: [
    const DerivedStatRowDraft(
      id: 'ds-hp',
      displayName: 'HP',
      exportKey: 'hp',
      formula: 'con * 10',
      outputType: DerivedStatOutputType.integer,
      roundingMode: RoundingMode.round,
    ),
    const DerivedStatRowDraft(
      id: 'ds-crit',
      displayName: 'Crit',
      exportKey: 'crit',
      formula: 'dex / 100',
      outputType: DerivedStatOutputType.float,
      roundingMode: RoundingMode.none,
    ),
  ],
);

void main() {
  draftLaws<ProjectSettingsDraft>(
    build: _build,
    // No keyed collections: the same build stands in.
    buildInOtherOrder: _build,
    copyWithNoArgs: (d) => d.copyWith(),
    changes: {
      'gameTitle': (d) => d.copyWith(gameTitle: 'Ash Reach'),
      'maxLevel': (d) => d.copyWith(maxLevel: 60),
      'softDeleteReferenceSeverity': (d) => d.copyWith(
        softDeleteReferenceSeverity: SoftDeleteReferenceSeverity.error,
      ),
      'stat displayName': (d) => d.copyWith(
        stats: [
          d.stats[0].copyWith(displayName: 'Might'),
          d.stats[1],
        ],
      ),
      'stat exportKey': (d) => d.copyWith(
        stats: [
          d.stats[0].copyWith(exportKey: 'mgt'),
          d.stats[1],
        ],
      ),
      'stat id resolved': (d) => d.copyWith(
        stats: [
          d.stats[0],
          d.stats[1].copyWith(id: 'abc'),
        ],
      ),
      'rarity colorHex': (d) => d.copyWith(
        rarities: [
          d.rarities[0].copyWith(colorHex: '#000000'),
          d.rarities[1],
        ],
      ),
      'rarity displayName': (d) => d.copyWith(
        rarities: [
          d.rarities[0].copyWith(displayName: 'Plain'),
          d.rarities[1],
        ],
      ),
      'crafting station': (d) => d.copyWith(
        craftingStations: [
          d.craftingStations[0].copyWith(displayName: 'Forge'),
          d.craftingStations[1],
        ],
      ),
      'crafting specialization': (d) =>
          d.copyWith(craftingSpecializations: [d.craftingSpecializations[0]]),
      'derived stat formula': (d) => d.copyWith(
        derivedStats: [
          d.derivedStats[0].copyWith(formula: 'con * 11'),
          d.derivedStats[1],
        ],
      ),
      'derived stat outputType': (d) => d.copyWith(
        derivedStats: [
          d.derivedStats[0].copyWith(outputType: DerivedStatOutputType.float),
          d.derivedStats[1],
        ],
      ),
      'derived stat roundingMode': (d) => d.copyWith(
        derivedStats: [
          d.derivedStats[0].copyWith(roundingMode: RoundingMode.floor),
          d.derivedStats[1],
        ],
      ),
    },
    reorders: {
      'stats': (d) => d.copyWith(stats: swapFirstTwo(d.stats)),
      'rarities': (d) => d.copyWith(rarities: swapFirstTwo(d.rarities)),
      'craftingStations': (d) =>
          d.copyWith(craftingStations: swapFirstTwo(d.craftingStations)),
      'craftingSpecializations': (d) => d.copyWith(
        craftingSpecializations: swapFirstTwo(d.craftingSpecializations),
      ),
      'derivedStats': (d) =>
          d.copyWith(derivedStats: swapFirstTwo(d.derivedStats)),
    },
    mutations: {
      'stats': (d) => d.stats.clear(),
      'rarities': (d) => d.rarities.clear(),
      'craftingStations': (d) => d.craftingStations.clear(),
      'craftingSpecializations': (d) => d.craftingSpecializations.clear(),
      'derivedStats': (d) => d.derivedStats.clear(),
    },
  );

  test('new meta ids use the 0.1.6 prefix', () {
    expect(isNewMetaId('new:1234'), isTrue);
    expect(isNewMetaId('stat-strength'), isFalse);
  });

  test('enums carry the 0.1.6 string values', () {
    expect(SoftDeleteReferenceSeverity.values.map((e) => e.value), [
      'Warning',
      'Error',
    ]);
    expect(DerivedStatOutputType.values.map((e) => e.value), [
      'integer',
      'float',
    ]);
    expect(RoundingMode.values.map((e) => e.value), ['floor', 'round', 'none']);
    expect(MetaInUseKind.values.map((e) => e.value), [
      'stat',
      'rarity',
      'item-category',
      'npc-type',
      'crafting-station',
      'crafting-specialization',
      'derived-stat',
    ]);
    expect(CustomFieldType.values.map((e) => e.value), [
      'text',
      'integer',
      'decimal',
      'boolean',
      'enum',
    ]);
    expect(CustomFieldScope.values.map((e) => e.value), [
      'item_category',
      'npc_type',
    ]);
  });

  test('fromValue round-trips and rejects unknown strings', () {
    for (final e in SoftDeleteReferenceSeverity.values) {
      expect(SoftDeleteReferenceSeverity.fromValue(e.value), e);
    }
    for (final e in DerivedStatOutputType.values) {
      expect(DerivedStatOutputType.fromValue(e.value), e);
    }
    for (final e in RoundingMode.values) {
      expect(RoundingMode.fromValue(e.value), e);
    }
    for (final e in CustomFieldType.values) {
      expect(CustomFieldType.fromValue(e.value), e);
    }
    for (final e in CustomFieldScope.values) {
      expect(CustomFieldScope.fromValue(e.value), e);
    }
    expect(
      () => SoftDeleteReferenceSeverity.fromValue('warning'),
      throwsArgumentError,
    );
    expect(() => CustomFieldType.fromValue('reference'), throwsArgumentError);
  });
}

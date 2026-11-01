import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

import 'support/draft_laws.dart';

LootTableDraft _build({bool otherOrder = false}) {
  final flags = <(String, Object?)>[
    ('night', true),
    (
      'zone',
      {
        'id': 'swamp',
        'tiers': [1, 2],
      },
    ),
    ('note', null),
  ];
  return LootTableDraft(
    displayName: 'Goblin Drops',
    exportKey: 'goblin_drops',
    description: 'Common goblin loot',
    entries: [
      LootTableEntryDraft(
        itemId: 'item-coin',
        weight: 70,
        quantityMin: 1,
        quantityMax: 5,
        conditionalFlags: {
          for (final (k, v) in otherOrder ? flags.reversed : flags) k: v,
        },
      ),
      LootTableEntryDraft(itemId: 'item-dagger', weight: 30),
    ],
  );
}

void main() {
  draftLaws<LootTableDraft>(
    build: _build,
    buildInOtherOrder: () => _build(otherOrder: true),
    copyWithNoArgs: (d) => d.copyWith(),
    changes: {
      'displayName': (d) => d.copyWith(displayName: 'Orc Drops'),
      'exportKey': (d) => d.copyWith(exportKey: 'orc_drops'),
      'description': (d) => d.copyWith(description: ''),
      'entry itemId': (d) => d.copyWith(
        entries: [
          d.entries[0].copyWith(itemId: 'item-gem'),
          d.entries[1],
        ],
      ),
      'entry weight': (d) => d.copyWith(
        entries: [d.entries[0].copyWith(weight: 71), d.entries[1]],
      ),
      'entry quantityMin': (d) => d.copyWith(
        entries: [d.entries[0].copyWith(quantityMin: 2), d.entries[1]],
      ),
      'entry quantityMax': (d) => d.copyWith(
        entries: [d.entries[0].copyWith(quantityMax: 6), d.entries[1]],
      ),
      'entry conditionalFlags nested': (d) => d.copyWith(
        entries: [
          d.entries[0].copyWith(
            conditionalFlags: {
              ...d.entries[0].conditionalFlags,
              'zone': {
                'id': 'swamp',
                'tiers': [2, 1],
              },
            },
          ),
          d.entries[1],
        ],
      ),
      'entry removed': (d) => d.copyWith(entries: [d.entries[0]]),
    },
    reorders: {'entries': (d) => d.copyWith(entries: swapFirstTwo(d.entries))},
    mutations: {
      'entries': (d) => d.entries.removeAt(0),
      'conditionalFlags': (d) => d.entries[0].conditionalFlags['x'] = 1,
      'nested conditionalFlags': (d) =>
          (d.entries[0].conditionalFlags['zone']! as Map)['id'] = 'bog',
    },
  );

  test('entry defaults match the schema defaults', () {
    final entry = LootTableEntryDraft(itemId: 'item-x', weight: 1);
    expect(entry.quantityMin, 1);
    expect(entry.quantityMax, 1);
    expect(entry.conditionalFlags, isEmpty);
  });
}

import 'package:anvil_core/anvil_core.dart';

import 'support/draft_laws.dart';

ItemDraft _build({bool otherOrder = false}) {
  final values = <(String, String?)>[
    ('cfd-weight', '2.5'),
    ('cfd-material', 'iron'),
    ('cfd-notes', null),
  ];
  return ItemDraft(
    displayName: 'Iron Sword',
    exportKey: 'iron_sword',
    description: 'Sharp',
    itemCategoryId: 'cat-weapon',
    rarityId: 'rarity-common',
    customFieldValues: {
      for (final (k, v) in otherOrder ? values.reversed : values) k: v,
    },
  );
}

void main() {
  draftLaws<ItemDraft>(
    build: _build,
    buildInOtherOrder: () => _build(otherOrder: true),
    copyWithNoArgs: (d) => d.copyWith(),
    changes: {
      'displayName': (d) => d.copyWith(displayName: 'Steel Sword'),
      'exportKey': (d) => d.copyWith(exportKey: 'steel_sword'),
      'description': (d) => d.copyWith(description: ''),
      'itemCategoryId': (d) => d.copyWith(itemCategoryId: 'cat-armor'),
      'rarityId': (d) => d.copyWith(rarityId: 'rarity-rare'),
      'customFieldValues value': (d) => d.copyWith(
        customFieldValues: {...d.customFieldValues, 'cfd-material': 'steel'},
      ),
      'customFieldValues null set': (d) => d.copyWith(
        customFieldValues: {...d.customFieldValues, 'cfd-notes': 'x'},
      ),
      'customFieldValues null key removed': (d) => d.copyWith(
        customFieldValues: {
          'cfd-weight': d.customFieldValues['cfd-weight'],
          'cfd-material': d.customFieldValues['cfd-material'],
        },
      ),
    },
    reorders: const {},
    mutations: {'customFieldValues': (d) => d.customFieldValues['cfd-x'] = 'y'},
  );
}

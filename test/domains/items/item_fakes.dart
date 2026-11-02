/// In-memory repositories and a harness for the items list and editor
/// widget tests. No SQLite.
library;

import 'package:anvil/app/editor/widgets/record_validation.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil/app/theme/anvil_theme.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final linux = TargetPlatformVariant.only(TargetPlatform.linux);

const weapon = 'cat-weapon';
const armor = 'cat-armor';
const potion = 'cat-potion';
const common = 'rarity-common';
const rare = 'rarity-rare';

const swordId = 'item-sword';
const shieldId = 'item-shield';
const elixirId = 'item-elixir';
const oldId = 'item-old';

/// Weapon fields: Damage (integer, required), Element (enum, default
/// `fire`). Armor fields: Slot (text, default `chest`), Heavy (boolean).
CustomFieldDefinition definition(
  String id,
  String category,
  String name,
  CustomFieldType type, {
  String? defaultValue,
  List<String> options = const [],
  bool required = false,
  int order = 0,
}) => CustomFieldDefinition(
  id: id,
  scopeType: CustomFieldScope.itemCategory,
  scopeId: category,
  fieldName: name,
  fieldType: type,
  defaultValue: defaultValue,
  enumOptions: options,
  isRequired: required,
  isSearchable: false,
  sortOrder: order,
  createdAt: '2026-10-30 10:00:00',
  updatedAt: '2026-10-30 10:00:00',
);

List<CustomFieldDefinition> sampleDefinitions() => [
  definition(
    'field-damage',
    weapon,
    'Damage',
    CustomFieldType.integer,
    required: true,
  ),
  definition(
    'field-element',
    weapon,
    'Element',
    CustomFieldType.enumeration,
    defaultValue: 'fire',
    options: const ['fire', 'ice'],
    order: 1,
  ),
  definition(
    'field-slot',
    armor,
    'Slot',
    CustomFieldType.text,
    defaultValue: 'chest',
  ),
  definition('field-heavy', armor, 'Heavy', CustomFieldType.boolean, order: 1),
];

class StoredItem {
  StoredItem(this.id, this.draft, {this.deletedAt, this.updatedAt = '1'});

  final String id;
  ItemDraft draft;
  String? deletedAt;
  String updatedAt;

  ItemRecord get record => ItemRecord(
    id: id,
    displayName: draft.displayName,
    exportKey: draft.exportKey,
    description: draft.description,
    itemCategoryId: draft.itemCategoryId,
    rarityId: draft.rarityId,
    createdAt: '2026-10-30 10:00:00',
    updatedAt: updatedAt,
    deletedAt: deletedAt,
  );
}

/// Iron Sword (weapon, common, Damage 12 and a stale Slot value), Tower
/// Shield (armor, rare, no values), Elixir (potion, common) and an
/// archived Old Club.
List<StoredItem> sampleItems() => [
  StoredItem(
    swordId,
    ItemDraft(
      displayName: 'Iron Sword',
      exportKey: 'iron-sword',
      description: 'A plain blade.',
      itemCategoryId: weapon,
      rarityId: common,
      customFieldValues: const {
        'field-damage': '12',
        'field-element': 'ice',
        'field-slot': 'hand',
      },
    ),
    updatedAt: '2026-10-30 10:00:01',
  ),
  StoredItem(
    shieldId,
    ItemDraft(
      displayName: 'Tower Shield',
      exportKey: 'tower-shield',
      itemCategoryId: armor,
      rarityId: rare,
    ),
    updatedAt: '2026-10-30 10:00:03',
  ),
  StoredItem(
    elixirId,
    ItemDraft(
      displayName: 'Elixir',
      exportKey: 'elixir',
      itemCategoryId: potion,
      rarityId: common,
    ),
    updatedAt: '2026-10-30 10:00:02',
  ),
  StoredItem(
    oldId,
    ItemDraft(
      displayName: 'Old Club',
      exportKey: 'old-club',
      itemCategoryId: weapon,
      rarityId: common,
    ),
    deletedAt: '2026-10-31 14:05:09',
  ),
];

/// [ItemRepository] over memory: `save` stores and returns the draft,
/// `usedBy` is scripted, every call is logged.
class FakeItemRepository implements ItemRepository {
  FakeItemRepository([List<StoredItem>? items])
    : items = {for (final i in items ?? sampleItems()) i.id: i};

  final Map<String, StoredItem> items;
  final calls = <String>[];
  final saved = <ItemDraft>[];
  final created = <CreateItemInput>[];
  final usedByScript = <String, ItemUsedBy>{};
  Object? saveError;
  var _next = 0;

  StoredItem _get(String id) =>
      items[id] ?? (throw RecordNotFound('items', id));

  @override
  Future<List<ItemRecord>> list({
    RecordListMode mode = RecordListMode.active,
  }) async {
    calls.add('list ${mode.name}');
    final rows = [
      for (final i in items.values)
        if (switch (mode) {
          RecordListMode.active => i.deletedAt == null,
          RecordListMode.all => true,
          RecordListMode.deletedOnly => i.deletedAt != null,
        })
          i.record,
    ];
    rows.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    return rows;
  }

  @override
  Future<int> countActive() async =>
      items.values.where((i) => i.deletedAt == null).length;

  @override
  Future<ItemRecord> get(String id) async => _get(id).record;

  @override
  Future<ItemDraft> load(String id) async {
    calls.add('load $id');
    return _get(id).draft;
  }

  @override
  Future<ItemRecord> create(CreateItemInput input) async {
    calls.add('create ${input.displayName}');
    created.add(input);
    final id = 'item-new-${_next++}';
    final stored = StoredItem(
      id,
      ItemDraft(
        displayName: input.displayName,
        exportKey: input.exportKey,
        description: input.description,
        itemCategoryId: input.itemCategoryId,
        rarityId: input.rarityId,
      ),
    );
    items[id] = stored;
    return stored.record;
  }

  @override
  Future<ItemDraft> save(String id, ItemDraft draft) async {
    calls.add('save $id');
    if (saveError case final error?) throw error;
    final stored = _get(id);
    saved.add(draft);
    stored.draft = draft;
    return draft;
  }

  @override
  Future<ItemRecord> duplicate(String id) async {
    calls.add('duplicate $id');
    final source = _get(id);
    final copyId = 'item-copy-${_next++}';
    final copy = StoredItem(
      copyId,
      source.draft.copyWith(
        displayName: '${source.draft.displayName} (Copy)',
        exportKey: '${source.draft.exportKey}-copy',
      ),
    );
    items[copyId] = copy;
    return copy.record;
  }

  @override
  Future<void> softDelete(String id) async {
    calls.add('softDelete $id');
    _get(id).deletedAt ??= '2026-11-01 09:00:00';
  }

  @override
  Future<void> restore(String id) async {
    calls.add('restore $id');
    _get(id).deletedAt = null;
  }

  @override
  Future<void> hardDelete(String id) async {
    calls.add('hardDelete $id');
    _get(id);
    items.remove(id);
  }

  @override
  Future<ItemUsedBy> usedBy(String id) async {
    calls.add('usedBy $id');
    return usedByScript[id] ?? ItemUsedBy(recipes: [], lootTables: []);
  }
}

/// The two meta lists the items pages read.
class FakeItemMetaRepository implements MetaRepository {
  final categories = <MetaItemCategory>[
    for (final (i, (id, name)) in [
      (weapon, 'Weapon'),
      (armor, 'Armor'),
      (potion, 'Potion'),
    ].indexed)
      MetaItemCategory(
        id: id,
        displayName: name,
        exportKey: name.toLowerCase(),
        description: '',
        sortOrder: i,
      ),
  ];

  final rarities = <MetaRarity>[
    const MetaRarity(
      id: common,
      displayName: 'Common',
      exportKey: 'common',
      colorHex: '#D8DEE9',
      sortOrder: 0,
    ),
    const MetaRarity(
      id: rare,
      displayName: 'Rare',
      exportKey: 'rare',
      colorHex: '#5E81AC',
      sortOrder: 1,
    ),
  ];

  @override
  Future<List<MetaItemCategory>> listItemCategories() async =>
      List.of(categories);

  @override
  Future<List<MetaRarity>> listRarities() async => List.of(rarities);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// The definitions by category; nothing else.
class FakeItemCustomFieldRepository implements CustomFieldRepository {
  final definitions = sampleDefinitions();
  final asked = <String>[];

  @override
  Future<List<CustomFieldDefinition>> listDefinitions(
    CustomFieldScope scopeType,
    String scopeId,
  ) async {
    asked.add(scopeId);
    return [
      for (final d in definitions)
        if (d.scopeType == scopeType && d.scopeId == scopeId) d,
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// The bulk writes of the items list over [repository].
class FakeItemLifecycleRepository implements LifecycleRepository {
  FakeItemLifecycleRepository(this.repository);

  final FakeItemRepository repository;

  @override
  Future<DeleteImpact> computeDeleteImpact(
    LifecycleDomain domain,
    List<String> ids,
  ) async => DeleteImpact(recordCount: ids.length, references: []);

  @override
  Future<int> bulkSoftDelete(LifecycleDomain domain, List<String> ids) async {
    repository.calls.add('bulkSoftDelete ${domain.value} ${ids.join(',')}');
    for (final id in ids) {
      await repository.softDelete(id);
    }
    return ids.length;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// The record validation an editor shows, without a session: [issues] by
/// record id, returned by every refresh, with the refreshes counted.
class FakeRecordValidation extends RecordValidationNotifier {
  FakeRecordValidation(super.key, this.script);

  final ItemTestScript script;

  @override
  List<ValidationIssue> build() => const [];

  @override
  List<ValidationIssue> refresh() {
    script.validations++;
    return state = script.issues[key.$2] ?? const [];
  }
}

/// What a harness's fakes are scripted with.
class ItemTestScript {
  final issues = <String, List<ValidationIssue>>{};
  var validations = 0;
}

ValidationIssue itemIssue(String id, String field, String message) =>
    ValidationIssue(
      id: 'issue-$field',
      domain: ValidationDomain.items,
      recordId: id,
      recordDisplayName: 'Iron Sword',
      field: field,
      severity: ValidationSeverity.error,
      message: message,
    );

/// A container over the fakes and [child] in the dark theme at 1400×1000.
class ItemHarness {
  ItemHarness({List<StoredItem>? items})
    : items = FakeItemRepository(items),
      meta = FakeItemMetaRepository(),
      customFields = FakeItemCustomFieldRepository() {
    lifecycle = FakeItemLifecycleRepository(this.items);
  }

  final FakeItemRepository items;
  final FakeItemMetaRepository meta;
  final FakeItemCustomFieldRepository customFields;
  late final FakeItemLifecycleRepository lifecycle;
  final script = ItemTestScript();
  late ProviderContainer container;

  int get epoch => container.read(writeEpochProvider);

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [
        itemRepositoryProvider.overrideWithValue(items),
        metaRepositoryProvider.overrideWithValue(meta),
        customFieldRepositoryProvider.overrideWithValue(customFields),
        lifecycleRepositoryProvider.overrideWithValue(lifecycle),
        recordValidationProvider.overrideWith2(
          (key) => FakeRecordValidation(key, script),
        ),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: anvilTheme(AnvilThemeSpec.dark),
          home: Scaffold(
            body: Padding(padding: const EdgeInsets.all(24), child: child),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

/// In-memory repositories and a harness for the NPC list and editor tests.
/// No SQLite.
library;

import 'package:anvil/app/editor/widgets/record_validation.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil/app/theme/anvil_theme.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

final linux = TargetPlatformVariant.only(TargetPlatform.linux);

const enemy = 'type-enemy';
const merchant = 'type-merchant';
const warrior = 'class-warrior';
const mage = 'class-mage';
const retired = 'class-retired';
const slash = 'ability-slash';
const fireball = 'ability-fireball';
const goblinDrops = 'loot-goblin';
const strength = 'stat-str';
const wisdom = 'stat-wis';
const sword = 'item-sword';

const goblinId = 'npc-goblin';
const marlaId = 'npc-marla';
const oldId = 'npc-old';

CustomFieldDefinition npcDefinition(
  String id,
  String type,
  String name,
  CustomFieldType fieldType, {
  String? defaultValue,
  List<String> options = const [],
  bool required = false,
  int order = 0,
}) => CustomFieldDefinition(
  id: id,
  scopeType: CustomFieldScope.npcType,
  scopeId: type,
  fieldName: name,
  fieldType: fieldType,
  defaultValue: defaultValue,
  enumOptions: options,
  isRequired: required,
  isSearchable: false,
  sortOrder: order,
  createdAt: '2026-10-30 10:00:00',
  updatedAt: '2026-10-30 10:00:00',
);

/// Enemy: Aggression (enum, default `hostile`) and Title (text).
/// Merchant: Title and Discount (integer, default `5`). The schema scopes
/// a definition to one type; the fake lists Title under both, so a type
/// change has a field whose value it keeps.
Map<String, List<CustomFieldDefinition>> sampleNpcDefinitions() {
  final title = npcDefinition(
    'field-title',
    enemy,
    'Title',
    CustomFieldType.text,
    order: 1,
  );
  return {
    enemy: [
      npcDefinition(
        'field-aggression',
        enemy,
        'Aggression',
        CustomFieldType.enumeration,
        defaultValue: 'hostile',
        options: const ['hostile', 'wary'],
      ),
      title,
    ],
    merchant: [
      title,
      npcDefinition(
        'field-discount',
        merchant,
        'Discount',
        CustomFieldType.integer,
        defaultValue: '5',
        order: 2,
      ),
    ],
  };
}

class StoredNpc {
  StoredNpc(this.id, this.draft, {this.deletedAt, this.updatedAt = '1'});

  final String id;
  NpcDraft draft;
  String? deletedAt;
  String updatedAt;

  NpcRecord get record => NpcRecord(
    id: id,
    displayName: draft.displayName,
    exportKey: draft.exportKey,
    description: draft.description,
    npcTypeId: draft.npcTypeId,
    lootTableId: draft.lootTableId,
    combatStats: draft.combatStats,
    createdAt: '2026-10-30 10:00:00',
    updatedAt: updatedAt,
    deletedAt: deletedAt,
  );
}

/// Goblin Raider (enemy, Goblin Drops, Warrior 3, Slash, Aggression
/// `wary` and Title `Scout`), Marla (merchant, Mage 2), an archived Old
/// Hermit (enemy).
List<StoredNpc> sampleNpcs() => [
  StoredNpc(
    goblinId,
    NpcDraft(
      displayName: 'Goblin Raider',
      exportKey: 'goblin_raider',
      description: 'Sneaky.',
      npcTypeId: enemy,
      lootTableId: goblinDrops,
      classAssignments: const [NpcClassAssignment(classId: warrior, level: 3)],
      abilityIds: const [slash],
      customFieldValues: const {
        'field-aggression': 'wary',
        'field-title': 'Scout',
      },
    ),
    updatedAt: '2026-10-30 10:00:01',
  ),
  StoredNpc(
    marlaId,
    NpcDraft(
      displayName: 'Marla',
      exportKey: 'marla',
      npcTypeId: merchant,
      classAssignments: const [NpcClassAssignment(classId: mage, level: 2)],
    ),
    updatedAt: '2026-10-30 10:00:03',
  ),
  StoredNpc(
    oldId,
    NpcDraft(displayName: 'Old Hermit', exportKey: 'old', npcTypeId: enemy),
    deletedAt: '2026-10-31 14:05:09',
  ),
];

class FakeNpcRepository implements NpcRepository {
  FakeNpcRepository([List<StoredNpc>? npcs])
    : npcs = {for (final n in npcs ?? sampleNpcs()) n.id: n};

  final Map<String, StoredNpc> npcs;
  final calls = <String>[];
  final saved = <NpcDraft>[];
  final created = <CreateNpcInput>[];
  var _next = 0;

  StoredNpc _get(String id) => npcs[id] ?? (throw RecordNotFound('npcs', id));

  @override
  Future<List<NpcRecord>> list({
    RecordListMode mode = RecordListMode.active,
  }) async {
    calls.add('list ${mode.name}');
    final rows = [
      for (final n in npcs.values)
        if (switch (mode) {
          RecordListMode.active => n.deletedAt == null,
          RecordListMode.all => true,
          RecordListMode.deletedOnly => n.deletedAt != null,
        })
          n.record,
    ];
    rows.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    return rows;
  }

  @override
  Future<int> countActive() async =>
      npcs.values.where((n) => n.deletedAt == null).length;

  @override
  Future<NpcRecord> get(String id) async => _get(id).record;

  @override
  Future<NpcDraft> load(String id) async {
    calls.add('load $id');
    return _get(id).draft;
  }

  @override
  Future<NpcRecord> create(CreateNpcInput input) async {
    calls.add('create ${input.displayName}');
    created.add(input);
    final id = 'npc-new-${_next++}';
    final stored = StoredNpc(
      id,
      NpcDraft(
        displayName: input.displayName,
        exportKey: input.exportKey,
        npcTypeId: input.npcTypeId,
      ),
    );
    npcs[id] = stored;
    return stored.record;
  }

  @override
  Future<NpcDraft> save(String id, NpcDraft draft) async {
    calls.add('save $id');
    final stored = _get(id);
    saved.add(draft);
    stored.draft = draft;
    return draft;
  }

  @override
  Future<NpcRecord> duplicate(String id) async {
    calls.add('duplicate $id');
    final source = _get(id);
    final copyId = 'npc-copy-${_next++}';
    final copy = StoredNpc(
      copyId,
      source.draft.copyWith(
        displayName: '${source.draft.displayName} (Copy)',
        exportKey: '${source.draft.exportKey}-copy',
      ),
    );
    npcs[copyId] = copy;
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
    npcs.remove(id);
  }

  @override
  Future<Map<String, double>> inheritedStatBlock(String id) =>
      throw UnimplementedError('inheritedStatBlock');
}

/// The NPC types, the two stats and the max level.
class FakeNpcMetaRepository implements MetaRepository {
  var maxLevel = 20;

  final types = <MetaNpcType>[
    const MetaNpcType(
      id: enemy,
      displayName: 'Enemy',
      exportKey: 'enemy',
      description: '',
      sortOrder: 0,
    ),
    const MetaNpcType(
      id: merchant,
      displayName: 'Merchant',
      exportKey: 'merchant',
      description: '',
      sortOrder: 1,
    ),
  ];

  final stats = <MetaStat>[
    // Out of order on purpose: the stat block sorts by `sortOrder`.
    const MetaStat(
      id: wisdom,
      displayName: 'Wisdom',
      exportKey: 'wis',
      sortOrder: 20,
    ),
    const MetaStat(
      id: strength,
      displayName: 'Strength',
      exportKey: 'str',
      sortOrder: 10,
    ),
  ];

  @override
  Future<List<MetaNpcType>> listNpcTypes() async => List.of(types);

  @override
  Future<List<MetaStat>> listStats() async => List.of(stats);

  @override
  Future<ProjectSettingsDraft> loadProjectSettings() async =>
      ProjectSettingsDraft(
        gameTitle: 'Test',
        maxLevel: maxLevel,
        softDeleteReferenceSeverity: SoftDeleteReferenceSeverity.warning,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

ClassRecord classRecord(String id, String name, {String? deletedAt}) =>
    ClassRecord(
      id: id,
      displayName: name,
      exportKey: name.toLowerCase(),
      description: '',
      resourceMultiplier: 1,
      createdAt: '2026-10-30 10:00:00',
      updatedAt: '2026-10-30 10:00:00',
      deletedAt: deletedAt,
    );

/// Warrior, Mage and a soft-deleted Retired class, with scripted growth:
/// Warrior has Strength `level * 2` and Wisdom 1 per level up to 20, Mage
/// Wisdom `level * 3`.
class FakeNpcClassRepository implements ClassRepository {
  final classes = <ClassRecord>[
    classRecord(mage, 'Mage'),
    classRecord(retired, 'Retired', deletedAt: '2026-10-31 10:00:00'),
    classRecord(warrior, 'Warrior'),
  ];

  final growth = <String, Map<StatGrowthKey, double>>{
    warrior: {
      for (var l = 1; l <= 20; l++) ...{
        StatGrowthKey(strength, l): l * 2.0,
        StatGrowthKey(wisdom, l): 1,
      },
    },
    mage: {for (var l = 1; l <= 20; l++) StatGrowthKey(wisdom, l): l * 3.0},
    retired: {for (var l = 1; l <= 20; l++) StatGrowthKey(strength, l): 100},
  };

  final growthAsked = <String>[];

  @override
  Future<List<ClassRecord>> list({
    RecordListMode mode = RecordListMode.active,
  }) async => [
    for (final c in classes)
      if (mode == RecordListMode.all || c.deletedAt == null) c,
  ];

  @override
  Future<Map<StatGrowthKey, double>> resolvedStatGrowth(String id) async {
    growthAsked.add(id);
    return growth[id] ?? (throw RecordNotFound('classes', id));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

AbilityRecord abilityRecord(String id, String name, {String? deletedAt}) =>
    AbilityRecord(
      id: id,
      displayName: name,
      exportKey: name.toLowerCase(),
      description: '',
      abilityType: '',
      resourceType: '',
      resourceCost: 0,
      cooldown: 0,
      statModifiers: const {},
      createdAt: '2026-10-30 10:00:00',
      updatedAt: '2026-10-30 10:00:00',
      deletedAt: deletedAt,
    );

class FakeNpcAbilityRepository implements AbilityRepository {
  final abilities = <AbilityRecord>[
    abilityRecord(fireball, 'Fireball'),
    abilityRecord(slash, 'Slash'),
  ];

  @override
  Future<List<AbilityRecord>> list({
    RecordListMode mode = RecordListMode.active,
  }) async => List.of(abilities);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class FakeNpcLootTableRepository implements LootTableRepository {
  final tables = <LootTableRecord>[
    LootTableRecord(
      id: goblinDrops,
      displayName: 'Goblin Drops',
      exportKey: 'goblin-drops',
      description: '',
      createdAt: '2026-10-30 10:00:00',
      updatedAt: '2026-10-30 10:00:00',
      deletedAt: null,
    ),
  ];

  @override
  Future<List<LootTableRecord>> list({
    RecordListMode mode = RecordListMode.active,
  }) async => List.of(tables);

  @override
  Future<LootTableDraft> load(String id) async => LootTableDraft(
    displayName: 'Goblin Drops',
    exportKey: 'goblin-drops',
    entries: [
      LootTableEntryDraft(itemId: sword, weight: 3),
      LootTableEntryDraft(
        itemId: 'item-gone',
        weight: 1,
        quantityMin: 1,
        quantityMax: 4,
      ),
    ],
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class FakeNpcItemRepository implements ItemRepository {
  @override
  Future<List<ItemRecord>> list({
    RecordListMode mode = RecordListMode.active,
  }) async => [
    ItemRecord(
      id: sword,
      displayName: 'Iron Sword',
      exportKey: 'iron-sword',
      description: '',
      itemCategoryId: 'cat',
      rarityId: 'rarity',
      createdAt: '2026-10-30 10:00:00',
      updatedAt: '2026-10-30 10:00:00',
      deletedAt: null,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class FakeNpcCustomFieldRepository implements CustomFieldRepository {
  final definitions = sampleNpcDefinitions();

  @override
  Future<List<CustomFieldDefinition>> listDefinitions(
    CustomFieldScope scopeType,
    String scopeId,
  ) async => [
    if (scopeType == CustomFieldScope.npcType) ...?definitions[scopeId],
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class FakeNpcLifecycleRepository implements LifecycleRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class FakeNpcValidation extends RecordValidationNotifier {
  FakeNpcValidation(super.key);

  @override
  List<ValidationIssue> build() => const [];

  @override
  List<ValidationIssue> refresh() => state = const [];
}

/// The fakes, overridden into a container.
class NpcHarness {
  NpcHarness({List<StoredNpc>? npcs}) : npcs = FakeNpcRepository(npcs);

  final FakeNpcRepository npcs;
  final meta = FakeNpcMetaRepository();
  final classes = FakeNpcClassRepository();
  final abilities = FakeNpcAbilityRepository();
  final lootTables = FakeNpcLootTableRepository();
  final items = FakeNpcItemRepository();
  final customFields = FakeNpcCustomFieldRepository();
  late ProviderContainer container;

  int get epoch => container.read(writeEpochProvider);

  List<Override> get overrides => [
    npcRepositoryProvider.overrideWithValue(npcs),
    metaRepositoryProvider.overrideWithValue(meta),
    classRepositoryProvider.overrideWithValue(classes),
    abilityRepositoryProvider.overrideWithValue(abilities),
    lootTableRepositoryProvider.overrideWithValue(lootTables),
    itemRepositoryProvider.overrideWithValue(items),
    customFieldRepositoryProvider.overrideWithValue(customFields),
    lifecycleRepositoryProvider.overrideWithValue(FakeNpcLifecycleRepository()),
    recordValidationProvider.overrideWith2(FakeNpcValidation.new),
  ];

  /// A container for controller tests.
  ProviderContainer containerOnly({List<Override> extra = const []}) {
    container = ProviderContainer.test(
      overrides: [...overrides, ...extra],
      retry: (_, _) => null,
    );
    return container;
  }

  /// Pumps [child] as the shell lays a page out at the app's 1400×800
  /// minimum with the 220 px sidebar open: 1180 px beside the sidebar,
  /// less the shell's 24 px padding, so the page gets 1132 px.
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1180, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = ProviderContainer(overrides: overrides, retry: (_, _) => null);
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

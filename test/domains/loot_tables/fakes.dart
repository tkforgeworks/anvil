/// In-memory stand-ins for the loot table pages' repositories, and the
/// container and app every loot table widget test pumps.
library;

import 'dart:io';

import 'package:anvil/app/editor/widgets/record_validation.dart';
import 'package:anvil/app/providers.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil/app/theme/anvil_theme.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final linux = TargetPlatformVariant.only(TargetPlatform.linux);

const goblinId = 'loot-goblin';
const chestId = 'loot-chest';

const ingotId = 'item-ingot';
const potionId = 'item-potion';
const swordId = 'item-sword';
const cursedId = 'item-cursed';

const raiderId = 'npc-raider';
const scoutId = 'npc-scout';

ItemRecord item(
  String id,
  String name, {
  String rarityId = 'rarity-common',
  String? deletedAt,
}) => ItemRecord(
  id: id,
  displayName: name,
  exportKey: id,
  description: '',
  itemCategoryId: 'cat-weapon',
  rarityId: rarityId,
  createdAt: '2026-10-30 10:00:00',
  updatedAt: '2026-10-30 10:00:00',
  deletedAt: deletedAt,
);

/// Three active items and one soft-deleted, by name.
List<ItemRecord> sampleItems() => [
  item(
    cursedId,
    'Cursed Dagger',
    rarityId: 'rarity-epic',
    deletedAt: '2026-10-31 20:58:16',
  ),
  item(potionId, 'Healing Potion'),
  item(ingotId, 'Iron Ingot'),
  item(swordId, 'Iron Sword', rarityId: 'rarity-uncommon'),
];

/// Goblin Drops as the fixture holds it: weights 60 / 30 / 10, the sword
/// flagged `boss_only`.
LootTableDraft goblinDraft() => LootTableDraft(
  displayName: 'Goblin Drops',
  exportKey: 'goblin_drops',
  description: 'What goblins carry.',
  entries: [
    LootTableEntryDraft(itemId: ingotId, weight: 60, quantityMax: 3),
    LootTableEntryDraft(itemId: potionId, weight: 30),
    LootTableEntryDraft(
      itemId: swordId,
      weight: 10,
      conditionalFlags: const {'boss_only': true},
    ),
  ],
);

LootTableDraft chestDraft() => LootTableDraft(
  displayName: 'Old Chest',
  exportKey: 'old_chest',
  entries: [LootTableEntryDraft(itemId: potionId, weight: 1)],
);

/// The loot tables table in memory: drafts, update stamps and deletion
/// stamps by id, the calls it received and scripted failures by call name.
class FakeLootTableRepository implements LootTableRepository {
  FakeLootTableRepository()
    : drafts = {goblinId: goblinDraft(), chestId: chestDraft()},
      updated = {
        goblinId: '2026-10-30 10:00:00',
        chestId: '2026-10-31 12:00:00',
      };

  final Map<String, LootTableDraft> drafts;
  final Map<String, String> updated;
  final deleted = <String, String>{};
  final calls = <String>[];

  /// The NPCs `usedBy` answers, by loot table id.
  final usedByRefs = <String, List<UsedByRef>>{
    goblinId: const [UsedByRef(raiderId, 'Goblin Raider')],
  };

  /// Thrown by the next call of that name (`save`, `create`, ...).
  final failures = <String, Object>{};
  var _next = 0;

  void _maybeFail(String call) {
    if (failures.remove(call) case final error?) throw error;
  }

  LootTableDraft _draft(String id) =>
      drafts[id] ?? (throw RecordNotFound('loot_tables', id));

  LootTableRecord _record(String id) {
    final d = _draft(id);
    return LootTableRecord(
      id: id,
      displayName: d.displayName,
      exportKey: d.exportKey,
      description: d.description,
      createdAt: '2026-10-30 10:00:00',
      updatedAt: updated[id] ?? '2026-11-01 08:00:00',
      deletedAt: deleted[id],
    );
  }

  @override
  Future<List<LootTableRecord>> list({
    RecordListMode mode = RecordListMode.active,
  }) async {
    calls.add('list ${mode.name}');
    _maybeFail('list');
    final rows = [
      for (final id in drafts.keys)
        if (switch (mode) {
          RecordListMode.active => !deleted.containsKey(id),
          RecordListMode.deletedOnly => deleted.containsKey(id),
          RecordListMode.all => true,
        })
          _record(id),
    ];
    return rows..sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
  }

  @override
  Future<int> countActive() async =>
      drafts.keys.where((id) => !deleted.containsKey(id)).length;

  @override
  Future<LootTableRecord> get(String id) async => _record(id);

  @override
  Future<LootTableDraft> load(String id) async {
    calls.add('load $id');
    _maybeFail('load');
    return _draft(id);
  }

  @override
  Future<LootTableRecord> create(CreateLootTableInput input) async {
    calls.add('create ${input.displayName}');
    _maybeFail('create');
    final id = 'loot-new-${++_next}';
    drafts[id] = LootTableDraft(
      displayName: input.displayName,
      exportKey: input.exportKey,
      description: input.description,
    );
    return _record(id);
  }

  @override
  Future<LootTableDraft> save(String id, LootTableDraft draft) async {
    calls.add('save $id');
    _maybeFail('save');
    _draft(id);
    final blockers = lootTableSaveBlockers(draft);
    if (blockers.isNotEmpty) {
      throw SaveBlocked([for (final b in blockers) b.message]);
    }
    drafts[id] = draft;
    return draft.copyWith();
  }

  @override
  Future<LootTableRecord> duplicate(String id) async {
    calls.add('duplicate $id');
    _maybeFail('duplicate');
    final source = _draft(id);
    final copy = 'loot-copy-${++_next}';
    drafts[copy] = source.copyWith(
      displayName: '${source.displayName} (Copy)',
      exportKey: '${source.exportKey}-copy$_next',
    );
    return _record(copy);
  }

  @override
  Future<void> softDelete(String id) async {
    calls.add('softDelete $id');
    _draft(id);
    deleted[id] ??= '2026-11-01 09:00:00';
  }

  @override
  Future<void> restore(String id) async {
    calls.add('restore $id');
    _draft(id);
    deleted.remove(id);
  }

  @override
  Future<void> hardDelete(String id) async {
    calls.add('hardDelete $id');
    _draft(id);
    drafts.remove(id);
    deleted.remove(id);
  }

  @override
  Future<List<UsedByRef>> usedBy(String id) async => usedByRefs[id] ?? const [];
}

/// The item list only; the loot table pages read nothing else.
class FakeItemRepository implements ItemRepository {
  FakeItemRepository([List<ItemRecord>? items])
    : items = items ?? sampleItems();

  final List<ItemRecord> items;

  @override
  Future<List<ItemRecord>> list({
    RecordListMode mode = RecordListMode.active,
  }) async => [
    for (final i in items)
      if (switch (mode) {
        RecordListMode.active => i.deletedAt == null,
        RecordListMode.deletedOnly => i.deletedAt != null,
        RecordListMode.all => true,
      })
        i,
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeItemRepository: ${invocation.memberName}');
}

/// The rarities only.
class FakeRarityMetaRepository implements MetaRepository {
  final rarities = const [
    MetaRarity(
      id: 'rarity-common',
      displayName: 'Common',
      exportKey: 'common',
      colorHex: '#9e9e9e',
      sortOrder: 0,
    ),
    MetaRarity(
      id: 'rarity-uncommon',
      displayName: 'Uncommon',
      exportKey: 'uncommon',
      colorHex: '#4caf50',
      sortOrder: 1,
    ),
    MetaRarity(
      id: 'rarity-epic',
      displayName: 'Epic',
      exportKey: 'epic',
      colorHex: '#9c27b0',
      sortOrder: 2,
    ),
  ];

  @override
  Future<List<MetaRarity>> listRarities() async => rarities;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'FakeRarityMetaRepository: ${invocation.memberName}',
  );
}

NpcRecord npc(
  String id,
  String name, {
  String? lootTableId,
  String? deletedAt,
}) => NpcRecord(
  id: id,
  displayName: name,
  exportKey: id,
  description: '',
  npcTypeId: 'npc-type-enemy',
  lootTableId: lootTableId,
  combatStats: const {},
  createdAt: '2026-10-30 10:00:00',
  updatedAt: '2026-10-30 10:00:00',
  deletedAt: deletedAt,
);

/// The NPC list only, for the Assigned column.
class FakeNpcRepository implements NpcRepository {
  final npcs = [
    npc(raiderId, 'Goblin Raider', lootTableId: goblinId),
    npc(scoutId, 'Goblin Scout', lootTableId: goblinId),
    npc('npc-merchant', 'Marla the Merchant'),
  ];

  @override
  Future<List<NpcRecord>> list({
    RecordListMode mode = RecordListMode.active,
  }) async => [
    for (final n in npcs)
      if (mode != RecordListMode.active || n.deletedAt == null) n,
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeNpcRepository: ${invocation.memberName}');
}

/// The bulk operations over [FakeLootTableRepository]; nothing else.
class FakeLootTableLifecycle implements LifecycleRepository {
  FakeLootTableLifecycle(this.tables);

  final FakeLootTableRepository tables;

  @override
  Future<DeleteImpact> computeDeleteImpact(
    LifecycleDomain domain,
    List<String> ids,
  ) async => DeleteImpact(recordCount: ids.length, references: const []);

  @override
  Future<int> bulkSoftDelete(LifecycleDomain domain, List<String> ids) async {
    tables.calls.add('bulkSoftDelete ${ids.join(',')}');
    for (final id in ids) {
      await tables.softDelete(id);
    }
    return ids.length;
  }

  @override
  Future<int> bulkRestore(LifecycleDomain domain, List<String> ids) async {
    tables.calls.add('bulkRestore ${ids.join(',')}');
    for (final id in ids) {
      await tables.restore(id);
    }
    return ids.length;
  }

  @override
  Future<int> bulkHardDelete(LifecycleDomain domain, List<String> ids) async {
    tables.calls.add('bulkHardDelete ${ids.join(',')}');
    for (final id in ids) {
      await tables.hardDelete(id);
    }
    return ids.length;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'FakeLootTableLifecycle: ${invocation.memberName}',
  );
}

/// The record validation pass without a session: [LootTableTestScript]
/// holds what every refresh answers and counts them.
class FakeRecordValidation extends RecordValidationNotifier {
  FakeRecordValidation(super.key, this.script);

  final LootTableTestScript script;

  @override
  List<ValidationIssue> build() => const [];

  @override
  List<ValidationIssue> refresh() {
    script.refreshes++;
    return state = script.issues;
  }
}

class LootTableTestScript {
  List<ValidationIssue> issues = const [];
  var refreshes = 0;
}

/// A container over the fakes, with retries off.
class LootTableTestHarness {
  LootTableTestHarness({List<ItemRecord>? items})
    : items = FakeItemRepository(items);

  final tables = FakeLootTableRepository();
  final FakeItemRepository items;
  final meta = FakeRarityMetaRepository();
  final npcs = FakeNpcRepository();
  final script = LootTableTestScript();
  late final ProviderContainer container;

  int get epoch => container.read(writeEpochProvider);

  ProviderContainer build({List overrides = const []}) {
    final logs = Directory.systemTemp.createTempSync('anvil-loot-logs');
    addTearDown(() => logs.deleteSync(recursive: true));
    container = ProviderContainer(
      overrides: [
        lootTableRepositoryProvider.overrideWithValue(tables),
        itemRepositoryProvider.overrideWithValue(items),
        metaRepositoryProvider.overrideWithValue(meta),
        npcRepositoryProvider.overrideWithValue(npcs),
        lifecycleRepositoryProvider.overrideWithValue(
          FakeLootTableLifecycle(tables),
        ),
        initialAppSettingsProvider.overrideWithValue(const AppSettings()),
        appLoggerProvider.overrideWithValue(
          AppLogger(directory: logs.path, minimumLevel: LogLevel.debug),
        ),
        recordValidationProvider.overrideWith2(
          (key) => FakeRecordValidation(key, script),
        ),
        ...overrides.cast(),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    return container;
  }

  /// [child] in an Anvil-themed app over [container], at the app's minimum
  /// window (1400×800) with the open sidebar's 220 px taken, so the page
  /// gets the width it has in the real shell.
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    build();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: anvilTheme(AnvilThemeSpec.dark),
          home: Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(width: 220),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

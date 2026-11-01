import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

import '../db/support/fixture_copy.dart';

final RegExp _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

/// 0.1.6 `new Date().toISOString()`.
final RegExp _jsIso = RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$');

const String _seeded = '2026-10-31 20:58:16';

/// One meta list, driven through the repository by closures so every list
/// gets the same add / update / reorder / delete checks.
final class _ListCase {
  const _ListCase({
    required this.name,
    required this.table,
    required this.kind,
    required this.seededIds,
    required this.list,
    required this.add,
    required this.update,
    required this.delete,
    required this.reorder,
    required this.freeId,
    required this.usedId,
    required this.usedReason,
    required this.usedCounts,
  });

  final String name;
  final String table;
  final MetaInUseKind kind;
  final List<String> seededIds;
  final Future<List<String>> Function(MetaRepository) list;

  /// Adds a row named [name] and returns (id, sortOrder, displayName).
  final Future<(String, int, String)> Function(MetaRepository, String name) add;
  final Future<String> Function(MetaRepository, String id, String name) update;
  final Future<void> Function(MetaRepository, String id) delete;
  final Future<void> Function(MetaRepository, List<String> ids) reorder;
  final String freeId;
  final String usedId;
  final String usedReason;
  final Map<String, int> usedCounts;
}

MetaItemInput _item(String name) =>
    MetaItemInput(displayName: name, exportKey: name.toLowerCase());

final List<_ListCase> _cases = [
  _ListCase(
    name: 'stats',
    table: 'stats',
    kind: MetaInUseKind.stat,
    seededIds: [
      'stat-strength',
      'stat-constitution',
      'stat-dexterity',
      'stat-intelligence',
      'stat-wisdom',
      'stat-resilience',
      'stat-charisma',
    ],
    list: (r) async => [for (final x in await r.listStats()) x.id],
    add: (r, n) async {
      final x = await r.addStat(_item(n));
      return (x.id, x.sortOrder, x.displayName);
    },
    update: (r, id, n) async => (await r.updateStat(id, _item(n))).displayName,
    delete: (r, id) => r.deleteStat(id),
    reorder: (r, ids) => r.reorderStats(ids),
    freeId: 'stat-charisma',
    usedId: 'stat-strength',
    usedReason: 'Stat is used by 1 class(es) in stat growth definitions.',
    usedCounts: {'classes': 1},
  ),
  _ListCase(
    name: 'rarities',
    table: 'rarities',
    kind: MetaInUseKind.rarity,
    seededIds: [
      'rarity-common',
      'rarity-uncommon',
      'rarity-rare',
      'rarity-epic',
      'rarity-legendary',
    ],
    list: (r) async => [for (final x in await r.listRarities()) x.id],
    add: (r, n) async {
      final x = await r.addRarity(
        MetaRarityInput(
          displayName: n,
          exportKey: n.toLowerCase(),
          colorHex: '#123456',
        ),
      );
      return (x.id, x.sortOrder, x.displayName);
    },
    update: (r, id, n) async => (await r.updateRarity(
      id,
      MetaRarityInput(
        displayName: n,
        exportKey: n.toLowerCase(),
        colorHex: '#654321',
      ),
    )).displayName,
    delete: (r, id) => r.deleteRarity(id),
    reorder: (r, ids) => r.reorderRarities(ids),
    freeId: 'rarity-legendary',
    usedId: 'rarity-common',
    usedReason: 'Rarity is used by 3 item(s).',
    usedCounts: {'items': 3},
  ),
  _ListCase(
    name: 'item categories',
    table: 'item_categories',
    kind: MetaInUseKind.itemCategory,
    seededIds: [
      'item-category-weapon',
      'item-category-armor',
      'item-category-accessory',
      'item-category-consumable',
      'item-category-quest-item',
      'item-category-crafting-resource',
      'item-category-blueprint',
    ],
    list: (r) async => [for (final x in await r.listItemCategories()) x.id],
    add: (r, n) async {
      final x = await r.addItemCategory(_item(n));
      return (x.id, x.sortOrder, x.displayName);
    },
    update: (r, id, n) async =>
        (await r.updateItemCategory(id, _item(n))).displayName,
    delete: (r, id) => r.deleteItemCategory(id),
    reorder: (r, ids) => r.reorderItemCategories(ids),
    freeId: 'item-category-blueprint',
    usedId: 'item-category-weapon',
    usedReason: 'Item category is used by 1 item(s).',
    usedCounts: {'items': 1},
  ),
  _ListCase(
    name: 'NPC types',
    table: 'npc_types',
    kind: MetaInUseKind.npcType,
    seededIds: ['npc-type-enemy', 'npc-type-merchant', 'npc-type-quest-giver'],
    list: (r) async => [for (final x in await r.listNpcTypes()) x.id],
    add: (r, n) async {
      final x = await r.addNpcType(_item(n));
      return (x.id, x.sortOrder, x.displayName);
    },
    update: (r, id, n) async =>
        (await r.updateNpcType(id, _item(n))).displayName,
    delete: (r, id) => r.deleteNpcType(id),
    reorder: (r, ids) => r.reorderNpcTypes(ids),
    freeId: 'npc-type-quest-giver',
    usedId: 'npc-type-merchant',
    usedReason: 'NPC type is used by 1 NPC(s).',
    usedCounts: {'npcs': 1},
  ),
  _ListCase(
    name: 'crafting stations',
    table: 'crafting_stations',
    kind: MetaInUseKind.craftingStation,
    seededIds: [
      'crafting-station-forge',
      'crafting-station-workbench',
      'crafting-station-alchemy-table',
      'crafting-station-enchanting-table',
    ],
    list: (r) async => [for (final x in await r.listCraftingStations()) x.id],
    add: (r, n) async {
      final x = await r.addCraftingStation(_item(n));
      return (x.id, x.sortOrder, x.displayName);
    },
    update: (r, id, n) async =>
        (await r.updateCraftingStation(id, _item(n))).displayName,
    delete: (r, id) => r.deleteCraftingStation(id),
    reorder: (r, ids) => r.reorderCraftingStations(ids),
    freeId: 'crafting-station-workbench',
    usedId: 'crafting-station-forge',
    usedReason: 'Station is used by 1 recipe(s).',
    usedCounts: {'recipes': 1},
  ),
  _ListCase(
    name: 'crafting specializations',
    table: 'crafting_specializations',
    kind: MetaInUseKind.craftingSpecialization,
    seededIds: [
      'crafting-specialization-blacksmithing',
      'crafting-specialization-carpentry',
      'crafting-specialization-alchemy',
      'crafting-specialization-enchanting',
    ],
    list: (r) async => [
      for (final x in await r.listCraftingSpecializations()) x.id,
    ],
    add: (r, n) async {
      final x = await r.addCraftingSpecialization(_item(n));
      return (x.id, x.sortOrder, x.displayName);
    },
    update: (r, id, n) async =>
        (await r.updateCraftingSpecialization(id, _item(n))).displayName,
    delete: (r, id) => r.deleteCraftingSpecialization(id),
    reorder: (r, ids) => r.reorderCraftingSpecializations(ids),
    freeId: 'crafting-specialization-carpentry',
    usedId: 'crafting-specialization-blacksmithing',
    usedReason: 'Specialization is used by 1 recipe(s).',
    usedCounts: {'recipes': 1},
  ),
  _ListCase(
    name: 'derived stats',
    table: 'derived_stat_definitions',
    kind: MetaInUseKind.derivedStat,
    seededIds: [
      'derived-stat-max-hp',
      'derived-stat-attack-power',
      'derived-stat-magic-power',
    ],
    list: (r) async => [for (final x in await r.listDerivedStats()) x.id],
    add: (r, n) async {
      final x = await r.addDerivedStat(
        DerivedStatInput(
          displayName: n,
          exportKey: n.toLowerCase(),
          formula: 'dex * 3',
          outputType: DerivedStatOutputType.float,
          roundingMode: RoundingMode.none,
        ),
      );
      return (x.id, x.sortOrder, x.displayName);
    },
    update: (r, id, n) async => (await r.updateDerivedStat(
      id,
      DerivedStatInput(
        displayName: n,
        exportKey: n.toLowerCase(),
        formula: 'wis + 1',
        outputType: DerivedStatOutputType.integer,
        roundingMode: RoundingMode.floor,
      ),
    )).displayName,
    delete: (r, id) => r.deleteDerivedStat(id),
    reorder: (r, ids) => r.reorderDerivedStats(ids),
    freeId: 'derived-stat-magic-power',
    usedId: 'derived-stat-max-hp',
    usedReason: 'Derived stat has overrides in 1 class(es).',
    usedCounts: {'classes': 1},
  ),
];

void main() {
  final fixture = FixtureCopy.setUpEach();

  late ProjectDatabase db;
  late MetaRepository repo;

  setUp(() {
    db = fixture().openFixture();
    repo = SqliteMetaRepository(db);
  });

  int count(String sql, [List<Object?> args = const []]) =>
      db.read((tx) => tx.select(sql, args)).first.values.first as int;

  int historyCount() => count('SELECT COUNT(*) FROM save_history');

  String latestHistory() =>
      db
              .read(
                (tx) => tx.select(
                  'SELECT description FROM save_history ORDER BY id DESC LIMIT 1',
                ),
              )
              .single['description']
          as String;

  Map<String, Object?> rowOf(String table, String id) => db
      .read((tx) => tx.select('SELECT * FROM $table WHERE id = ?', [id]))
      .single;

  /// Every meta table, project_info and the history count, for proving a
  /// refused save changed nothing.
  Map<String, Object?> snapshotAll() => db.read(
    (tx) => {
      for (final t in [
        'project_info',
        'stats',
        'rarities',
        'item_categories',
        'npc_types',
        'crafting_stations',
        'crafting_specializations',
        'derived_stat_definitions',
        'save_history',
      ])
        t: [
          for (final r in tx.select('SELECT * FROM $t ORDER BY rowid')) {...r},
        ],
    },
  );

  group('seeded lists read back in 0.1.6 order', () {
    test('stats', () async {
      final stats = await repo.listStats();
      expect(stats.first.id, 'stat-strength');
      expect(stats.first.displayName, 'Strength');
      expect(stats.first.exportKey, 'str');
      expect(stats.first.sortOrder, 10);
      expect(
        [for (final s in stats) s.exportKey],
        ['str', 'con', 'dex', 'int', 'wis', 'res', 'cha'],
      );
    });

    test('rarities carry their colour', () async {
      final rarities = await repo.listRarities();
      expect(
        [for (final r in rarities) '${r.exportKey} ${r.colorHex}'],
        [
          'common #D8DEE9',
          'uncommon #A3BE8C',
          'rare #5E81AC',
          'epic #B48EAD',
          'legendary #EBCB8B',
        ],
      );
    });

    test('item categories, NPC types, stations, specializations', () async {
      final categories = await repo.listItemCategories();
      expect(categories.first.displayName, 'Weapon');
      expect(categories.first.description, isA<String>());
      expect(categories.last.exportKey, 'blueprint');
      expect(
        [for (final n in await repo.listNpcTypes()) n.displayName],
        ['Enemy', 'Merchant', 'Quest Giver'],
      );
      expect(
        [for (final s in await repo.listCraftingStations()) s.exportKey],
        ['forge', 'workbench', 'alchemy_table', 'enchanting_table'],
      );
      expect(
        [for (final s in await repo.listCraftingSpecializations()) s.sortOrder],
        [10, 20, 30, 40],
      );
    });

    test('derived stats', () async {
      final derived = await repo.listDerivedStats();
      expect(derived.first.id, 'derived-stat-max-hp');
      expect(derived.first.formula, 'con * 10');
      expect(derived.first.outputType, DerivedStatOutputType.integer);
      expect(derived.first.roundingMode, RoundingMode.round);
      expect(
        [for (final d in derived) d.exportKey],
        ['max_hp', 'attack_power', 'magic_power'],
      );
    });

    for (final c in _cases) {
      test('${c.name}: ids', () async {
        expect(await c.list(repo), c.seededIds);
      });
    }
  });

  test('loadProjectSettings reads the scalars and the five lists', () async {
    final settings = await repo.loadProjectSettings();
    expect(settings.gameTitle, 'Forge & Fable');
    expect(settings.maxLevel, 20);
    expect(
      settings.softDeleteReferenceSeverity,
      SoftDeleteReferenceSeverity.warning,
    );
    expect(
      settings.stats.first,
      const MetaRowDraft(
        id: 'stat-strength',
        displayName: 'Strength',
        exportKey: 'str',
      ),
    );
    expect(settings.stats, hasLength(7));
    expect(settings.rarities.last.colorHex, '#EBCB8B');
    expect(settings.craftingStations, hasLength(4));
    expect(settings.craftingSpecializations, hasLength(4));
    expect(settings.derivedStats.first.formula, 'con * 10');
  });

  for (final c in _cases) {
    group(c.name, () {
      test(
        'add appends at MAX(sort_order) + 1 with a UUID and history',
        () async {
          final before = historyCount();
          final (id, sortOrder, displayName) = await c.add(repo, 'Zeta');
          expect(id, matches(_uuidV4));
          expect(displayName, 'Zeta');
          final seededMax =
              rowOf(c.table, c.seededIds.last)['sort_order'] as int;
          expect(sortOrder, seededMax + 1);
          expect(await c.list(repo), [...c.seededIds, id]);
          final row = rowOf(c.table, id);
          expect(row['created_at'], matches(_jsIso));
          expect(row['updated_at'], row['created_at']);
          expect(historyCount(), before + 1);
          expect(latestHistory(), 'Project settings changed');
        },
      );

      test('update changes the row and updated_at', () async {
        final id = c.seededIds[1];
        expect(rowOf(c.table, id)['updated_at'], _seeded);
        expect(await c.update(repo, id, 'Renamed'), 'Renamed');
        final row = rowOf(c.table, id);
        expect(row['display_name'], 'Renamed');
        expect(row['export_key'], 'renamed');
        expect(row['updated_at'], matches(_jsIso));
        expect(row['sort_order'], 20);
        expect(latestHistory(), 'Project settings changed');
      });

      test('update of an unknown id throws RecordNotFound', () async {
        final before = historyCount();
        await expectLater(
          c.update(repo, 'missing', 'X'),
          throwsA(
            isA<RecordNotFound>()
                .having((e) => e.domain, 'domain', c.table)
                .having((e) => e.id, 'id', 'missing'),
          ),
        );
        expect(historyCount(), before);
      });

      test('reorder reverses and reads back in the new order', () async {
        final reversed = c.seededIds.reversed.toList();
        await c.reorder(repo, reversed);
        expect(await c.list(repo), reversed);
        expect(rowOf(c.table, reversed.first)['sort_order'], 0);
        expect(latestHistory(), 'Project settings changed');
      });

      test('delete of a free row succeeds', () async {
        expect(
          await repo.checkInUse(c.kind, c.freeId),
          const MetaInUseResult.free(),
        );
        await c.delete(repo, c.freeId);
        expect(await c.list(repo), [
          for (final id in c.seededIds)
            if (id != c.freeId) id,
        ]);
      });

      test('delete of an in-use row throws MetaInUse', () async {
        final check = await repo.checkInUse(c.kind, c.usedId);
        expect(check.inUse, isTrue);
        expect(check.reason, c.usedReason);
        final before = historyCount();
        await expectLater(
          c.delete(repo, c.usedId),
          throwsA(
            isA<MetaInUse>()
                .having((e) => e.kind, 'kind', c.kind.value)
                .having((e) => e.counts, 'counts', c.usedCounts),
          ),
        );
        expect(await c.list(repo), c.seededIds);
        expect(historyCount(), before);
      });

      test('delete of an unknown id throws RecordNotFound', () async {
        await expectLater(
          c.delete(repo, 'missing'),
          throwsA(isA<RecordNotFound>()),
        );
      });
    });
  }

  group('in-use checks that need a soft delete', () {
    void softDelete(String table, String id) =>
        db.saveTransaction('test', (tx) {
          tx.execute(
            "UPDATE $table SET deleted_at = datetime('now') WHERE id = ?",
            [id],
          );
        });

    test('item category: items first, then custom field definitions', () async {
      expect(
        (await repo.checkInUse(
          MetaInUseKind.itemCategory,
          'item-category-weapon',
        )).reason,
        'Item category is used by 1 item(s).',
      );
      softDelete('items', '6069c26a-d758-4981-b29b-eed2c95fe6f3');
      expect(
        (await repo.checkInUse(
          MetaInUseKind.itemCategory,
          'item-category-weapon',
        )).reason,
        'Item category has 2 custom field definition(s). '
        'Delete those fields first.',
      );
      await expectLater(
        repo.deleteItemCategory('item-category-weapon'),
        throwsA(
          isA<MetaInUse>()
              .having((e) => e.kind, 'kind', 'item-category')
              .having((e) => e.counts, 'counts', {'customFieldDefinitions': 2}),
        ),
      );
    });

    test('NPC type: NPCs first, then custom field definitions', () async {
      expect(
        (await repo.checkInUse(MetaInUseKind.npcType, 'npc-type-enemy')).reason,
        'NPC type is used by 1 NPC(s).',
      );
      softDelete('npcs', '9516c484-83f0-488a-a9d5-a7ce0f006d7f');
      expect(
        (await repo.checkInUse(MetaInUseKind.npcType, 'npc-type-enemy')).reason,
        'NPC type has 1 custom field definition(s). Delete those fields first.',
      );
      await expectLater(
        repo.deleteNpcType('npc-type-enemy'),
        throwsA(
          isA<MetaInUse>().having((e) => e.counts, 'counts', {
            'customFieldDefinitions': 1,
          }),
        ),
      );
    });

    test('soft-deleted items do not count towards a rarity', () async {
      // Cursed Dagger is soft-deleted and the only epic item.
      expect(
        await repo.checkInUse(MetaInUseKind.rarity, 'rarity-epic'),
        const MetaInUseResult.free(),
      );
    });
  });

  group('saveProjectSettings', () {
    test('commits every change in one history row', () async {
      final before = historyCount();
      final loaded = await repo.loadProjectSettings();
      final draft = loaded.copyWith(
        gameTitle: 'Ember & Ash',
        maxLevel: 60,
        softDeleteReferenceSeverity: SoftDeleteReferenceSeverity.error,
        stats: [
          ...loaded.stats,
          const MetaRowDraft(
            id: '${newMetaIdPrefix}tmp-1',
            displayName: 'Luck',
            exportKey: 'lck',
          ),
        ],
        rarities: [
          for (final r in loaded.rarities)
            r.id == 'rarity-rare' ? r.copyWith(displayName: 'Scarce') : r,
        ],
        craftingSpecializations: [
          for (final s in loaded.craftingSpecializations)
            if (s.id != 'crafting-specialization-carpentry') s,
        ],
        derivedStats: loaded.derivedStats.reversed.toList(),
      );

      final saved = await repo.saveProjectSettings(draft);

      expect(historyCount(), before + 1);
      expect(latestHistory(), 'Project settings changed');
      expect(saved, await repo.loadProjectSettings());
      expect(saved.gameTitle, 'Ember & Ash');
      expect(saved.maxLevel, 60);
      expect(
        saved.softDeleteReferenceSeverity,
        SoftDeleteReferenceSeverity.error,
      );

      final luck = saved.stats.last;
      expect(luck.displayName, 'Luck');
      expect(luck.id, matches(_uuidV4));
      expect(rowOf('stats', luck.id)['sort_order'], 71);
      expect(
        [for (final s in saved.stats) s.id].take(7),
        loaded.stats.map((s) => s.id),
      );

      expect(saved.rarities[2].displayName, 'Scarce');
      expect(rowOf('rarities', 'rarity-rare')['updated_at'], matches(_jsIso));
      expect(rowOf('rarities', 'rarity-common')['updated_at'], _seeded);

      expect([
        for (final s in saved.craftingSpecializations) s.id,
      ], isNot(contains('crafting-specialization-carpentry')));
      expect(saved.craftingSpecializations, hasLength(3));

      expect(
        [for (final d in saved.derivedStats) d.id],
        [
          'derived-stat-magic-power',
          'derived-stat-attack-power',
          'derived-stat-max-hp',
        ],
      );
      expect(
        rowOf(
          'derived_stat_definitions',
          'derived-stat-magic-power',
        )['sort_order'],
        0,
      );
      // An untouched list keeps its stored order values.
      expect(
        rowOf('crafting_stations', 'crafting-station-forge')['sort_order'],
        10,
      );
    });

    test('removing an in-use rarity rolls everything back', () async {
      final before = snapshotAll();
      final loaded = await repo.loadProjectSettings();
      final draft = loaded.copyWith(
        gameTitle: 'Changed',
        stats: [
          ...loaded.stats,
          const MetaRowDraft(
            id: '${newMetaIdPrefix}x',
            displayName: 'Luck',
            exportKey: 'lck',
          ),
        ],
        rarities: [
          for (final r in loaded.rarities)
            if (r.id != 'rarity-common') r,
        ],
      );
      await expectLater(
        repo.saveProjectSettings(draft),
        throwsA(
          isA<MetaInUse>().having((e) => e.kind, 'kind', 'rarity').having(
            (e) => e.counts,
            'counts',
            {'items': 3},
          ),
        ),
      );
      expect(snapshotAll(), before);
    });

    test('an unchanged draft round-trips the game title', () async {
      final loaded = await repo.loadProjectSettings();
      final saved = await repo.saveProjectSettings(
        loaded.copyWith(gameTitle: 'Forge & Fable: Second Edition'),
      );
      expect(saved.gameTitle, 'Forge & Fable: Second Edition');
      expect(
        (await repo.loadProjectSettings()).gameTitle,
        'Forge & Fable: Second Edition',
      );
      expect(saved.copyWith(gameTitle: loaded.gameTitle), loaded);
      // Nothing in the lists changed, so no list row was rewritten.
      expect(rowOf('stats', 'stat-strength')['updated_at'], _seeded);
    });

    test('a draft row whose id is gone throws RecordNotFound', () async {
      final loaded = await repo.loadProjectSettings();
      await expectLater(
        repo.saveProjectSettings(
          loaded.copyWith(
            stats: [
              ...loaded.stats,
              const MetaRowDraft(id: 'gone', displayName: 'G', exportKey: 'g'),
            ],
          ),
        ),
        throwsA(
          isA<RecordNotFound>().having((e) => e.domain, 'domain', 'stats'),
        ),
      );
    });
  });
}

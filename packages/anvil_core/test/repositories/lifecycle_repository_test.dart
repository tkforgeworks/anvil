import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

import '../db/support/fixture_copy.dart';

const String _warrior = '8cb0cf2e-a3f2-47ad-ad82-158dc9eb3d8a';
const String _mage = 'a7b87a4c-f898-4ebd-bfca-a8163101fc77';
const String _slash = 'a41d8d54-0a88-49c8-b53a-0cb21ef14f6a';
const String _fireball = '4e5b5a67-ba0b-43b2-bdfa-3bd426f83c7e';
const String _retiredMove = 'b252cd54-6b6e-4534-b5dc-5b5c2d53262b';
const String _ironIngot = '11a74879-0851-4af7-8ff1-7be63edae9f2';
const String _leatherStrip = '990f8604-827f-4890-b130-122bf252788a';
const String _ironSword = '6069c26a-d758-4981-b29b-eed2c95fe6f3';
const String _moonpetal = '65e565f0-6126-4927-b3f7-cccc4c3ed0f3';
const String _healingPotion = 'a4b66c54-05d2-4007-bed7-8f13bee1f087';
const String _cursedDagger = '436aa413-a7d6-4671-b067-28139fc1fa05';
const String _forgeIronSword = 'a7a5c929-8193-457c-bedd-eea367abf255';
const String _brewHealingPotion = '2f3bcc27-2306-43c3-99ee-87b9319fd960';
const String _goblin = '9516c484-83f0-488a-a9d5-a7ce0f006d7f';
const String _marla = '1fdfd4c3-bf59-405d-9a77-f4ad056d82b4';
const String _goblinDrops = '1e11b296-71a9-4976-887b-d0f32e25becb';
const String _unknown = '00000000-0000-4000-8000-000000000000';

const String _fixtureTime = '2026-10-31 20:58:16';

const List<String> _tables = [
  'classes',
  'abilities',
  'items',
  'recipes',
  'npcs',
  'loot_tables',
];

void main() {
  final fixture = FixtureCopy.setUpEach();

  late ProjectDatabase db;
  late LifecycleRepository repo;

  setUp(() {
    db = fixture().openFixture();
    repo = SqliteLifecycleRepository(db);
  });

  List<Map<String, Object?>> rows(
    String sql, [
    List<Object?> parameters = const [],
  ]) => db.read(
    (tx) => [
      for (final r in tx.select(sql, parameters)) {...r},
    ],
  );

  int count(String sql, [List<Object?> parameters = const []]) =>
      rows(sql, parameters).single.values.single as int;

  int historyCount() => count('SELECT COUNT(*) FROM save_history');

  String latestHistory() =>
      rows('SELECT description FROM save_history ORDER BY id DESC LIMIT 1')
              .single['description']
          as String;

  String? deletedAt(String table, String id) =>
      rows('SELECT deleted_at FROM $table WHERE id = ?', [
            id,
          ]).single['deleted_at']
          as String?;

  bool exists(String table, String id) =>
      count('SELECT COUNT(*) FROM $table WHERE id = ?', [id]) == 1;

  /// Every active row of the six tables.
  Map<String, List<Map<String, Object?>>> activeRows() => {
    for (final t in _tables)
      t: rows('SELECT * FROM $t WHERE deleted_at IS NULL ORDER BY id'),
  };

  /// Runs raw SQL as test setup (bypassing the repository's rules).
  void setUpSql(String sql, [List<Object?> parameters = const []]) =>
      db.saveTransaction('test setup', (tx) => tx.execute(sql, parameters));

  test('LifecycleDomain carries the 0.1.6 strings, tables and labels', () {
    expect(
      [for (final d in LifecycleDomain.values) d.value],
      ['classes', 'abilities', 'items', 'recipes', 'npcs', 'loot-tables'],
    );
    expect([for (final d in LifecycleDomain.values) d.table], _tables);
    expect(LifecycleDomain.lootTables.saveDomain, SaveDomain.lootTables);
    expect(
      LifecycleDomain.fromValue('loot-tables'),
      LifecycleDomain.lootTables,
    );
    expect(() => LifecycleDomain.fromValue('meta'), throwsArgumentError);
  });

  test(
    'countDeleted counts the fixture soft-deleted ability and item',
    () async {
      expect(
        await repo.countDeleted(),
        const RecordCounts(abilities: 1, items: 1),
      );
      await SqliteNpcRepository(db).softDelete(_marla);
      expect(
        await repo.countDeleted(),
        const RecordCounts(abilities: 1, items: 1, npcs: 1),
      );
    },
  );

  group('bulkSoftDelete', () {
    test('sets deleted_at on each active id and writes one history '
        'row', () async {
      final before = historyCount();
      expect(
        await repo.bulkSoftDelete(LifecycleDomain.items, [
          _ironIngot,
          _leatherStrip,
        ]),
        2,
      );
      for (final id in [_ironIngot, _leatherStrip]) {
        expect(deletedAt('items', id), isNotNull);
        expect(
          rows('SELECT updated_at FROM items WHERE id = ?', [id]).single.values,
          isNot([_fixtureTime]),
        );
      }
      expect(deletedAt('items', _ironSword), isNull);
      expect(historyCount(), before + 1);
      expect(latestHistory(), '2 items deleted');
    });

    test('skips unknown, repeated and already deleted ids, and counts the '
        'rows changed', () async {
      expect(
        await repo.bulkSoftDelete(LifecycleDomain.items, [
          _ironIngot,
          _ironIngot,
          _cursedDagger,
          _unknown,
          _moonpetal,
        ]),
        2,
      );
      expect(deletedAt('items', _cursedDagger), _fixtureTime);
      expect(latestHistory(), '2 items deleted');
    });

    test('describes one record as 0.1.6 did', () async {
      expect(await repo.bulkSoftDelete(LifecycleDomain.npcs, [_goblin]), 1);
      expect(latestHistory(), 'NPC deleted');
      expect(
        await repo.bulkSoftDelete(LifecycleDomain.lootTables, [_goblinDrops]),
        1,
      );
      expect(latestHistory(), 'Loot Table deleted');
    });

    test('writes nothing when no id changes', () async {
      final before = historyCount();
      expect(await repo.bulkSoftDelete(LifecycleDomain.items, []), 0);
      expect(
        await repo.bulkSoftDelete(LifecycleDomain.items, [
          _unknown,
          _cursedDagger,
        ]),
        0,
      );
      expect(historyCount(), before);
    });
  });

  test('bulkRestore clears deleted_at on the deleted ids only', () async {
    await repo.bulkSoftDelete(LifecycleDomain.items, [_ironIngot, _moonpetal]);
    final potionBefore = rows('SELECT * FROM items WHERE id = ?', [
      _healingPotion,
    ]).single;
    final before = historyCount();

    expect(
      await repo.bulkRestore(LifecycleDomain.items, [
        _ironIngot,
        _moonpetal,
        _cursedDagger,
        _healingPotion,
        _unknown,
      ]),
      3,
    );

    for (final id in [_ironIngot, _moonpetal, _cursedDagger]) {
      expect(deletedAt('items', id), isNull);
    }
    // An active id is not touched, not even its updated_at.
    expect(
      rows('SELECT * FROM items WHERE id = ?', [_healingPotion]).single,
      potionBefore,
    );
    expect(historyCount(), before + 1);
    expect(latestHistory(), '3 items restored');

    expect(
      await repo.bulkRestore(LifecycleDomain.abilities, [_retiredMove]),
      1,
    );
    expect(latestHistory(), 'Ability restored');
    expect(await repo.bulkRestore(LifecycleDomain.abilities, [_slash]), 0);
  });

  group('bulkHardDelete', () {
    test('deletes NPCs, active or not, with cascaded assignments and their '
        'custom field values', () async {
      await SqliteNpcRepository(db).softDelete(_marla);
      final before = historyCount();

      expect(
        await repo.bulkHardDelete(LifecycleDomain.npcs, [
          _goblin,
          _marla,
          _unknown,
        ]),
        2,
      );

      expect(count('SELECT COUNT(*) FROM npcs'), 0);
      expect(count('SELECT COUNT(*) FROM npc_class_assignments'), 0);
      expect(count('SELECT COUNT(*) FROM npc_ability_assignments'), 0);
      expect(
        count("SELECT COUNT(*) FROM custom_field_values WHERE domain = 'npcs'"),
        0,
      );
      // Item values are untouched.
      expect(
        count(
          "SELECT COUNT(*) FROM custom_field_values WHERE domain = 'items'",
        ),
        2,
      );
      expect(historyCount(), before + 1);
      expect(latestHistory(), '2 NPCs permanently deleted');
    });

    test('cascades recipe ingredients', () async {
      expect(
        await repo.bulkHardDelete(LifecycleDomain.recipes, [
          _forgeIronSword,
          _brewHealingPotion,
        ]),
        2,
      );
      expect(count('SELECT COUNT(*) FROM recipes'), 0);
      expect(count('SELECT COUNT(*) FROM recipe_ingredients'), 0);
      expect(latestHistory(), '2 recipes permanently deleted');

      // The items are free now; one item is described as 0.1.6 did.
      expect(await repo.bulkHardDelete(LifecycleDomain.items, [_moonpetal]), 1);
      expect(exists('items', _moonpetal), isFalse);
      expect(latestHistory(), 'Item permanently deleted');
    });

    test('rolls everything back as SaveFailed when a foreign key '
        'refuses', () async {
      final before = historyCount();
      final itemsBefore = rows('SELECT * FROM items ORDER BY id');
      final valuesBefore = rows('SELECT * FROM custom_field_values');
      await expectLater(
        repo.bulkHardDelete(LifecycleDomain.items, [_cursedDagger, _ironSword]),
        throwsA(isA<SaveFailed>()),
      );
      expect(rows('SELECT * FROM items ORDER BY id'), itemsBefore);
      expect(rows('SELECT * FROM custom_field_values'), valuesBefore);
      expect(historyCount(), before);
    });
  });

  group('emptyTrash', () {
    test('deletes every soft-deleted row and leaves the active rows', () async {
      final active = activeRows();
      final before = historyCount();

      expect(await repo.emptyTrash(), 2);

      expect(exists('abilities', _retiredMove), isFalse);
      expect(exists('items', _cursedDagger), isFalse);
      expect(await repo.countDeleted(), RecordCounts.empty);
      expect(activeRows(), active);
      expect(historyCount(), before + 1);
      expect(latestHistory(), 'Changes across 6 domains');
    });

    test('covers every domain and removes NPC custom field values', () async {
      final npcs = SqliteNpcRepository(db);
      await npcs.softDelete(_goblin);
      await npcs.softDelete(_marla);
      await SqliteLootTableRepository(db).softDelete(_goblinDrops);
      await SqliteRecipeRepository(db).softDelete(_forgeIronSword);
      final classes = SqliteClassRepository(db);
      final unused = await classes.create(
        CreateClassInput(displayName: 'Unused', exportKey: 'unused'),
      );
      await classes.softDelete(unused.id);
      expect(
        await repo.countDeleted(),
        const RecordCounts(
          classes: 1,
          abilities: 1,
          items: 1,
          recipes: 1,
          npcs: 2,
          lootTables: 1,
        ),
      );

      expect(await repo.emptyTrash(), 7);

      expect(await repo.countDeleted(), RecordCounts.empty);
      expect(
        count("SELECT COUNT(*) FROM custom_field_values WHERE domain = 'npcs'"),
        0,
      );
      expect(exists('classes', _warrior), isTrue);
    });

    test('writes nothing when the trash is empty', () async {
      await repo.emptyTrash();
      final before = historyCount();
      expect(await repo.emptyTrash(), 0);
      expect(historyCount(), before);
    });

    test('rolls back as SaveFailed when a foreign key refuses', () async {
      // A soft-deleted class still assigned to an active NPC.
      await SqliteClassRepository(db).softDelete(_mage);
      final before = historyCount();
      await expectLater(repo.emptyTrash(), throwsA(isA<SaveFailed>()));
      expect(
        await repo.countDeleted(),
        const RecordCounts(classes: 1, abilities: 1, items: 1),
      );
      expect(historyCount(), before);

      // 0.1.6's table order deletes classes before NPCs, so a class whose
      // only referrer is itself in the trash is refused too, as in 0.1.6.
      await SqliteNpcRepository(db).softDelete(_marla);
      await expectLater(repo.emptyTrash(), throwsA(isA<SaveFailed>()));
      expect(
        await repo.countDeleted(),
        const RecordCounts(classes: 1, abilities: 1, items: 1, npcs: 1),
      );
    });
  });

  group('computeDeleteImpact', () {
    test('a class referenced by NPCs', () async {
      expect(
        await repo.computeDeleteImpact(LifecycleDomain.classes, [_warrior]),
        DeleteImpact(
          recordCount: 1,
          references: const [
            DeleteImpactReference(
              domain: LifecycleDomain.npcs,
              field: 'npc_class_assignments',
              recordCount: 2,
              description: 'NPC class assignments',
            ),
          ],
        ),
      );
      // Distinct NPCs across several ids.
      expect(
        await repo.computeDeleteImpact(LifecycleDomain.classes, [
          _warrior,
          _mage,
        ]),
        DeleteImpact(
          recordCount: 2,
          references: const [
            DeleteImpactReference(
              domain: LifecycleDomain.npcs,
              field: 'npc_class_assignments',
              recordCount: 2,
              description: 'NPC class assignments',
            ),
          ],
        ),
      );
    });

    test('an item referenced as output, ingredient and loot entry', () async {
      expect(
        await repo.computeDeleteImpact(LifecycleDomain.items, [_ironSword]),
        DeleteImpact(
          recordCount: 1,
          references: const [
            DeleteImpactReference(
              domain: LifecycleDomain.recipes,
              field: 'output_item_id',
              recordCount: 1,
              description: 'recipe output items',
            ),
            DeleteImpactReference(
              domain: LifecycleDomain.lootTables,
              field: 'loot_table_entries',
              recordCount: 1,
              description: 'loot table entries',
            ),
          ],
        ),
      );
      expect(
        await repo.computeDeleteImpact(LifecycleDomain.items, [
          _ironIngot,
          _leatherStrip,
          _moonpetal,
        ]),
        DeleteImpact(
          recordCount: 3,
          references: const [
            DeleteImpactReference(
              domain: LifecycleDomain.recipes,
              field: 'recipe_ingredients',
              recordCount: 2,
              description: 'recipe ingredients',
            ),
            DeleteImpactReference(
              domain: LifecycleDomain.lootTables,
              field: 'loot_table_entries',
              recordCount: 1,
              description: 'loot table entries',
            ),
          ],
        ),
      );
    });

    test('an ability referenced by classes and an NPC', () async {
      expect(
        await repo.computeDeleteImpact(LifecycleDomain.abilities, [_slash]),
        DeleteImpact(
          recordCount: 1,
          references: const [
            DeleteImpactReference(
              domain: LifecycleDomain.classes,
              field: 'class_ability_assignments',
              recordCount: 2,
              description: 'class ability assignments',
            ),
            DeleteImpactReference(
              domain: LifecycleDomain.npcs,
              field: 'npc_ability_assignments',
              recordCount: 1,
              description: 'NPC ability assignments',
            ),
          ],
        ),
      );
      expect(
        await repo.computeDeleteImpact(LifecycleDomain.abilities, [_fireball]),
        DeleteImpact(
          recordCount: 1,
          references: const [
            DeleteImpactReference(
              domain: LifecycleDomain.classes,
              field: 'class_ability_assignments',
              recordCount: 1,
              description: 'class ability assignments',
            ),
          ],
        ),
      );
    });

    test('a loot table referenced by an NPC; recipes and NPCs have no '
        'references', () async {
      expect(
        await repo.computeDeleteImpact(LifecycleDomain.lootTables, [
          _goblinDrops,
        ]),
        DeleteImpact(
          recordCount: 1,
          references: const [
            DeleteImpactReference(
              domain: LifecycleDomain.npcs,
              field: 'loot_table_id',
              recordCount: 1,
              description: 'NPC loot table references',
            ),
          ],
        ),
      );
      expect(
        await repo.computeDeleteImpact(LifecycleDomain.recipes, [
          _forgeIronSword,
        ]),
        DeleteImpact(recordCount: 1, references: const []),
      );
      expect(
        await repo.computeDeleteImpact(LifecycleDomain.npcs, [_goblin, _marla]),
        DeleteImpact(recordCount: 2, references: const []),
      );
    });

    test('leaves out soft-deleted referrers, counts every id asked about and '
        'is empty for no ids', () async {
      await SqliteNpcRepository(db).softDelete(_goblin);
      final before = historyCount();
      expect(
        await repo.computeDeleteImpact(LifecycleDomain.classes, [
          _warrior,
          _unknown,
        ]),
        DeleteImpact(
          recordCount: 2,
          references: const [
            DeleteImpactReference(
              domain: LifecycleDomain.npcs,
              field: 'npc_class_assignments',
              recordCount: 1,
              description: 'NPC class assignments',
            ),
          ],
        ),
      );
      expect(
        await repo.computeDeleteImpact(LifecycleDomain.lootTables, [
          _goblinDrops,
        ]),
        DeleteImpact(recordCount: 1, references: const []),
      );
      expect(
        await repo.computeDeleteImpact(LifecycleDomain.items, []),
        DeleteImpact(recordCount: 0, references: const []),
      );
      expect(historyCount(), before);
    });
  });

  test('weeklyDeltas: zero for old rows, then created minus deleted in the '
      'last 7 days', () async {
    // The fixture was generated on 2026-10-31, so its rows only count as
    // old relative to the wall clock until 2026-11-07: age them first.
    for (final t in _tables) {
      setUpSql("UPDATE $t SET created_at = '2026-01-01 00:00:00'");
      setUpSql(
        "UPDATE $t SET deleted_at = '2026-01-01 00:00:00' "
        'WHERE deleted_at IS NOT NULL',
      );
    }
    expect(await repo.weeklyDeltas(), RecordCounts.empty);

    await SqliteItemRepository(db).create(
      const CreateItemInput(
        displayName: 'Bronze Axe',
        exportKey: 'bronze_axe',
        itemCategoryId: 'item-category-weapon',
        rarityId: 'rarity-common',
      ),
    );
    await SqliteAbilityRepository(db).softDelete(_slash);
    await repo.bulkSoftDelete(LifecycleDomain.npcs, [_goblin, _marla]);

    expect(
      await repo.weeklyDeltas(),
      const RecordCounts(items: 1, abilities: -1, npcs: -2),
    );

    // A record created and deleted this week counts only as deleted.
    final npcs = SqliteNpcRepository(db);
    final temp = await npcs.create(
      CreateNpcInput(
        displayName: 'Temp',
        exportKey: 'temp',
        npcTypeId: 'npc-type-enemy',
      ),
    );
    await npcs.softDelete(temp.id);
    expect(
      await repo.weeklyDeltas(),
      const RecordCounts(items: 1, abilities: -1, npcs: -3),
    );
  });
}

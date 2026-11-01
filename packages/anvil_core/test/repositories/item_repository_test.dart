import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

import '../db/support/fixture_copy.dart';

const String _ironIngot = '11a74879-0851-4af7-8ff1-7be63edae9f2';
const String _leatherStrip = '990f8604-827f-4890-b130-122bf252788a';
const String _ironSword = '6069c26a-d758-4981-b29b-eed2c95fe6f3';
const String _moonpetal = '65e565f0-6126-4927-b3f7-cccc4c3ed0f3';
const String _healingPotion = 'a4b66c54-05d2-4007-bed7-8f13bee1f087';
const String _cursedDagger = '436aa413-a7d6-4671-b067-28139fc1fa05';
const String _unknown = '00000000-0000-4000-8000-000000000000';

const String _damage = '18790df6-c2dc-4597-b0b2-679b538d7729';
const String _handedness = 'd62cfe4d-504e-4a84-b15f-af0d0b90bb9d';
const String _aggression = '3789fc46-bc57-4677-ad44-73d9b334788f';

const String _forgeIronSword = 'a7a5c929-8193-457c-bedd-eea367abf255';
const String _brewHealingPotion = '2f3bcc27-2306-43c3-99ee-87b9319fd960';
const String _goblinDrops = '1e11b296-71a9-4976-887b-d0f32e25becb';

const String _fixtureTime = '2026-10-31 20:58:16';

void main() {
  final fixture = FixtureCopy.setUpEach();

  late ProjectDatabase db;
  late ItemRepository repo;

  setUp(() {
    db = fixture().openFixture();
    repo = SqliteItemRepository(db);
  });

  List<Map<String, Object?>> rows(
    String sql, [
    List<Object?> parameters = const [],
  ]) => db.read(
    (tx) => [
      for (final r in tx.select(sql, parameters)) {...r},
    ],
  );

  int historyCount() =>
      rows('SELECT COUNT(*) AS c FROM save_history').single['c'] as int;

  String latestHistory() =>
      rows('SELECT description FROM save_history ORDER BY id DESC LIMIT 1')
              .single['description']
          as String;

  Map<String, Object?> itemRow(String id) =>
      rows('SELECT * FROM items WHERE id = ?', [id]).single;

  List<Map<String, Object?>> valueRows(String id) => rows(
    "SELECT * FROM custom_field_values WHERE domain = 'items' "
    'AND record_id = ? ORDER BY field_definition_id',
    [id],
  );

  Map<String, Object?> without(Map<String, Object?> row, String column) =>
      {...row}..remove(column);

  /// Runs raw SQL as test setup (bypassing the repository's rules).
  void setUpSql(String sql, [List<Object?> parameters = const []]) =>
      db.saveTransaction('test setup', (tx) => tx.execute(sql, parameters));

  test('load reads every fixture item with its custom field values', () async {
    expect(
      await repo.load(_ironSword),
      ItemDraft(
        displayName: 'Iron Sword',
        exportKey: 'iron_sword',
        description: 'A sturdy, reliable blade',
        itemCategoryId: 'item-category-weapon',
        rarityId: 'rarity-uncommon',
        customFieldValues: {_damage: '14', _handedness: 'one-handed'},
      ),
    );
    expect(
      await repo.load(_ironIngot),
      ItemDraft(
        displayName: 'Iron Ingot',
        exportKey: 'iron_ingot',
        description: 'Smelted iron.',
        itemCategoryId: 'item-category-crafting-resource',
        rarityId: 'rarity-common',
      ),
    );
    expect(
      await repo.load(_leatherStrip),
      ItemDraft(
        displayName: 'Leather Strip',
        exportKey: 'leather_strip',
        itemCategoryId: 'item-category-crafting-resource',
        rarityId: 'rarity-common',
      ),
    );
    expect(
      await repo.load(_moonpetal),
      ItemDraft(
        displayName: 'Moonpetal Herb',
        exportKey: 'moonpetal_herb',
        itemCategoryId: 'item-category-crafting-resource',
        rarityId: 'rarity-rare',
      ),
    );
    expect(
      await repo.load(_healingPotion),
      ItemDraft(
        displayName: 'Healing Potion',
        exportKey: 'healing_potion',
        description: 'Restores 50 HP',
        itemCategoryId: 'item-category-consumable',
        rarityId: 'rarity-common',
      ),
    );
    // Soft-deleted items load too (the recycle bin shows them).
    expect(
      await repo.load(_cursedDagger),
      ItemDraft(
        displayName: 'Cursed Dagger',
        exportKey: 'cursed_dagger',
        itemCategoryId: 'item-category-weapon',
        rarityId: 'rarity-epic',
      ),
    );
  });

  test('get returns the row, soft-deleted or not', () async {
    final sword = await repo.get(_ironSword);
    expect(sword.id, _ironSword);
    expect(sword.displayName, 'Iron Sword');
    expect(sword.exportKey, 'iron_sword');
    expect(sword.itemCategoryId, 'item-category-weapon');
    expect(sword.rarityId, 'rarity-uncommon');
    expect(sword.createdAt, _fixtureTime);
    expect(sword.updatedAt, _fixtureTime);
    expect(sword.deletedAt, isNull);
    expect((await repo.get(_cursedDagger)).deletedAt, _fixtureTime);
  });

  test('list modes and countActive, before and after a soft delete', () async {
    Future<List<String>> names(RecordListMode mode) async => [
      for (final r in await repo.list(mode: mode)) r.displayName,
    ];

    expect(await names(RecordListMode.active), [
      'Healing Potion',
      'Iron Ingot',
      'Iron Sword',
      'Leather Strip',
      'Moonpetal Herb',
    ]);
    expect([
      for (final r in await repo.list()) r.displayName,
    ], await names(RecordListMode.active));
    expect(await names(RecordListMode.deletedOnly), ['Cursed Dagger']);
    expect(await names(RecordListMode.all), [
      'Cursed Dagger',
      'Healing Potion',
      'Iron Ingot',
      'Iron Sword',
      'Leather Strip',
      'Moonpetal Herb',
    ]);
    expect(await repo.countActive(), 5);

    await repo.softDelete(_healingPotion);
    expect(await names(RecordListMode.active), [
      'Iron Ingot',
      'Iron Sword',
      'Leather Strip',
      'Moonpetal Herb',
    ]);
    expect(await names(RecordListMode.deletedOnly), [
      'Cursed Dagger',
      'Healing Potion',
    ]);
    expect(await names(RecordListMode.all), hasLength(6));
    expect(await repo.countActive(), 4);
  });

  test('list orders by display name ignoring case', () async {
    await repo.create(
      const CreateItemInput(
        displayName: 'iron Axe',
        exportKey: 'iron_axe',
        itemCategoryId: 'item-category-weapon',
        rarityId: 'rarity-common',
      ),
    );
    expect([for (final r in await repo.list()) r.displayName].sublist(1, 4), [
      'iron Axe',
      'Iron Ingot',
      'Iron Sword',
    ]);
  });

  test('save(id, load(id)) changes only updated_at and adds one history '
      'row', () async {
    for (final id in [
      _ironIngot,
      _leatherStrip,
      _ironSword,
      _moonpetal,
      _healingPotion,
    ]) {
      final before = itemRow(id);
      final valuesBefore = valueRows(id);
      final historyBefore = historyCount();
      final draft = await repo.load(id);

      expect(await repo.save(id, draft), draft);

      expect(without(itemRow(id), 'updated_at'), without(before, 'updated_at'));
      expect(itemRow(id)['updated_at'], isNot(_fixtureTime));
      expect(
        [for (final r in valueRows(id)) without(r, 'updated_at')],
        [for (final r in valuesBefore) without(r, 'updated_at')],
      );
      expect(historyCount(), historyBefore + 1);
      expect(latestHistory(), '${draft.displayName} - Item changed');
    }
    expect(valueRows(_ironSword), hasLength(2));
  });

  test('create inserts an item with no custom field values', () async {
    final before = historyCount();
    final created = await repo.create(
      const CreateItemInput(
        displayName: 'Bronze Axe',
        exportKey: 'bronze_axe',
        description: 'Cheap.',
        itemCategoryId: 'item-category-weapon',
        rarityId: 'rarity-common',
      ),
    );
    expect(created.id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4')));
    expect(created.id, hasLength(36));
    expect(created.displayName, 'Bronze Axe');
    expect(created.exportKey, 'bronze_axe');
    expect(created.description, 'Cheap.');
    expect(created.deletedAt, isNull);
    expect(
      await repo.load(created.id),
      ItemDraft(
        displayName: 'Bronze Axe',
        exportKey: 'bronze_axe',
        description: 'Cheap.',
        itemCategoryId: 'item-category-weapon',
        rarityId: 'rarity-common',
      ),
    );
    expect(historyCount(), before + 1);
    expect(latestHistory(), 'Bronze Axe - Item created');
  });

  test('create refuses a used export key with the key', () async {
    final before = historyCount();
    await expectLater(
      repo.create(
        const CreateItemInput(
          displayName: 'Another',
          exportKey: 'cursed_dagger',
          itemCategoryId: 'item-category-weapon',
          rarityId: 'rarity-common',
        ),
      ),
      throwsA(
        isA<DuplicateExportKey>().having(
          (e) => e.exportKey,
          'exportKey',
          'cursed_dagger',
        ),
      ),
    );
    expect(historyCount(), before);
  });

  test('save writes changed fields, a changed and a cleared custom field '
      'value', () async {
    final draft = (await repo.load(_ironSword)).copyWith(
      displayName: 'Steel Sword',
      exportKey: 'steel_sword',
      description: 'Sharper.',
      rarityId: 'rarity-rare',
      customFieldValues: {_damage: '20', _handedness: null},
    );

    final saved = await repo.save(_ironSword, draft);

    expect(saved, draft);
    expect(await repo.load(_ironSword), draft);
    final row = itemRow(_ironSword);
    expect(row['display_name'], 'Steel Sword');
    expect(row['export_key'], 'steel_sword');
    expect(row['description'], 'Sharper.');
    expect(row['rarity_id'], 'rarity-rare');
    expect(row['created_at'], _fixtureTime);
    // A null value is stored as a row with NULL, as 0.1.6 stored it.
    expect(
      {
        for (final r in valueRows(_ironSword))
          r['field_definition_id']: r['value'],
      },
      {_damage: '20', _handedness: null},
    );
    expect(latestHistory(), 'Steel Sword - Item changed');
  });

  test('save replaces the value rows: a value left out is deleted', () async {
    final draft = (await repo.load(_ironSword))
        .copyWith(customFieldValues: {_damage: '14'});
    await repo.save(_ironSword, draft);
    expect(
      [for (final r in valueRows(_ironSword)) r['field_definition_id']],
      [_damage],
    );
  });

  test('save keeps values outside the category when the category is '
      'unchanged, as 0.1.6 setCustomFieldValues did', () async {
    final draft = (await repo.load(_ironIngot))
        .copyWith(customFieldValues: {_damage: '3'});
    expect(await repo.save(_ironIngot, draft), draft);
    expect(valueRows(_ironIngot).single['value'], '3');
  });

  test('a category change drops values of fields outside the new '
      'category', () async {
    final draft = (await repo.load(_ironSword))
        .copyWith(itemCategoryId: 'item-category-consumable');
    final saved = await repo.save(_ironSword, draft);
    expect(saved.itemCategoryId, 'item-category-consumable');
    expect(saved.customFieldValues, isEmpty);
    expect(valueRows(_ironSword), isEmpty);
  });

  group('save is refused', () {
    late Map<String, Object?> rowBefore;
    late List<Map<String, Object?>> valuesBefore;
    late int historyBefore;

    setUp(() {
      rowBefore = itemRow(_ironSword);
      valuesBefore = valueRows(_ironSword);
      historyBefore = historyCount();
    });

    void expectUnchanged() {
      expect(itemRow(_ironSword), rowBefore);
      expect(valueRows(_ironSword), valuesBefore);
      expect(historyCount(), historyBefore);
    }

    for (final (field, edit) in <(String, ItemDraft Function(ItemDraft))>[
      ('displayName', (d) => d.copyWith(displayName: '  ')),
      ('exportKey', (d) => d.copyWith(exportKey: '')),
      ('itemCategoryId', (d) => d.copyWith(itemCategoryId: '')),
      ('rarityId', (d) => d.copyWith(rarityId: '')),
    ]) {
      test('with SaveBlocked for an empty $field', () async {
        final draft = edit(
          (await repo.load(_ironSword))
              .copyWith(customFieldValues: {_damage: '99'}),
        );
        final blockers = itemSaveBlockers(draft);
        expect([for (final b in blockers) b.field], [field]);
        await expectLater(
          repo.save(_ironSword, draft),
          throwsA(
            isA<SaveBlocked>().having((e) => e.blockers, 'blockers', [
              blockers.single.message,
            ]),
          ),
        );
        expectUnchanged();
      });
    }

    test('with DuplicateExportKey naming the key, soft-deleted owners '
        'included', () async {
      for (final key in ['iron_ingot', 'cursed_dagger']) {
        final draft = (await repo.load(_ironSword)).copyWith(exportKey: key);
        await expectLater(
          repo.save(_ironSword, draft),
          throwsA(
            isA<DuplicateExportKey>().having((e) => e.exportKey, 'key', key),
          ),
        );
      }
      expectUnchanged();
    });

    test('with RecordNotFound for a soft-deleted or unknown id', () async {
      final draft = await repo.load(_cursedDagger);
      final daggerBefore = itemRow(_cursedDagger);
      await expectLater(
        repo.save(_cursedDagger, draft),
        throwsA(
          isA<RecordNotFound>()
              .having((e) => e.domain, 'domain', 'items')
              .having((e) => e.id, 'id', _cursedDagger),
        ),
      );
      expect(itemRow(_cursedDagger), daggerBefore);
      await expectLater(
        repo.save(_unknown, draft.copyWith(exportKey: 'fresh_key')),
        throwsA(isA<RecordNotFound>()),
      );
      expectUnchanged();
    });
  });

  test('RecordNotFound for an unknown id everywhere else', () async {
    final notFound = throwsA(
      isA<RecordNotFound>()
          .having((e) => e.domain, 'domain', 'items')
          .having((e) => e.id, 'id', _unknown),
    );
    final before = historyCount();
    await expectLater(repo.get(_unknown), notFound);
    await expectLater(repo.load(_unknown), notFound);
    await expectLater(repo.duplicate(_unknown), notFound);
    await expectLater(repo.softDelete(_unknown), notFound);
    await expectLater(repo.restore(_unknown), notFound);
    await expectLater(repo.hardDelete(_unknown), notFound);
    expect(historyCount(), before);
  });

  test('duplicate copies the item and its category-scoped values', () async {
    // A value of a field outside the weapon category, which 0.1.6's
    // duplicate did not copy.
    await repo.save(
      _ironSword,
      (await repo.load(_ironSword)).copyWith(
        customFieldValues: {
          _damage: '14',
          _handedness: 'one-handed',
          _aggression: 'hostile',
        },
      ),
    );
    final before = historyCount();

    final copy = await repo.duplicate(_ironSword);

    expect(copy.id, isNot(_ironSword));
    expect(copy.displayName, 'Iron Sword (Copy)');
    expect(copy.exportKey, matches(RegExp(r'^iron-sword-copy-[0-9a-f]{8}$')));
    expect(copy.deletedAt, isNull);
    expect(
      await repo.load(copy.id),
      ItemDraft(
        displayName: 'Iron Sword (Copy)',
        exportKey: copy.exportKey,
        description: 'A sturdy, reliable blade',
        itemCategoryId: 'item-category-weapon',
        rarityId: 'rarity-uncommon',
        customFieldValues: {_damage: '14', _handedness: 'one-handed'},
      ),
    );
    expect(historyCount(), before + 1);
    expect(latestHistory(), 'Iron Sword (Copy) - Item duplicated');

    final second = await repo.duplicate(_ironSword);
    expect(second.exportKey, isNot(copy.exportKey));
  });

  test('soft delete and restore', () async {
    await repo.softDelete(_ironSword);
    var row = itemRow(_ironSword);
    expect(row['deleted_at'], isNotNull);
    expect(row['updated_at'], isNot(_fixtureTime));
    expect(latestHistory(), 'Iron Sword - Item deleted');
    // Custom field values stay with a soft-deleted item.
    expect(valueRows(_ironSword), hasLength(2));

    await repo.restore(_ironSword);
    row = itemRow(_ironSword);
    expect(row['deleted_at'], isNull);
    expect(latestHistory(), 'Iron Sword - Item restored');
    expect((await repo.load(_ironSword)).customFieldValues, hasLength(2));
  });

  test('soft deleting a deleted item keeps its deleted_at', () async {
    final before = historyCount();
    await repo.softDelete(_cursedDagger);
    expect(itemRow(_cursedDagger)['deleted_at'], _fixtureTime);
    expect(historyCount(), before + 1);
    expect(latestHistory(), 'Cursed Dagger - Item deleted');
  });

  test('hard delete removes the item and its custom field values', () async {
    final copy = await repo.duplicate(_ironSword);
    expect(valueRows(copy.id), hasLength(2));

    await repo.hardDelete(copy.id);

    expect(rows('SELECT * FROM items WHERE id = ?', [copy.id]), isEmpty);
    expect(valueRows(copy.id), isEmpty);
    expect(latestHistory(), 'Iron Sword (Copy) - Item permanently deleted');

    await repo.hardDelete(_cursedDagger);
    expect(rows('SELECT * FROM items WHERE id = ?', [_cursedDagger]), isEmpty);
  });

  test('hard delete of a referenced item fails as SaveFailed and changes '
      'nothing', () async {
    final before = historyCount();
    await expectLater(repo.hardDelete(_ironSword), throwsA(isA<SaveFailed>()));
    expect(itemRow(_ironSword)['display_name'], 'Iron Sword');
    expect(valueRows(_ironSword), hasLength(2));
    expect(historyCount(), before);
  });

  test('usedBy lists the fixture recipes and loot tables', () async {
    const forge = UsedByRef(_forgeIronSword, 'Forge Iron Sword');
    const brew = UsedByRef(_brewHealingPotion, 'Brew Healing Potion');
    const goblin = UsedByRef(_goblinDrops, 'Goblin Drops');

    expect(
      await repo.usedBy(_ironIngot),
      ItemUsedBy(recipes: [forge], lootTables: [goblin]),
    );
    expect(
      await repo.usedBy(_leatherStrip),
      ItemUsedBy(recipes: [forge], lootTables: []),
    );
    // As output.
    expect(
      await repo.usedBy(_ironSword),
      ItemUsedBy(recipes: [forge], lootTables: [goblin]),
    );
    expect(
      await repo.usedBy(_healingPotion),
      ItemUsedBy(recipes: [brew], lootTables: [goblin]),
    );
    expect(
      await repo.usedBy(_moonpetal),
      ItemUsedBy(recipes: [brew], lootTables: []),
    );
    expect(
      await repo.usedBy(_unknown),
      ItemUsedBy(recipes: [], lootTables: []),
    );
  });

  test('usedBy lists each recipe and loot table once, ordered ignoring case, '
      'active only', () async {
    // Iron Sword as both output and ingredient of one recipe (save refuses
    // that now; data from 0.1.6 can hold it), and in two entries of one
    // loot table.
    setUpSql(
      'INSERT INTO recipe_ingredients (recipe_id, item_id, quantity, '
      'sort_order) VALUES (?, ?, 1, 2)',
      [_forgeIronSword, _ironSword],
    );
    setUpSql(
      'INSERT INTO loot_table_entries (id, loot_table_id, item_id, weight, '
      "sort_order) VALUES ('extra-entry', ?, ?, 5, 3)",
      [_goblinDrops, _ironSword],
    );
    final recipes = SqliteRecipeRepository(db);
    final pie = await recipes.create(
      CreateRecipeInput(
        displayName: 'apple pie',
        exportKey: 'apple_pie',
        outputItemId: _ironSword,
      ),
    );
    final gone = await recipes.create(
      CreateRecipeInput(
        displayName: 'Zz Gone',
        exportKey: 'zz_gone',
        outputItemId: _ironSword,
      ),
    );
    await recipes.softDelete(gone.id);

    final usedBy = await repo.usedBy(_ironSword);
    expect(usedBy.recipes, [
      UsedByRef(pie.id, 'apple pie'),
      const UsedByRef(_forgeIronSword, 'Forge Iron Sword'),
    ]);
    expect(usedBy.lootTables, [const UsedByRef(_goblinDrops, 'Goblin Drops')]);
  });
}

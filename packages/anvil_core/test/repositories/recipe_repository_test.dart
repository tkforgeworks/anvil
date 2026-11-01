import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

import '../db/support/fixture_copy.dart';

const String _ironIngot = '11a74879-0851-4af7-8ff1-7be63edae9f2';
const String _leatherStrip = '990f8604-827f-4890-b130-122bf252788a';
const String _ironSword = '6069c26a-d758-4981-b29b-eed2c95fe6f3';
const String _moonpetal = '65e565f0-6126-4927-b3f7-cccc4c3ed0f3';
const String _healingPotion = 'a4b66c54-05d2-4007-bed7-8f13bee1f087';

const String _forgeIronSword = 'a7a5c929-8193-457c-bedd-eea367abf255';
const String _brewHealingPotion = '2f3bcc27-2306-43c3-99ee-87b9319fd960';
const String _unknown = '00000000-0000-4000-8000-000000000000';

const String _fixtureTime = '2026-10-31 20:58:16';

void main() {
  final fixture = FixtureCopy.setUpEach();

  late ProjectDatabase db;
  late RecipeRepository repo;

  setUp(() {
    db = fixture().openFixture();
    repo = SqliteRecipeRepository(db);
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

  Map<String, Object?> recipeRow(String id) =>
      rows('SELECT * FROM recipes WHERE id = ?', [id]).single;

  List<Map<String, Object?>> ingredientRows(String id) => rows(
    'SELECT * FROM recipe_ingredients WHERE recipe_id = ? ORDER BY sort_order',
    [id],
  );

  Map<String, Object?> without(Map<String, Object?> row, String column) =>
      {...row}..remove(column);

  final forgeDraft = RecipeDraft(
    displayName: 'Forge Iron Sword',
    exportKey: 'forge_iron_sword',
    description: 'Two ingots and a strip.',
    outputItemId: _ironSword,
    outputQuantity: 1,
    craftingStationId: 'crafting-station-forge',
    craftingSpecializationId: 'crafting-specialization-blacksmithing',
    ingredients: const [
      RecipeIngredient(itemId: _ironIngot, quantity: 2),
      RecipeIngredient(itemId: _leatherStrip, quantity: 1),
    ],
  );

  test('load reads both fixture recipes with ingredients in order', () async {
    expect(await repo.load(_forgeIronSword), forgeDraft);
    expect(
      await repo.load(_brewHealingPotion),
      RecipeDraft(
        displayName: 'Brew Healing Potion',
        exportKey: 'brew_healing_potion',
        outputItemId: _healingPotion,
        outputQuantity: 3,
        craftingStationId: 'crafting-station-alchemy-table',
        ingredients: const [RecipeIngredient(itemId: _moonpetal, quantity: 2)],
      ),
    );
  });

  test('get returns the row', () async {
    final brew = await repo.get(_brewHealingPotion);
    expect(brew.displayName, 'Brew Healing Potion');
    expect(brew.outputItemId, _healingPotion);
    expect(brew.outputQuantity, 3);
    expect(brew.craftingStationId, 'crafting-station-alchemy-table');
    expect(brew.craftingSpecializationId, isNull);
    expect(brew.createdAt, _fixtureTime);
    expect(brew.deletedAt, isNull);
  });

  test('list modes and countActive, before and after a soft delete', () async {
    Future<List<String>> names(RecordListMode mode) async => [
      for (final r in await repo.list(mode: mode)) r.displayName,
    ];

    expect(await names(RecordListMode.active), [
      'Brew Healing Potion',
      'Forge Iron Sword',
    ]);
    expect(await names(RecordListMode.deletedOnly), isEmpty);
    expect(await names(RecordListMode.all), [
      'Brew Healing Potion',
      'Forge Iron Sword',
    ]);
    expect(await repo.countActive(), 2);

    await repo.softDelete(_brewHealingPotion);
    expect(
      [for (final r in await repo.list()) r.displayName],
      ['Forge Iron Sword'],
    );
    expect(await names(RecordListMode.deletedOnly), ['Brew Healing Potion']);
    expect(await names(RecordListMode.all), [
      'Brew Healing Potion',
      'Forge Iron Sword',
    ]);
    expect(await repo.countActive(), 1);
  });

  test('save(id, load(id)) changes only updated_at and adds one history '
      'row', () async {
    for (final id in [_forgeIronSword, _brewHealingPotion]) {
      final before = recipeRow(id);
      final ingredientsBefore = ingredientRows(id);
      final historyBefore = historyCount();
      final draft = await repo.load(id);

      expect(await repo.save(id, draft), draft);

      expect(
        without(recipeRow(id), 'updated_at'),
        without(before, 'updated_at'),
      );
      expect(recipeRow(id)['updated_at'], isNot(_fixtureTime));
      expect(ingredientRows(id), ingredientsBefore);
      expect(historyCount(), historyBefore + 1);
      expect(latestHistory(), '${draft.displayName} - Recipe changed');
    }
  });

  test('create applies the 0.1.6 defaults and has no ingredients', () async {
    final before = historyCount();
    final created = await repo.create(
      const CreateRecipeInput(
        displayName: 'Smelt Ingot',
        exportKey: 'smelt_ingot',
        outputItemId: _ironIngot,
      ),
    );
    expect(created.id, hasLength(36));
    expect(created.outputQuantity, 1);
    expect(created.craftingStationId, isNull);
    expect(created.craftingSpecializationId, isNull);
    expect(created.description, '');
    expect(
      await repo.load(created.id),
      RecipeDraft(
        displayName: 'Smelt Ingot',
        exportKey: 'smelt_ingot',
        outputItemId: _ironIngot,
      ),
    );
    expect(historyCount(), before + 1);
    expect(latestHistory(), 'Smelt Ingot - Recipe created');
  });

  test('create refuses a used export key with the key', () async {
    await expectLater(
      repo.create(
        const CreateRecipeInput(
          displayName: 'X',
          exportKey: 'forge_iron_sword',
          outputItemId: _ironIngot,
        ),
      ),
      throwsA(
        isA<DuplicateExportKey>().having(
          (e) => e.exportKey,
          'key',
          'forge_iron_sword',
        ),
      ),
    );
  });

  test('save writes changed fields, a cleared station and reordered '
      'ingredients', () async {
    final draft = forgeDraft.copyWith(
      displayName: 'Forge Fine Sword',
      exportKey: 'forge_fine_sword',
      description: '',
      outputQuantity: 2,
      craftingStationId: null,
      ingredients: const [
        RecipeIngredient(itemId: _leatherStrip, quantity: 4),
        RecipeIngredient(itemId: _moonpetal, quantity: 1),
        RecipeIngredient(itemId: _ironIngot, quantity: 3),
      ],
    );

    expect(await repo.save(_forgeIronSword, draft), draft);
    expect(await repo.load(_forgeIronSword), draft);

    final row = recipeRow(_forgeIronSword);
    expect(row['display_name'], 'Forge Fine Sword');
    expect(row['output_quantity'], 2);
    expect(row['crafting_station_id'], isNull);
    expect(
      row['crafting_specialization_id'],
      'crafting-specialization-blacksmithing',
    );
    expect(
      [
        for (final r in ingredientRows(_forgeIronSword))
          [r['item_id'], r['quantity'], r['sort_order']],
      ],
      [
        [_leatherStrip, 4, 0],
        [_moonpetal, 1, 1],
        [_ironIngot, 3, 2],
      ],
    );
    expect(latestHistory(), 'Forge Fine Sword - Recipe changed');
  });

  test('save with no ingredients removes them all', () async {
    final draft = forgeDraft.copyWith(ingredients: []);
    expect(await repo.save(_forgeIronSword, draft), draft);
    expect(ingredientRows(_forgeIronSword), isEmpty);
  });

  group('save is refused', () {
    late Map<String, Object?> rowBefore;
    late List<Map<String, Object?>> ingredientsBefore;
    late int historyBefore;

    setUp(() {
      rowBefore = recipeRow(_forgeIronSword);
      ingredientsBefore = ingredientRows(_forgeIronSword);
      historyBefore = historyCount();
    });

    void expectUnchanged() {
      expect(recipeRow(_forgeIronSword), rowBefore);
      expect(ingredientRows(_forgeIronSword), ingredientsBefore);
      expect(historyCount(), historyBefore);
    }

    for (final (i, (path, message, edit)) in <(String, String, RecipeDraft)>[
      (
        'displayName',
        'Display name is required.',
        forgeDraft.copyWith(displayName: ' '),
      ),
      (
        'exportKey',
        'Export key is required.',
        forgeDraft.copyWith(exportKey: ''),
      ),
      (
        'outputItemId',
        'Output item is required.',
        forgeDraft.copyWith(outputItemId: ''),
      ),
      (
        'outputQuantity',
        'Output quantity must be at least 1.',
        forgeDraft.copyWith(outputQuantity: 0),
      ),
      (
        'ingredients[1].quantity',
        'Ingredient 2: quantity must be at least 1.',
        forgeDraft.copyWith(
          ingredients: const [
            RecipeIngredient(itemId: _ironIngot, quantity: 2),
            RecipeIngredient(itemId: _leatherStrip, quantity: 0),
          ],
        ),
      ),
      (
        'ingredients[2].itemId',
        'Ingredient 3: the item is already an ingredient.',
        forgeDraft.copyWith(
          ingredients: [
            ...forgeDraft.ingredients,
            const RecipeIngredient(itemId: _ironIngot, quantity: 1),
          ],
        ),
      ),
      (
        'ingredients[0].itemId',
        'A recipe ingredient cannot be the same item as the output item.',
        forgeDraft.copyWith(
          ingredients: const [
            RecipeIngredient(itemId: _ironSword, quantity: 1),
            RecipeIngredient(itemId: _leatherStrip, quantity: 1),
          ],
        ),
      ),
      (
        'ingredients[0].itemId',
        'A recipe ingredient cannot be the same item as the output item.',
        forgeDraft.copyWith(outputItemId: _ironIngot),
      ),
    ].indexed) {
      test('with SaveBlocked, case $i: $path ($message)', () async {
        final draft = edit.copyWith(description: 'changed');
        expect(recipeSaveBlockers(draft), [SaveBlocker(path, message)]);
        await expectLater(
          repo.save(_forgeIronSword, draft),
          throwsA(
            isA<SaveBlocked>().having((e) => e.blockers, 'blockers', [message]),
          ),
        );
        expectUnchanged();
      });
    }

    test('with DuplicateExportKey naming the key', () async {
      await expectLater(
        repo.save(
          _forgeIronSword,
          forgeDraft.copyWith(exportKey: 'brew_healing_potion'),
        ),
        throwsA(
          isA<DuplicateExportKey>().having(
            (e) => e.exportKey,
            'key',
            'brew_healing_potion',
          ),
        ),
      );
      expectUnchanged();
    });

    test('with RecordNotFound for an unknown id', () async {
      await expectLater(
        repo.save(_unknown, forgeDraft.copyWith(exportKey: 'other')),
        throwsA(
          isA<RecordNotFound>()
              .having((e) => e.domain, 'domain', 'recipes')
              .having((e) => e.id, 'id', _unknown),
        ),
      );
      expectUnchanged();
    });
  });

  test('save of a soft-deleted recipe is RecordNotFound', () async {
    await repo.softDelete(_forgeIronSword);
    final rowBefore = recipeRow(_forgeIronSword);
    final historyBefore = historyCount();
    await expectLater(
      repo.save(_forgeIronSword, forgeDraft.copyWith(outputQuantity: 5)),
      throwsA(isA<RecordNotFound>().having((e) => e.id, 'id', _forgeIronSword)),
    );
    expect(recipeRow(_forgeIronSword), rowBefore);
    expect(ingredientRows(_forgeIronSword), hasLength(2));
    expect(historyCount(), historyBefore);
    // It still loads.
    expect(await repo.load(_forgeIronSword), forgeDraft);
  });

  test('RecordNotFound for an unknown id everywhere else', () async {
    final notFound = throwsA(
      isA<RecordNotFound>().having((e) => e.domain, 'domain', 'recipes'),
    );
    await expectLater(repo.get(_unknown), notFound);
    await expectLater(repo.load(_unknown), notFound);
    await expectLater(repo.duplicate(_unknown), notFound);
    await expectLater(repo.softDelete(_unknown), notFound);
    await expectLater(repo.restore(_unknown), notFound);
    await expectLater(repo.hardDelete(_unknown), notFound);
  });

  test('duplicate copies the recipe and its ingredients', () async {
    final before = historyCount();
    final copy = await repo.duplicate(_forgeIronSword);
    expect(copy.id, isNot(_forgeIronSword));
    expect(copy.displayName, 'Forge Iron Sword (Copy)');
    expect(
      copy.exportKey,
      matches(RegExp(r'^forge-iron-sword-copy-[0-9a-f]{8}$')),
    );
    expect(
      await repo.load(copy.id),
      forgeDraft.copyWith(
        displayName: 'Forge Iron Sword (Copy)',
        exportKey: copy.exportKey,
      ),
    );
    expect([for (final r in ingredientRows(copy.id)) r['sort_order']], [0, 1]);
    expect(historyCount(), before + 1);
    expect(latestHistory(), 'Forge Iron Sword (Copy) - Recipe duplicated');
  });

  test('soft delete, restore and hard delete', () async {
    await repo.softDelete(_forgeIronSword);
    expect(recipeRow(_forgeIronSword)['deleted_at'], isNotNull);
    expect(latestHistory(), 'Forge Iron Sword - Recipe deleted');
    expect(ingredientRows(_forgeIronSword), hasLength(2));

    await repo.restore(_forgeIronSword);
    expect(recipeRow(_forgeIronSword)['deleted_at'], isNull);
    expect(latestHistory(), 'Forge Iron Sword - Recipe restored');

    await repo.hardDelete(_forgeIronSword);
    expect(
      rows('SELECT * FROM recipes WHERE id = ?', [_forgeIronSword]),
      isEmpty,
    );
    expect(ingredientRows(_forgeIronSword), isEmpty);
    expect(latestHistory(), 'Forge Iron Sword - Recipe permanently deleted');
    expect(await repo.countActive(), 1);
  });
}

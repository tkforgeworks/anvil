import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_save_prototype/src/core/project_database.dart';
import 'package:recipe_save_prototype/src/core/recipe_draft.dart';
import 'package:recipe_save_prototype/src/core/recipe_repository.dart';
import 'package:recipe_save_prototype/src/core/sqlite_recipe_repository.dart';

import 'support/fixture.dart';

void main() {
  late FixtureCopy fixture;
  late SqliteRecipeRepository repo;
  late List<int> fixtureBytes;

  setUpAll(() => fixtureBytes = File(fixturePath).readAsBytesSync());

  setUp(() {
    fixture = FixtureCopy.open();
    repo = SqliteRecipeRepository(fixture.project);
  });

  tearDown(() {
    fixture.close();
    // The real file is never touched: only the copy is opened.
    expect(File(fixturePath).readAsBytesSync(), fixtureBytes);
  });

  group('AC1: opens a copy of a real .anvil file', () {
    test('the copy lives in a temp dir and is in WAL mode', () {
      expect(fixture.project.path, isNot(contains('test/fixtures')));
      expect(
        fixture.project.db.select('PRAGMA journal_mode').first.values.first,
        'wal',
      );
      expect(
        fixture.project.db.select('PRAGMA foreign_keys').first.values.first,
        1,
      );
    });

    test('lists the two fixture recipes', () async {
      final recipes = await repo.listRecipes();
      expect(recipes.map((r) => r.displayName), [
        'Brew Healing Potion',
        'Forge Iron Sword',
      ]);
    });

    test('loads Forge Iron Sword with its two ingredients in order', () async {
      final draft = await repo.loadRecipe(forgeIronSwordId);
      expect(draft.displayName, 'Forge Iron Sword');
      expect(draft.exportKey, 'forge_iron_sword');
      expect(draft.outputItemId, ironSwordId);
      expect(draft.craftingStationId, 'crafting-station-forge');
      expect(
        draft.craftingSpecializationId,
        'crafting-specialization-blacksmithing',
      );
      expect(draft.ingredients, const [
        IngredientLine(itemId: ironIngotId, quantity: 2),
        IngredientLine(itemId: leatherStripId, quantity: 1),
      ]);
    });

    test('lookups include the archived item flagged as archived', () async {
      final lookups = await repo.loadLookups();
      expect(lookups.items.where((i) => !i.archived), hasLength(5));
      expect(
        lookups.items.singleWhere((i) => i.archived).displayName,
        'Cursed Dagger',
      );
      expect(lookups.stations, hasLength(4));
      expect(lookups.specializations, hasLength(4));
    });
  });

  group('AC6: one transaction for recipe, ingredients and history', () {
    test('a save writes all three and returns the read-back draft', () async {
      final before = await repo.loadRecipe(forgeIronSwordId);
      final historyBefore = fixture.historyCount();
      final edited = before.copyWith(
        displayName: 'Forge Steel Sword',
        craftingSpecializationId: null,
        ingredients: [
          before.ingredients[1].copyWith(quantity: 3),
          before.ingredients[0],
          const IngredientLine(itemId: moonpetalHerbId, quantity: 1),
        ],
      );

      final persisted = await repo.saveRecipe(edited);

      expect(persisted, edited);
      expect(await repo.loadRecipe(forgeIronSwordId), edited);
      final row = fixture.snapshot(forgeIronSwordId);
      expect(
        (row['recipe'] as List).single,
        containsPair('display_name', 'Forge Steel Sword'),
      );
      expect(
        (row['ingredients'] as List).map((r) => (r as Map)['sort_order']),
        [0, 1, 2],
      );
      expect(fixture.historyCount(), historyBefore + 1);
      final latest = (await fixture.project.recentSaves(limit: 1)).single;
      expect(latest.description, "Recipe 'Forge Steel Sword' changed");
      expect(latest.isAutoSave, isFalse);
    });

    test('a forced failure before COMMIT rolls everything back', () async {
      final before = fixture.snapshot(forgeIronSwordId);
      final draft = await repo.loadRecipe(forgeIronSwordId);
      fixture.project.debugFailBeforeCommit = () => true;

      await expectLater(
        repo.saveRecipe(
          draft.copyWith(
            displayName: 'Never Written',
            ingredients: [draft.ingredients.first.copyWith(quantity: 9)],
          ),
        ),
        throwsA(isA<ForcedSaveFailure>()),
      );

      expect(fixture.snapshot(forgeIronSwordId), before);
      expect(
        fixture.project.db.autocommit,
        isTrue,
        reason: 'no open transaction',
      );
      // The connection is still usable for the next save.
      fixture.project.debugFailBeforeCommit = null;
      await repo.saveRecipe(draft.copyWith(displayName: 'Written'));
      expect(fixture.historyCount(), (before['historyCount'] as int) + 1);
    });

    test('a constraint failure mid-save rolls back the recipe row', () async {
      final before = fixture.snapshot(forgeIronSwordId);
      final draft = await repo.loadRecipe(forgeIronSwordId);

      // FK violation on the ingredient insert, after the UPDATE succeeded.
      await expectLater(
        repo.saveRecipe(
          draft.copyWith(
            displayName: 'Half Written',
            ingredients: const [
              IngredientLine(itemId: 'no-such-item', quantity: 1),
            ],
          ),
        ),
        throwsA(anything),
      );

      expect(fixture.snapshot(forgeIronSwordId), before);
    });
  });

  group('AC7: output used as ingredient', () {
    test('the repository refuses the save and writes nothing', () async {
      final before = fixture.snapshot(forgeIronSwordId);
      final draft = await repo.loadRecipe(forgeIronSwordId);

      await expectLater(
        repo.saveRecipe(
          draft.copyWith(
            ingredients: [
              ...draft.ingredients,
              IngredientLine(itemId: draft.outputItemId, quantity: 1),
            ],
          ),
        ),
        throwsA(isA<RecipeSaveBlocked>()),
      );

      expect(fixture.snapshot(forgeIronSwordId), before);
    });
  });
}

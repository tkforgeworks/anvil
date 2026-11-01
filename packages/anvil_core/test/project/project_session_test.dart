import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

import '../db/support/fixture_copy.dart';

void main() {
  final fixture = FixtureCopy.setUpEach();
  late ProjectService service;

  setUp(() {
    service = ProjectService(supportDirectory: fixture().pathFor('support'));
  });

  test('a session opened on the fixture has every repository, each working '
      'for one read', () async {
    final result = await service.open(fixture().copyFixture());
    final session = (result as ProjectOpened).session;

    expect(await session.classes.countActive(), 2);
    expect(await session.abilities.countActive(), 2);
    expect(await session.items.countActive(), 5);
    expect(await session.recipes.countActive(), 2);
    expect(await session.npcs.countActive(), 2);
    expect(await session.lootTables.countActive(), 1);
    expect(await session.meta.listStats(), hasLength(7));
    expect(
      await session.customFields.listDefinitions(
        CustomFieldScope.npcType,
        'npc-type-enemy',
      ),
      hasLength(1),
    );
    expect(await session.templates.list(), isA<List<CustomTemplate>>());
    expect(await session.saveHistory.recent(), hasLength(2));
    expect(
      await session.lifecycle.countDeleted(),
      const RecordCounts(abilities: 1, items: 1),
    );
    await service.close(session);
  });

  test('a created session has every repository on the new file', () async {
    final session = await service.create(
      projectName: 'Fresh',
      gameTitle: 'Saga',
      parentFolder: fixture().pathFor('projects'),
    );

    expect(await session.npcs.list(), isEmpty);
    expect(await session.lifecycle.weeklyDeltas(), RecordCounts.empty);
    final created = await session.items.create(
      const CreateItemInput(
        displayName: 'Stick',
        exportKey: 'stick',
        itemCategoryId: 'item-category-weapon',
        rarityId: 'rarity-common',
      ),
    );
    expect((await session.items.get(created.id)).displayName, 'Stick');
    expect([
      for (final e in await session.saveHistory.recent()) e.description,
    ], contains('Stick - Item created'));
    await service.close(session);
  });
}

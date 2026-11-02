import 'package:anvil/app/domains/items/items_editor_controller.dart';
import 'package:anvil/app/editor/editor_state.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../dialogs/fakes.dart' show copyFixture;

/// The fixture's ids: Iron Sword is a weapon, whose fields are `damage`
/// (integer, required) and `handedness` (enum, default `one-handed`), with
/// both values stored.
const ironSword = '6069c26a-d758-4981-b29b-eed2c95fe6f3';
const damage = '18790df6-c2dc-4597-b0b2-679b538d7729';
const handedness = 'd62cfe4d-504e-4a84-b15f-af0d0b90bb9d';
const consumable = 'item-category-consumable';

/// The item editor controller over the real repositories on a copy of the
/// 0.1.6 fixture.
void main() {
  late ProjectDatabase db;
  late SqliteItemRepository items;
  late SqliteSaveHistoryRepository history;
  late ProviderContainer container;

  setUp(() {
    db = ProjectDatabase.open(copyFixture());
    addTearDown(db.close);
    items = SqliteItemRepository(db);
    history = SqliteSaveHistoryRepository(db);
    container = ProviderContainer.test(
      overrides: [
        itemRepositoryProvider.overrideWithValue(items),
        customFieldRepositoryProvider.overrideWithValue(
          SqliteCustomFieldRepository(db),
        ),
      ],
      retry: (_, _) => null,
    );
  });

  Future<ItemEditorController> open(String id) async {
    final provider = itemsEditorProvider(id);
    container.listen(provider, (_, _) {});
    await container.read(provider.future);
    return container.read(provider.notifier);
  }

  /// A new active weapon with no custom field values.
  Future<String> newWeapon() async => (await items.create(
    const CreateItemInput(
      displayName: 'Bronze Axe',
      exportKey: 'bronze-axe',
      itemCategoryId: 'item-category-weapon',
      rarityId: 'rarity-common',
    ),
  )).id;

  EditorState<ItemDraft> state(String id) =>
      container.read(itemsEditorProvider(id)).requireValue;

  test('save writes the draft, its custom field values and one save history '
      'row in one transaction', () async {
    final axe = await newWeapon();
    final controller = await open(axe);
    // The default fills the empty enum field without dirtying the draft.
    expect(state(axe).draft.customFieldValues, {handedness: 'one-handed'});
    expect(state(axe).isDirty, isFalse);
    final before = await history.recent(limit: 50);

    controller.setCustomFieldValue(damage, '9', typing: true);
    controller.setDescription('  Hums at night.  ');
    final outcome = await controller.save();
    expect(state(axe).saveError, isNull);
    expect(outcome, SaveOutcome.saved);

    final after = await history.recent(limit: 50);
    expect(after.length, before.length + 1);
    expect(
      after.map((e) => e.description),
      contains('Bronze Axe - Item changed'),
    );
    expect(container.read(writeEpochProvider), 1);

    final stored = await items.load(axe);
    expect(stored.description, 'Hums at night.');
    expect(stored.customFieldValues, {damage: '9', handedness: 'one-handed'});
    expect(state(axe).isDirty, isFalse);
    expect(state(axe).draft, stored);
  });

  test('a category change drops the old category values in the draft and '
      'on disk, undoably until saved', () async {
    final controller = await open(ironSword);
    expect(state(ironSword).draft.customFieldValues, {
      damage: '14',
      handedness: 'one-handed',
    });

    await controller.setCategory(consumable);
    expect(state(ironSword).draft.itemCategoryId, consumable);
    expect(state(ironSword).draft.customFieldValues, isEmpty);
    controller.undo();
    expect(state(ironSword).draft.customFieldValues, hasLength(2));
    controller.redo();

    expect(await controller.save(), SaveOutcome.saved);
    final stored = await items.load(ironSword);
    expect(stored.itemCategoryId, consumable);
    expect(stored.customFieldValues, isEmpty);
  });

  test('a duplicate export key fails the save and keeps the draft', () async {
    final axe = await newWeapon();
    final controller = await open(axe);
    final sword = await items.get(ironSword);
    final before = await history.recent(limit: 50);

    controller.setExportKey(sword.exportKey);
    expect(await controller.save(), SaveOutcome.failed);
    expect(state(axe).saveError, contains(sword.exportKey));
    expect(state(axe).isDirty, isTrue);
    expect((await history.recent(limit: 50)).length, before.length);
  });
}

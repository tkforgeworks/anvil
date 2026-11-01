import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

ItemDraft _valid() => ItemDraft(
  displayName: 'Iron Sword',
  exportKey: 'iron_sword',
  itemCategoryId: 'item-category-weapon',
  rarityId: 'rarity-common',
  customFieldValues: {'f': null},
);

void main() {
  test('a complete draft has no blockers', () {
    expect(itemSaveBlockers(_valid()), isEmpty);
  });

  test('an empty or blank display name blocks', () {
    for (final name in ['', '   ']) {
      expect(itemSaveBlockers(_valid().copyWith(displayName: name)), [
        const SaveBlocker('displayName', 'Display name is required.'),
      ]);
    }
  });

  test('an empty or blank export key blocks', () {
    for (final key in ['', ' \t']) {
      expect(itemSaveBlockers(_valid().copyWith(exportKey: key)), [
        const SaveBlocker('exportKey', 'Export key is required.'),
      ]);
    }
  });

  test('an empty item category blocks', () {
    expect(itemSaveBlockers(_valid().copyWith(itemCategoryId: '')), [
      const SaveBlocker('itemCategoryId', 'Item category is required.'),
    ]);
  });

  test('an empty rarity blocks', () {
    expect(itemSaveBlockers(_valid().copyWith(rarityId: '')), [
      const SaveBlocker('rarityId', 'Rarity is required.'),
    ]);
  });

  test('every broken rule is reported, in field order', () {
    final draft = ItemDraft(
      displayName: '',
      exportKey: '',
      itemCategoryId: '',
      rarityId: '',
    );
    expect(
      [for (final b in itemSaveBlockers(draft)) b.field],
      ['displayName', 'exportKey', 'itemCategoryId', 'rarityId'],
    );
  });

  test('an unknown category id or empty custom field value is not a '
      'blocker', () {
    final draft = _valid().copyWith(
      itemCategoryId: 'no-such-category',
      customFieldValues: {'required-field': ''},
    );
    expect(itemSaveBlockers(draft), isEmpty);
  });
}

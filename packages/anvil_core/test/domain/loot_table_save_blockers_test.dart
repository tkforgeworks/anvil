import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

LootTableEntryDraft _entry({int weight = 10, int min = 1, int max = 1}) =>
    LootTableEntryDraft(
      itemId: 'ingot',
      weight: weight,
      quantityMin: min,
      quantityMax: max,
    );

LootTableDraft _valid([List<LootTableEntryDraft>? entries]) => LootTableDraft(
  displayName: 'Goblin Drops',
  exportKey: 'goblin_drops',
  entries:
      entries ??
      [
        _entry(weight: 60, max: 3),
        _entry(weight: 30),
        _entry(weight: 1, min: 2, max: 2),
      ],
);

void main() {
  test('a complete draft has no blockers', () {
    expect(lootTableSaveBlockers(_valid()), isEmpty);
    expect(lootTableSaveBlockers(_valid(const [])), isEmpty);
  });

  test('an empty or blank display name blocks', () {
    expect(lootTableSaveBlockers(_valid().copyWith(displayName: '  ')), [
      const SaveBlocker('displayName', 'Display name is required.'),
    ]);
  });

  test('an empty or blank export key blocks', () {
    expect(lootTableSaveBlockers(_valid().copyWith(exportKey: '')), [
      const SaveBlocker('exportKey', 'Export key is required.'),
    ]);
  });

  test('a weight below 1 blocks with its index', () {
    for (final w in [0, -1]) {
      expect(lootTableSaveBlockers(_valid([_entry(), _entry(weight: w)])), [
        const SaveBlocker(
          'entries[1].weight',
          'Entry 2: weight must be at least 1.',
        ),
      ]);
    }
  });

  test('a minimum quantity below 1 blocks', () {
    expect(lootTableSaveBlockers(_valid([_entry(min: 0, max: 0)])), [
      const SaveBlocker(
        'entries[0].quantityMin',
        'Entry 1: minimum quantity must be at least 1.',
      ),
    ]);
  });

  test('a maximum below the minimum blocks', () {
    expect(
      lootTableSaveBlockers(
        _valid([_entry(), _entry(), _entry(min: 3, max: 2)]),
      ),
      [
        const SaveBlocker(
          'entries[2].quantityMax',
          'Entry 3: maximum quantity cannot be less than the minimum.',
        ),
      ],
    );
  });

  test('every broken rule of an entry is reported', () {
    expect(
      [
        for (final b in lootTableSaveBlockers(
          _valid([_entry(weight: 0, min: 0, max: -1)]),
        ))
          b.field,
      ],
      ['entries[0].weight', 'entries[0].quantityMin', 'entries[0].quantityMax'],
    );
  });

  test('the same item in two entries and flags are not blockers', () {
    final draft = _valid([
      LootTableEntryDraft(
        itemId: 'ingot',
        weight: 1,
        conditionalFlags: {'boss_only': true},
      ),
      _entry(),
    ]);
    expect(lootTableSaveBlockers(draft), isEmpty);
  });
}

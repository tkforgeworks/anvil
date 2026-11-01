import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

import '../db/support/fixture_copy.dart';

const String _ironIngot = '11a74879-0851-4af7-8ff1-7be63edae9f2';
const String _ironSword = '6069c26a-d758-4981-b29b-eed2c95fe6f3';
const String _healingPotion = 'a4b66c54-05d2-4007-bed7-8f13bee1f087';

const String _goblinDrops = '1e11b296-71a9-4976-887b-d0f32e25becb';
const String _goblinRaider = '9516c484-83f0-488a-a9d5-a7ce0f006d7f';
const String _unknown = '00000000-0000-4000-8000-000000000000';

const String _fixtureTime = '2026-10-31 20:58:16';

void main() {
  final fixture = FixtureCopy.setUpEach();

  late ProjectDatabase db;
  late LootTableRepository repo;

  setUp(() {
    db = fixture().openFixture();
    repo = SqliteLootTableRepository(db);
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

  Map<String, Object?> tableRow(String id) =>
      rows('SELECT * FROM loot_tables WHERE id = ?', [id]).single;

  List<Map<String, Object?>> entryRows(String id) => rows(
    'SELECT * FROM loot_table_entries WHERE loot_table_id = ? '
    'ORDER BY sort_order',
    [id],
  );

  Map<String, Object?> without(Map<String, Object?> row, String column) =>
      {...row}..remove(column);

  void setUpSql(String sql, [List<Object?> parameters = const []]) =>
      db.saveTransaction('test setup', (tx) => tx.execute(sql, parameters));

  final goblinDraft = LootTableDraft(
    displayName: 'Goblin Drops',
    exportKey: 'goblin_drops',
    description: 'What goblins carry',
    entries: [
      LootTableEntryDraft(
        itemId: _ironIngot,
        weight: 60,
        quantityMin: 1,
        quantityMax: 3,
      ),
      LootTableEntryDraft(itemId: _healingPotion, weight: 30),
      LootTableEntryDraft(
        itemId: _ironSword,
        weight: 10,
        conditionalFlags: {'boss_only': true},
      ),
    ],
  );

  test('load reads the fixture loot table with entries in order', () async {
    final draft = await repo.load(_goblinDrops);
    expect(draft, goblinDraft);
    expect(draft.entries.last.conditionalFlags, {'boss_only': true});
    expect(draft.entries.first.conditionalFlags, isEmpty);
  });

  test('get returns the row', () async {
    final table = await repo.get(_goblinDrops);
    expect(table.displayName, 'Goblin Drops');
    expect(table.exportKey, 'goblin_drops');
    expect(table.description, 'What goblins carry');
    expect(table.createdAt, _fixtureTime);
    expect(table.updatedAt, _fixtureTime);
    expect(table.deletedAt, isNull);
  });

  test('list modes and countActive, before and after a soft delete', () async {
    final second = await repo.create(
      const CreateLootTableInput(displayName: 'boss chest', exportKey: 'boss'),
    );
    Future<List<String>> names(RecordListMode mode) async => [
      for (final r in await repo.list(mode: mode)) r.displayName,
    ];

    expect(await names(RecordListMode.active), ['boss chest', 'Goblin Drops']);
    expect(await names(RecordListMode.deletedOnly), isEmpty);
    expect(await names(RecordListMode.all), ['boss chest', 'Goblin Drops']);
    expect(await repo.countActive(), 2);

    await repo.softDelete(second.id);
    expect(
      [for (final r in await repo.list()) r.displayName],
      ['Goblin Drops'],
    );
    expect(await names(RecordListMode.deletedOnly), ['boss chest']);
    expect(await names(RecordListMode.all), ['boss chest', 'Goblin Drops']);
    expect(await repo.countActive(), 1);
  });

  test('save(id, load(id)) changes only updated_at and the entry ids, and '
      'adds one history row', () async {
    final before = tableRow(_goblinDrops);
    final entriesBefore = entryRows(_goblinDrops);
    final historyBefore = historyCount();
    final draft = await repo.load(_goblinDrops);

    expect(await repo.save(_goblinDrops, draft), draft);

    expect(
      without(tableRow(_goblinDrops), 'updated_at'),
      without(before, 'updated_at'),
    );
    expect(tableRow(_goblinDrops)['updated_at'], isNot(_fixtureTime));
    final entriesAfter = entryRows(_goblinDrops);
    expect(
      [for (final r in entriesAfter) without(r, 'id')],
      [for (final r in entriesBefore) without(r, 'id')],
    );
    // The flags text is byte-identical to what 0.1.6 wrote.
    expect(
      [for (final r in entriesAfter) r['conditional_flags']],
      ['{}', '{}', '{"boss_only":true}'],
    );
    // Every entry row gets a new id on save, as in 0.1.6.
    final oldIds = {for (final r in entriesBefore) r['id']};
    for (final r in entriesAfter) {
      expect(oldIds, isNot(contains(r['id'])));
      expect(r['id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
    }
    expect(historyCount(), historyBefore + 1);
    expect(latestHistory(), 'Goblin Drops - Loot Table changed');
  });

  test('create inserts a loot table with no entries', () async {
    final before = historyCount();
    final created = await repo.create(
      const CreateLootTableInput(
        displayName: 'Chest',
        exportKey: 'chest',
        description: 'Wooden.',
      ),
    );
    expect(created.id, hasLength(36));
    expect(
      await repo.load(created.id),
      LootTableDraft(
        displayName: 'Chest',
        exportKey: 'chest',
        description: 'Wooden.',
      ),
    );
    expect(historyCount(), before + 1);
    expect(latestHistory(), 'Chest - Loot Table created');
    await expectLater(
      repo.create(
        const CreateLootTableInput(displayName: 'Y', exportKey: 'chest'),
      ),
      throwsA(
        isA<DuplicateExportKey>().having((e) => e.exportKey, 'key', 'chest'),
      ),
    );
  });

  test('save writes changed fields and reordered, edited entries', () async {
    final draft = goblinDraft.copyWith(
      displayName: 'Goblin Loot',
      exportKey: 'goblin_loot',
      entries: [
        goblinDraft.entries[2].copyWith(
          weight: 15,
          conditionalFlags: {
            'boss_only': false,
            'tags': ['rare', 2.5],
            'nested': {'level': 3},
          },
        ),
        goblinDraft.entries[0].copyWith(quantityMin: 2, quantityMax: 2),
        LootTableEntryDraft(itemId: _ironIngot, weight: 5, quantityMax: 9),
      ],
    );

    expect(await repo.save(_goblinDrops, draft), draft);
    expect(await repo.load(_goblinDrops), draft);

    expect(tableRow(_goblinDrops)['display_name'], 'Goblin Loot');
    expect(
      [
        for (final r in entryRows(_goblinDrops))
          [
            r['item_id'],
            r['weight'],
            r['quantity_min'],
            r['quantity_max'],
            r['conditional_flags'],
            r['sort_order'],
          ],
      ],
      [
        [
          _ironSword,
          15,
          1,
          1,
          '{"boss_only":false,"tags":["rare",2.5],"nested":{"level":3}}',
          0,
        ],
        [_ironIngot, 60, 2, 2, '{}', 1],
        [_ironIngot, 5, 1, 9, '{}', 2],
      ],
    );
    expect(latestHistory(), 'Goblin Loot - Loot Table changed');
  });

  group('save is refused', () {
    late Map<String, Object?> rowBefore;
    late List<Map<String, Object?>> entriesBefore;
    late int historyBefore;

    setUp(() {
      rowBefore = tableRow(_goblinDrops);
      entriesBefore = entryRows(_goblinDrops);
      historyBefore = historyCount();
    });

    void expectUnchanged() {
      expect(tableRow(_goblinDrops), rowBefore);
      expect(entryRows(_goblinDrops), entriesBefore);
      expect(historyCount(), historyBefore);
    }

    List<LootTableEntryDraft> withEntry(int i, LootTableEntryDraft entry) =>
        [...goblinDraft.entries]..[i] = entry;

    for (final (path, message, draft) in <(String, String, LootTableDraft)>[
      (
        'displayName',
        'Display name is required.',
        goblinDraft.copyWith(displayName: ''),
      ),
      (
        'exportKey',
        'Export key is required.',
        goblinDraft.copyWith(exportKey: '  '),
      ),
      (
        'entries[1].weight',
        'Entry 2: weight must be at least 1.',
        goblinDraft.copyWith(
          entries: withEntry(1, goblinDraft.entries[1].copyWith(weight: 0)),
        ),
      ),
      (
        'entries[0].quantityMin',
        'Entry 1: minimum quantity must be at least 1.',
        goblinDraft.copyWith(
          entries: withEntry(
            0,
            goblinDraft.entries[0].copyWith(quantityMin: 0),
          ),
        ),
      ),
      (
        'entries[2].quantityMax',
        'Entry 3: maximum quantity cannot be less than the minimum.',
        goblinDraft.copyWith(
          entries: withEntry(
            2,
            goblinDraft.entries[2].copyWith(quantityMin: 4, quantityMax: 3),
          ),
        ),
      ),
    ]) {
      test('with SaveBlocked, not clamped: $path', () async {
        expect(lootTableSaveBlockers(draft), [SaveBlocker(path, message)]);
        await expectLater(
          repo.save(_goblinDrops, draft),
          throwsA(
            isA<SaveBlocked>().having((e) => e.blockers, 'blockers', [message]),
          ),
        );
        expectUnchanged();
      });
    }

    test('with DuplicateExportKey naming the key', () async {
      await repo.create(
        const CreateLootTableInput(displayName: 'Other', exportKey: 'other'),
      );
      historyBefore = historyCount();
      await expectLater(
        repo.save(_goblinDrops, goblinDraft.copyWith(exportKey: 'other')),
        throwsA(
          isA<DuplicateExportKey>().having((e) => e.exportKey, 'key', 'other'),
        ),
      );
      expectUnchanged();
    });

    test('with RecordNotFound for a soft-deleted or unknown id', () async {
      await expectLater(
        repo.save(_unknown, goblinDraft.copyWith(exportKey: 'fresh')),
        throwsA(
          isA<RecordNotFound>()
              .having((e) => e.domain, 'domain', 'loot_tables')
              .having((e) => e.id, 'id', _unknown),
        ),
      );
      expectUnchanged();

      await repo.softDelete(_goblinDrops);
      final deletedRow = tableRow(_goblinDrops);
      final count = historyCount();
      await expectLater(
        repo.save(_goblinDrops, goblinDraft.copyWith(description: 'x')),
        throwsA(isA<RecordNotFound>().having((e) => e.id, 'id', _goblinDrops)),
      );
      expect(tableRow(_goblinDrops), deletedRow);
      expect(entryRows(_goblinDrops), entriesBefore);
      expect(historyCount(), count);
      expect(await repo.load(_goblinDrops), goblinDraft);
    });
  });

  test('RecordNotFound for an unknown id everywhere else', () async {
    final notFound = throwsA(
      isA<RecordNotFound>().having((e) => e.domain, 'domain', 'loot_tables'),
    );
    await expectLater(repo.get(_unknown), notFound);
    await expectLater(repo.load(_unknown), notFound);
    await expectLater(repo.duplicate(_unknown), notFound);
    await expectLater(repo.softDelete(_unknown), notFound);
    await expectLater(repo.restore(_unknown), notFound);
    await expectLater(repo.hardDelete(_unknown), notFound);
  });

  test('duplicate copies the table and its entries with new ids', () async {
    final before = historyCount();
    final copy = await repo.duplicate(_goblinDrops);
    expect(copy.displayName, 'Goblin Drops (Copy)');
    // 0.1.6 used the plain slug `goblin-drops-copy`; 0.2.0 adds the suffix.
    expect(copy.exportKey, matches(RegExp(r'^goblin-drops-copy-[0-9a-f]{8}$')));
    expect(
      await repo.load(copy.id),
      goblinDraft.copyWith(
        displayName: 'Goblin Drops (Copy)',
        exportKey: copy.exportKey,
      ),
    );
    final sourceIds = {for (final r in entryRows(_goblinDrops)) r['id']};
    final copyEntries = entryRows(copy.id);
    expect(copyEntries, hasLength(3));
    for (final r in copyEntries) {
      expect(sourceIds, isNot(contains(r['id'])));
    }
    expect(copyEntries.last['conditional_flags'], '{"boss_only":true}');
    expect(historyCount(), before + 1);
    expect(latestHistory(), 'Goblin Drops (Copy) - Loot Table duplicated');
  });

  test('soft delete, restore and hard delete', () async {
    final copy = await repo.duplicate(_goblinDrops);

    await repo.softDelete(copy.id);
    expect(tableRow(copy.id)['deleted_at'], isNotNull);
    expect(entryRows(copy.id), hasLength(3));
    expect(latestHistory(), 'Goblin Drops (Copy) - Loot Table deleted');

    await repo.restore(copy.id);
    expect(tableRow(copy.id)['deleted_at'], isNull);
    expect(latestHistory(), 'Goblin Drops (Copy) - Loot Table restored');

    await repo.hardDelete(copy.id);
    expect(rows('SELECT * FROM loot_tables WHERE id = ?', [copy.id]), isEmpty);
    expect(entryRows(copy.id), isEmpty);
    expect(
      latestHistory(),
      'Goblin Drops (Copy) - Loot Table permanently deleted',
    );
  });

  test('hard delete of a table an NPC drops from fails as SaveFailed and '
      'changes nothing', () async {
    final before = historyCount();
    await expectLater(
      repo.hardDelete(_goblinDrops),
      throwsA(isA<SaveFailed>()),
    );
    expect(entryRows(_goblinDrops), hasLength(3));
    expect(historyCount(), before);
  });

  test('usedBy lists the active NPCs that drop from the table', () async {
    expect(await repo.usedBy(_goblinDrops), [
      const UsedByRef(_goblinRaider, 'Goblin Raider'),
    ]);
    expect(await repo.usedBy(_unknown), isEmpty);

    setUpSql("UPDATE npcs SET deleted_at = datetime('now') WHERE id = ?", [
      _goblinRaider,
    ]);
    expect(await repo.usedBy(_goblinDrops), isEmpty);
  });
}

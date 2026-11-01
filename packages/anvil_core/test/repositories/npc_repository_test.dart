import 'dart:convert';
import 'dart:io';

import 'package:anvil_core/anvil_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../db/support/fixture_copy.dart';

const String _goblin = '9516c484-83f0-488a-a9d5-a7ce0f006d7f';
const String _marla = '1fdfd4c3-bf59-405d-9a77-f4ad056d82b4';
const String _unknown = '00000000-0000-4000-8000-000000000000';

const String _warrior = '8cb0cf2e-a3f2-47ad-ad82-158dc9eb3d8a';
const String _mage = 'a7b87a4c-f898-4ebd-bfca-a8163101fc77';
const String _slash = 'a41d8d54-0a88-49c8-b53a-0cb21ef14f6a';
const String _fireball = '4e5b5a67-ba0b-43b2-bdfa-3bd426f83c7e';
const String _goblinDrops = '1e11b296-71a9-4976-887b-d0f32e25becb';

const String _aggression = '3789fc46-bc57-4677-ad44-73d9b334788f';
const String _damage = '18790df6-c2dc-4597-b0b2-679b538d7729';

/// A merchant-scoped field the tests add.
const String _haggle = 'test-field-haggle';

const String _enemy = 'npc-type-enemy';
const String _merchant = 'npc-type-merchant';

const String _fixtureTime = '2026-10-31 20:58:16';

/// The three tables an NPC owns rows in, keyed by their NPC column.
const Map<String, String> _owned = {
  'npc_class_assignments': 'npc_id',
  'npc_ability_assignments': 'npc_id',
  'custom_field_values': 'record_id',
};

void main() {
  final fixture = FixtureCopy.setUpEach();

  late ProjectDatabase db;
  late NpcRepository repo;

  setUp(() {
    db = fixture().openFixture();
    repo = SqliteNpcRepository(db);
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

  Map<String, Object?> npcRow(String id) =>
      rows('SELECT * FROM npcs WHERE id = ?', [id]).single;

  List<Map<String, Object?>> valueRows(String id) => rows(
    "SELECT * FROM custom_field_values WHERE domain = 'npcs' "
    'AND record_id = ? ORDER BY field_definition_id',
    [id],
  );

  /// The NPC's owned rows without the value rows' `updated_at`.
  Map<String, List<Map<String, Object?>>> ownedRows(String id) => {
    for (final MapEntry(key: table, value: column) in _owned.entries)
      table: [
        for (final r in rows(
          'SELECT * FROM $table WHERE $column = ? ORDER BY rowid',
          [id],
        ))
          {...r}..remove('updated_at'),
      ],
  };

  Map<String, Object?> without(Map<String, Object?> row, String column) =>
      {...row}..remove(column);

  /// Runs raw SQL as test setup (bypassing the repository's rules).
  void setUpSql(String sql, [List<Object?> parameters = const []]) =>
      db.saveTransaction('test setup', (tx) => tx.execute(sql, parameters));

  void addMerchantField() => setUpSql(
    'INSERT INTO custom_field_definitions (id, scope_type, scope_id, '
    "field_name, field_type) VALUES (?, 'npc_type', ?, 'haggle', 'text')",
    [_haggle, _merchant],
  );

  test('load matches context-full.json for both fixture NPCs', () async {
    final context = jsonDecode(
      File(p.join(fixturesDir, 'context-full.json')).readAsStringSync(),
    ) as Map<String, Object?>;
    // The context keys custom fields by name.
    const fieldIds = {'aggression': _aggression};
    final npcs = (context['npcs'] as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(npcs, hasLength(2));
    for (final npc in npcs) {
      final classes = (npc['class_assignments'] as List<Object?>)
          .cast<Map<String, Object?>>();
      final abilities = (npc['ability_assignments'] as List<Object?>)
          .cast<Map<String, Object?>>();
      final draft = await repo.load(npc['id'] as String);
      expect(
        draft,
        NpcDraft(
          displayName: npc['display_name'] as String,
          exportKey: npc['export_key'] as String,
          description: npc['description'] as String,
          npcTypeId: npc['npc_type_id'] as String,
          lootTableId: npc['loot_table_id'] as String?,
          combatStats: {
            for (final e
                in (npc['combat_stats'] as Map<String, Object?>).entries)
              e.key: (e.value as num).toDouble(),
          },
          classAssignments: [
            for (final c in classes)
              NpcClassAssignment(
                classId: c['class_id'] as String,
                level: c['level'] as int,
              ),
          ],
          abilityIds: [for (final a in abilities) a['ability_id'] as String],
          customFieldValues: {
            for (final e
                in (npc['custom_fields'] as Map<String, Object?>).entries)
              fieldIds[e.key]!: e.value as String?,
          },
        ),
      );
      // The stored key order is kept.
      expect(
        draft.combatStats.keys,
        (npc['combat_stats'] as Map<String, Object?>).keys,
      );
    }
  });

  test('load reads the fixture NPCs in detail', () async {
    expect(
      await repo.load(_goblin),
      NpcDraft(
        displayName: 'Goblin Raider',
        exportKey: 'goblin_raider',
        description: 'Small, mean, numerous',
        npcTypeId: _enemy,
        lootTableId: _goblinDrops,
        combatStats: const {'hp': 35, 'armor': 2},
        classAssignments: const [
          NpcClassAssignment(classId: _warrior, level: 3),
        ],
        abilityIds: const [_slash],
        customFieldValues: const {_aggression: 'hostile'},
      ),
    );
    expect(
      await repo.load(_marla),
      NpcDraft(
        displayName: 'Marla the Merchant',
        exportKey: 'marla_merchant',
        npcTypeId: _merchant,
        combatStats: const {'hp': 20},
        classAssignments: const [
          NpcClassAssignment(classId: _mage, level: 2),
          NpcClassAssignment(classId: _warrior, level: 1),
        ],
      ),
    );
  });

  test('get returns the row, soft-deleted or not', () async {
    final goblin = await repo.get(_goblin);
    expect(goblin.id, _goblin);
    expect(goblin.displayName, 'Goblin Raider');
    expect(goblin.exportKey, 'goblin_raider');
    expect(goblin.description, 'Small, mean, numerous');
    expect(goblin.npcTypeId, _enemy);
    expect(goblin.lootTableId, _goblinDrops);
    expect(goblin.combatStats, {'hp': 35.0, 'armor': 2.0});
    expect(goblin.createdAt, _fixtureTime);
    expect(goblin.updatedAt, _fixtureTime);
    expect(goblin.deletedAt, isNull);
    expect((await repo.get(_marla)).lootTableId, isNull);

    await repo.softDelete(_marla);
    expect((await repo.get(_marla)).deletedAt, isNotNull);
  });

  test('list modes and countActive, before and after a soft delete', () async {
    Future<List<String>> names(RecordListMode mode) async => [
      for (final r in await repo.list(mode: mode)) r.displayName,
    ];

    expect(await names(RecordListMode.active), [
      'Goblin Raider',
      'Marla the Merchant',
    ]);
    expect([
      for (final r in await repo.list()) r.displayName,
    ], await names(RecordListMode.active));
    expect(await names(RecordListMode.deletedOnly), isEmpty);
    expect(await names(RecordListMode.all), hasLength(2));
    expect(await repo.countActive(), 2);

    await repo.softDelete(_goblin);
    expect(await names(RecordListMode.active), ['Marla the Merchant']);
    expect(await names(RecordListMode.deletedOnly), ['Goblin Raider']);
    expect(await names(RecordListMode.all), [
      'Goblin Raider',
      'Marla the Merchant',
    ]);
    expect(await repo.countActive(), 1);
  });

  test('list orders by display name ignoring case', () async {
    await repo.create(
      CreateNpcInput(
        displayName: 'goblin Archer',
        exportKey: 'goblin_archer',
        npcTypeId: _enemy,
      ),
    );
    expect(
      [for (final r in await repo.list()) r.displayName],
      ['goblin Archer', 'Goblin Raider', 'Marla the Merchant'],
    );
  });

  test('save(id, load(id)) changes only updated_at and adds one history '
      'row', () async {
    for (final id in [_goblin, _marla]) {
      final before = npcRow(id);
      final ownedBefore = ownedRows(id);
      final historyBefore = historyCount();
      final draft = await repo.load(id);

      expect(await repo.save(id, draft), draft);

      // combat_stats_json is rewritten byte for byte, as JSON.stringify.
      expect(without(npcRow(id), 'updated_at'), without(before, 'updated_at'));
      expect(npcRow(id)['updated_at'], isNot(_fixtureTime));
      expect(ownedRows(id), ownedBefore);
      expect(historyCount(), historyBefore + 1);
      expect(latestHistory(), '${draft.displayName} - NPC changed');
    }
    expect(npcRow(_goblin)['combat_stats_json'], '{"hp":35,"armor":2}');
  });

  test('create inserts an NPC with no assignments or values', () async {
    final before = historyCount();
    final created = await repo.create(
      CreateNpcInput(
        displayName: 'Bandit',
        exportKey: 'bandit',
        description: 'Roadside.',
        npcTypeId: _enemy,
        lootTableId: _goblinDrops,
        combatStats: const {'hp': 12.5, 'armor': null},
      ),
    );
    expect(created.id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4')));
    expect(created.id, hasLength(36));
    expect(created.displayName, 'Bandit');
    expect(created.lootTableId, _goblinDrops);
    expect(created.combatStats, {'hp': 12.5, 'armor': null});
    expect(created.deletedAt, isNull);
    expect(npcRow(created.id)['combat_stats_json'], '{"hp":12.5,"armor":null}');
    expect(
      await repo.load(created.id),
      NpcDraft(
        displayName: 'Bandit',
        exportKey: 'bandit',
        description: 'Roadside.',
        npcTypeId: _enemy,
        lootTableId: _goblinDrops,
        combatStats: const {'hp': 12.5, 'armor': null},
      ),
    );
    expect(historyCount(), before + 1);
    expect(latestHistory(), 'Bandit - NPC created');

    final plain = await repo.create(
      CreateNpcInput(
        displayName: 'Plain',
        exportKey: 'plain',
        npcTypeId: _enemy,
      ),
    );
    expect(npcRow(plain.id)['combat_stats_json'], '{}');
    expect(npcRow(plain.id)['description'], '');
  });

  test('create refuses a used export key with the key', () async {
    await repo.softDelete(_marla);
    final before = historyCount();
    for (final key in ['goblin_raider', 'marla_merchant']) {
      await expectLater(
        repo.create(
          CreateNpcInput(displayName: 'X', exportKey: key, npcTypeId: _enemy),
        ),
        throwsA(
          isA<DuplicateExportKey>().having((e) => e.exportKey, 'key', key),
        ),
      );
    }
    expect(historyCount(), before);
  });

  test('save writes every field and replaces the assignments in '
      'order', () async {
    final draft = (await repo.load(_marla)).copyWith(
      displayName: 'Marla the Wise',
      exportKey: 'marla_wise',
      description: 'Older now.',
      lootTableId: _goblinDrops,
      combatStats: {'armor': 4, 'hp': 22.5},
      classAssignments: const [
        NpcClassAssignment(classId: _warrior, level: 7),
        NpcClassAssignment(classId: _mage, level: 2),
      ],
      abilityIds: [_fireball, _slash],
    );

    final saved = await repo.save(_marla, draft);

    expect(saved, draft);
    expect(await repo.load(_marla), draft);
    final row = npcRow(_marla);
    expect(row['display_name'], 'Marla the Wise');
    expect(row['export_key'], 'marla_wise');
    expect(row['description'], 'Older now.');
    expect(row['loot_table_id'], _goblinDrops);
    expect(row['combat_stats_json'], '{"armor":4,"hp":22.5}');
    expect(row['created_at'], _fixtureTime);
    expect(
      rows(
        'SELECT class_id, level, sort_order FROM npc_class_assignments '
        'WHERE npc_id = ? ORDER BY sort_order',
        [_marla],
      ),
      [
        {'class_id': _warrior, 'level': 7, 'sort_order': 0},
        {'class_id': _mage, 'level': 2, 'sort_order': 1},
      ],
    );
    expect(
      rows(
        'SELECT ability_id, sort_order FROM npc_ability_assignments '
        'WHERE npc_id = ? ORDER BY sort_order',
        [_marla],
      ),
      [
        {'ability_id': _fireball, 'sort_order': 0},
        {'ability_id': _slash, 'sort_order': 1},
      ],
    );
    expect(latestHistory(), 'Marla the Wise - NPC changed');

    // Clearing the loot table and every list.
    final cleared = draft.copyWith(
      lootTableId: null,
      combatStats: const {},
      classAssignments: const [],
      abilityIds: const [],
    );
    expect(await repo.save(_marla, cleared), cleared);
    expect(npcRow(_marla)['loot_table_id'], isNull);
    expect(npcRow(_marla)['combat_stats_json'], '{}');
    expect(ownedRows(_marla).values.every((r) => r.isEmpty), isTrue);
  });

  test('save writes a changed and a cleared custom field value', () async {
    final draft = (await repo.load(_goblin))
        .copyWith(customFieldValues: {_aggression: null});
    expect(await repo.save(_goblin, draft), draft);
    expect(valueRows(_goblin).single['value'], isNull);

    final changed = draft.copyWith(customFieldValues: {_aggression: 'wary'});
    expect(await repo.save(_goblin, changed), changed);
    expect(valueRows(_goblin).single['value'], 'wary');

    final dropped = draft.copyWith(customFieldValues: const {});
    expect(await repo.save(_goblin, dropped), dropped);
    expect(valueRows(_goblin), isEmpty);
  });

  test('save keeps values outside the type when the type is unchanged, as '
      '0.1.6 setCustomFieldValues did', () async {
    final draft = (await repo.load(_goblin))
        .copyWith(customFieldValues: {_aggression: 'hostile', _damage: '3'});
    expect(await repo.save(_goblin, draft), draft);
    expect(valueRows(_goblin), hasLength(2));
  });

  test('a type change drops values of fields outside the new type', () async {
    addMerchantField();
    final draft = (await repo.load(_goblin)).copyWith(
      npcTypeId: _merchant,
      customFieldValues: {_aggression: 'hostile', _haggle: 'yes'},
    );
    final saved = await repo.save(_goblin, draft);
    expect(saved.npcTypeId, _merchant);
    expect(saved.customFieldValues, {_haggle: 'yes'});
    expect(
      [for (final r in valueRows(_goblin)) r['field_definition_id']],
      [_haggle],
    );
  });

  group('save is refused', () {
    late Map<String, Object?> rowBefore;
    late Map<String, List<Map<String, Object?>>> ownedBefore;
    late int historyBefore;

    setUp(() {
      rowBefore = npcRow(_goblin);
      ownedBefore = ownedRows(_goblin);
      historyBefore = historyCount();
    });

    void expectUnchanged() {
      expect(npcRow(_goblin), rowBefore);
      expect(ownedRows(_goblin), ownedBefore);
      expect(historyCount(), historyBefore);
    }

    for (final (field, edit) in <(String, NpcDraft Function(NpcDraft))>[
      ('displayName', (d) => d.copyWith(displayName: '  ')),
      ('exportKey', (d) => d.copyWith(exportKey: '')),
      ('npcTypeId', (d) => d.copyWith(npcTypeId: '')),
      (
        'classAssignments[0].level',
        (d) => d.copyWith(
          classAssignments: const [
            NpcClassAssignment(classId: _warrior, level: 0),
          ],
        ),
      ),
      (
        'classAssignments[1].classId',
        (d) => d.copyWith(
          classAssignments: const [
            NpcClassAssignment(classId: _warrior, level: 3),
            NpcClassAssignment(classId: _warrior, level: 4),
          ],
        ),
      ),
      ('abilityIds[1]', (d) => d.copyWith(abilityIds: [_slash, _slash])),
    ]) {
      test('with SaveBlocked for $field', () async {
        final draft = edit(
          (await repo.load(_goblin)).copyWith(description: 'changed'),
        );
        final blockers = npcSaveBlockers(draft);
        expect([for (final b in blockers) b.field], [field]);
        await expectLater(
          repo.save(_goblin, draft),
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
      await repo.softDelete(_marla);
      historyBefore = historyCount();
      final draft = (await repo.load(_goblin))
          .copyWith(exportKey: 'marla_merchant');
      await expectLater(
        repo.save(_goblin, draft),
        throwsA(
          isA<DuplicateExportKey>().having(
            (e) => e.exportKey,
            'key',
            'marla_merchant',
          ),
        ),
      );
      expectUnchanged();
    });

    test('with RecordNotFound for a soft-deleted or unknown id', () async {
      await repo.softDelete(_marla);
      historyBefore = historyCount();
      final draft = await repo.load(_marla);
      final marlaBefore = npcRow(_marla);
      await expectLater(
        repo.save(_marla, draft),
        throwsA(
          isA<RecordNotFound>()
              .having((e) => e.domain, 'domain', 'npcs')
              .having((e) => e.id, 'id', _marla),
        ),
      );
      expect(npcRow(_marla), marlaBefore);
      await expectLater(
        repo.save(_unknown, draft.copyWith(exportKey: 'fresh_key')),
        throwsA(isA<RecordNotFound>()),
      );
      expectUnchanged();
    });

    test('with SaveFailed for a class SQLite does not know, rolling back '
        'the row', () async {
      final draft = (await repo.load(_goblin)).copyWith(
        displayName: 'Renamed',
        classAssignments: const [
          NpcClassAssignment(classId: 'no-such-class', level: 1),
        ],
      );
      await expectLater(repo.save(_goblin, draft), throwsA(isA<SaveFailed>()));
      expectUnchanged();
    });
  });

  test('RecordNotFound for an unknown id everywhere else', () async {
    final notFound = throwsA(
      isA<RecordNotFound>()
          .having((e) => e.domain, 'domain', 'npcs')
          .having((e) => e.id, 'id', _unknown),
    );
    final before = historyCount();
    await expectLater(repo.get(_unknown), notFound);
    await expectLater(repo.load(_unknown), notFound);
    await expectLater(repo.duplicate(_unknown), notFound);
    await expectLater(repo.softDelete(_unknown), notFound);
    await expectLater(repo.restore(_unknown), notFound);
    await expectLater(repo.hardDelete(_unknown), notFound);
    await expectLater(repo.inheritedStatBlock(_unknown), notFound);
    expect(historyCount(), before);
  });

  test('duplicate copies the NPC, its assignments and its type-scoped '
      'values', () async {
    // A value of a field outside the enemy type, which the copy leaves out.
    await repo.save(
      _goblin,
      (await repo.load(_goblin))
          .copyWith(customFieldValues: {_aggression: 'hostile', _damage: '9'}),
    );
    await repo.save(
      _goblin,
      (await repo.load(_goblin)).copyWith(abilityIds: [_slash, _fireball]),
    );
    final before = historyCount();

    final copy = await repo.duplicate(_goblin);

    expect(copy.id, isNot(_goblin));
    expect(copy.displayName, 'Goblin Raider (Copy)');
    expect(
      copy.exportKey,
      matches(RegExp(r'^goblin-raider-copy-[0-9a-f]{8}$')),
    );
    expect(copy.deletedAt, isNull);
    expect(npcRow(copy.id)['combat_stats_json'], '{"hp":35,"armor":2}');
    expect(
      await repo.load(copy.id),
      NpcDraft(
        displayName: 'Goblin Raider (Copy)',
        exportKey: copy.exportKey,
        description: 'Small, mean, numerous',
        npcTypeId: _enemy,
        lootTableId: _goblinDrops,
        combatStats: const {'hp': 35, 'armor': 2},
        classAssignments: const [
          NpcClassAssignment(classId: _warrior, level: 3),
        ],
        abilityIds: const [_slash, _fireball],
        customFieldValues: const {_aggression: 'hostile'},
      ),
    );
    expect(historyCount(), before + 1);
    expect(latestHistory(), 'Goblin Raider (Copy) - NPC duplicated');

    final second = await repo.duplicate(_goblin);
    expect(second.exportKey, isNot(copy.exportKey));
  });

  test('soft delete and restore', () async {
    await repo.softDelete(_goblin);
    var row = npcRow(_goblin);
    expect(row['deleted_at'], isNotNull);
    expect(row['updated_at'], isNot(_fixtureTime));
    expect(latestHistory(), 'Goblin Raider - NPC deleted');
    // Assignments and values stay with a soft-deleted NPC.
    expect(ownedRows(_goblin).values.every((r) => r.length == 1), isTrue);

    await repo.restore(_goblin);
    row = npcRow(_goblin);
    expect(row['deleted_at'], isNull);
    expect(latestHistory(), 'Goblin Raider - NPC restored');
  });

  test('soft deleting a deleted NPC keeps its deleted_at', () async {
    setUpSql(
      "UPDATE npcs SET deleted_at = '2026-01-02 03:04:05' WHERE id = ?",
      [_goblin],
    );
    final before = historyCount();
    await repo.softDelete(_goblin);
    expect(npcRow(_goblin)['deleted_at'], '2026-01-02 03:04:05');
    expect(historyCount(), before + 1);
    expect(latestHistory(), 'Goblin Raider - NPC deleted');
  });

  test('hard delete removes the NPC, its values and its assignments', () async {
    await repo.hardDelete(_goblin);

    expect(rows('SELECT * FROM npcs WHERE id = ?', [_goblin]), isEmpty);
    expect(ownedRows(_goblin).values.every((r) => r.isEmpty), isTrue);
    expect(latestHistory(), 'Goblin Raider - NPC permanently deleted');
    // The other NPC's rows are untouched.
    expect(ownedRows(_marla)['npc_class_assignments'], hasLength(2));
  });

  group('inheritedStatBlock', () {
    test('sums each assigned class growth at its level, formulas '
        'evaluated', () async {
      // Warrior 3: strength 16 (manual), constitution 12 + 3 * 3.
      expect(await repo.inheritedStatBlock(_goblin), {
        'stat-strength': 16.0,
        'stat-constitution': 21.0,
        'stat-dexterity': 0.0,
        'stat-intelligence': 0.0,
        'stat-wisdom': 0.0,
        'stat-resilience': 0.0,
        'stat-charisma': 0.0,
      });
      // Mage 2: intelligence 8 + 2 * 4, wisdom 20 - 2 (max_level 20);
      // Warrior 1: strength 12, constitution 12 + 1 * 3.
      final marla = await repo.inheritedStatBlock(_marla);
      expect(marla, {
        'stat-strength': 12.0,
        'stat-constitution': 15.0,
        'stat-dexterity': 0.0,
        'stat-intelligence': 16.0,
        'stat-wisdom': 18.0,
        'stat-resilience': 0.0,
        'stat-charisma': 0.0,
      });
      expect(marla.keys.first, 'stat-strength');
    });

    test('ignores overrides and follows the stored assignments', () async {
      await repo.save(
        _goblin,
        (await repo.load(_goblin)).copyWith(
          combatStats: {'stat-strength': 99},
          classAssignments: const [
            NpcClassAssignment(classId: _warrior, level: 5),
            NpcClassAssignment(classId: _mage, level: 20),
          ],
        ),
      );
      final block = await repo.inheritedStatBlock(_goblin);
      expect(block['stat-strength'], 20.0);
      expect(block['stat-constitution'], 27.0);
      expect(block['stat-intelligence'], 88.0);
      expect(block['stat-wisdom'], 0.0);
    });

    test(
      'equals the C4 function over ClassRepository.resolvedStatGrowth',
      () async {
        final classes = SqliteClassRepository(db);
        final stats = await SqliteMetaRepository(db).listStats();
        for (final id in [_goblin, _marla]) {
          final draft = await repo.load(id);
          final rows = computeNpcStatBlock(
            stats: stats,
            classAssignments: draft.classAssignments,
            growthByClass: {
              for (final a in draft.classAssignments)
                a.classId: await classes.resolvedStatGrowth(a.classId),
            },
            combatStats: draft.combatStats,
          );
          expect(await repo.inheritedStatBlock(id), {
            for (final r in rows) r.statId: r.inherited,
          });
        }
      },
    );

    test('is all zeros without class assignments', () async {
      final bare = await repo.create(
        CreateNpcInput(
          displayName: 'Bare',
          exportKey: 'bare',
          npcTypeId: _enemy,
        ),
      );
      final block = await repo.inheritedStatBlock(bare.id);
      expect(block, hasLength(7));
      expect(block.values.every((v) => v == 0), isTrue);
    });
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:anvil_core/anvil_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../db/support/fixture_copy.dart';

const String _warrior = '8cb0cf2e-a3f2-47ad-ad82-158dc9eb3d8a';
const String _mage = 'a7b87a4c-f898-4ebd-bfca-a8163101fc77';
const String _slash = 'a41d8d54-0a88-49c8-b53a-0cb21ef14f6a';
const String _fireball = '4e5b5a67-ba0b-43b2-bdfa-3bd426f83c7e';
const String _goblin = '9516c484-83f0-488a-a9d5-a7ce0f006d7f';
const String _marla = '1fdfd4c3-bf59-405d-9a77-f4ad056d82b4';
const String _unknown = '00000000-0000-4000-8000-000000000000';

/// The five junction tables a class owns.
const List<String> _junctions = [
  'class_stat_growth',
  'class_stat_growth_formulas',
  'class_ability_assignments',
  'class_derived_stat_overrides',
  'class_metadata_fields',
];

void main() {
  final fixture = FixtureCopy.setUpEach();

  late ProjectDatabase db;
  late ClassRepository repo;

  setUp(() {
    db = fixture().openFixture();
    repo = SqliteClassRepository(db);
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

  /// Every class row and junction row of [classId], without the timestamps
  /// a save rewrites: `classes.updated_at`, and the junction rows'
  /// `created_at`/`updated_at` (they are deleted and re-inserted, as in
  /// 0.1.6).
  Map<String, List<Map<String, Object?>>> classState(String classId) => {
    'classes': [
      for (final r in rows('SELECT * FROM classes WHERE id = ?', [classId]))
        {...r}..remove('updated_at'),
    ],
    for (final t in _junctions)
      t: [
        for (final r in rows(
          'SELECT * FROM $t WHERE class_id = ? ORDER BY rowid',
          [classId],
        ))
          {...r}
            ..remove('created_at')
            ..remove('updated_at'),
      ],
  };

  int junctionRows(String classId) => [
    for (final t in _junctions)
      rows('SELECT COUNT(*) AS c FROM $t WHERE class_id = ?', [
            classId,
          ]).single['c']
          as int,
  ].fold(0, (a, b) => a + b);

  group('load', () {
    test('reads the Warrior with every junction list', () async {
      final draft = await repo.load(_warrior);
      expect(draft.displayName, 'Warrior');
      expect(draft.exportKey, 'warrior');
      expect(draft.description, 'Front-line fighter');
      expect(draft.resourceMultiplier, 1.25);
      expect(draft.statGrowth, {
        for (var level = 1; level <= 5; level++)
          StatGrowthKey('stat-strength', level): 10.0 + 2 * level,
      });
      expect(draft.statGrowth.keys.map((k) => k.level), [1, 2, 3, 4, 5]);
      expect(draft.statGrowthFormulas, {'stat-constitution': '12 + level * 3'});
      expect(draft.abilityIds, [_slash]);
      expect(draft.derivedStatOverrides, {
        'derived-stat-max-hp': 'constitution * 12',
      });
      expect(draft.metadataFields, [
        const ClassMetadataField(fieldKey: 'base_speed', value: 4),
      ]);
    });

    test('reads the Mage with formulas and ordered assignments', () async {
      final draft = await repo.load(_mage);
      expect(draft.displayName, 'Mage');
      expect(draft.exportKey, 'mage');
      expect(draft.description, 'Glass cannon, comma, "quoted"');
      expect(draft.resourceMultiplier, 0.8);
      expect(draft.statGrowth, isEmpty);
      expect(draft.statGrowthFormulas, {
        'stat-intelligence': '8 + level * 4',
        'stat-wisdom': 'max_level - level',
      });
      expect(draft.abilityIds, [_fireball, _slash]);
      expect(draft.derivedStatOverrides, isEmpty);
      expect(draft.metadataFields, isEmpty);
    });

    test('reads metadata fields ordered by key', () async {
      db.saveTransaction('seed', (tx) {
        for (final key in ['zeta', 'alpha', 'Mid']) {
          tx.execute(
            'INSERT INTO class_metadata_fields (class_id, field_key, value) '
            'VALUES (?, ?, 1)',
            [_mage, key],
          );
        }
      });
      final draft = await repo.load(_mage);
      expect(draft.metadataFields.map((f) => f.fieldKey), [
        'Mid',
        'alpha',
        'zeta',
      ]);
    });

    test('loads a soft-deleted class', () async {
      await repo.softDelete(_mage);
      expect((await repo.load(_mage)).displayName, 'Mage');
      expect((await repo.get(_mage)).deletedAt, isNotNull);
    });

    test('get returns the record', () async {
      final record = await repo.get(_warrior);
      expect(record.id, _warrior);
      expect(record.displayName, 'Warrior');
      expect(record.resourceMultiplier, 1.25);
      expect(record.createdAt, '2026-10-31 20:58:16');
      expect(record.updatedAt, '2026-10-31 20:58:16');
      expect(record.deletedAt, isNull);
    });
  });

  group('save', () {
    for (final (name, id) in [('Warrior', _warrior), ('Mage', _mage)]) {
      test('save(load) of the $name changes only updated_at and records one '
          'history row', () async {
        final before = classState(id);
        final history = historyCount();
        final loaded = await repo.load(id);

        final saved = await repo.save(id, loaded);

        expect(saved, loaded);
        expect(classState(id), before);
        expect(historyCount(), history + 1);
        expect(latestHistory(), '$name - Class changed');
        expect(
          rows('SELECT updated_at FROM classes WHERE id = ?', [
            id,
          ]).single['updated_at'],
          matches(RegExp(r'^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$')),
        );
      });
    }

    test('writes changed growth, reordered abilities and a new metadata '
        'field as one unit', () async {
      final loaded = await repo.load(_mage);
      final draft = loaded.copyWith(
        description: 'Changed',
        resourceMultiplier: 1.5,
        statGrowth: {
          const StatGrowthKey('stat-dexterity', 2): 7.5,
          const StatGrowthKey('stat-dexterity', 1): 6,
        },
        statGrowthFormulas: {'stat-intelligence': 'level'},
        abilityIds: [_slash, _fireball],
        derivedStatOverrides: {'derived-stat-magic-power': 'int * 3'},
        metadataFields: [
          const ClassMetadataField(fieldKey: 'mana_regen', value: 2.5),
          const ClassMetadataField(fieldKey: 'focus', value: 1),
        ],
      );

      final saved = await repo.save(_mage, draft);

      // Metadata fields read back ordered by key, as 0.1.6 read them.
      expect(
        saved,
        draft.copyWith(
          metadataFields: [
            const ClassMetadataField(fieldKey: 'focus', value: 1),
            const ClassMetadataField(fieldKey: 'mana_regen', value: 2.5),
          ],
        ),
      );
      expect(await repo.load(_mage), saved);
      expect(
        rows(
          'SELECT ability_id, sort_order FROM class_ability_assignments '
          'WHERE class_id = ? ORDER BY sort_order',
          [_mage],
        ),
        [
          {'ability_id': _slash, 'sort_order': 0},
          {'ability_id': _fireball, 'sort_order': 1},
        ],
      );
      expect(
        rows(
          'SELECT stat_id, level, value FROM class_stat_growth '
          'WHERE class_id = ? ORDER BY level',
          [_mage],
        ),
        [
          {'stat_id': 'stat-dexterity', 'level': 1, 'value': 6.0},
          {'stat_id': 'stat-dexterity', 'level': 2, 'value': 7.5},
        ],
      );
      expect(latestHistory(), 'Mage - Class changed');
      // The other class is untouched.
      expect((await repo.load(_warrior)).abilityIds, [_slash]);
    });

    test('keeps manual entries of a formula-mode stat as stored', () async {
      final loaded = await repo.load(_warrior);
      final draft = loaded.copyWith(
        statGrowth: {
          ...loaded.statGrowth,
          const StatGrowthKey('stat-constitution', 1): 99,
        },
      );
      expect(await repo.save(_warrior, draft), draft);
    });

    test('clears every junction list', () async {
      final loaded = await repo.load(_warrior);
      final empty = ClassDraft(
        displayName: loaded.displayName,
        exportKey: loaded.exportKey,
        description: loaded.description,
        resourceMultiplier: loaded.resourceMultiplier,
      );
      expect(await repo.save(_warrior, empty), empty);
      expect(junctionRows(_warrior), 0);
    });

    test('records the draft display name in the history row', () async {
      final draft = (await repo.load(_warrior)).copyWith(displayName: 'Knight');
      await repo.save(_warrior, draft);
      expect(latestHistory(), 'Knight - Class changed');
      expect((await repo.get(_warrior)).displayName, 'Knight');
    });

    group('refuses a draft with save blockers and writes nothing', () {
      final cases = <String, ClassDraft Function(ClassDraft)>{
        'displayName': (d) => d.copyWith(displayName: '  '),
        'exportKey': (d) => d.copyWith(exportKey: ''),
        'abilityIds[1]': (d) => d.copyWith(abilityIds: [_slash, _slash]),
        'statGrowth': (d) => d.copyWith(
          statGrowth: {const StatGrowthKey('stat-strength', 0): 1},
        ),
        'derivedStatOverrides.derived-stat-max-hp': (d) => d.copyWith(
          derivedStatOverrides: {'derived-stat-max-hp': 'constitution *'},
        ),
        'metadataFields[0].fieldKey': (d) => d.copyWith(
          metadataFields: [const ClassMetadataField(fieldKey: '1x', value: 1)],
        ),
        'metadataFields[1].fieldKey': (d) => d.copyWith(
          metadataFields: [
            const ClassMetadataField(fieldKey: 'k', value: 1),
            const ClassMetadataField(fieldKey: 'k', value: 2),
          ],
        ),
      };
      for (final MapEntry(key: field, value: breakIt) in cases.entries) {
        test(field, () async {
          final before = classState(_warrior);
          final history = historyCount();
          final draft = breakIt(await repo.load(_warrior));
          final blockers = classSaveBlockers(draft);
          expect(blockers.map((b) => b.field), [field]);

          await expectLater(
            repo.save(_warrior, draft),
            throwsA(
              isA<SaveBlocked>().having((e) => e.blockers, 'blockers', [
                blockers.single.message,
              ]),
            ),
          );
          expect(classState(_warrior), before);
          expect(historyCount(), history);
        });
      }
    });

    test('refuses an export key another class holds, naming it', () async {
      final history = historyCount();
      final draft = (await repo.load(_warrior)).copyWith(exportKey: 'mage');
      await expectLater(
        repo.save(_warrior, draft),
        throwsA(
          isA<DuplicateExportKey>().having((e) => e.exportKey, 'key', 'mage'),
        ),
      );
      expect((await repo.get(_warrior)).exportKey, 'warrior');
      expect(historyCount(), history);
    });

    test('accepts the class keeping its own export key', () async {
      final draft = await repo.load(_warrior);
      expect((await repo.save(_warrior, draft)).exportKey, 'warrior');
    });

    test('refuses a soft-deleted class', () async {
      final draft = await repo.load(_mage);
      await repo.softDelete(_mage);
      final before = classState(_mage);
      final history = historyCount();
      await expectLater(
        repo.save(_mage, draft.copyWith(description: 'x')),
        throwsA(
          isA<RecordNotFound>()
              .having((e) => e.domain, 'domain', 'classes')
              .having((e) => e.id, 'id', _mage),
        ),
      );
      expect(classState(_mage), before);
      expect(historyCount(), history);
    });

    test('refuses an unknown id', () async {
      final draft = await repo.load(_warrior);
      final history = historyCount();
      await expectLater(
        repo.save(_unknown, draft.copyWith(exportKey: 'new-key')),
        throwsA(isA<RecordNotFound>()),
      );
      expect(historyCount(), history);
    });

    test('a reference SQLite refuses surfaces as SaveFailed and rolls '
        'back', () async {
      final before = classState(_warrior);
      final history = historyCount();
      final draft = (await repo.load(_warrior))
          .copyWith(abilityIds: [_slash, 'no-such-ability'], description: 'x');
      await expectLater(repo.save(_warrior, draft), throwsA(isA<SaveFailed>()));
      expect(classState(_warrior), before);
      expect(historyCount(), history);
    });
  });

  group('list and count', () {
    test('the three modes before and after a soft delete', () async {
      Future<List<String>> names(RecordListMode mode) async => [
        for (final r in await repo.list(mode: mode)) r.displayName,
      ];

      expect(await names(RecordListMode.active), ['Mage', 'Warrior']);
      expect(await names(RecordListMode.all), ['Mage', 'Warrior']);
      expect(await names(RecordListMode.deletedOnly), isEmpty);
      expect(await repo.countActive(), 2);

      await repo.softDelete(_warrior);

      expect(await names(RecordListMode.active), ['Mage']);
      expect(await names(RecordListMode.all), ['Mage', 'Warrior']);
      expect(await names(RecordListMode.deletedOnly), ['Warrior']);
      expect(await repo.countActive(), 1);
      expect(
        (await repo.list(mode: RecordListMode.deletedOnly)).single.deletedAt,
        isNotNull,
      );
    });

    test('orders by display name ignoring case', () async {
      await repo.create(
        const CreateClassInput(displayName: 'archer', exportKey: 'archer'),
      );
      await repo.create(
        const CreateClassInput(displayName: 'Zealot', exportKey: 'zealot'),
      );
      expect(
        [for (final r in await repo.list()) r.displayName],
        ['archer', 'Mage', 'Warrior', 'Zealot'],
      );
    });
  });

  group('create', () {
    test(
      'inserts a class with the 0.1.6 defaults and no junction rows',
      () async {
        final history = historyCount();
        final record = await repo.create(
          const CreateClassInput(displayName: 'Paladin', exportKey: 'paladin'),
        );
        expect(
          record.id,
          matches(
            RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
              r'[0-9a-f]{12}$',
            ),
          ),
        );
        expect(record.displayName, 'Paladin');
        expect(record.exportKey, 'paladin');
        expect(record.description, '');
        expect(record.resourceMultiplier, 1);
        expect(record.deletedAt, isNull);
        expect(record.createdAt, record.updatedAt);
        expect(
          await repo.load(record.id),
          ClassDraft(displayName: 'Paladin', exportKey: 'paladin'),
        );
        expect(historyCount(), history + 1);
        expect(latestHistory(), 'Paladin - Class created');
        expect(await repo.countActive(), 3);
      },
    );

    test('writes the given description and multiplier', () async {
      final record = await repo.create(
        const CreateClassInput(
          displayName: 'Bard',
          exportKey: 'bard',
          description: 'Sings',
          resourceMultiplier: 0.5,
        ),
      );
      expect(record.description, 'Sings');
      expect(record.resourceMultiplier, 0.5);
    });

    test('refuses a taken export key, naming it', () async {
      final history = historyCount();
      await expectLater(
        repo.create(
          const CreateClassInput(displayName: 'Other', exportKey: 'warrior'),
        ),
        throwsA(
          isA<DuplicateExportKey>().having(
            (e) => e.exportKey,
            'key',
            'warrior',
          ),
        ),
      );
      expect(await repo.countActive(), 2);
      expect(historyCount(), history);
    });
  });

  group('duplicate', () {
    test('copies the class and every junction list', () async {
      final history = historyCount();
      final copy = await repo.duplicate(_warrior);

      expect(copy.id, isNot(_warrior));
      expect(copy.displayName, 'Warrior (Copy)');
      expect(copy.exportKey, matches(RegExp(r'^warrior-copy-[0-9a-f]{8}$')));
      expect(copy.description, 'Front-line fighter');
      expect(copy.resourceMultiplier, 1.25);
      final source = await repo.load(_warrior);
      expect(
        await repo.load(copy.id),
        source.copyWith(
          displayName: copy.displayName,
          exportKey: copy.exportKey,
        ),
      );
      expect(junctionRows(copy.id), junctionRows(_warrior));
      expect(historyCount(), history + 1);
      expect(latestHistory(), 'Warrior (Copy) - Class duplicated');
    });

    test('keeps the assignment order', () async {
      final copy = await repo.duplicate(_mage);
      expect((await repo.load(copy.id)).abilityIds, [_fireball, _slash]);
    });

    test('repeated duplicates get distinct export keys', () async {
      final a = await repo.duplicate(_mage);
      final b = await repo.duplicate(_mage);
      expect(a.exportKey, isNot(b.exportKey));
    });

    test('refuses an unknown id', () async {
      final history = historyCount();
      await expectLater(
        repo.duplicate(_unknown),
        throwsA(isA<RecordNotFound>()),
      );
      expect(historyCount(), history);
    });
  });

  group('soft delete, restore and hard delete', () {
    test('soft delete sets deleted_at once; restore clears it', () async {
      await repo.softDelete(_warrior);
      expect(latestHistory(), 'Warrior - Class deleted');
      final deletedAt = (await repo.get(_warrior)).deletedAt;
      expect(deletedAt, isNotNull);

      // COALESCE keeps the first deletion time.
      db.saveTransaction('backdate', (tx) {
        tx.execute(
          "UPDATE classes SET deleted_at = '2020-01-01 00:00:00' WHERE id = ?",
          [_warrior],
        );
      });
      await repo.softDelete(_warrior);
      expect((await repo.get(_warrior)).deletedAt, '2020-01-01 00:00:00');

      final history = historyCount();
      await repo.restore(_warrior);
      expect((await repo.get(_warrior)).deletedAt, isNull);
      expect(historyCount(), history + 1);
      expect(latestHistory(), 'Warrior - Class restored');
      // Junction data survives a soft delete.
      expect((await repo.load(_warrior)).abilityIds, [_slash]);
    });

    test(
      'hard delete removes the row and cascades its junction rows',
      () async {
        final copy = await repo.duplicate(_warrior);
        expect(junctionRows(copy.id), greaterThan(0));
        await repo.softDelete(copy.id);

        final history = historyCount();
        await repo.hardDelete(copy.id);

        expect(historyCount(), history + 1);
        expect(latestHistory(), 'Warrior (Copy) - Class permanently deleted');
        expect(junctionRows(copy.id), 0);
        await expectLater(repo.get(copy.id), throwsA(isA<RecordNotFound>()));
        expect(junctionRows(_warrior), 9);
      },
    );

    test(
      'hard delete of a class NPCs reference is refused by SQLite',
      () async {
        final before = classState(_warrior);
        final history = historyCount();
        await expectLater(
          repo.hardDelete(_warrior),
          throwsA(isA<SaveFailed>()),
        );
        expect(classState(_warrior), before);
        expect(historyCount(), history);
      },
    );

    test('each refuses an unknown id without a history row', () async {
      final history = historyCount();
      for (final run in <Future<void> Function()>[
        () => repo.softDelete(_unknown),
        () => repo.restore(_unknown),
        () => repo.hardDelete(_unknown),
      ]) {
        await expectLater(
          run(),
          throwsA(
            isA<RecordNotFound>()
                .having((e) => e.domain, 'domain', 'classes')
                .having((e) => e.id, 'id', _unknown),
          ),
        );
      }
      expect(historyCount(), history);
    });
  });

  test('get, load and resolvedStatGrowth refuse an unknown id', () async {
    await expectLater(repo.get(_unknown), throwsA(isA<RecordNotFound>()));
    await expectLater(repo.load(_unknown), throwsA(isA<RecordNotFound>()));
    await expectLater(
      repo.resolvedStatGrowth(_unknown),
      throwsA(isA<RecordNotFound>()),
    );
  });

  group('usedBy', () {
    test('lists the active NPCs assigned the class, by name', () async {
      expect(await repo.usedBy(_warrior), [
        const UsedByRef(_goblin, 'Goblin Raider'),
        const UsedByRef(_marla, 'Marla the Merchant'),
      ]);
      expect(await repo.usedBy(_mage), [
        const UsedByRef(_marla, 'Marla the Merchant'),
      ]);
    });

    test('leaves out soft-deleted NPCs', () async {
      db.saveTransaction('soft delete NPC', (tx) {
        tx.execute(
          "UPDATE npcs SET deleted_at = datetime('now') WHERE id = ?",
          [_goblin],
        );
      });
      expect(await repo.usedBy(_warrior), [
        const UsedByRef(_marla, 'Marla the Merchant'),
      ]);
    });

    test('is empty for an unused or unknown class', () async {
      final copy = await repo.duplicate(_warrior);
      expect(await repo.usedBy(copy.id), isEmpty);
      expect(await repo.usedBy(_unknown), isEmpty);
    });
  });

  group('resolvedStatGrowth', () {
    final context = jsonDecode(
      File(p.join(fixturesDir, 'context-full.json')).readAsStringSync(),
    ) as Map<String, Object?>;

    Map<StatGrowthKey, double> electronGrowth(String classId) {
      final cls = (context['classes'] as List<Object?>)
          .cast<Map<String, Object?>>()
          .singleWhere((c) => c['id'] == classId);
      return {
        for (final e
            in (cls['stat_growth'] as List<Object?>)
                .cast<Map<String, Object?>>())
          StatGrowthKey(e['stat_id'] as String, e['level'] as int):
              (e['value'] as num).toDouble(),
      };
    }

    for (final (name, id) in [('Warrior', _warrior), ('Mage', _mage)]) {
      test('matches the Electron export context for the $name', () async {
        final resolved = await repo.resolvedStatGrowth(id);
        final expected = electronGrowth(id);
        expect(resolved, expected);
        expect(resolved.keys.toList(), expected.keys.toList());
      });
    }

    test('follows the project max level', () async {
      db.saveTransaction('max level', (tx) {
        tx.execute('UPDATE project_info SET max_level = 3');
      });
      final resolved = await repo.resolvedStatGrowth(_mage);
      expect(resolved, {
        const StatGrowthKey('stat-intelligence', 1): 12.0,
        const StatGrowthKey('stat-intelligence', 2): 16.0,
        const StatGrowthKey('stat-intelligence', 3): 20.0,
        const StatGrowthKey('stat-wisdom', 1): 2.0,
        const StatGrowthKey('stat-wisdom', 2): 1.0,
        const StatGrowthKey('stat-wisdom', 3): 0.0,
      });
    });
  });
}

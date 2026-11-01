import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

import '../db/support/fixture_copy.dart';

const String _slash = 'a41d8d54-0a88-49c8-b53a-0cb21ef14f6a';
const String _fireball = '4e5b5a67-ba0b-43b2-bdfa-3bd426f83c7e';
const String _retired = 'b252cd54-6b6e-4534-b5dc-5b5c2d53262b';
const String _warrior = '8cb0cf2e-a3f2-47ad-ad82-158dc9eb3d8a';
const String _mage = 'a7b87a4c-f898-4ebd-bfca-a8163101fc77';
const String _goblin = '9516c484-83f0-488a-a9d5-a7ce0f006d7f';
const String _unknown = '00000000-0000-4000-8000-000000000000';

void main() {
  final fixture = FixtureCopy.setUpEach();

  late ProjectDatabase db;
  late AbilityRepository repo;

  setUp(() {
    db = fixture().openFixture();
    repo = SqliteAbilityRepository(db);
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

  Map<String, Object?> abilityRow(String id) =>
      rows('SELECT * FROM abilities WHERE id = ?', [id]).single;

  String modifiersJson(String id) =>
      abilityRow(id)['stat_modifiers_json'] as String;

  group('load and get', () {
    test('reads every ability in the fixture', () async {
      expect(
        await repo.load(_slash),
        AbilityDraft(
          displayName: 'Slash',
          exportKey: 'slash',
          description: 'A basic melee strike, "quick" & cheap.',
          abilityType: 'active',
          resourceType: 'stamina',
          resourceCost: 5,
          cooldown: 1,
          statModifiers: const {'strength': 2},
        ),
      );
      expect(
        await repo.load(_fireball),
        AbilityDraft(
          displayName: 'Fireball',
          exportKey: 'fireball',
          description: 'Hurls a ball of fire.\nBurns.',
          abilityType: 'active',
          resourceType: 'mana',
          resourceCost: 12,
          cooldown: 3,
          statModifiers: const {'intelligence': 3, 'wisdom': 1},
        ),
      );
      // Soft-deleted, still loadable.
      expect(
        await repo.load(_retired),
        AbilityDraft(
          displayName: 'Retired Move',
          exportKey: 'retired_move',
          abilityType: 'passive',
        ),
      );
    });

    test('get returns the full row with decoded stat modifiers', () async {
      final record = await repo.get(_fireball);
      expect(record.id, _fireball);
      expect(record.displayName, 'Fireball');
      expect(record.resourceType, 'mana');
      expect(record.resourceCost, 12);
      expect(record.statModifiers, {'intelligence': 3.0, 'wisdom': 1.0});
      expect(record.statModifiers.keys, ['intelligence', 'wisdom']);
      expect(record.createdAt, '2026-10-31 20:58:16');
      expect(record.deletedAt, isNull);
      expect((await repo.get(_retired)).deletedAt, '2026-10-31 20:58:16');
    });

    test('get and load refuse an unknown id', () async {
      await expectLater(
        repo.get(_unknown),
        throwsA(
          isA<RecordNotFound>()
              .having((e) => e.domain, 'domain', 'abilities')
              .having((e) => e.id, 'id', _unknown),
        ),
      );
      await expectLater(repo.load(_unknown), throwsA(isA<RecordNotFound>()));
    });
  });

  group('save', () {
    for (final (name, id) in [('Slash', _slash), ('Fireball', _fireball)]) {
      test('save(load) of $name changes only updated_at and records one '
          'history row', () async {
        final before = abilityRow(id)..remove('updated_at');
        final history = historyCount();
        final loaded = await repo.load(id);

        expect(await repo.save(id, loaded), loaded);

        expect(abilityRow(id)..remove('updated_at'), before);
        expect(historyCount(), history + 1);
        expect(latestHistory(), '$name - Ability changed');
      });
    }

    test('keeps the 0.1.6 stat modifier JSON byte for byte', () async {
      await repo.save(_fireball, await repo.load(_fireball));
      expect(modifiersJson(_fireball), '{"intelligence":3,"wisdom":1}');
    });

    test('writes stat modifiers as JSON.stringify did', () async {
      final loaded = await repo.load(_slash);
      final cases = <String, Map<String, double>>{
        '{}': {},
        '{"b":1.5,"a":-2}': {'b': 1.5, 'a': -2},
        // Array-index keys come first in ascending order, as in JavaScript.
        '{"2":3,"10":2,"x":1}': {'x': 1, '10': 2, '2': 3},
        '{"tiny":1e-7,"big":1e+21}': {'tiny': 1e-7, 'big': 1e21},
      };
      for (final MapEntry(key: json, value: modifiers) in cases.entries) {
        final saved = await repo.save(
          _slash,
          loaded.copyWith(statModifiers: modifiers),
        );
        expect(modifiersJson(_slash), json);
        expect(saved.statModifiers, modifiers, reason: json);
      }
    });

    test('writes every field and reads the draft back', () async {
      final draft = AbilityDraft(
        displayName: 'Cleave',
        exportKey: 'cleave',
        description: 'Hits twice',
        abilityType: 'active',
        resourceType: 'rage',
        resourceCost: 7.5,
        cooldown: 0.25,
        statModifiers: const {'strength': 4, 'dexterity': 0.5},
      );
      expect(await repo.save(_slash, draft), draft);
      expect(await repo.load(_slash), draft);
      final row = abilityRow(_slash);
      expect(row['display_name'], 'Cleave');
      expect(row['resource_cost'], 7.5);
      expect(row['cooldown'], 0.25);
      expect(latestHistory(), 'Cleave - Ability changed');
    });

    test('refuses a blank display name or export key and writes '
        'nothing', () async {
      final loaded = await repo.load(_slash);
      final before = abilityRow(_slash);
      final history = historyCount();
      for (final (field, draft) in [
        ('displayName', loaded.copyWith(displayName: ' ')),
        ('exportKey', loaded.copyWith(exportKey: '')),
      ]) {
        final blockers = abilitySaveBlockers(draft);
        expect(blockers.map((b) => b.field), [field]);
        await expectLater(
          repo.save(_slash, draft),
          throwsA(
            isA<SaveBlocked>().having((e) => e.blockers, 'blockers', [
              blockers.single.message,
            ]),
          ),
        );
      }
      expect(abilityRow(_slash), before);
      expect(historyCount(), history);
    });

    test('refuses an export key another ability holds, naming it', () async {
      final history = historyCount();
      // Soft-deleted abilities still hold their key.
      for (final key in ['fireball', 'retired_move']) {
        await expectLater(
          repo.save(_slash, (await repo.load(_slash)).copyWith(exportKey: key)),
          throwsA(
            isA<DuplicateExportKey>().having((e) => e.exportKey, 'key', key),
          ),
        );
      }
      expect(historyCount(), history);
      expect((await repo.get(_slash)).exportKey, 'slash');
    });

    test('refuses a soft-deleted or unknown ability', () async {
      final draft = await repo.load(_retired);
      final before = abilityRow(_retired);
      final history = historyCount();
      // The unknown id gets a free key: the export key check runs first.
      for (final (id, key) in [
        (_retired, 'retired_move'),
        (_unknown, 'free'),
      ]) {
        await expectLater(
          repo.save(id, draft.copyWith(description: 'x', exportKey: key)),
          throwsA(
            isA<RecordNotFound>()
                .having((e) => e.domain, 'domain', 'abilities')
                .having((e) => e.id, 'id', id),
          ),
        );
      }
      expect(abilityRow(_retired), before);
      expect(historyCount(), history);
    });
  });

  group('list and count', () {
    test('the three modes before and after a soft delete', () async {
      Future<List<String>> names(RecordListMode mode) async => [
        for (final r in await repo.list(mode: mode)) r.displayName,
      ];

      expect(await names(RecordListMode.active), ['Fireball', 'Slash']);
      expect(await names(RecordListMode.all), [
        'Fireball',
        'Retired Move',
        'Slash',
      ]);
      expect(await names(RecordListMode.deletedOnly), ['Retired Move']);
      expect(await repo.countActive(), 2);

      await repo.softDelete(_slash);

      expect(await names(RecordListMode.active), ['Fireball']);
      expect(await names(RecordListMode.all), [
        'Fireball',
        'Retired Move',
        'Slash',
      ]);
      expect(await names(RecordListMode.deletedOnly), [
        'Retired Move',
        'Slash',
      ]);
      expect(await repo.countActive(), 1);
    });

    test('list rows carry the decoded stat modifiers', () async {
      final slash = (await repo.list()).singleWhere((r) => r.id == _slash);
      expect(slash.statModifiers, {'strength': 2.0});
      expect(slash.abilityType, 'active');
    });
  });

  group('create', () {
    test('inserts with the 0.1.6 defaults', () async {
      final history = historyCount();
      final record = await repo.create(
        CreateAbilityInput(displayName: 'Block', exportKey: 'block'),
      );
      expect(record.displayName, 'Block');
      expect(record.description, '');
      expect(record.abilityType, '');
      expect(record.resourceType, '');
      expect(record.resourceCost, 0);
      expect(record.cooldown, 0);
      expect(record.statModifiers, isEmpty);
      expect(record.deletedAt, isNull);
      expect(modifiersJson(record.id), '{}');
      expect(historyCount(), history + 1);
      expect(latestHistory(), 'Block - Ability created');
      expect(await repo.countActive(), 3);
    });

    test('writes every given field', () async {
      final record = await repo.create(
        CreateAbilityInput(
          displayName: 'Heal',
          exportKey: 'heal',
          description: 'Mends',
          abilityType: 'active',
          resourceType: 'mana',
          resourceCost: 8,
          cooldown: 2,
          statModifiers: const {'wisdom': 2},
        ),
      );
      expect(await repo.load(record.id), isA<AbilityDraft>());
      expect(modifiersJson(record.id), '{"wisdom":2}');
      expect(record.resourceType, 'mana');
    });

    test('refuses a taken export key, naming it', () async {
      final history = historyCount();
      await expectLater(
        repo.create(CreateAbilityInput(displayName: 'X', exportKey: 'slash')),
        throwsA(
          isA<DuplicateExportKey>().having((e) => e.exportKey, 'key', 'slash'),
        ),
      );
      expect(historyCount(), history);
    });
  });

  group('duplicate', () {
    test('copies every field under a new name and key', () async {
      final history = historyCount();
      final copy = await repo.duplicate(_fireball);
      expect(copy.id, isNot(_fireball));
      expect(copy.displayName, 'Fireball (Copy)');
      expect(copy.exportKey, matches(RegExp(r'^fireball-copy-[0-9a-f]{8}$')));
      expect(
        await repo.load(copy.id),
        (await repo.load(_fireball))
            .copyWith(displayName: copy.displayName, exportKey: copy.exportKey),
      );
      expect(modifiersJson(copy.id), modifiersJson(_fireball));
      expect(historyCount(), history + 1);
      expect(latestHistory(), 'Fireball (Copy) - Ability duplicated');
    });

    test('refuses an unknown id', () async {
      await expectLater(
        repo.duplicate(_unknown),
        throwsA(isA<RecordNotFound>()),
      );
    });
  });

  group('soft delete, restore and hard delete', () {
    test('soft delete then restore, one history row each', () async {
      final history = historyCount();
      await repo.softDelete(_fireball);
      expect((await repo.get(_fireball)).deletedAt, isNotNull);
      expect(latestHistory(), 'Fireball - Ability deleted');
      await repo.restore(_fireball);
      expect((await repo.get(_fireball)).deletedAt, isNull);
      expect(latestHistory(), 'Fireball - Ability restored');
      expect(historyCount(), history + 2);
    });

    test('soft delete keeps an existing deleted_at', () async {
      await repo.softDelete(_retired);
      expect((await repo.get(_retired)).deletedAt, '2026-10-31 20:58:16');
    });

    test('hard delete removes an unreferenced ability', () async {
      final history = historyCount();
      await repo.hardDelete(_retired);
      await expectLater(repo.get(_retired), throwsA(isA<RecordNotFound>()));
      expect(historyCount(), history + 1);
      expect(latestHistory(), 'Retired Move - Ability permanently deleted');
    });

    test('hard delete of an assigned ability is refused by SQLite', () async {
      final before = abilityRow(_slash);
      final history = historyCount();
      await expectLater(repo.hardDelete(_slash), throwsA(isA<SaveFailed>()));
      expect(abilityRow(_slash), before);
      expect(historyCount(), history);
    });

    test('each refuses an unknown id without a history row', () async {
      final history = historyCount();
      for (final run in <Future<void> Function()>[
        () => repo.softDelete(_unknown),
        () => repo.restore(_unknown),
        () => repo.hardDelete(_unknown),
      ]) {
        await expectLater(run(), throwsA(isA<RecordNotFound>()));
      }
      expect(historyCount(), history);
    });
  });

  group('usedBy', () {
    test('lists active classes and NPCs, by name', () async {
      expect(
        await repo.usedBy(_slash),
        AbilityUsedBy(
          classes: const [
            UsedByRef(_mage, 'Mage'),
            UsedByRef(_warrior, 'Warrior'),
          ],
          npcs: const [UsedByRef(_goblin, 'Goblin Raider')],
        ),
      );
      expect(
        await repo.usedBy(_fireball),
        AbilityUsedBy(
          classes: const [UsedByRef(_mage, 'Mage')],
          npcs: const [],
        ),
      );
    });

    test('leaves out soft-deleted classes and NPCs', () async {
      await SqliteClassRepository(db).softDelete(_warrior);
      db.saveTransaction('soft delete NPC', (tx) {
        tx.execute(
          "UPDATE npcs SET deleted_at = datetime('now') WHERE id = ?",
          [_goblin],
        );
      });
      expect(
        await repo.usedBy(_slash),
        AbilityUsedBy(
          classes: const [UsedByRef(_mage, 'Mage')],
          npcs: const [],
        ),
      );
    });

    test('is empty for an unused or unknown ability', () async {
      final empty = AbilityUsedBy(classes: const [], npcs: const []);
      expect(await repo.usedBy(_retired), empty);
      expect(await repo.usedBy(_unknown), empty);
    });
  });
}

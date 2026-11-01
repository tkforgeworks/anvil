import 'package:anvil_core/anvil_core.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import '../db/support/fixture_copy.dart';

// Scenarios from Electron's src/main/validation/__tests__/engine.test.ts that
// validation-mutations.sql does not already pin, run on a freshly migrated
// project (seeded ids from 002_seed_meta_layer).
const _weapon = 'item-category-weapon';
const _common = 'rarity-common';
const _enemy = 'npc-type-enemy';
const _con = 'stat-constitution';

void main() {
  final copy = FixtureCopy.setUpEach();

  late ProjectDatabase db;
  // ignore: invalid_use_of_internal_member
  Database sql() => db.handle;

  setUp(() {
    db = copy().openEmpty();
    runMigrations(db);
  });

  void insertClass(String id, {double resourceMultiplier = 1}) => sql().execute(
    'INSERT INTO classes (id, display_name, export_key, '
    'resource_multiplier) VALUES (?, ?, ?, ?)',
    [id, 'Class $id', 'class_$id', resourceMultiplier],
  );

  void insertDerivedStat(String id, String exportKey, String formula) =>
      sql().execute(
        'INSERT INTO derived_stat_definitions '
        '(id, display_name, export_key, formula) VALUES (?, ?, ?, ?)',
        [id, exportKey, exportKey, formula],
      );

  void insertOverride(String classId, String derivedStatId, String formula) =>
      sql().execute(
        'INSERT INTO class_derived_stat_overrides '
        '(class_id, derived_stat_id, formula) VALUES (?, ?, ?)',
        [classId, derivedStatId, formula],
      );

  void setSeverity(String severity) => sql().execute(
    'UPDATE project_info SET soft_delete_reference_severity = ? WHERE id = 1',
    [severity],
  );

  test('an empty project has no issues', () {
    expect(validateProject(db), isEmpty);
  });

  group('soft-delete reference severity', () {
    setUp(() {
      sql().execute(
        'INSERT INTO loot_tables (id, display_name, export_key, deleted_at) '
        "VALUES ('loot-1', 'Old Drops', 'old_drops', datetime('now'))",
      );
      sql().execute(
        'INSERT INTO npcs (id, display_name, export_key, npc_type_id, '
        "loot_table_id) VALUES ('npc-1', 'Grunt', 'grunt', ?, 'loot-1')",
        [_enemy],
      );
      sql().execute(
        'INSERT INTO items (id, display_name, export_key, item_category_id, '
        "rarity_id, deleted_at) VALUES ('item-1', 'Old Sword', 'old_sword', "
        "?, ?, datetime('now'))",
        [_weapon, _common],
      );
      sql().execute(
        'INSERT INTO loot_tables (id, display_name, export_key) '
        "VALUES ('loot-2', 'Drops', 'drops')",
      );
      sql().execute(
        'INSERT INTO loot_table_entries (id, loot_table_id, item_id, weight) '
        "VALUES ('e1', 'loot-2', 'item-1', 1)",
      );
    });

    test('Warning makes soft-deleted references warnings', () {
      setSeverity('Warning');
      expect(validateProject(db), [
        ValidationIssue(
          domain: ValidationDomain.npcs,
          recordId: 'npc-1',
          recordDisplayName: 'Grunt',
          field: 'lootTableId',
          severity: ValidationSeverity.warning,
          message: "References soft-deleted loot table 'Old Drops'.",
        ),
        ValidationIssue(
          domain: ValidationDomain.lootTables,
          recordId: 'loot-2',
          recordDisplayName: 'Drops',
          field: 'entries',
          severity: ValidationSeverity.warning,
          message: "Assignment references soft-deleted item 'Old Sword'.",
        ),
      ]);
    });

    test('Error makes them errors', () {
      setSeverity('Error');
      final issues = validateProject(db);
      expect(issues, hasLength(2));
      expect(
        issues.map((i) => i.severity),
        everyElement(ValidationSeverity.error),
      );
    });

    test('broken references are errors whatever the setting', () {
      setSeverity('Warning');
      sql().execute('PRAGMA foreign_keys = OFF');
      sql().execute(
        'INSERT INTO npcs (id, display_name, export_key, npc_type_id, '
        "loot_table_id) VALUES ('npc-2', 'Lost', 'lost', ?, 'nowhere')",
        [_enemy],
      );
      sql().execute('PRAGMA foreign_keys = ON');
      final broken = validateProject(db)
          .where((i) => i.recordId == 'npc-2')
          .single;
      expect(broken.severity, ValidationSeverity.error);
      expect(broken.message, "References nonexistent loot table 'nowhere'.");
    });
  });

  group('derived-stat runtime at level 1', () {
    test('a base formula that fails syntax gets no runtime issue', () {
      insertDerivedStat('d-broken', 'broken', 'con *');
      insertClass('c1');
      final issues = validateProject(db);
      expect(issues, hasLength(1));
      expect(issues.single.domain, ValidationDomain.derivedStats);
      expect(issues.single.message, startsWith('Formula syntax error: '));
    });

    test('an override that fails syntax gets no runtime issue', () {
      insertDerivedStat('d-hp', 'test_hp', '100 / con');
      insertClass('c1');
      insertOverride('c1', 'd-hp', '/ broken');
      final issues = validateProject(db);
      expect(issues, hasLength(1));
      expect(issues.single.field, 'derivedStat:test_hp');
      expect(
        issues.single.message,
        "Override formula for 'test_hp' has syntax error: "
        "Unexpected '/' at position 0",
      );
    });

    test('a stat without a level-1 growth entry binds to 0', () {
      insertDerivedStat('d-ratio', 'ratio', '100 / con');
      insertClass('c1');
      expect(validateProject(db), [
        ValidationIssue(
          domain: ValidationDomain.classes,
          recordId: 'c1',
          recordDisplayName: 'Class c1',
          field: 'derivedStat:ratio',
          severity: ValidationSeverity.warning,
          message: "Formula for 'ratio' failed at level 1: Division by zero",
        ),
      ]);
    });

    test('a level-1 growth entry binds the stat', () {
      insertDerivedStat('d-ratio', 'ratio', '100 / con');
      insertClass('c1');
      sql().execute(
        'INSERT INTO class_stat_growth (class_id, stat_id, level, value) '
        "VALUES ('c1', ?, 1, 5)",
        [_con],
      );
      expect(validateProject(db), isEmpty);
    });

    test('a metadata field overrides a stat binding of the same key', () {
      insertDerivedStat('d-ratio', 'ratio', '100 / con');
      insertClass('c1');
      sql().execute(
        'INSERT INTO class_stat_growth (class_id, stat_id, level, value) '
        "VALUES ('c1', ?, 1, 5)",
        [_con],
      );
      sql().execute(
        'INSERT INTO class_metadata_fields (class_id, field_key, value) '
        "VALUES ('c1', 'con', 0)",
      );
      final issues = validateProject(db);
      expect(issues, hasLength(1));
      expect(
        issues.single.message,
        "Formula for 'ratio' failed at level 1: Division by zero",
      );
    });

    test('resource_multiplier is bound from the class', () {
      insertDerivedStat('d-rm', 'rm_check', '1 / (resource_multiplier - 2)');
      insertClass('c-one');
      insertClass('c-two', resourceMultiplier: 2);
      final issues = validateProject(db);
      expect([for (final i in issues) i.recordId], ['c-two']);
    });

    test('soft-deleted classes are not evaluated', () {
      insertDerivedStat('d-ratio', 'ratio', '100 / con');
      sql().execute(
        'INSERT INTO classes (id, display_name, export_key, deleted_at) '
        "VALUES ('c-gone', 'Gone', 'gone', datetime('now'))",
      );
      expect(validateProject(db), isEmpty);
    });
  });

  group('derived-stat cycles', () {
    test('an override that keeps the base cycle adds no class issue', () {
      insertDerivedStat('a', 'a', 'b + 1');
      insertDerivedStat('b', 'b', 'a + 1');
      insertClass('c1');
      insertOverride('c1', 'a', 'b + 2');
      final cycleIssues = validateProject(db)
          .where((i) => i.message.contains('cycle'))
          .toList();
      expect(
        [for (final i in cycleIssues) i.domain],
        [ValidationDomain.derivedStats, ValidationDomain.derivedStats],
      );
    });

    test('an override that breaks the base cycle adds no class issue', () {
      insertDerivedStat('a', 'a', 'b + 1');
      insertDerivedStat('b', 'b', 'a + 1');
      insertClass('c1');
      insertOverride('c1', 'a', '3');
      final classCycle = validateProject(db)
          .where((i) => i.field == 'derivedStatOverrides');
      expect(classCycle, isEmpty);
    });

    test('a self-reference is a one-stat cycle', () {
      insertDerivedStat('s', 'selfish', 'selfish + 1');
      final issues = validateProject(db);
      expect(
        issues.single.message,
        'Derived stat is part of a dependency cycle: selfish → selfish.',
      );
    });
  });

  group('stat growth formulas', () {
    void insertGrowthFormula(String classId, String formula) => sql().execute(
      'INSERT INTO class_stat_growth_formulas (class_id, stat_id, formula) '
      'VALUES (?, ?, ?)',
      [classId, _con, formula],
    );

    test('only the first failing level is reported', () {
      insertClass('c1');
      insertGrowthFormula('c1', '1 / (level - level)');
      expect(validateProject(db), [
        ValidationIssue(
          domain: ValidationDomain.classes,
          recordId: 'c1',
          recordDisplayName: 'Class c1',
          field: 'statGrowthFormula:Constitution',
          severity: ValidationSeverity.error,
          message:
              'Stat growth formula for Constitution fails at level 1: '
              'Division by zero',
        ),
      ]);
    });

    test('the level range ends at the project max_level', () {
      sql().execute('UPDATE project_info SET max_level = 4 WHERE id = 1');
      insertClass('c1');
      insertGrowthFormula('c1', '1 / (level - 5)');
      expect(validateProject(db), isEmpty);
      sql().execute('UPDATE project_info SET max_level = 5 WHERE id = 1');
      expect(
        validateProject(db).single.message,
        'Stat growth formula for Constitution fails at level 5: '
        'Division by zero',
      );
    });

    test('max_level is bound', () {
      sql().execute('UPDATE project_info SET max_level = 3 WHERE id = 1');
      insertClass('c1');
      insertGrowthFormula('c1', '1 / (max_level - level)');
      expect(
        validateProject(db).single.message,
        'Stat growth formula for Constitution fails at level 3: '
        'Division by zero',
      );
    });
  });

  group('ValidationIssue', () {
    ValidationIssue sample({String? id, String? field = 'rarityId'}) =>
        ValidationIssue(
          id: id,
          domain: ValidationDomain.lootTables,
          recordId: 'r1',
          recordDisplayName: 'Record',
          field: field,
          severity: ValidationSeverity.warning,
          message: 'm',
        );

    test('equality ignores the id', () {
      expect(sample(id: 'a'), sample(id: 'b'));
      expect(sample(id: 'a').hashCode, sample(id: 'b').hashCode);
      expect(sample(), isNot(sample(field: null)));
    });

    test('toJson uses the 0.1.6 keys and strings, without the id', () {
      expect(sample(field: null).toJson(), {
        'domain': 'loot-tables',
        'recordId': 'r1',
        'recordDisplayName': 'Record',
        'field': null,
        'severity': 'warning',
        'message': 'm',
      });
    });

    test('fromValue round-trips every enum value', () {
      for (final d in ValidationDomain.values) {
        expect(ValidationDomain.fromValue(d.value), d);
      }
      for (final s in ValidationSeverity.values) {
        expect(ValidationSeverity.fromValue(s.value), s);
      }
      expect(() => ValidationDomain.fromValue('nope'), throwsArgumentError);
    });
  });
}

import 'dart:io';

import 'package:anvil_core/anvil_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../db/support/fixture_copy.dart';

/// A fresh fixture copy with `validation-mutations.sql` applied, split on
/// `;\n` as the vitest oracle splits it.
ProjectDatabase _openMutatedFixture(FixtureCopy copy) {
  final db = copy.openFixture();
  final sql = File(
    p.join(fixturesDir, 'validation', 'validation-mutations.sql'),
  ).readAsStringSync();
  for (final statement in sql.split(';\n')) {
    if (statement.trim().isEmpty) continue;
    // ignore: invalid_use_of_internal_member
    db.handle.execute(statement.trim());
  }
  return db;
}

const _tables = {
  ValidationDomain.classes: 'classes',
  ValidationDomain.abilities: 'abilities',
  ValidationDomain.items: 'items',
  ValidationDomain.recipes: 'recipes',
  ValidationDomain.npcs: 'npcs',
  ValidationDomain.lootTables: 'loot_tables',
  ValidationDomain.derivedStats: 'derived_stat_definitions',
};

List<Map<String, Object?>> _json(List<ValidationIssue> issues) => [
  for (final i in issues) i.toJson(),
];

List<ValidationIssue> _filtered(
  List<ValidationIssue> all,
  ValidationDomain domain,
  String id,
) => [
  for (final i in all)
    if (i.domain == domain && i.recordId == id) i,
];

void main() {
  final copy = FixtureCopy.setUpEach();

  test('every record with issues gets exactly its project-pass issues', () {
    final db = _openMutatedFixture(copy());
    final all = validateProject(db);
    final pairs = {for (final i in all) (i.domain, i.recordId)};
    expect(pairs.length, greaterThan(15));
    for (final (domain, id) in pairs) {
      final expected = _filtered(all, domain, id);
      expect(
        _json(validateRecord(db, domain, id)),
        _json(expected),
        reason: '${domain.value}/$id',
      );
    }
  });

  test('every record in the project, with or without issues, matches', () {
    final db = _openMutatedFixture(copy());
    final all = validateProject(db);
    var withoutIssues = 0;
    for (final MapEntry(key: domain, value: table) in _tables.entries) {
      // ignore: invalid_use_of_internal_member
      for (final row in db.handle.select('SELECT id FROM $table')) {
        final id = row['id'] as String;
        final expected = _filtered(all, domain, id);
        if (expected.isEmpty) withoutIssues++;
        expect(
          validateRecord(db, domain, id),
          expected,
          reason: '${domain.value}/$id',
        );
      }
    }
    expect(withoutIssues, greaterThan(5));
  });

  test('a record without issues returns an empty list', () {
    final db = _openMutatedFixture(copy());
    // Brew Healing Potion, Iron Ingot and the Slash ability.
    expect(
      validateRecord(
        db,
        ValidationDomain.recipes,
        '2f3bcc27-2306-43c3-99ee-87b9319fd960',
      ),
      isEmpty,
    );
    expect(
      validateRecord(
        db,
        ValidationDomain.items,
        '11a74879-0851-4af7-8ff1-7be63edae9f2',
      ),
      isEmpty,
    );
    expect(
      validateRecord(
        db,
        ValidationDomain.abilities,
        'a41d8d54-0a88-49c8-b53a-0cb21ef14f6a',
      ),
      isEmpty,
    );
  });

  test('an unknown id returns an empty list in every domain', () {
    final db = _openMutatedFixture(copy());
    for (final domain in ValidationDomain.values) {
      expect(validateRecord(db, domain, 'no-such-record'), isEmpty);
    }
  });

  test('a record id from another domain reports nothing', () {
    final db = _openMutatedFixture(copy());
    // The Warrior has issues as a class, none as an item.
    const warrior = '8cb0cf2e-a3f2-47ad-ad82-158dc9eb3d8a';
    expect(validateRecord(db, ValidationDomain.classes, warrior), isNotEmpty);
    expect(validateRecord(db, ValidationDomain.items, warrior), isEmpty);
  });

  test('a derived stat in the base cycle gets its cycle issue', () {
    final db = _openMutatedFixture(copy());
    final issues = validateRecord(
      db,
      ValidationDomain.derivedStats,
      'mut-ds-cycle-a',
    );
    expect(issues, hasLength(1));
    expect(
      issues.single.message,
      'Derived stat is part of a dependency cycle: '
      'Cycle B → Cycle A → Cycle B.',
    );
  });

  test('on the unmodified fixture only the Warrior has an issue', () {
    final db = copy().openFixture();
    final warrior = validateRecord(
      db,
      ValidationDomain.classes,
      '8cb0cf2e-a3f2-47ad-ad82-158dc9eb3d8a',
    );
    expect(warrior, validateProject(db));
    expect(
      validateRecord(
        db,
        ValidationDomain.classes,
        'a7b87a4c-f898-4ebd-bfca-a8163101fc77',
      ),
      isEmpty,
    );
  });
}

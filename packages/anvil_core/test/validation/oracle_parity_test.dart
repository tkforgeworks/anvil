import 'dart:convert';
import 'dart:io';

import 'package:anvil_core/anvil_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../db/support/fixture_copy.dart';

List<Object?> _oracle(String name) =>
    jsonDecode(File(p.join(fixturesDir, 'validation', name)).readAsStringSync())
        as List<Object?>;

/// A fresh fixture copy with `validation-mutations.sql` applied, split on
/// `;\n` as the vitest oracle splits it.
ProjectDatabase openMutatedFixture(FixtureCopy copy) {
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

void main() {
  final copy = FixtureCopy.setUpEach();

  test('the 0.1.6 fixture matches validation-issues-fixture.json', () {
    final db = copy().openFixture();
    expect([
      for (final i in validateProject(db)) i.toJson(),
    ], _oracle('validation-issues-fixture.json'));
  });

  test('the mutated fixture matches validation-issues-mutated.json', () {
    final db = openMutatedFixture(copy());
    final expected = _oracle('validation-issues-mutated.json');
    final actual = [for (final i in validateProject(db)) i.toJson()];
    expect(actual.length, expected.length);
    for (var i = 0; i < expected.length; i++) {
      expect(actual[i], expected[i], reason: 'issue $i');
    }
  });

  test('issue ids are unique within a run', () {
    final issues = validateProject(openMutatedFixture(copy()));
    expect({for (final i in issues) i.id}.length, issues.length);
  });
}

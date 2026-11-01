import 'dart:io';

import 'package:anvil_core/anvil_core.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'support/fixture_copy.dart';

void main() {
  final fixture = FixtureCopy.setUpEach();

  test('open sets WAL journal mode and foreign keys', () {
    final db = fixture().openFixture();
    expect(db.isOpen, isTrue);
    expect(db.handle.select('PRAGMA journal_mode').single.values.first, 'wal');
    expect(db.handle.select('PRAGMA foreign_keys').single.values.first, 1);
  });

  test('open creates a missing file', () {
    final path = fixture().pathFor('new.anvil');
    expect(File(path).existsSync(), isFalse);
    fixture().track(ProjectDatabase.open(path));
    expect(File(path).existsSync(), isTrue);
  });

  test('openReadOnly refuses writes and has foreign keys on', () {
    final path = fixture().copyFixture();
    // Put the copy in WAL mode the way the app does, then reopen read-only.
    ProjectDatabase.open(path).close();
    final db = fixture().track(ProjectDatabase.openReadOnly(path));

    expect(db.handle.select('PRAGMA foreign_keys').single.values.first, 1);
    expect(db.handle.select('PRAGMA journal_mode').single.values.first, 'wal');
    expect(
      db.handle.select('SELECT COUNT(*) AS n FROM stats').single['n'],
      greaterThan(0),
    );
    expect(
      () => db.handle.execute(
        "INSERT INTO save_history (description) VALUES ('nope')",
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('close is idempotent and flips isOpen', () {
    final db = fixture().openFixture();
    db.close();
    expect(db.isOpen, isFalse);
    db.close();
    expect(db.isOpen, isFalse);
    expect(() => db.handle, throwsStateError);
  });

  test('integrityCheck passes on the fixture', () {
    fixture().openFixture().integrityCheck();
  });

  // Page 5 of the fixture is the `stats` table leaf (7 cells, content from
  // offset 3567). The brief's example offset, 4096 * 3 + 200, lands in the
  // unallocated gap of the one-cell `project_info` leaf on page 4, which
  // integrity_check does not inspect, so it still reports `ok` there.
  const statsLeaf = 4096 * 4;
  for (final (label, offset) in [
    ('cell content', statsLeaf + 4096 - 64),
    ('cell pointer array', statsLeaf + 8),
  ]) {
    test('integrityCheck throws IntegrityCheckFailed on a corrupt $label', () {
      final path = fixture().copyFixture();
      final bytes = File(path).readAsBytesSync();
      bytes.fillRange(offset, offset + 64, 0xFF);
      File(path).writeAsBytesSync(bytes);

      final db = fixture().track(ProjectDatabase.open(path));
      Object? thrown;
      try {
        db.integrityCheck();
      } catch (e) {
        thrown = e;
      }
      expect(thrown, isA<IntegrityCheckFailed>());
      expect(thrown, isNot(isA<SqliteException>()));
      expect((thrown as IntegrityCheckFailed).message, isNotEmpty);
    });
  }

  test('snapshot writes a copy with no pending migrations and the same '
      'schema', () {
    final db = fixture().openFixture();
    final target = fixture().pathFor('snapshot.anvil');
    db.snapshot(target);

    final copy = fixture().track(ProjectDatabase.open(target));
    expect(pendingMigrations(copy), isEmpty);
    expect(masterRows(copy.handle), masterRows(db.handle));
    copy.integrityCheck();
  });

  test('snapshot includes changes still in the WAL file', () {
    final db = fixture().openFixture();
    db.handle.execute(
      "INSERT INTO save_history (description) VALUES ('only in wal')",
    );
    expect(File('${db.path}-wal').lengthSync(), greaterThan(0));

    final target = fixture().pathFor('snapshot.anvil');
    db.snapshot(target);
    final copy = fixture().track(ProjectDatabase.openReadOnly(target));
    expect(
      copy.handle
          .select(
            "SELECT COUNT(*) AS n FROM save_history WHERE description = 'only in wal'",
          )
          .single['n'],
      1,
    );
  });

  test('checkpoint(truncate) leaves an empty or absent -wal file', () {
    final db = fixture().openFixture();
    db.handle.execute(
      "INSERT INTO save_history (description) VALUES ('checkpoint me')",
    );
    final wal = File('${db.path}-wal');
    expect(wal.lengthSync(), greaterThan(0));

    db.checkpoint(CheckpointMode.truncate);
    expect(!wal.existsSync() || wal.lengthSync() == 0, isTrue);
  });

  test('checkpoint accepts every mode', () {
    final db = fixture().openFixture();
    for (final mode in CheckpointMode.values) {
      db.checkpoint(mode);
    }
  });

  test('read sees one consistent view', () {
    final db = fixture().openFixture();
    final writer = fixture().track(ProjectDatabase.open(db.path));
    const count = 'SELECT COUNT(*) AS n FROM save_history';
    final before = db.handle.select(count).single['n'] as int;

    final seen = db.read((tx) {
      final first = tx.select(count).single['n'];
      writer.handle.execute(
        "INSERT INTO save_history (description) VALUES ('concurrent')",
      );
      final second = tx.select(count).single['n'];
      return (first, second);
    });

    expect(seen, (before, before));
    expect(db.handle.autocommit, isTrue);
    expect(db.handle.select(count).single['n'], before + 1);
  });

  test('read rolls back on throw and leaves no transaction open', () {
    final db = fixture().openFixture();
    expect(
      () => db.read((tx) {
        tx.select('SELECT 1');
        throw const FormatException('boom');
      }),
      throwsFormatException,
    );
    expect(db.handle.autocommit, isTrue);
  });

  test('a ReadScope cannot be used after its transaction', () {
    final db = fixture().openFixture();
    final scope = db.read((tx) => tx);
    expect(() => scope.select('SELECT 1'), throwsStateError);
  });
}

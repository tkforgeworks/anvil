import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

import 'support/fixture_copy.dart';

void main() {
  final fixture = FixtureCopy.setUpEach();

  int historyCount(ProjectDatabase db) =>
      db
              .read((tx) => tx.select('SELECT COUNT(*) c FROM save_history'))
              .first['c']
          as int;

  const insertClass =
      'INSERT INTO classes (id, display_name, export_key, created_at, '
      "updated_at) VALUES (?, ?, ?, datetime('now'), datetime('now'))";

  int classCount(ProjectDatabase db) =>
      db.read((tx) => tx.select('SELECT COUNT(*) c FROM classes')).first['c']
          as int;

  test('commit adds one history row and keeps the writes', () {
    final db = fixture().openFixture();
    final before = historyCount(db);
    final classes = classCount(db);
    final result = db.saveTransaction('Test - Class created', (tx) {
      tx.execute(insertClass, ['c-new', 'Test', 'test-new']);
      expect(tx.changes, 1);
      return 42;
    });
    expect(result, 42);
    expect(historyCount(db), before + 1);
    expect(classCount(db), classes + 1);
    final newest = readRecentSaves(db, limit: 1).single;
    expect(newest.description, 'Test - Class created');
    expect(newest.isAutoSave, isFalse);
  });

  test('a throwing body rolls back and leaves autocommit', () {
    final db = fixture().openFixture();
    final before = historyCount(db);
    final classes = classCount(db);
    expect(
      () => db.saveTransaction('x', (tx) {
        tx.execute(insertClass, ['c-new', 'Test', 'test-new']);
        throw ArgumentError('boom');
      }),
      throwsArgumentError,
    );
    expect(historyCount(db), before);
    expect(classCount(db), classes);
    // ignore: invalid_use_of_internal_member
    expect(db.handle.autocommit, isTrue);
  });

  test('duplicate export_key surfaces DuplicateExportKey and rolls back', () {
    final db = fixture().openFixture();
    final before = historyCount(db);
    expect(
      () => db.saveTransaction('x', (tx) {
        tx.execute(insertClass, ['c-a', 'A', 'dup-key']);
        tx.execute(insertClass, ['c-b', 'B', 'dup-key']);
      }),
      throwsA(isA<DuplicateExportKey>()),
    );
    expect(historyCount(db), before);
    expect(
      db.read(
        (tx) => tx.select("SELECT 1 FROM classes WHERE export_key = 'dup-key'"),
      ),
      isEmpty,
    );
  });

  test('other SQLite failures become SaveFailed', () {
    final db = fixture().openFixture();
    expect(
      () => db.saveTransaction('x', (tx) => tx.execute('SELECT * FROM nope')),
      throwsA(isA<SaveFailed>()),
    );
  });

  test('core exceptions pass through unchanged', () {
    final db = fixture().openFixture();
    expect(
      () => db.saveTransaction(
        'x',
        (tx) => throw const RecordNotFound('items', 'i1'),
      ),
      throwsA(isA<RecordNotFound>()),
    );
  });

  test('history trims to 50, oldest first', () {
    final db = fixture().openFixture();
    db.saveTransaction('seed', (tx) {
      for (var i = 0; i < 60; i++) {
        tx.execute(
          'INSERT INTO save_history (saved_at, description, is_auto_save) '
          'VALUES (?, ?, 0)',
          [
            '2025-01-01 00:${(i ~/ 60).toString().padLeft(2, '0')}:'
                '${(i % 60).toString().padLeft(2, '0')}',
            'old $i',
          ],
        );
      }
    });
    expect(historyCount(db), 50);
    final rows = readRecentSaves(db);
    // The new row (now) is newest; the oldest surviving seed is old 11 or so.
    expect(rows.first.description, 'seed');
    expect(rows.any((r) => r.description == 'old 0'), isFalse);
    expect(rows.any((r) => r.description == 'old 59'), isTrue);
  });

  test(
    'readRecentSaves is newest first, converts savedAt and honours limit',
    () {
      final db = fixture().openFixture();
      db.saveTransaction('seed', (tx) {
        tx.execute(
          'INSERT INTO save_history (saved_at, description, is_auto_save) '
          "VALUES ('2099-11-01 14:00:00', 'future', 1)",
        );
      });
      final rows = readRecentSaves(db, limit: 2);
      expect(rows, hasLength(2));
      expect(rows.first.description, 'future');
      expect(rows.first.savedAt, '2099-11-01T14:00:00Z');
      expect(rows.first.isAutoSave, isTrue);
    },
  );

  test('nesting throws StateError', () {
    final db = fixture().openFixture();
    expect(
      () => db.saveTransaction('a', (tx) => db.saveTransaction('b', (_) {})),
      throwsStateError,
    );
    expect(
      () => db.read((_) => db.saveTransaction('b', (_) {})),
      throwsStateError,
    );
    // Usable afterwards.
    db.saveTransaction('ok', (_) {});
  });

  test('SaveScope is dead after the transaction', () {
    final db = fixture().openFixture();
    late SaveScope leaked;
    db.saveTransaction('x', (tx) => leaked = tx);
    expect(() => leaked.select('SELECT 1'), throwsStateError);
  });
}

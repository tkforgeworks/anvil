import 'package:anvil_core/anvil_core.dart';
import 'package:anvil_core/src/db/migrations/migration_runner.dart'
    show applyMigrations, jsIsoTimestamp;
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'support/fixture_copy.dart';

const _electronFilenames = [
  '001_init',
  '002_seed_meta_layer',
  '003_class_overrides_and_metadata',
  '004_ability_resource_type',
  '005_custom_templates',
  '006_stat_growth_formulas',
  '007_save_history',
];

final _jsIso = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$');

List<String> _appliedFilenames(ProjectDatabase db) => [
  for (final row in db.handle.select(
    'SELECT filename FROM schema_migrations ORDER BY rowid',
  ))
    row['filename'] as String,
];

int _schemaVersion(ProjectDatabase db) =>
    db.handle
            .select('SELECT schema_version FROM project_info WHERE id = 1')
            .single['schema_version']
        as int;

void main() {
  final fixture = FixtureCopy.setUpEach();

  test('the migration list matches Electron and the schema version', () {
    expect([for (final m in allMigrations) m.filename], _electronFilenames);
    expect(currentSchemaVersion, allMigrations.length);
    expect(currentSchemaVersion, 7);
  });

  test('the 0.1.6 fixture has no pending migrations and runMigrations is a '
      'no-op on it', () {
    final db = fixture().openFixture();
    expect(pendingMigrations(db), isEmpty);

    const migrationsSql = 'SELECT * FROM schema_migrations ORDER BY filename';
    const infoSql = 'SELECT * FROM project_info';
    final migrationsBefore = rowsOf(db.handle, migrationsSql);
    final infoBefore = rowsOf(db.handle, infoSql);
    expect(migrationsBefore, hasLength(7));

    runMigrations(db);

    expect(rowsOf(db.handle, migrationsSql), migrationsBefore);
    expect(rowsOf(db.handle, infoSql), infoBefore);
  });

  test('pendingMigrations on an empty file lists all seven and creates '
      'nothing', () {
    final db = fixture().openEmpty();
    expect(pendingMigrations(db), _electronFilenames);
    expect(db.handle.select('SELECT name FROM sqlite_master'), isEmpty);
  });

  test('a fresh file gets all seven migrations, JS ISO timestamps and '
      'schema version 7', () {
    final db = fixture().openEmpty();
    runMigrations(db);

    expect(_appliedFilenames(db), _electronFilenames);
    for (final row in db.handle.select(
      'SELECT applied_at FROM schema_migrations',
    )) {
      expect(row['applied_at'], matches(_jsIso));
    }
    expect(_schemaVersion(db), 7);
    expect(pendingMigrations(db), isEmpty);
    expect(db.handle.autocommit, isTrue);
  });

  test('a database at migration 4 gets only 5 to 7', () {
    final db = fixture().openEmpty();
    applyMigrations(db, allMigrations.take(4));
    const first4Sql = 'SELECT * FROM schema_migrations ORDER BY rowid';
    final first4 = rowsOf(db.handle, first4Sql);
    expect([for (final r in first4) r['filename']], _electronFilenames.take(4));
    expect(pendingMigrations(db), _electronFilenames.skip(4));

    runMigrations(db);

    final all = rowsOf(db.handle, first4Sql);
    expect(all.take(4), first4, reason: '1-4 must not be re-applied');
    expect([for (final r in all) r['filename']], _electronFilenames);
    expect(_schemaVersion(db), 7);
  });

  test('a failing 005 throws MigrationFailed, keeps 1-4 and rolls back', () {
    final db = fixture().openEmpty();
    db.handle.execute('CREATE TABLE custom_templates (other INTEGER)');

    Object? thrown;
    try {
      runMigrations(db);
    } catch (e) {
      thrown = e;
    }

    expect(thrown, isA<MigrationFailed>());
    expect(thrown, isNot(isA<SqliteException>()));
    final failure = thrown as MigrationFailed;
    expect(failure.filename, '005_custom_templates');
    expect(failure.cause, isA<SqliteException>());
    expect(failure.toString(), contains('005_custom_templates'));

    expect(_appliedFilenames(db), _electronFilenames.take(4));
    expect(db.handle.autocommit, isTrue);
    // Nothing after the failure ran, and the version update was skipped:
    // 002's upsert left it at 2.
    expect(
      db.handle.select(
        "SELECT name FROM sqlite_master WHERE name = 'save_history'",
      ),
      isEmpty,
    );
    expect(_schemaVersion(db), 2);
  });

  test('a failure in the runner bookkeeping is a MigrationFailed too', () {
    final path = fixture().pathFor('readonly.anvil');
    ProjectDatabase.open(path).close();
    final db = fixture().track(ProjectDatabase.openReadOnly(path));
    expect(
      () => runMigrations(db),
      throwsA(
        isA<MigrationFailed>().having(
          (e) => e.filename,
          'filename',
          'schema_migrations',
        ),
      ),
    );
  });

  test('001 copies a legacy project_meta row', () {
    final db = fixture().openEmpty();
    db.handle.execute('''
      CREATE TABLE project_meta (
        id INTEGER PRIMARY KEY, project_name TEXT, game_title TEXT,
        schema_version INTEGER, max_level INTEGER,
        created_at TEXT, updated_at TEXT
      );
      INSERT INTO project_meta VALUES
        (1, 'Old Project', 'Old Game', 1, 30, '2025-01-01 00:00:00',
         '2025-01-02 00:00:00');
    ''');

    runMigrations(db);

    final info = db.handle.select('SELECT * FROM project_info').single;
    expect(info['project_name'], 'Old Project');
    expect(info['game_title'], 'Old Game');
    expect(info['created_at'], '2025-01-01 00:00:00');
    // 002's upsert then resets these, as in Electron.
    expect(info['max_level'], 50);
    expect(info['schema_version'], 7);
  });

  test('jsIsoTimestamp prints JavaScript toISOString form in UTC', () {
    expect(
      jsIsoTimestamp(DateTime.utc(2026, 1, 2, 3, 4, 5, 6, 999)),
      '2026-01-02T03:04:05.006Z',
    );
    expect(jsIsoTimestamp(DateTime.now()), matches(_jsIso));
  });
}

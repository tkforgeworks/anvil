import 'package:meta/meta.dart';
import 'package:sqlite3/sqlite3.dart';

import '../errors.dart';
import '../project_database.dart';
import 'migration.dart';
import 'migrations.dart';

/// Same text as `runner.ts`, so the stored `sqlite_master.sql` matches.
const _createSchemaMigrations =
    '''\n    CREATE TABLE IF NOT EXISTS schema_migrations (
      filename   TEXT PRIMARY KEY,
      applied_at TEXT NOT NULL
    )
  ''';

/// The filenames in [allMigrations] not yet recorded in `schema_migrations`,
/// in order. Read-only: when the table does not exist every migration is
/// pending and nothing is created.
///
/// Throws [MigrationFailed] (filename `schema_migrations`) if the table
/// cannot be read.
List<String> pendingMigrations(ProjectDatabase db) {
  final applied = _guard('schema_migrations', () {
    final handle = db.handle;
    final exists = handle.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name = 'schema_migrations'",
    );
    return exists.isEmpty ? <String>{} : _appliedSet(handle);
  });
  return [
    for (final m in allMigrations)
      if (!applied.contains(m.filename)) m.filename,
  ];
}

/// Applies every pending migration, reproducing `runMigrations` in
/// `runner.ts`:
///
/// 1. `CREATE TABLE IF NOT EXISTS schema_migrations` (same SQL text).
/// 2. For each pending migration: `BEGIN`, `up`, `INSERT INTO
///    schema_migrations` with `applied_at` in JavaScript `toISOString()`
///    form, `COMMIT`; on any error `ROLLBACK` and throw [MigrationFailed],
///    leaving later migrations unapplied.
/// 3. If any migration ran, set `project_info.schema_version` to
///    [currentSchemaVersion] with `updated_at = datetime('now')`.
///
/// Never throws `SqliteException`; every failure is a [MigrationFailed].
/// Logging (Electron's `logInfo`/`logError`) is left to the caller, since
/// the core has no logger yet.
void runMigrations(ProjectDatabase db) => applyMigrations(db, allMigrations);

/// [runMigrations] over an explicit, ordered list instead of
/// [allMigrations], so tests can stop after migration N and compare with
/// Electron's state at that step. The version written to `project_info` is
/// still [currentSchemaVersion], exactly as `runner.ts` does it.
@visibleForTesting
void applyMigrations(ProjectDatabase db, Iterable<Migration> migrations) {
  final handle = db.handle;
  final applied = _guard('schema_migrations', () {
    handle.execute(_createSchemaMigrations);
    return _appliedSet(handle);
  });

  var ranAny = false;
  for (final migration in migrations) {
    if (applied.contains(migration.filename)) continue;

    try {
      handle.execute('BEGIN');
      migration.up(handle);
      handle.execute(
        'INSERT INTO schema_migrations (filename, applied_at) VALUES (?, ?)',
        [migration.filename, jsIsoTimestamp(DateTime.now())],
      );
      handle.execute('COMMIT');
      ranAny = true;
    } catch (cause) {
      _rollbackQuietly(handle);
      throw MigrationFailed(migration.filename, cause);
    }
  }

  if (ranAny) {
    _guard('project_info.schema_version', () {
      handle.execute(
        'UPDATE project_info SET schema_version = ?, '
        "updated_at = datetime('now') WHERE id = 1",
        [currentSchemaVersion],
      );
    });
  }
}

/// [time] in UTC as JavaScript's `Date.prototype.toISOString()` prints it:
/// `YYYY-MM-DDTHH:mm:ss.sssZ` (milliseconds, not Dart's microseconds).
@visibleForTesting
String jsIsoTimestamp(DateTime time) {
  final t = time.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)}'
      'T${two(t.hour)}:${two(t.minute)}:${two(t.second)}'
      '.${t.millisecond.toString().padLeft(3, '0')}Z';
}

Set<String> _appliedSet(Database handle) => {
  for (final row in handle.select('SELECT filename FROM schema_migrations'))
    row['filename'] as String,
};

T _guard<T>(String filename, T Function() body) {
  try {
    return body();
  } on MigrationFailed {
    rethrow;
  } catch (cause) {
    throw MigrationFailed(filename, cause);
  }
}

void _rollbackQuietly(Database handle) {
  if (handle.autocommit) return;
  try {
    handle.execute('ROLLBACK');
  } on SqliteException {
    // SQLite may already have rolled back (for example on SQLITE_FULL); the
    // original failure is what the caller needs.
  }
}

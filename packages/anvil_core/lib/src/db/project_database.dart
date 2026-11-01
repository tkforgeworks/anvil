import 'package:meta/meta.dart';
import 'package:sqlite3/sqlite3.dart';

import 'errors.dart';
import 'save_history.dart' show saveHistoryLimit;

/// `PRAGMA wal_checkpoint` modes.
enum CheckpointMode { passive, full, restart, truncate }

/// One open project file and the only owner of its `sqlite3` handle.
///
/// Opening sets the same pragmas as Electron's `connection.ts`. Opening does
/// not migrate; call `runMigrations` explicitly (the project lifecycle
/// decides when, and on a copy).
///
/// Errors: [open], [openReadOnly], [snapshot], [checkpoint] and [read] may
/// still propagate `SqliteException`; the project-lifecycle ticket
/// (ANVL-182) wraps those at its layer. [integrityCheck] never does, and
/// neither does the migration runner.
final class ProjectDatabase {
  ProjectDatabase._(this._db, this.path);

  /// Opens [path] read-write, creating the file if absent, and runs
  /// `PRAGMA journal_mode = WAL` then `PRAGMA foreign_keys = ON`, in
  /// Electron's order.
  factory ProjectDatabase.open(String path) {
    final db = sqlite3.open(path);
    try {
      db.execute('PRAGMA journal_mode = WAL');
      db.execute('PRAGMA foreign_keys = ON');
    } catch (_) {
      db.close();
      rethrow;
    }
    return ProjectDatabase._(db, path);
  }

  /// Opens [path] with `OpenMode.readOnly` and `PRAGMA foreign_keys = ON`
  /// (it is per connection, so background readers set it too).
  ///
  /// `journal_mode` is not set: WAL is persisted in the file header by the
  /// read-write connection that created it, and a read-only handle reads
  /// that mode as is. Checked against the bundled SQLite: on a read-only
  /// handle `PRAGMA journal_mode = WAL` is a no-op returning `wal` for a WAL
  /// file, and fails with SQLITE_READONLY (8) for a rollback-journal file
  /// (such as the 0.1.6 fixture, whose header says `delete`), so it is
  /// never run here.
  factory ProjectDatabase.openReadOnly(String path) {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      db.execute('PRAGMA foreign_keys = ON');
    } catch (_) {
      db.close();
      rethrow;
    }
    return ProjectDatabase._(db, path);
  }

  final Database _db;
  bool _open = true;
  bool _inTransaction = false;

  /// The file this handle was opened on.
  final String path;

  bool get isOpen => _open;

  /// The raw handle, for the `Sqlite*Repository` classes and the migration
  /// runner inside `anvil_core` only. It is `@internal`, so code outside
  /// this package (the app) gets an analyzer warning if it touches it: no
  /// `sqlite3` type crosses the repository boundary.
  @internal
  Database get handle {
    _checkOpen();
    return _db;
  }

  /// Closes the handle. Safe to call more than once.
  void close() {
    if (!_open) return;
    _open = false;
    _db.close();
  }

  /// Runs `PRAGMA integrity_check`. Passes on a single `ok` row; anything
  /// else, or any error while checking, throws [IntegrityCheckFailed].
  void integrityCheck() {
    final List<String> rows;
    try {
      rows = [
        for (final row in handle.select('PRAGMA integrity_check'))
          '${row.values.first}',
      ];
    } catch (e) {
      throw IntegrityCheckFailed('$e');
    }
    if (rows.length == 1 && rows.single == 'ok') return;
    throw IntegrityCheckFailed(
      rows.isEmpty ? 'integrity_check returned no rows' : rows.join('\n'),
    );
  }

  /// Writes a consistent copy of the database to [path] with
  /// `VACUUM INTO ?`, including anything still in the `-wal` file. This is
  /// the only sanctioned way to copy a project: a plain file copy of an open
  /// WAL database can miss committed pages. [path] must not exist.
  void snapshot(String path) {
    handle.execute('VACUUM INTO ?', [path]);
  }

  /// Runs `PRAGMA wal_checkpoint(MODE)`.
  void checkpoint(CheckpointMode mode) {
    handle.execute('PRAGMA wal_checkpoint(${mode.name.toUpperCase()})');
  }

  /// Runs [body] in a deferred read transaction (`BEGIN` ... `COMMIT`), so
  /// several queries see one consistent state. Rolls back and rethrows if
  /// [body] throws. The [ReadScope] is only valid inside [body].
  T read<T>(T Function(ReadScope tx) body) {
    final db = handle;
    if (_inTransaction) {
      throw StateError('read called inside another transaction');
    }
    _inTransaction = true;
    try {
      db.execute('BEGIN');
      final scope = ReadScope._(db);
      try {
        final result = body(scope);
        db.execute('COMMIT');
        return result;
      } catch (_) {
        if (!db.autocommit) db.execute('ROLLBACK');
        rethrow;
      } finally {
        scope._db = null;
      }
    } finally {
      _inTransaction = false;
    }
  }

  /// Runs [body] in one `BEGIN IMMEDIATE` transaction and records the change
  /// as one `save_history` row ([description], `is_auto_save = 0`), trimming
  /// the history to [saveHistoryLimit] rows as 0.1.6 does. Commits when
  /// [body] returns; on any throw rolls back and rethrows.
  ///
  /// A `SqliteException` from [body] never escapes: a `UNIQUE` failure on
  /// `export_key` becomes [DuplicateExportKey], anything else [SaveFailed].
  /// Core exception types pass through unchanged. Synchronous like [read];
  /// the `Future`s live on the repository interfaces. Nesting (inside
  /// another [saveTransaction] or [read]) throws [StateError].
  T saveTransaction<T>(String description, T Function(SaveScope tx) body) {
    final db = handle;
    if (_inTransaction) {
      throw StateError('saveTransaction called inside another transaction');
    }
    _inTransaction = true;
    final scope = SaveScope._(db);
    try {
      db.execute('BEGIN IMMEDIATE');
      try {
        final result = body(scope);
        db.execute(
          'INSERT INTO save_history (saved_at, description, is_auto_save) '
          "VALUES (datetime('now'), ?, 0)",
          [description],
        );
        _trimSaveHistory(db);
        db.execute('COMMIT');
        return result;
      } catch (e) {
        if (!db.autocommit) db.execute('ROLLBACK');
        if (e is SqliteException) throw _mapSaveError(e);
        rethrow;
      }
    } finally {
      scope._db = null;
      _inTransaction = false;
    }
  }

  static void _trimSaveHistory(Database db) {
    final count =
        db.select('SELECT COUNT(*) AS cnt FROM save_history').first['cnt']
            as int;
    if (count > saveHistoryLimit) {
      db.execute(
        'DELETE FROM save_history WHERE id IN ('
        'SELECT id FROM save_history ORDER BY saved_at ASC LIMIT ?)',
        [count - saveHistoryLimit],
      );
    }
  }

  static Exception _mapSaveError(SqliteException e) {
    final message = e.message;
    if (message.contains('UNIQUE constraint failed') &&
        message.contains('export_key')) {
      // SQLite names the column, never the value, so the key is unknown.
      return const DuplicateExportKey(null);
    }
    return SaveFailed(message, e);
  }

  void _checkOpen() {
    if (!_open) throw StateError('ProjectDatabase is closed: $path');
  }
}

/// Query access inside [ProjectDatabase.read]: `SELECT` only.
final class ReadScope {
  ReadScope._(this._db);

  Database? _db;

  ResultSet select(String sql, [List<Object?> parameters = const []]) {
    final db = _db;
    if (db == null) {
      throw StateError('ReadScope used outside its read transaction');
    }
    return db.select(sql, parameters);
  }
}

/// Read and write access inside [ProjectDatabase.saveTransaction]. Domain
/// code writes `datetime('now')` itself.
final class SaveScope {
  SaveScope._(this._db);

  Database? _db;

  Database get _live {
    final db = _db;
    if (db == null) {
      throw StateError('SaveScope used outside its save transaction');
    }
    return db;
  }

  ResultSet select(String sql, [List<Object?> parameters = const []]) =>
      _live.select(sql, parameters);

  void execute(String sql, [List<Object?> parameters = const []]) =>
      _live.execute(sql, parameters);

  /// Rows changed by the most recent statement, so a save can require
  /// exactly one updated row.
  int get changes => _live.updatedRows;
}

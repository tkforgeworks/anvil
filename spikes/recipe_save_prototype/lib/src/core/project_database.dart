/// The open project file, plus the one save transaction every record editor
/// goes through.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'recipe_repository.dart';

/// Thrown by the debug fault hook right before COMMIT.
final class ForcedSaveFailure implements Exception {
  const ForcedSaveFailure();
  @override
  String toString() => 'Forced save failure (debug toggle), rolled back.';
}

final class ProjectDatabase implements SaveHistoryReader {
  ProjectDatabase._(this.db, this.path);

  /// Opens [path] the way the Electron app does (`connection.ts`): WAL
  /// journal and foreign keys on.
  factory ProjectDatabase.open(String path) {
    final db = sqlite3.open(path);
    db.execute('PRAGMA foreign_keys = ON');
    db.select('PRAGMA journal_mode = WAL');
    return ProjectDatabase._(db, path);
  }

  /// Copies [sourcePath] into [workDir] and opens the copy. The source file
  /// is never opened, so it cannot be modified.
  ///
  /// A plain file copy is only safe while no other process has the source
  /// open: a live WAL-mode database can hold committed pages in its `-wal`
  /// sidecar. See FINDINGS.md.
  factory ProjectDatabase.openCopy(
    String sourcePath, {
    required Directory workDir,
  }) {
    final target = p.join(workDir.path, p.basename(sourcePath));
    File(sourcePath).copySync(target);
    return ProjectDatabase.open(target);
  }

  /// Raw handle, for repositories in this layer only. Editors never see it.
  final Database db;
  final String path;

  /// Debug fault injection: when this returns true, [saveTransaction] throws
  /// [ForcedSaveFailure] after every write and before COMMIT.
  bool Function()? debugFailBeforeCommit;

  /// Same cap as the Electron `save-history-service.ts`.
  static const int maxHistoryEntries = 50;

  /// Runs [body] and records one save-history row in a single transaction.
  ///
  /// ```
  /// BEGIN IMMEDIATE
  ///   body()                      -- the record's own writes
  ///   INSERT INTO save_history     -- one row per record save
  ///   DELETE oldest beyond 50
  ///   (debug fault hook)
  /// COMMIT                        -- or ROLLBACK on any throw
  /// ```
  T saveTransaction<T>(
    String description,
    T Function() body, {
    bool isAutoSave = false,
  }) {
    db.execute('BEGIN IMMEDIATE');
    try {
      final result = body();
      db.execute(
        'INSERT INTO save_history (saved_at, description, is_auto_save) '
        "VALUES (datetime('now'), ?, ?)",
        [description, isAutoSave ? 1 : 0],
      );
      db.execute(
        'DELETE FROM save_history WHERE id NOT IN '
        '(SELECT id FROM save_history ORDER BY saved_at DESC, id DESC LIMIT ?)',
        [maxHistoryEntries],
      );
      if (debugFailBeforeCommit?.call() ?? false) {
        throw const ForcedSaveFailure();
      }
      db.execute('COMMIT');
      return result;
    } catch (_) {
      // COMMIT itself can fail (SQLITE_BUSY, disk full) and leave the
      // transaction open; autocommit is false exactly while one is open.
      if (!db.autocommit) {
        db.execute('ROLLBACK');
      }
      rethrow;
    }
  }

  @override
  Future<List<SaveHistoryEntry>> recentSaves({int limit = 5}) async {
    final rows = db.select(
      'SELECT id, saved_at, description, is_auto_save FROM save_history '
      'ORDER BY saved_at DESC, id DESC LIMIT ?',
      [limit],
    );
    return [
      for (final row in rows)
        SaveHistoryEntry(
          id: row['id'] as int,
          savedAt: row['saved_at'] as String,
          description: row['description'] as String,
          isAutoSave: row['is_auto_save'] == 1,
        ),
    ];
  }

  void close() => db.close();
}

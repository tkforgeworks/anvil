// Ported verbatim from src/main/db/migrations/007_save_history.ts (Electron 0.1.6).
// The SQL text is the Electron template literal byte for byte, so the text
// SQLite stores in sqlite_master matches files created by 0.1.x.
import 'package:sqlite3/sqlite3.dart';

import 'migration.dart';

/// `007_save_history`: the `save_history` table (its AUTOINCREMENT also creates
/// `sqlite_sequence`).
const m007SaveHistory = Migration('007_save_history', _up);

void _up(Database db) {
  db.execute('''\n    CREATE TABLE IF NOT EXISTS save_history (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      saved_at    TEXT NOT NULL DEFAULT (datetime('now')),
      description TEXT NOT NULL DEFAULT '',
      is_auto_save INTEGER NOT NULL DEFAULT 0
    )
  ''');
}

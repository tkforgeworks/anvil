// Ported verbatim from src/main/db/migrations/006_stat_growth_formulas.ts (Electron 0.1.6).
// The SQL text is the Electron template literal byte for byte, so the text
// SQLite stores in sqlite_master matches files created by 0.1.x.
import 'package:sqlite3/sqlite3.dart';

import 'migration.dart';

/// `006_stat_growth_formulas`: formula-mode stat growth per class and stat.
const m006StatGrowthFormulas = Migration('006_stat_growth_formulas', _up);

void _up(Database db) {
  db.execute('''\n    CREATE TABLE IF NOT EXISTS class_stat_growth_formulas (
      class_id   TEXT NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
      stat_id    TEXT NOT NULL REFERENCES stats(id) ON DELETE CASCADE,
      formula    TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      PRIMARY KEY (class_id, stat_id)
    )
  ''');
}

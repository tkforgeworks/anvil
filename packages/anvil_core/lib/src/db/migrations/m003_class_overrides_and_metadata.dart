// Ported verbatim from src/main/db/migrations/003_class_overrides_and_metadata.ts (Electron 0.1.6).
// The SQL text is the Electron template literal byte for byte, so the text
// SQLite stores in sqlite_master matches files created by 0.1.x.
import 'package:sqlite3/sqlite3.dart';

import 'migration.dart';

/// `003_class_overrides_and_metadata`: per-class derived stat overrides and class metadata fields.
const m003ClassOverridesAndMetadata = Migration(
  '003_class_overrides_and_metadata',
  _up,
);

void _up(Database db) {
  db.execute('''\n    CREATE TABLE IF NOT EXISTS class_derived_stat_overrides (
      class_id        TEXT NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
      derived_stat_id TEXT NOT NULL REFERENCES derived_stat_definitions(id) ON DELETE CASCADE,
      formula         TEXT NOT NULL,
      created_at      TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at      TEXT NOT NULL DEFAULT (datetime('now')),
      PRIMARY KEY (class_id, derived_stat_id)
    );

    CREATE TABLE IF NOT EXISTS class_metadata_fields (
      class_id  TEXT NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
      field_key TEXT NOT NULL,
      value     REAL NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      PRIMARY KEY (class_id, field_key)
    );
  ''');
}

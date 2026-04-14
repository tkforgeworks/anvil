import type { DbConnection } from '../connection'

export function up(db: DbConnection): void {
  db.exec(`
    CREATE TABLE IF NOT EXISTS class_derived_stat_overrides (
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
  `)
}

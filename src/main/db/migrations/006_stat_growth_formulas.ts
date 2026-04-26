import type { DbConnection } from '../connection'

export function up(db: DbConnection): void {
  db.exec(`
    CREATE TABLE IF NOT EXISTS class_stat_growth_formulas (
      class_id   TEXT NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
      stat_id    TEXT NOT NULL REFERENCES stats(id) ON DELETE CASCADE,
      formula    TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      PRIMARY KEY (class_id, stat_id)
    )
  `)
}

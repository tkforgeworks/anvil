import type { DbConnection } from '../connection'

/**
 * Initial migration — establishes the project metadata table.
 * Full domain schema is applied in the Data Model & Schema Foundation epic.
 */
export function up(db: DbConnection): void {
  db.exec(`
    CREATE TABLE IF NOT EXISTS project_meta (
      id          INTEGER PRIMARY KEY CHECK (id = 1),
      project_name   TEXT    NOT NULL DEFAULT '',
      game_title     TEXT    NOT NULL DEFAULT '',
      schema_version INTEGER NOT NULL DEFAULT 1,
      max_level      INTEGER NOT NULL DEFAULT 50,
      created_at     TEXT    NOT NULL DEFAULT (datetime('now')),
      updated_at     TEXT    NOT NULL DEFAULT (datetime('now'))
    )
  `)
}

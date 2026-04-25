import type { DbConnection } from '../connection'

export function up(db: DbConnection): void {
  db.exec(`
    CREATE TABLE custom_templates (
      id          TEXT PRIMARY KEY,
      name        TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      template_source TEXT NOT NULL DEFAULT '',
      format      TEXT NOT NULL DEFAULT 'text',
      created_at  TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
    )
  `)
}

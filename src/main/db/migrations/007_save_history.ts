import type { DbConnection } from '../connection'

export function up(db: DbConnection): void {
  db.exec(`
    CREATE TABLE IF NOT EXISTS save_history (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      saved_at    TEXT NOT NULL DEFAULT (datetime('now')),
      description TEXT NOT NULL DEFAULT '',
      is_auto_save INTEGER NOT NULL DEFAULT 0
    )
  `)
}

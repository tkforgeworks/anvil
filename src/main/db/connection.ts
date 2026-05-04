import Database from 'better-sqlite3'
import { logDebug } from '../logging/app-logger'

export type DbConnection = Database.Database

let _db: DbConnection | null = null

/**
 * Opens a better-sqlite3 database at the given path and stores it as the
 * module-level singleton. Call this once during app startup (or when a project
 * is opened). All domain handlers obtain the connection via getDb().
 *
 * Enables WAL mode for atomic write semantics (PRD §8.2).
 * Enables foreign key enforcement.
 *
 * @throws If the file cannot be opened or created.
 */
export function openDatabase(filePath: string): DbConnection {
  const db = new Database(filePath)

  db.pragma('journal_mode = WAL')
  db.pragma('foreign_keys = ON')

  _db = db
  logDebug(`Database opened: ${filePath}`)
  return db
}

/**
 * Returns the active database connection.
 * @throws If openDatabase has not been called yet.
 */
export function getDb(): DbConnection {
  if (!_db) {
    throw new Error('Database not initialised. Call openDatabase() before accessing the database.')
  }
  return _db
}

/**
 * Closes the database connection cleanly and clears the singleton.
 * Safe to call if the connection is already closed.
 */
export function closeDatabase(db: DbConnection): void {
  if (db.open) {
    db.close()
  }
  _db = null
  logDebug('Database closed')
}

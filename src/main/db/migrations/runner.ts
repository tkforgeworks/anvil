import type { DbConnection } from '../connection'
import * as migration001 from './001_init'
import * as migration002 from './002_seed_meta_layer'

interface Migration {
  version: number
  filename: string
  up: (db: DbConnection) => void
}

/**
 * All migrations in version order.
 * Add new migrations here as the schema evolves.
 */
const MIGRATIONS: Migration[] = [
  { version: 1, filename: '001_init', up: migration001.up },
  { version: 2, filename: '002_seed_meta_layer', up: migration002.up },
]

export const CURRENT_SCHEMA_VERSION = MIGRATIONS.length

/**
 * Applies any pending migrations to the database.
 *
 * On first run, creates the schema_migrations tracking table.
 * Already-applied migrations are skipped.
 * Each migration runs inside a transaction — a failure rolls back cleanly.
 *
 * @throws {MigrationError} If a migration fails to apply.
 */
export function runMigrations(db: DbConnection): void {
  db.exec(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      filename   TEXT PRIMARY KEY,
      applied_at TEXT NOT NULL
    )
  `)

  const applied = new Set(
    (db.prepare('SELECT filename FROM schema_migrations').all() as { filename: string }[]).map(
      (row) => row.filename,
    ),
  )

  const insertApplied = db.prepare(
    'INSERT INTO schema_migrations (filename, applied_at) VALUES (?, ?)',
  )

  for (const migration of MIGRATIONS) {
    if (applied.has(migration.filename)) continue

    const apply = db.transaction(() => {
      migration.up(db)
      insertApplied.run(migration.filename, new Date().toISOString())
    })

    try {
      apply()
    } catch (cause) {
      throw new MigrationError(migration.filename, cause)
    }
  }

  db.prepare('UPDATE project_info SET schema_version = ?, updated_at = datetime(\'now\') WHERE id = 1').run(
    CURRENT_SCHEMA_VERSION,
  )
}

export class MigrationError extends Error {
  constructor(
    public readonly migrationFilename: string,
    cause: unknown,
  ) {
    super(`Migration failed: ${migrationFilename}`, { cause })
    this.name = 'MigrationError'
  }
}

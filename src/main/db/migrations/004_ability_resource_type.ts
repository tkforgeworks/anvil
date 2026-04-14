import type { DbConnection } from '../connection'

/**
 * Adds resource_type to the abilities table.
 */
export function up(db: DbConnection): void {
  db.exec(`
    ALTER TABLE abilities ADD COLUMN resource_type TEXT NOT NULL DEFAULT '';
  `)
}

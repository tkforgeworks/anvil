import { getDb, type DbConnection } from '../db/connection'

export type DomainTableName = 'classes' | 'abilities' | 'items' | 'recipes' | 'npcs' | 'loot_tables'

export interface DomainRecordRow {
  id: string
  displayName: string
  exportKey: string
  description: string
  createdAt: string
  updatedAt: string
  deletedAt: string | null
}

export interface UpdateDomainIdentityInput {
  displayName: string
  exportKey: string
  description?: string
}

interface DomainRecordDbRow {
  id: string
  display_name: string
  export_key: string
  description: string
  created_at: string
  updated_at: string
  deleted_at: string | null
}

function toDomainRecord(row: DomainRecordDbRow): DomainRecordRow {
  return {
    id: row.id,
    displayName: row.display_name,
    exportKey: row.export_key,
    description: row.description,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    deletedAt: row.deleted_at,
  }
}

export class DomainRepository {
  constructor(
    protected readonly tableName: DomainTableName,
    protected readonly dbProvider: () => DbConnection = getDb,
  ) {}

  list(includeDeleted = false, deletedOnly = false): DomainRecordRow[] {
    const whereClause = deletedOnly
      ? 'WHERE deleted_at IS NOT NULL'
      : includeDeleted ? '' : 'WHERE deleted_at IS NULL'
    const rows = this.dbProvider()
      .prepare(
        `SELECT id, display_name, export_key, description, created_at, updated_at, deleted_at
         FROM ${this.tableName}
         ${whereClause}
         ORDER BY display_name COLLATE NOCASE`,
      )
      .all() as DomainRecordDbRow[]

    return rows.map(toDomainRecord)
  }

  get(id: string): DomainRecordRow | null {
    const row = this.dbProvider()
      .prepare(
        `SELECT id, display_name, export_key, description, created_at, updated_at, deleted_at
         FROM ${this.tableName}
         WHERE id = ?`,
      )
      .get(id) as DomainRecordDbRow | undefined

    return row ? toDomainRecord(row) : null
  }

  countActive(): number {
    const row = this.dbProvider()
      .prepare(`SELECT COUNT(*) AS count FROM ${this.tableName} WHERE deleted_at IS NULL`)
      .get() as { count: number }

    return row.count
  }

  updateIdentity(id: string, input: UpdateDomainIdentityInput): DomainRecordRow | null {
    this.dbProvider()
      .prepare(
        `UPDATE ${this.tableName}
         SET display_name = @displayName,
             export_key = @exportKey,
             description = @description,
             updated_at = datetime('now')
         WHERE id = @id`,
      )
      .run({
        id,
        displayName: input.displayName,
        exportKey: input.exportKey,
        description: input.description ?? '',
      })

    return this.get(id)
  }

  softDelete(id: string): void {
    this.dbProvider()
      .prepare(
        `UPDATE ${this.tableName}
         SET deleted_at = COALESCE(deleted_at, datetime('now')),
             updated_at = datetime('now')
         WHERE id = ?`,
      )
      .run(id)
  }

  restore(id: string): void {
    this.dbProvider()
      .prepare(
        `UPDATE ${this.tableName}
         SET deleted_at = NULL,
             updated_at = datetime('now')
         WHERE id = ?`,
      )
      .run(id)
  }

  hardDelete(id: string): void {
    this.dbProvider()
      .prepare(`DELETE FROM ${this.tableName} WHERE id = ?`)
      .run(id)
  }
}

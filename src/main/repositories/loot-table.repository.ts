import { randomUUID } from 'crypto'
import { getDb, type DbConnection } from '../db/connection'
import { DomainRepository } from './domain-repository'
import type {
  CreateLootTableEntryInput,
  CreateLootTableInput,
  LootTableEntry,
  LootTableRecord,
  UpdateLootTableInput,
} from '../../shared/domain-types'

interface LootTableDbRow {
  id: string
  display_name: string
  export_key: string
  description: string
  created_at: string
  updated_at: string
  deleted_at: string | null
}

interface LootTableEntryDbRow {
  id: string
  loot_table_id: string
  item_id: string
  weight: number
  quantity_min: number
  quantity_max: number
  conditional_flags: string
  sort_order: number
}

function toLootTableRecord(row: LootTableDbRow): LootTableRecord {
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

function toLootTableEntry(row: LootTableEntryDbRow): LootTableEntry {
  return {
    id: row.id,
    lootTableId: row.loot_table_id,
    itemId: row.item_id,
    weight: row.weight,
    quantityMin: row.quantity_min,
    quantityMax: row.quantity_max,
    conditionalFlags: JSON.parse(row.conditional_flags) as Record<string, unknown>,
    sortOrder: row.sort_order,
  }
}

const SELECT_COLS = `
  id, display_name, export_key, description,
  created_at, updated_at, deleted_at
`

export class LootTableRepository extends DomainRepository {
  constructor(dbProvider: () => DbConnection = getDb) {
    super('loot_tables', dbProvider)
  }

  override list(includeDeleted = false): LootTableRecord[] {
    const where = includeDeleted ? '' : 'WHERE deleted_at IS NULL'
    const rows = this.dbProvider()
      .prepare(
        `SELECT ${SELECT_COLS} FROM loot_tables ${where} ORDER BY display_name COLLATE NOCASE`,
      )
      .all() as LootTableDbRow[]
    return rows.map(toLootTableRecord)
  }

  override get(id: string): LootTableRecord | null {
    const row = this.dbProvider()
      .prepare(`SELECT ${SELECT_COLS} FROM loot_tables WHERE id = ?`)
      .get(id) as LootTableDbRow | undefined
    return row ? toLootTableRecord(row) : null
  }

  create(input: CreateLootTableInput): LootTableRecord {
    const id = randomUUID()
    this.dbProvider()
      .prepare(
        `INSERT INTO loot_tables (id, display_name, export_key, description)
         VALUES (@id, @displayName, @exportKey, @description)`,
      )
      .run({
        id,
        displayName: input.displayName,
        exportKey: input.exportKey,
        description: input.description ?? '',
      })
    return this.get(id)!
  }

  update(id: string, input: UpdateLootTableInput): LootTableRecord | null {
    const current = this.get(id)
    if (!current) return null
    this.dbProvider()
      .prepare(
        `UPDATE loot_tables
         SET display_name = @displayName,
             export_key   = @exportKey,
             description  = @description,
             updated_at   = datetime('now')
         WHERE id = @id`,
      )
      .run({
        id,
        displayName: input.displayName ?? current.displayName,
        exportKey: input.exportKey ?? current.exportKey,
        description: input.description ?? current.description,
      })
    return this.get(id)
  }

  getEntries(lootTableId: string): LootTableEntry[] {
    const rows = this.dbProvider()
      .prepare(
        `SELECT id, loot_table_id, item_id, weight,
                quantity_min, quantity_max, conditional_flags, sort_order
         FROM loot_table_entries
         WHERE loot_table_id = ?
         ORDER BY sort_order`,
      )
      .all(lootTableId) as LootTableEntryDbRow[]
    return rows.map(toLootTableEntry)
  }

  setEntries(lootTableId: string, entries: CreateLootTableEntryInput[]): LootTableEntry[] {
    const db = this.dbProvider()
    const del = db.prepare('DELETE FROM loot_table_entries WHERE loot_table_id = ?')
    const ins = db.prepare(
      `INSERT INTO loot_table_entries
         (id, loot_table_id, item_id, weight, quantity_min, quantity_max,
          conditional_flags, sort_order)
       VALUES
         (@id, @lootTableId, @itemId, @weight, @quantityMin, @quantityMax,
          @conditionalFlags, @sortOrder)`,
    )
    db.transaction(() => {
      del.run(lootTableId)
      for (const [index, e] of entries.entries()) {
        ins.run({
          id: randomUUID(),
          lootTableId,
          itemId: e.itemId,
          weight: e.weight,
          quantityMin: e.quantityMin ?? 1,
          quantityMax: e.quantityMax ?? 1,
          conditionalFlags: JSON.stringify(e.conditionalFlags ?? {}),
          sortOrder: e.sortOrder ?? index,
        })
      }
    })()
    return this.getEntries(lootTableId)
  }
}

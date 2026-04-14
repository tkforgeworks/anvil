import { randomUUID } from 'crypto'
import { getDb, type DbConnection } from '../db/connection'
import { DomainRepository } from './domain-repository'
import type {
  CreateItemInput,
  CustomFieldValue,
  ItemRecord,
  UpdateItemInput,
} from '../../shared/domain-types'

interface ItemDbRow {
  id: string
  display_name: string
  export_key: string
  description: string
  item_category_id: string
  rarity_id: string
  created_at: string
  updated_at: string
  deleted_at: string | null
}

interface CustomFieldValueDbRow {
  field_definition_id: string
  value: string | null
}

function toItemRecord(row: ItemDbRow): ItemRecord {
  return {
    id: row.id,
    displayName: row.display_name,
    exportKey: row.export_key,
    description: row.description,
    itemCategoryId: row.item_category_id,
    rarityId: row.rarity_id,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    deletedAt: row.deleted_at,
  }
}

const SELECT_COLS = `
  id, display_name, export_key, description,
  item_category_id, rarity_id,
  created_at, updated_at, deleted_at
`

function slugify(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
}

export class ItemRepository extends DomainRepository {
  constructor(dbProvider: () => DbConnection = getDb) {
    super('items', dbProvider)
  }

  override list(includeDeleted = false): ItemRecord[] {
    const where = includeDeleted ? '' : 'WHERE deleted_at IS NULL'
    const rows = this.dbProvider()
      .prepare(
        `SELECT ${SELECT_COLS} FROM items ${where} ORDER BY display_name COLLATE NOCASE`,
      )
      .all() as ItemDbRow[]
    return rows.map(toItemRecord)
  }

  override get(id: string): ItemRecord | null {
    const row = this.dbProvider()
      .prepare(`SELECT ${SELECT_COLS} FROM items WHERE id = ?`)
      .get(id) as ItemDbRow | undefined
    return row ? toItemRecord(row) : null
  }

  create(input: CreateItemInput): ItemRecord {
    const id = randomUUID()
    this.dbProvider()
      .prepare(
        `INSERT INTO items
           (id, display_name, export_key, description, item_category_id, rarity_id)
         VALUES
           (@id, @displayName, @exportKey, @description, @itemCategoryId, @rarityId)`,
      )
      .run({
        id,
        displayName: input.displayName,
        exportKey: input.exportKey,
        description: input.description ?? '',
        itemCategoryId: input.itemCategoryId,
        rarityId: input.rarityId,
      })
    return this.get(id)!
  }

  duplicate(id: string): ItemRecord | null {
    const source = this.get(id)
    if (!source) return null

    const newId = randomUUID()
    const newDisplayName = `${source.displayName} (Copy)`
    const newExportKey = `${slugify(newDisplayName)}-${randomUUID().slice(0, 8)}`
    const db = this.dbProvider()

    db.transaction(() => {
      db.prepare(
        `INSERT INTO items
           (id, display_name, export_key, description, item_category_id, rarity_id)
         VALUES
           (@id, @displayName, @exportKey, @description, @itemCategoryId, @rarityId)`,
      ).run({
        id: newId,
        displayName: newDisplayName,
        exportKey: newExportKey,
        description: source.description,
        itemCategoryId: source.itemCategoryId,
        rarityId: source.rarityId,
      })

      const values = this.getCustomFieldValues(source.id)
      const ins = db.prepare(
        `INSERT INTO custom_field_values (domain, record_id, field_definition_id, value)
         VALUES ('items', @recordId, @fieldDefinitionId, @value)`,
      )
      for (const value of values) {
        ins.run({
          recordId: newId,
          fieldDefinitionId: value.fieldDefinitionId,
          value: value.value,
        })
      }
    })()

    return this.get(newId)!
  }

  update(id: string, input: UpdateItemInput): ItemRecord | null {
    const current = this.get(id)
    if (!current) return null
    this.dbProvider()
      .prepare(
        `UPDATE items
         SET display_name      = @displayName,
             export_key        = @exportKey,
             description       = @description,
             item_category_id  = @itemCategoryId,
             rarity_id         = @rarityId,
             updated_at        = datetime('now')
         WHERE id = @id`,
      )
      .run({
        id,
        displayName: input.displayName ?? current.displayName,
        exportKey: input.exportKey ?? current.exportKey,
        description: input.description ?? current.description,
        itemCategoryId: input.itemCategoryId ?? current.itemCategoryId,
        rarityId: input.rarityId ?? current.rarityId,
      })
    return this.get(id)
  }

  override hardDelete(id: string): void {
    const db = this.dbProvider()
    db.transaction(() => {
      db.prepare(
        `DELETE FROM custom_field_values WHERE domain = 'items' AND record_id = ?`,
      ).run(id)
      db.prepare('DELETE FROM items WHERE id = ?').run(id)
    })()
  }

  getCustomFieldValues(itemId: string): CustomFieldValue[] {
    const rows = this.dbProvider()
      .prepare(
        `SELECT field_definition_id, value
         FROM custom_field_values
         WHERE domain = 'items' AND record_id = ?`,
      )
      .all(itemId) as CustomFieldValueDbRow[]
    return rows.map((r) => ({
      fieldDefinitionId: r.field_definition_id,
      value: r.value,
    }))
  }

  setCustomFieldValues(itemId: string, values: CustomFieldValue[]): void {
    const db = this.dbProvider()
    const del = db.prepare(
      `DELETE FROM custom_field_values WHERE domain = 'items' AND record_id = ?`,
    )
    const ins = db.prepare(
      `INSERT INTO custom_field_values (domain, record_id, field_definition_id, value)
       VALUES ('items', @recordId, @fieldDefinitionId, @value)
       ON CONFLICT (domain, record_id, field_definition_id)
       DO UPDATE SET value = excluded.value, updated_at = datetime('now')`,
    )
    db.transaction(() => {
      del.run(itemId)
      for (const v of values) {
        ins.run({ recordId: itemId, fieldDefinitionId: v.fieldDefinitionId, value: v.value })
      }
    })()
  }
}

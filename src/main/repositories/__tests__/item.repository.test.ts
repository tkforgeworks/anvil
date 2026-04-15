import Database from 'better-sqlite3'
import { describe, it, expect, beforeEach } from 'vitest'
import { runMigrations } from '../../db/migrations/runner'
import { ItemRepository } from '../item.repository'

// These IDs are seeded by migration002
const CATEGORY_ID = 'item-category-weapon'
const ARMOR_CATEGORY_ID = 'item-category-armor'
const RARITY_ID = 'rarity-common'

function makeDb(): Database.Database {
  const db = new Database(':memory:')
  db.pragma('foreign_keys = ON')
  runMigrations(db)
  return db
}

describe('ItemRepository', () => {
  let db: Database.Database
  let repo: ItemRepository

  beforeEach(() => {
    db = makeDb()
    repo = new ItemRepository(() => db)
  })

  // ── create + get ─────────────────────────────────────────────────────────

  it('create: returns the record and makes it retrievable via get', () => {
    const record = repo.create({
      displayName: 'Iron Sword',
      exportKey: 'iron_sword',
      itemCategoryId: CATEGORY_ID,
      rarityId: RARITY_ID,
    })

    expect(record.id).toBeTruthy()
    expect(record.displayName).toBe('Iron Sword')
    expect(record.itemCategoryId).toBe(CATEGORY_ID)
    expect(record.rarityId).toBe(RARITY_ID)
    expect(record.deletedAt).toBeNull()

    const fetched = repo.get(record.id)
    expect(fetched).not.toBeNull()
    expect(fetched!.id).toBe(record.id)
  })

  it('get: returns null for a non-existent id', () => {
    expect(repo.get('does-not-exist')).toBeNull()
  })

  // ── list ─────────────────────────────────────────────────────────────────

  it('list: active record appears in default list', () => {
    repo.create({ displayName: 'Iron Sword', exportKey: 'iron_sword', itemCategoryId: CATEGORY_ID, rarityId: RARITY_ID })
    expect(repo.list()).toHaveLength(1)
  })

  it('list: soft-deleted record is excluded by default', () => {
    const record = repo.create({ displayName: 'Iron Sword', exportKey: 'iron_sword', itemCategoryId: CATEGORY_ID, rarityId: RARITY_ID })
    repo.softDelete(record.id)
    expect(repo.list()).toHaveLength(0)
  })

  it('list: soft-deleted record appears when includeDeleted is true', () => {
    const record = repo.create({ displayName: 'Iron Sword', exportKey: 'iron_sword', itemCategoryId: CATEGORY_ID, rarityId: RARITY_ID })
    repo.softDelete(record.id)
    expect(repo.list(true)).toHaveLength(1)
  })

  // ── update ───────────────────────────────────────────────────────────────

  it('update: persists changed fields', () => {
    const record = repo.create({ displayName: 'Iron Sword', exportKey: 'iron_sword', itemCategoryId: CATEGORY_ID, rarityId: RARITY_ID })
    const updated = repo.update(record.id, { displayName: 'Steel Sword', exportKey: 'steel_sword', itemCategoryId: CATEGORY_ID, rarityId: RARITY_ID })
    expect(updated!.displayName).toBe('Steel Sword')
    expect(updated!.exportKey).toBe('steel_sword')
  })

  it('update: unspecified fields retain their previous values', () => {
    const record = repo.create({
      displayName: 'Iron Sword',
      exportKey: 'iron_sword',
      itemCategoryId: CATEGORY_ID,
      rarityId: RARITY_ID,
      description: 'A basic sword',
    })
    // description is not passed in the update
    const updated = repo.update(record.id, { displayName: 'Steel Sword', exportKey: record.exportKey, itemCategoryId: CATEGORY_ID, rarityId: RARITY_ID })
    expect(updated!.description).toBe('A basic sword')
  })

  it('update: returns null for a non-existent id', () => {
    expect(repo.update('does-not-exist', { displayName: 'X', exportKey: 'x', itemCategoryId: CATEGORY_ID, rarityId: RARITY_ID })).toBeNull()
  })

  // ── duplicate ────────────────────────────────────────────────────────────

  it('duplicate: creates an active copy with a new id and regenerated export key', () => {
    const record = repo.create({
      displayName: 'Iron Sword',
      exportKey: 'iron_sword',
      itemCategoryId: CATEGORY_ID,
      rarityId: RARITY_ID,
      description: 'A basic sword',
    })

    const copy = repo.duplicate(record.id)

    expect(copy).not.toBeNull()
    expect(copy!.id).not.toBe(record.id)
    expect(copy!.displayName).toBe('Iron Sword (Copy)')
    expect(copy!.exportKey).toMatch(/^iron-sword-copy-[a-f0-9]{8}$/)
    expect(copy!.description).toBe('A basic sword')
    expect(copy!.itemCategoryId).toBe(record.itemCategoryId)
    expect(copy!.rarityId).toBe(record.rarityId)
    expect(copy!.deletedAt).toBeNull()
    expect(repo.list()).toHaveLength(2)
  })

  it('duplicate: copies custom field values to the new item', () => {
    const record = repo.create({
      displayName: 'Iron Sword',
      exportKey: 'iron_sword',
      itemCategoryId: CATEGORY_ID,
      rarityId: RARITY_ID,
    })
    db.prepare(
      `INSERT INTO custom_field_definitions (id, scope_type, scope_id, field_name, field_type, sort_order)
       VALUES ('cfd-damage', 'item_category', '${CATEGORY_ID}', 'damage', 'integer', 1)`,
    ).run()
    repo.setCustomFieldValues(record.id, [{ fieldDefinitionId: 'cfd-damage', value: '50' }])

    const copy = repo.duplicate(record.id)

    expect(copy).not.toBeNull()
    expect(repo.getCustomFieldValues(copy!.id)).toEqual([
      { fieldDefinitionId: 'cfd-damage', value: '50' },
    ])
  })

  it('duplicate: ignores stale custom field values outside the current category', () => {
    const record = repo.create({
      displayName: 'Iron Sword',
      exportKey: 'iron_sword',
      itemCategoryId: CATEGORY_ID,
      rarityId: RARITY_ID,
    })
    db.prepare(
      `INSERT INTO custom_field_definitions (id, scope_type, scope_id, field_name, field_type, sort_order)
       VALUES ('cfd-damage', 'item_category', '${CATEGORY_ID}', 'damage', 'integer', 1)`,
    ).run()
    db.prepare(
      `INSERT INTO custom_field_definitions (id, scope_type, scope_id, field_name, field_type, sort_order)
       VALUES ('cfd-defense', 'item_category', '${ARMOR_CATEGORY_ID}', 'defense', 'integer', 1)`,
    ).run()
    repo.setCustomFieldValues(record.id, [
      { fieldDefinitionId: 'cfd-damage', value: '50' },
      { fieldDefinitionId: 'cfd-defense', value: '20' },
    ])

    const copy = repo.duplicate(record.id)

    expect(copy).not.toBeNull()
    expect(repo.getCustomFieldValues(copy!.id)).toEqual([
      { fieldDefinitionId: 'cfd-damage', value: '50' },
    ])
  })

  it('duplicate: returns null for a non-existent id', () => {
    expect(repo.duplicate('does-not-exist')).toBeNull()
  })

  // ── softDelete + restore ─────────────────────────────────────────────────

  it('softDelete: sets deletedAt and excludes record from default list', () => {
    const record = repo.create({ displayName: 'Iron Sword', exportKey: 'iron_sword', itemCategoryId: CATEGORY_ID, rarityId: RARITY_ID })
    repo.softDelete(record.id)

    expect(repo.get(record.id)!.deletedAt).not.toBeNull()
    expect(repo.list()).toHaveLength(0)
  })

  it('restore: clears deletedAt and record reappears in default list', () => {
    const record = repo.create({ displayName: 'Iron Sword', exportKey: 'iron_sword', itemCategoryId: CATEGORY_ID, rarityId: RARITY_ID })
    repo.softDelete(record.id)
    repo.restore(record.id)

    expect(repo.get(record.id)!.deletedAt).toBeNull()
    expect(repo.list()).toHaveLength(1)
  })

  // ── custom field values sub-table ────────────────────────────────────────

  it('getCustomFieldValues: returns empty array before any values are set', () => {
    const record = repo.create({ displayName: 'Iron Sword', exportKey: 'iron_sword', itemCategoryId: CATEGORY_ID, rarityId: RARITY_ID })
    expect(repo.getCustomFieldValues(record.id)).toEqual([])
  })

  it('setCustomFieldValues / getCustomFieldValues: round-trips values', () => {
    const record = repo.create({ displayName: 'Iron Sword', exportKey: 'iron_sword', itemCategoryId: CATEGORY_ID, rarityId: RARITY_ID })
    db.prepare(
      `INSERT INTO custom_field_definitions (id, scope_type, scope_id, field_name, field_type, sort_order)
       VALUES ('cfd-damage', 'item_category', '${CATEGORY_ID}', 'damage', 'integer', 1)`,
    ).run()

    const values = [{ fieldDefinitionId: 'cfd-damage', value: '50' }]
    repo.setCustomFieldValues(record.id, values)
    expect(repo.getCustomFieldValues(record.id)).toEqual(values)
  })

  it('setCustomFieldValues: replaces existing values on re-set', () => {
    const record = repo.create({ displayName: 'Iron Sword', exportKey: 'iron_sword', itemCategoryId: CATEGORY_ID, rarityId: RARITY_ID })
    db.prepare(
      `INSERT INTO custom_field_definitions (id, scope_type, scope_id, field_name, field_type, sort_order)
       VALUES ('cfd-damage', 'item_category', '${CATEGORY_ID}', 'damage', 'integer', 1)`,
    ).run()

    repo.setCustomFieldValues(record.id, [{ fieldDefinitionId: 'cfd-damage', value: '30' }])
    repo.setCustomFieldValues(record.id, [{ fieldDefinitionId: 'cfd-damage', value: '75' }])

    const result = repo.getCustomFieldValues(record.id)
    expect(result).toHaveLength(1)
    expect(result[0].value).toBe('75')
  })

  it('update: changing item category removes custom field values outside the new category', () => {
    const record = repo.create({
      displayName: 'Iron Sword',
      exportKey: 'iron_sword',
      itemCategoryId: CATEGORY_ID,
      rarityId: RARITY_ID,
    })
    db.prepare(
      `INSERT INTO custom_field_definitions (id, scope_type, scope_id, field_name, field_type, sort_order)
       VALUES ('cfd-damage', 'item_category', '${CATEGORY_ID}', 'damage', 'integer', 1)`,
    ).run()
    db.prepare(
      `INSERT INTO custom_field_definitions (id, scope_type, scope_id, field_name, field_type, sort_order)
       VALUES ('cfd-defense', 'item_category', '${ARMOR_CATEGORY_ID}', 'defense', 'integer', 1)`,
    ).run()
    repo.setCustomFieldValues(record.id, [
      { fieldDefinitionId: 'cfd-damage', value: '50' },
      { fieldDefinitionId: 'cfd-defense', value: '20' },
    ])

    repo.update(record.id, { itemCategoryId: ARMOR_CATEGORY_ID })

    expect(repo.getCustomFieldValues(record.id)).toEqual([
      { fieldDefinitionId: 'cfd-defense', value: '20' },
    ])
  })
})

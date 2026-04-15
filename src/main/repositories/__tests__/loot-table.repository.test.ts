import Database from 'better-sqlite3'
import { describe, it, expect, beforeEach } from 'vitest'
import { runMigrations } from '../../db/migrations/runner'
import { ItemRepository } from '../item.repository'
import { LootTableRepository } from '../loot-table.repository'

const CATEGORY_ID = 'item-category-weapon'
const RARITY_ID = 'rarity-common'

function makeDb(): Database.Database {
  const db = new Database(':memory:')
  db.pragma('foreign_keys = ON')
  runMigrations(db)
  return db
}

describe('LootTableRepository', () => {
  let db: Database.Database
  let repo: LootTableRepository

  beforeEach(() => {
    db = makeDb()
    repo = new LootTableRepository(() => db)
  })

  // ── create + get ─────────────────────────────────────────────────────────

  it('create: returns the record and makes it retrievable via get', () => {
    const record = repo.create({ displayName: 'Goblin Drops', exportKey: 'goblin_drops' })

    expect(record.id).toBeTruthy()
    expect(record.displayName).toBe('Goblin Drops')
    expect(record.exportKey).toBe('goblin_drops')
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
    repo.create({ displayName: 'Goblin Drops', exportKey: 'goblin_drops' })
    expect(repo.list()).toHaveLength(1)
  })

  it('list: soft-deleted record is excluded by default', () => {
    const record = repo.create({ displayName: 'Goblin Drops', exportKey: 'goblin_drops' })
    repo.softDelete(record.id)
    expect(repo.list()).toHaveLength(0)
  })

  it('list: soft-deleted record appears when includeDeleted is true', () => {
    const record = repo.create({ displayName: 'Goblin Drops', exportKey: 'goblin_drops' })
    repo.softDelete(record.id)
    expect(repo.list(true)).toHaveLength(1)
  })

  // ── update ───────────────────────────────────────────────────────────────

  it('update: persists changed fields', () => {
    const record = repo.create({ displayName: 'Goblin Drops', exportKey: 'goblin_drops' })
    const updated = repo.update(record.id, { displayName: 'Goblin Elite Drops', exportKey: 'goblin_elite_drops' })
    expect(updated!.displayName).toBe('Goblin Elite Drops')
    expect(updated!.exportKey).toBe('goblin_elite_drops')
  })

  it('update: unspecified fields retain their previous values', () => {
    const record = repo.create({
      displayName: 'Goblin Drops',
      exportKey: 'goblin_drops',
      description: 'Standard goblin loot',
    })
    // description not passed
    const updated = repo.update(record.id, { displayName: 'Goblin Drops', exportKey: record.exportKey })
    expect(updated!.description).toBe('Standard goblin loot')
  })

  it('update: returns null for a non-existent id', () => {
    expect(repo.update('does-not-exist', { displayName: 'X', exportKey: 'x' })).toBeNull()
  })

  it('duplicate: copies the loot table and all entries with a new id', () => {
    const table = repo.create({ displayName: 'Goblin Drops', exportKey: 'goblin_drops', description: 'Standard goblin loot' })
    const itemRepo = new ItemRepository(() => db)
    const item = itemRepo.create({
      displayName: 'Goblin Ear',
      exportKey: 'goblin_ear',
      itemCategoryId: CATEGORY_ID,
      rarityId: RARITY_ID,
    })
    repo.setEntries(table.id, [
      {
        itemId: item.id,
        weight: 10,
        quantityMin: 1,
        quantityMax: 3,
        conditionalFlags: { text: 'night' },
        sortOrder: 0,
      },
    ])

    const copy = repo.duplicate(table.id)

    expect(copy).not.toBeNull()
    expect(copy!.id).not.toBe(table.id)
    expect(copy!.displayName).toBe('Goblin Drops (Copy)')
    expect(copy!.exportKey).toBe('goblin-drops-copy')
    expect(copy!.description).toBe('Standard goblin loot')

    const copiedEntries = repo.getEntries(copy!.id)
    expect(copiedEntries).toHaveLength(1)
    expect(copiedEntries[0]).toMatchObject({
      itemId: item.id,
      weight: 10,
      quantityMin: 1,
      quantityMax: 3,
      conditionalFlags: { text: 'night' },
      sortOrder: 0,
    })
  })

  it('duplicate: returns null for a non-existent id', () => {
    expect(repo.duplicate('does-not-exist')).toBeNull()
  })

  // ── softDelete + restore ─────────────────────────────────────────────────

  it('softDelete: sets deletedAt and excludes record from default list', () => {
    const record = repo.create({ displayName: 'Goblin Drops', exportKey: 'goblin_drops' })
    repo.softDelete(record.id)

    expect(repo.get(record.id)!.deletedAt).not.toBeNull()
    expect(repo.list()).toHaveLength(0)
  })

  it('restore: clears deletedAt and record reappears in default list', () => {
    const record = repo.create({ displayName: 'Goblin Drops', exportKey: 'goblin_drops' })
    repo.softDelete(record.id)
    repo.restore(record.id)

    expect(repo.get(record.id)!.deletedAt).toBeNull()
    expect(repo.list()).toHaveLength(1)
  })

  // ── loot table entries sub-table ──────────────────────────────────────────

  it('getEntries: returns empty array before any entries are set', () => {
    const table = repo.create({ displayName: 'Goblin Drops', exportKey: 'goblin_drops' })
    expect(repo.getEntries(table.id)).toEqual([])
  })

  it('setEntries / getEntries: round-trips entries', () => {
    const table = repo.create({ displayName: 'Goblin Drops', exportKey: 'goblin_drops' })
    const itemRepo = new ItemRepository(() => db)
    const item = itemRepo.create({
      displayName: 'Goblin Ear',
      exportKey: 'goblin_ear',
      itemCategoryId: CATEGORY_ID,
      rarityId: RARITY_ID,
    })

    const entries = repo.setEntries(table.id, [
      { itemId: item.id, weight: 10, quantityMin: 1, quantityMax: 3, sortOrder: 0 },
    ])

    expect(entries).toHaveLength(1)
    expect(entries[0].itemId).toBe(item.id)
    expect(entries[0].weight).toBe(10)
    expect(entries[0].quantityMin).toBe(1)
    expect(entries[0].quantityMax).toBe(3)

    expect(repo.getEntries(table.id)).toHaveLength(1)
  })

  it('setEntries: replaces existing entries on re-set', () => {
    const table = repo.create({ displayName: 'Goblin Drops', exportKey: 'goblin_drops' })
    const itemRepo = new ItemRepository(() => db)
    const item1 = itemRepo.create({ displayName: 'Goblin Ear', exportKey: 'goblin_ear', itemCategoryId: CATEGORY_ID, rarityId: RARITY_ID })
    const item2 = itemRepo.create({ displayName: 'Goblin Tooth', exportKey: 'goblin_tooth', itemCategoryId: CATEGORY_ID, rarityId: RARITY_ID })

    repo.setEntries(table.id, [{ itemId: item1.id, weight: 10, sortOrder: 0 }])
    repo.setEntries(table.id, [{ itemId: item2.id, weight: 5, sortOrder: 0 }])

    const result = repo.getEntries(table.id)
    expect(result).toHaveLength(1)
    expect(result[0].itemId).toBe(item2.id)
    expect(result[0].weight).toBe(5)
  })

  it('setEntries: normalizes weight and quantity bounds to positive integers', () => {
    const table = repo.create({ displayName: 'Goblin Drops', exportKey: 'goblin_drops' })
    const itemRepo = new ItemRepository(() => db)
    const item = itemRepo.create({ displayName: 'Goblin Ear', exportKey: 'goblin_ear', itemCategoryId: CATEGORY_ID, rarityId: RARITY_ID })

    const result = repo.setEntries(table.id, [{ itemId: item.id, weight: 0, quantityMin: 4, quantityMax: 2 }])

    expect(result[0].weight).toBe(1)
    expect(result[0].quantityMin).toBe(4)
    expect(result[0].quantityMax).toBe(4)
  })
})

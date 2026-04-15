import Database from 'better-sqlite3'
import { describe, it, expect, beforeEach } from 'vitest'
import { runMigrations } from '../../db/migrations/runner'
import { ItemRepository } from '../item.repository'
import { RecipeRepository } from '../recipe.repository'

// Seeded IDs used to create the prerequisite item
const CATEGORY_ID = 'item-category-weapon'
const RARITY_ID = 'rarity-common'
const STATION_ID = 'crafting-station-forge'

function makeDb(): Database.Database {
  const db = new Database(':memory:')
  db.pragma('foreign_keys = ON')
  runMigrations(db)
  return db
}

describe('RecipeRepository', () => {
  let db: Database.Database
  let repo: RecipeRepository
  let outputItemId: string

  beforeEach(() => {
    db = makeDb()
    repo = new RecipeRepository(() => db)

    // recipes.output_item_id references items(id) — create a prerequisite item
    const itemRepo = new ItemRepository(() => db)
    outputItemId = itemRepo.create({
      displayName: 'Iron Sword',
      exportKey: 'iron_sword',
      itemCategoryId: CATEGORY_ID,
      rarityId: RARITY_ID,
    }).id
  })

  // ── create + get ─────────────────────────────────────────────────────────

  it('create: returns the record and makes it retrievable via get', () => {
    const record = repo.create({
      displayName: 'Forge Iron Sword',
      exportKey: 'forge_iron_sword',
      outputItemId,
      outputQuantity: 1,
    })

    expect(record.id).toBeTruthy()
    expect(record.displayName).toBe('Forge Iron Sword')
    expect(record.outputItemId).toBe(outputItemId)
    expect(record.outputQuantity).toBe(1)
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
    repo.create({ displayName: 'Forge Iron Sword', exportKey: 'forge_iron_sword', outputItemId, outputQuantity: 1 })
    expect(repo.list()).toHaveLength(1)
  })

  it('list: soft-deleted record is excluded by default', () => {
    const record = repo.create({ displayName: 'Forge Iron Sword', exportKey: 'forge_iron_sword', outputItemId, outputQuantity: 1 })
    repo.softDelete(record.id)
    expect(repo.list()).toHaveLength(0)
  })

  it('list: soft-deleted record appears when includeDeleted is true', () => {
    const record = repo.create({ displayName: 'Forge Iron Sword', exportKey: 'forge_iron_sword', outputItemId, outputQuantity: 1 })
    repo.softDelete(record.id)
    expect(repo.list(true)).toHaveLength(1)
  })

  // ── update ───────────────────────────────────────────────────────────────

  it('update: persists changed fields', () => {
    const record = repo.create({
      displayName: 'Forge Iron Sword',
      exportKey: 'forge_iron_sword',
      outputItemId,
      outputQuantity: 1,
    })
    const updated = repo.update(record.id, {
      displayName: 'Forge Iron Sword x2',
      exportKey: 'forge_iron_sword_x2',
      outputItemId,
      outputQuantity: 2,
    })
    expect(updated!.displayName).toBe('Forge Iron Sword x2')
    expect(updated!.outputQuantity).toBe(2)
  })

  it('update: unspecified fields retain their previous values', () => {
    const record = repo.create({
      displayName: 'Forge Iron Sword',
      exportKey: 'forge_iron_sword',
      outputItemId,
      outputQuantity: 3,
      craftingStationId: STATION_ID,
    })
    // craftingStationId not passed
    const updated = repo.update(record.id, { displayName: 'Updated', exportKey: record.exportKey, outputItemId })
    expect(updated!.outputQuantity).toBe(3)
    expect(updated!.craftingStationId).toBe(STATION_ID)
  })

  it('update: returns null for a non-existent id', () => {
    expect(repo.update('does-not-exist', { displayName: 'X', exportKey: 'x', outputItemId })).toBeNull()
  })

  // ── duplicate ────────────────────────────────────────────────────────────

  it('duplicate: creates an active copy with a new id and regenerated export key', () => {
    const record = repo.create({
      displayName: 'Forge Iron Sword',
      exportKey: 'forge_iron_sword',
      outputItemId,
      outputQuantity: 2,
      craftingStationId: STATION_ID,
    })

    const copy = repo.duplicate(record.id)

    expect(copy).not.toBeNull()
    expect(copy!.id).not.toBe(record.id)
    expect(copy!.displayName).toBe('Forge Iron Sword (Copy)')
    expect(copy!.exportKey).toMatch(/^forge-iron-sword-copy-[a-f0-9]{8}$/)
    expect(copy!.outputItemId).toBe(record.outputItemId)
    expect(copy!.outputQuantity).toBe(2)
    expect(copy!.craftingStationId).toBe(STATION_ID)
    expect(copy!.deletedAt).toBeNull()
  })

  it('duplicate: copies ingredient references by internal id', () => {
    const record = repo.create({
      displayName: 'Forge Iron Sword',
      exportKey: 'forge_iron_sword',
      outputItemId,
      outputQuantity: 1,
    })
    const itemRepo = new ItemRepository(() => db)
    const ingredientItem = itemRepo.create({
      displayName: 'Iron Ore',
      exportKey: 'iron_ore',
      itemCategoryId: 'item-category-crafting-resource',
      rarityId: RARITY_ID,
    })
    const ingredients = [{ itemId: ingredientItem.id, quantity: 3, sortOrder: 0 }]
    repo.setIngredients(record.id, ingredients)

    const copy = repo.duplicate(record.id)

    expect(copy).not.toBeNull()
    expect(repo.getIngredients(copy!.id)).toEqual(ingredients)
  })

  it('duplicate: returns null for a non-existent id', () => {
    expect(repo.duplicate('does-not-exist')).toBeNull()
  })

  // ── softDelete + restore ─────────────────────────────────────────────────

  it('softDelete: sets deletedAt and excludes record from default list', () => {
    const record = repo.create({ displayName: 'Forge Iron Sword', exportKey: 'forge_iron_sword', outputItemId, outputQuantity: 1 })
    repo.softDelete(record.id)

    expect(repo.get(record.id)!.deletedAt).not.toBeNull()
    expect(repo.list()).toHaveLength(0)
  })

  it('restore: clears deletedAt and record reappears in default list', () => {
    const record = repo.create({ displayName: 'Forge Iron Sword', exportKey: 'forge_iron_sword', outputItemId, outputQuantity: 1 })
    repo.softDelete(record.id)
    repo.restore(record.id)

    expect(repo.get(record.id)!.deletedAt).toBeNull()
    expect(repo.list()).toHaveLength(1)
  })

  // ── ingredients sub-table ─────────────────────────────────────────────────

  it('getIngredients: returns empty array before any entries are set', () => {
    const record = repo.create({ displayName: 'Forge Iron Sword', exportKey: 'forge_iron_sword', outputItemId, outputQuantity: 1 })
    expect(repo.getIngredients(record.id)).toEqual([])
  })

  it('setIngredients / getIngredients: round-trips ingredient entries', () => {
    const record = repo.create({ displayName: 'Forge Iron Sword', exportKey: 'forge_iron_sword', outputItemId, outputQuantity: 1 })

    // Create a second item to use as an ingredient
    const itemRepo = new ItemRepository(() => db)
    const ingredientItem = itemRepo.create({
      displayName: 'Iron Ore',
      exportKey: 'iron_ore',
      itemCategoryId: 'item-category-crafting-resource',
      rarityId: RARITY_ID,
    })

    const ingredients = [{ itemId: ingredientItem.id, quantity: 3, sortOrder: 0 }]
    repo.setIngredients(record.id, ingredients)
    expect(repo.getIngredients(record.id)).toEqual(ingredients)
  })

  it('setIngredients: replaces existing entries on re-set', () => {
    const record = repo.create({ displayName: 'Forge Iron Sword', exportKey: 'forge_iron_sword', outputItemId, outputQuantity: 1 })
    const itemRepo = new ItemRepository(() => db)
    const ing1 = itemRepo.create({ displayName: 'Iron Ore', exportKey: 'iron_ore', itemCategoryId: 'item-category-crafting-resource', rarityId: RARITY_ID })
    const ing2 = itemRepo.create({ displayName: 'Coal', exportKey: 'coal', itemCategoryId: 'item-category-crafting-resource', rarityId: RARITY_ID })

    repo.setIngredients(record.id, [{ itemId: ing1.id, quantity: 5, sortOrder: 0 }])
    repo.setIngredients(record.id, [{ itemId: ing2.id, quantity: 2, sortOrder: 0 }])

    const result = repo.getIngredients(record.id)
    expect(result).toHaveLength(1)
    expect(result[0].itemId).toBe(ing2.id)
  })
})

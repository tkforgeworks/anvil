import { randomUUID } from 'crypto'
import { getDb, type DbConnection } from '../db/connection'
import { DomainRepository } from './domain-repository'
import type {
  CreateRecipeInput,
  RecipeIngredient,
  RecipeRecord,
  UpdateRecipeInput,
} from '../../shared/domain-types'

interface RecipeDbRow {
  id: string
  display_name: string
  export_key: string
  description: string
  output_item_id: string
  output_quantity: number
  crafting_station_id: string | null
  crafting_specialization_id: string | null
  created_at: string
  updated_at: string
  deleted_at: string | null
}

interface IngredientDbRow {
  item_id: string
  quantity: number
  sort_order: number
}

function toRecipeRecord(row: RecipeDbRow): RecipeRecord {
  return {
    id: row.id,
    displayName: row.display_name,
    exportKey: row.export_key,
    description: row.description,
    outputItemId: row.output_item_id,
    outputQuantity: row.output_quantity,
    craftingStationId: row.crafting_station_id,
    craftingSpecializationId: row.crafting_specialization_id,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    deletedAt: row.deleted_at,
  }
}

const SELECT_COLS = `
  id, display_name, export_key, description,
  output_item_id, output_quantity, crafting_station_id, crafting_specialization_id,
  created_at, updated_at, deleted_at
`

export class RecipeRepository extends DomainRepository {
  constructor(dbProvider: () => DbConnection = getDb) {
    super('recipes', dbProvider)
  }

  override list(includeDeleted = false): RecipeRecord[] {
    const where = includeDeleted ? '' : 'WHERE deleted_at IS NULL'
    const rows = this.dbProvider()
      .prepare(
        `SELECT ${SELECT_COLS} FROM recipes ${where} ORDER BY display_name COLLATE NOCASE`,
      )
      .all() as RecipeDbRow[]
    return rows.map(toRecipeRecord)
  }

  override get(id: string): RecipeRecord | null {
    const row = this.dbProvider()
      .prepare(`SELECT ${SELECT_COLS} FROM recipes WHERE id = ?`)
      .get(id) as RecipeDbRow | undefined
    return row ? toRecipeRecord(row) : null
  }

  create(input: CreateRecipeInput): RecipeRecord {
    const id = randomUUID()
    this.dbProvider()
      .prepare(
        `INSERT INTO recipes
           (id, display_name, export_key, description,
            output_item_id, output_quantity, crafting_station_id, crafting_specialization_id)
         VALUES
           (@id, @displayName, @exportKey, @description,
            @outputItemId, @outputQuantity, @craftingStationId, @craftingSpecializationId)`,
      )
      .run({
        id,
        displayName: input.displayName,
        exportKey: input.exportKey,
        description: input.description ?? '',
        outputItemId: input.outputItemId,
        outputQuantity: input.outputQuantity ?? 1,
        craftingStationId: input.craftingStationId ?? null,
        craftingSpecializationId: input.craftingSpecializationId ?? null,
      })
    return this.get(id)!
  }

  update(id: string, input: UpdateRecipeInput): RecipeRecord | null {
    const current = this.get(id)
    if (!current) return null
    this.dbProvider()
      .prepare(
        `UPDATE recipes
         SET display_name               = @displayName,
             export_key                 = @exportKey,
             description                = @description,
             output_item_id             = @outputItemId,
             output_quantity            = @outputQuantity,
             crafting_station_id        = @craftingStationId,
             crafting_specialization_id = @craftingSpecializationId,
             updated_at                 = datetime('now')
         WHERE id = @id`,
      )
      .run({
        id,
        displayName: input.displayName ?? current.displayName,
        exportKey: input.exportKey ?? current.exportKey,
        description: input.description ?? current.description,
        outputItemId: input.outputItemId ?? current.outputItemId,
        outputQuantity: input.outputQuantity ?? current.outputQuantity,
        // Use explicit undefined check so callers can pass null to clear the FK
        craftingStationId:
          input.craftingStationId !== undefined
            ? input.craftingStationId
            : current.craftingStationId,
        craftingSpecializationId:
          input.craftingSpecializationId !== undefined
            ? input.craftingSpecializationId
            : current.craftingSpecializationId,
      })
    return this.get(id)
  }

  getIngredients(recipeId: string): RecipeIngredient[] {
    const rows = this.dbProvider()
      .prepare(
        `SELECT item_id AS itemId, quantity, sort_order AS sortOrder
         FROM recipe_ingredients
         WHERE recipe_id = ?
         ORDER BY sort_order`,
      )
      .all(recipeId) as RecipeIngredient[]
    return rows
  }

  setIngredients(recipeId: string, ingredients: RecipeIngredient[]): void {
    const db = this.dbProvider()
    const del = db.prepare('DELETE FROM recipe_ingredients WHERE recipe_id = ?')
    const ins = db.prepare(
      `INSERT INTO recipe_ingredients (recipe_id, item_id, quantity, sort_order)
       VALUES (@recipeId, @itemId, @quantity, @sortOrder)`,
    )
    db.transaction(() => {
      del.run(recipeId)
      for (const ing of ingredients) {
        ins.run({
          recipeId,
          itemId: ing.itemId,
          quantity: ing.quantity,
          sortOrder: ing.sortOrder,
        })
      }
    })()
  }
}

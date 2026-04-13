import { randomUUID } from 'crypto'
import { getDb, type DbConnection } from '../db/connection'
import { DomainRepository } from './domain-repository'
import type {
  AbilityRecord,
  CreateAbilityInput,
  UpdateAbilityInput,
} from '../../shared/domain-types'

interface AbilityDbRow {
  id: string
  display_name: string
  export_key: string
  description: string
  ability_type: string
  resource_cost: number
  cooldown: number
  stat_modifiers_json: string
  created_at: string
  updated_at: string
  deleted_at: string | null
}

function toAbilityRecord(row: AbilityDbRow): AbilityRecord {
  return {
    id: row.id,
    displayName: row.display_name,
    exportKey: row.export_key,
    description: row.description,
    abilityType: row.ability_type,
    resourceCost: row.resource_cost,
    cooldown: row.cooldown,
    statModifiers: JSON.parse(row.stat_modifiers_json) as Record<string, number>,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    deletedAt: row.deleted_at,
  }
}

const SELECT_COLS = `
  id, display_name, export_key, description,
  ability_type, resource_cost, cooldown, stat_modifiers_json,
  created_at, updated_at, deleted_at
`

export class AbilityRepository extends DomainRepository {
  constructor(dbProvider: () => DbConnection = getDb) {
    super('abilities', dbProvider)
  }

  override list(includeDeleted = false): AbilityRecord[] {
    const where = includeDeleted ? '' : 'WHERE deleted_at IS NULL'
    const rows = this.dbProvider()
      .prepare(
        `SELECT ${SELECT_COLS} FROM abilities ${where} ORDER BY display_name COLLATE NOCASE`,
      )
      .all() as AbilityDbRow[]
    return rows.map(toAbilityRecord)
  }

  override get(id: string): AbilityRecord | null {
    const row = this.dbProvider()
      .prepare(`SELECT ${SELECT_COLS} FROM abilities WHERE id = ?`)
      .get(id) as AbilityDbRow | undefined
    return row ? toAbilityRecord(row) : null
  }

  create(input: CreateAbilityInput): AbilityRecord {
    const id = randomUUID()
    this.dbProvider()
      .prepare(
        `INSERT INTO abilities
           (id, display_name, export_key, description,
            ability_type, resource_cost, cooldown, stat_modifiers_json)
         VALUES
           (@id, @displayName, @exportKey, @description,
            @abilityType, @resourceCost, @cooldown, @statModifiersJson)`,
      )
      .run({
        id,
        displayName: input.displayName,
        exportKey: input.exportKey,
        description: input.description ?? '',
        abilityType: input.abilityType ?? '',
        resourceCost: input.resourceCost ?? 0,
        cooldown: input.cooldown ?? 0,
        statModifiersJson: JSON.stringify(input.statModifiers ?? {}),
      })
    return this.get(id)!
  }

  update(id: string, input: UpdateAbilityInput): AbilityRecord | null {
    const current = this.get(id)
    if (!current) return null
    this.dbProvider()
      .prepare(
        `UPDATE abilities
         SET display_name       = @displayName,
             export_key         = @exportKey,
             description        = @description,
             ability_type       = @abilityType,
             resource_cost      = @resourceCost,
             cooldown           = @cooldown,
             stat_modifiers_json = @statModifiersJson,
             updated_at         = datetime('now')
         WHERE id = @id`,
      )
      .run({
        id,
        displayName: input.displayName ?? current.displayName,
        exportKey: input.exportKey ?? current.exportKey,
        description: input.description ?? current.description,
        abilityType: input.abilityType ?? current.abilityType,
        resourceCost: input.resourceCost ?? current.resourceCost,
        cooldown: input.cooldown ?? current.cooldown,
        statModifiersJson: JSON.stringify(input.statModifiers ?? current.statModifiers),
      })
    return this.get(id)
  }
}

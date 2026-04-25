import { randomUUID } from 'crypto'
import { getDb, type DbConnection } from '../db/connection'
import { DomainRepository } from './domain-repository'
import type {
  CreateNpcInput,
  CustomFieldValue,
  NpcAbilityAssignment,
  NpcClassAssignment,
  NpcRecord,
  UpdateNpcInput,
} from '../../shared/domain-types'

interface NpcDbRow {
  id: string
  display_name: string
  export_key: string
  description: string
  npc_type_id: string
  loot_table_id: string | null
  combat_stats_json: string
  created_at: string
  updated_at: string
  deleted_at: string | null
}

interface CustomFieldValueDbRow {
  field_definition_id: string
  value: string | null
}

function toNpcRecord(row: NpcDbRow): NpcRecord {
  return {
    id: row.id,
    displayName: row.display_name,
    exportKey: row.export_key,
    description: row.description,
    npcTypeId: row.npc_type_id,
    lootTableId: row.loot_table_id,
    combatStats: JSON.parse(row.combat_stats_json) as Record<string, number | null>,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    deletedAt: row.deleted_at,
  }
}

const SELECT_COLS = `
  id, display_name, export_key, description,
  npc_type_id, loot_table_id, combat_stats_json,
  created_at, updated_at, deleted_at
`

function slugify(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
}

export class NpcRepository extends DomainRepository {
  constructor(dbProvider: () => DbConnection = getDb) {
    super('npcs', dbProvider)
  }

  override list(includeDeleted = false, deletedOnly = false): NpcRecord[] {
    const where = deletedOnly
      ? 'WHERE deleted_at IS NOT NULL'
      : includeDeleted ? '' : 'WHERE deleted_at IS NULL'
    const rows = this.dbProvider()
      .prepare(
        `SELECT ${SELECT_COLS} FROM npcs ${where} ORDER BY display_name COLLATE NOCASE`,
      )
      .all() as NpcDbRow[]
    return rows.map(toNpcRecord)
  }

  override get(id: string): NpcRecord | null {
    const row = this.dbProvider()
      .prepare(`SELECT ${SELECT_COLS} FROM npcs WHERE id = ?`)
      .get(id) as NpcDbRow | undefined
    return row ? toNpcRecord(row) : null
  }

  create(input: CreateNpcInput): NpcRecord {
    const id = randomUUID()
    this.dbProvider()
      .prepare(
        `INSERT INTO npcs
           (id, display_name, export_key, description,
            npc_type_id, loot_table_id, combat_stats_json)
         VALUES
           (@id, @displayName, @exportKey, @description,
            @npcTypeId, @lootTableId, @combatStatsJson)`,
      )
      .run({
        id,
        displayName: input.displayName,
        exportKey: input.exportKey,
        description: input.description ?? '',
        npcTypeId: input.npcTypeId,
        lootTableId: input.lootTableId ?? null,
        combatStatsJson: JSON.stringify(input.combatStats ?? {}),
      })
    return this.get(id)!
  }

  duplicate(id: string): NpcRecord | null {
    const source = this.get(id)
    if (!source) return null

    const newId = randomUUID()
    const copyName = `${source.displayName} (Copy)`
    const db = this.dbProvider()

    db.transaction(() => {
      db.prepare(
        `INSERT INTO npcs
           (id, display_name, export_key, description,
            npc_type_id, loot_table_id, combat_stats_json)
         VALUES
           (@id, @displayName, @exportKey, @description,
            @npcTypeId, @lootTableId, @combatStatsJson)`,
      ).run({
        id: newId,
        displayName: copyName,
        exportKey: slugify(copyName),
        description: source.description,
        npcTypeId: source.npcTypeId,
        lootTableId: source.lootTableId,
        combatStatsJson: JSON.stringify(source.combatStats),
      })

      const classIns = db.prepare(
        `INSERT INTO npc_class_assignments (npc_id, class_id, level, sort_order)
         VALUES (@npcId, @classId, @level, @sortOrder)`,
      )
      for (const assignment of this.getClassAssignments(id)) {
        classIns.run({ npcId: newId, ...assignment })
      }

      const abilityIns = db.prepare(
        `INSERT INTO npc_ability_assignments (npc_id, ability_id, sort_order)
         VALUES (@npcId, @abilityId, @sortOrder)`,
      )
      for (const assignment of this.getAbilityAssignments(id)) {
        abilityIns.run({ npcId: newId, ...assignment })
      }

      const valueIns = db.prepare(
        `INSERT INTO custom_field_values (domain, record_id, field_definition_id, value)
         VALUES ('npcs', @recordId, @fieldDefinitionId, @value)`,
      )
      for (const value of this.getCustomFieldValues(id)) {
        valueIns.run({ recordId: newId, ...value })
      }
    })()

    return this.get(newId)!
  }

  update(id: string, input: UpdateNpcInput): NpcRecord | null {
    const current = this.get(id)
    if (!current) return null
    const npcTypeId = input.npcTypeId ?? current.npcTypeId
    const db = this.dbProvider()
    db.transaction(() => {
      db.prepare(
        `UPDATE npcs
           SET display_name      = @displayName,
               export_key        = @exportKey,
               description       = @description,
               npc_type_id       = @npcTypeId,
               loot_table_id     = @lootTableId,
               combat_stats_json = @combatStatsJson,
               updated_at        = datetime('now')
           WHERE id = @id`,
      ).run({
        id,
        displayName: input.displayName ?? current.displayName,
        exportKey: input.exportKey ?? current.exportKey,
        description: input.description ?? current.description,
        npcTypeId,
        lootTableId:
          input.lootTableId !== undefined ? input.lootTableId : current.lootTableId,
        combatStatsJson: JSON.stringify(input.combatStats ?? current.combatStats),
      })

      if (npcTypeId !== current.npcTypeId) {
        db.prepare(
          `DELETE FROM custom_field_values
           WHERE domain = 'npcs'
             AND record_id = ?
             AND field_definition_id NOT IN (
               SELECT id FROM custom_field_definitions
               WHERE scope_type = 'npc_type' AND scope_id = ?
             )`,
        ).run(id, npcTypeId)
      }
    })()
    return this.get(id)
  }

  override hardDelete(id: string): void {
    const db = this.dbProvider()
    db.transaction(() => {
      db.prepare(
        `DELETE FROM custom_field_values WHERE domain = 'npcs' AND record_id = ?`,
      ).run(id)
      db.prepare('DELETE FROM npcs WHERE id = ?').run(id)
    })()
  }

  getClassAssignments(npcId: string): NpcClassAssignment[] {
    const rows = this.dbProvider()
      .prepare(
        `SELECT class_id AS classId, level, sort_order AS sortOrder
         FROM npc_class_assignments
         WHERE npc_id = ?
         ORDER BY sort_order`,
      )
      .all(npcId) as NpcClassAssignment[]
    return rows
  }

  setClassAssignments(npcId: string, assignments: NpcClassAssignment[]): void {
    const db = this.dbProvider()
    const del = db.prepare('DELETE FROM npc_class_assignments WHERE npc_id = ?')
    const ins = db.prepare(
      `INSERT INTO npc_class_assignments (npc_id, class_id, level, sort_order)
       VALUES (@npcId, @classId, @level, @sortOrder)`,
    )
    db.transaction(() => {
      del.run(npcId)
      for (const a of assignments) {
        ins.run({ npcId, classId: a.classId, level: a.level, sortOrder: a.sortOrder })
      }
    })()
  }

  getAbilityAssignments(npcId: string): NpcAbilityAssignment[] {
    const rows = this.dbProvider()
      .prepare(
        `SELECT ability_id AS abilityId, sort_order AS sortOrder
         FROM npc_ability_assignments
         WHERE npc_id = ?
         ORDER BY sort_order`,
      )
      .all(npcId) as NpcAbilityAssignment[]
    return rows
  }

  setAbilityAssignments(npcId: string, assignments: NpcAbilityAssignment[]): void {
    const db = this.dbProvider()
    const del = db.prepare('DELETE FROM npc_ability_assignments WHERE npc_id = ?')
    const ins = db.prepare(
      `INSERT INTO npc_ability_assignments (npc_id, ability_id, sort_order)
       VALUES (@npcId, @abilityId, @sortOrder)`,
    )
    db.transaction(() => {
      del.run(npcId)
      for (const a of assignments) {
        ins.run({ npcId, abilityId: a.abilityId, sortOrder: a.sortOrder })
      }
    })()
  }

  getCustomFieldValues(npcId: string): CustomFieldValue[] {
    const rows = this.dbProvider()
      .prepare(
        `SELECT field_definition_id, value
         FROM custom_field_values
         WHERE domain = 'npcs' AND record_id = ?`,
      )
      .all(npcId) as CustomFieldValueDbRow[]
    return rows.map((r) => ({
      fieldDefinitionId: r.field_definition_id,
      value: r.value,
    }))
  }

  setCustomFieldValues(npcId: string, values: CustomFieldValue[]): void {
    const db = this.dbProvider()
    const del = db.prepare(
      `DELETE FROM custom_field_values WHERE domain = 'npcs' AND record_id = ?`,
    )
    const ins = db.prepare(
      `INSERT INTO custom_field_values (domain, record_id, field_definition_id, value)
       VALUES ('npcs', @recordId, @fieldDefinitionId, @value)
       ON CONFLICT (domain, record_id, field_definition_id)
       DO UPDATE SET value = excluded.value, updated_at = datetime('now')`,
    )
    db.transaction(() => {
      del.run(npcId)
      for (const v of values) {
        ins.run({ recordId: npcId, fieldDefinitionId: v.fieldDefinitionId, value: v.value })
      }
    })()
  }
}

import { randomUUID } from 'crypto'
import { getDb, type DbConnection } from '../db/connection'
import { DomainRepository } from './domain-repository'
import type {
  ClassRecord,
  ClassAbilityAssignment,
  CreateClassInput,
  StatGrowthEntry,
  UpdateClassInput,
} from '../../shared/domain-types'

interface ClassDbRow {
  id: string
  display_name: string
  export_key: string
  description: string
  resource_multiplier: number
  created_at: string
  updated_at: string
  deleted_at: string | null
}

function toClassRecord(row: ClassDbRow): ClassRecord {
  return {
    id: row.id,
    displayName: row.display_name,
    exportKey: row.export_key,
    description: row.description,
    resourceMultiplier: row.resource_multiplier,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    deletedAt: row.deleted_at,
  }
}

const SELECT_COLS = `
  id, display_name, export_key, description, resource_multiplier,
  created_at, updated_at, deleted_at
`

export class ClassRepository extends DomainRepository {
  constructor(dbProvider: () => DbConnection = getDb) {
    super('classes', dbProvider)
  }

  override list(includeDeleted = false): ClassRecord[] {
    const where = includeDeleted ? '' : 'WHERE deleted_at IS NULL'
    const rows = this.dbProvider()
      .prepare(
        `SELECT ${SELECT_COLS} FROM classes ${where} ORDER BY display_name COLLATE NOCASE`,
      )
      .all() as ClassDbRow[]
    return rows.map(toClassRecord)
  }

  override get(id: string): ClassRecord | null {
    const row = this.dbProvider()
      .prepare(`SELECT ${SELECT_COLS} FROM classes WHERE id = ?`)
      .get(id) as ClassDbRow | undefined
    return row ? toClassRecord(row) : null
  }

  duplicate(id: string): ClassRecord | null {
    const source = this.get(id)
    if (!source) return null
    const newId = randomUUID()
    const newDisplayName = `${source.displayName} (Copy)`
    const newExportKey = newDisplayName
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-|-$/g, '')
    this.dbProvider()
      .prepare(
        `INSERT INTO classes (id, display_name, export_key, description, resource_multiplier)
         VALUES (@id, @displayName, @exportKey, @description, @resourceMultiplier)`,
      )
      .run({
        id: newId,
        displayName: newDisplayName,
        exportKey: newExportKey,
        description: source.description,
        resourceMultiplier: source.resourceMultiplier,
      })
    const growthEntries = this.getStatGrowth(id)
    if (growthEntries.length > 0) this.setStatGrowth(newId, growthEntries)
    const assignments = this.getAbilityAssignments(id)
    if (assignments.length > 0) this.setAbilityAssignments(newId, assignments)
    return this.get(newId)!
  }

  create(input: CreateClassInput): ClassRecord {
    const id = randomUUID()
    this.dbProvider()
      .prepare(
        `INSERT INTO classes (id, display_name, export_key, description, resource_multiplier)
         VALUES (@id, @displayName, @exportKey, @description, @resourceMultiplier)`,
      )
      .run({
        id,
        displayName: input.displayName,
        exportKey: input.exportKey,
        description: input.description ?? '',
        resourceMultiplier: input.resourceMultiplier ?? 1,
      })
    return this.get(id)!
  }

  update(id: string, input: UpdateClassInput): ClassRecord | null {
    const current = this.get(id)
    if (!current) return null
    this.dbProvider()
      .prepare(
        `UPDATE classes
         SET display_name      = @displayName,
             export_key        = @exportKey,
             description       = @description,
             resource_multiplier = @resourceMultiplier,
             updated_at        = datetime('now')
         WHERE id = @id`,
      )
      .run({
        id,
        displayName: input.displayName ?? current.displayName,
        exportKey: input.exportKey ?? current.exportKey,
        description: input.description ?? current.description,
        resourceMultiplier: input.resourceMultiplier ?? current.resourceMultiplier,
      })
    return this.get(id)
  }

  getStatGrowth(classId: string): StatGrowthEntry[] {
    const rows = this.dbProvider()
      .prepare(
        `SELECT stat_id AS statId, level, value
         FROM class_stat_growth
         WHERE class_id = ?
         ORDER BY stat_id, level`,
      )
      .all(classId) as StatGrowthEntry[]
    return rows
  }

  setStatGrowth(classId: string, entries: StatGrowthEntry[]): void {
    const db = this.dbProvider()
    const del = db.prepare('DELETE FROM class_stat_growth WHERE class_id = ?')
    const ins = db.prepare(
      `INSERT INTO class_stat_growth (class_id, stat_id, level, value)
       VALUES (@classId, @statId, @level, @value)`,
    )
    db.transaction(() => {
      del.run(classId)
      for (const e of entries) {
        ins.run({ classId, statId: e.statId, level: e.level, value: e.value })
      }
    })()
  }

  getAbilityAssignments(classId: string): ClassAbilityAssignment[] {
    const rows = this.dbProvider()
      .prepare(
        `SELECT ability_id AS abilityId, sort_order AS sortOrder
         FROM class_ability_assignments
         WHERE class_id = ?
         ORDER BY sort_order`,
      )
      .all(classId) as ClassAbilityAssignment[]
    return rows
  }

  setAbilityAssignments(classId: string, assignments: ClassAbilityAssignment[]): void {
    const db = this.dbProvider()
    const del = db.prepare('DELETE FROM class_ability_assignments WHERE class_id = ?')
    const ins = db.prepare(
      `INSERT INTO class_ability_assignments (class_id, ability_id, sort_order)
       VALUES (@classId, @abilityId, @sortOrder)`,
    )
    db.transaction(() => {
      del.run(classId)
      for (const a of assignments) {
        ins.run({ classId, abilityId: a.abilityId, sortOrder: a.sortOrder })
      }
    })()
  }
}

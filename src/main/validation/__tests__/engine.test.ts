import Database from 'better-sqlite3'
import { describe, it, expect, beforeEach } from 'vitest'
import { runMigrations } from '../../db/migrations/runner'
import { validateProject } from '../engine'
import type { ValidationIssue } from '../../../shared/domain-types'

// Seeded IDs (see 002_seed_meta_layer.ts)
const ITEM_CATEGORY_WEAPON = 'item-category-weapon'
const RARITY_COMMON = 'rarity-common'
const NPC_TYPE_ENEMY = 'npc-type-enemy'
const STATION_FORGE = 'crafting-station-forge'
const STAT_CON = 'stat-constitution'

function makeDb(): Database.Database {
  const db = new Database(':memory:')
  db.pragma('foreign_keys = ON')
  runMigrations(db)
  return db
}

// ─── Helpers for seeding records directly via SQL ────────────────────────────

let counter = 0
const nextId = (prefix: string): string => `${prefix}-${++counter}`

function insertClass(db: Database.Database, opts: Partial<{
  id: string; displayName: string; exportKey: string; resourceMultiplier: number; deleted: boolean
}> = {}): string {
  const id = opts.id ?? nextId('class')
  db.prepare(
    `INSERT INTO classes (id, display_name, export_key, resource_multiplier, deleted_at)
     VALUES (?, ?, ?, ?, ?)`,
  ).run(
    id,
    opts.displayName ?? `Class ${id}`,
    opts.exportKey ?? `class_${id.replace(/-/g, '_')}`,
    opts.resourceMultiplier ?? 1,
    opts.deleted ? new Date().toISOString() : null,
  )
  return id
}

function insertAbility(db: Database.Database, opts: Partial<{
  id: string; displayName: string; deleted: boolean
}> = {}): string {
  const id = opts.id ?? nextId('ability')
  db.prepare(
    `INSERT INTO abilities (id, display_name, export_key, deleted_at) VALUES (?, ?, ?, ?)`,
  ).run(
    id,
    opts.displayName ?? `Ability ${id}`,
    `ability_${id.replace(/-/g, '_')}`,
    opts.deleted ? new Date().toISOString() : null,
  )
  return id
}

function insertItem(db: Database.Database, opts: Partial<{
  id: string; displayName: string; categoryId: string; rarityId: string; deleted: boolean
}> = {}): string {
  const id = opts.id ?? nextId('item')
  db.prepare(
    `INSERT INTO items (id, display_name, export_key, item_category_id, rarity_id, deleted_at)
     VALUES (?, ?, ?, ?, ?, ?)`,
  ).run(
    id,
    opts.displayName ?? `Item ${id}`,
    `item_${id.replace(/-/g, '_')}`,
    opts.categoryId ?? ITEM_CATEGORY_WEAPON,
    opts.rarityId ?? RARITY_COMMON,
    opts.deleted ? new Date().toISOString() : null,
  )
  return id
}

function insertNpc(db: Database.Database, opts: Partial<{
  id: string; displayName: string; npcTypeId: string; lootTableId: string | null
}> = {}): string {
  const id = opts.id ?? nextId('npc')
  db.prepare(
    `INSERT INTO npcs (id, display_name, export_key, npc_type_id, loot_table_id)
     VALUES (?, ?, ?, ?, ?)`,
  ).run(
    id,
    opts.displayName ?? `NPC ${id}`,
    `npc_${id.replace(/-/g, '_')}`,
    opts.npcTypeId ?? NPC_TYPE_ENEMY,
    opts.lootTableId ?? null,
  )
  return id
}

function insertLootTable(db: Database.Database, opts: Partial<{
  id: string; displayName: string; deleted: boolean
}> = {}): string {
  const id = opts.id ?? nextId('loot')
  db.prepare(
    `INSERT INTO loot_tables (id, display_name, export_key, deleted_at) VALUES (?, ?, ?, ?)`,
  ).run(
    id,
    opts.displayName ?? `Loot ${id}`,
    `loot_${id.replace(/-/g, '_')}`,
    opts.deleted ? new Date().toISOString() : null,
  )
  return id
}

function insertDerivedStat(
  db: Database.Database,
  opts: { id?: string; displayName?: string; exportKey: string; formula: string },
): string {
  const id = opts.id ?? nextId('derived')
  db.prepare(
    `INSERT INTO derived_stat_definitions (id, display_name, export_key, formula)
     VALUES (?, ?, ?, ?)`,
  ).run(id, opts.displayName ?? opts.exportKey, opts.exportKey, opts.formula)
  return id
}

function setSoftDeleteRefSeverity(db: Database.Database, severity: 'Warning' | 'Error'): void {
  db.prepare(`INSERT OR IGNORE INTO project_info (id) VALUES (1)`).run()
  db.prepare(`UPDATE project_info SET soft_delete_reference_severity = ? WHERE id = 1`).run(severity)
}

function findIssues(issues: ValidationIssue[], predicate: (i: ValidationIssue) => boolean): ValidationIssue[] {
  return issues.filter(predicate)
}

// ─── Tests ───────────────────────────────────────────────────────────────────

describe('validateProject', () => {
  let db: Database.Database

  beforeEach(() => {
    counter = 0
    db = makeDb()
  })

  it('returns no issues for an empty project', () => {
    expect(validateProject(db)).toEqual([])
  })

  // ── Direct reference checks ────────────────────────────────────────────────

  describe('broken direct references', () => {
    it('flags item with missing item_category_id', () => {
      // Bypass FK with a temporary disable — the app allows soft-deleted targets
      // but tests need to simulate genuine dangling FKs.
      db.pragma('foreign_keys = OFF')
      db.prepare(
        `INSERT INTO items (id, display_name, export_key, item_category_id, rarity_id)
         VALUES ('i1', 'Orphan', 'orphan', 'nonexistent-category', ?)`,
      ).run(RARITY_COMMON)
      db.pragma('foreign_keys = ON')

      const issues = validateProject(db)
      const match = findIssues(issues, (i) =>
        i.domain === 'items' && i.recordId === 'i1' && i.field === 'itemCategoryId',
      )
      expect(match).toHaveLength(1)
      expect(match[0].severity).toBe('error')
      expect(match[0].message).toContain('nonexistent-category')
    })

    it('ignores broken references on soft-deleted owners', () => {
      db.pragma('foreign_keys = OFF')
      db.prepare(
        `INSERT INTO items (id, display_name, export_key, item_category_id, rarity_id, deleted_at)
         VALUES ('i1', 'Orphan', 'orphan', 'missing', ?, datetime('now'))`,
      ).run(RARITY_COMMON)
      db.pragma('foreign_keys = ON')

      expect(validateProject(db)).toEqual([])
    })

    it('flags NPC pointing at a nonexistent loot table', () => {
      db.pragma('foreign_keys = OFF')
      insertNpc(db, { id: 'n1', lootTableId: 'nowhere' })
      db.pragma('foreign_keys = ON')

      const matches = findIssues(validateProject(db), (i) => i.field === 'lootTableId')
      expect(matches).toHaveLength(1)
      expect(matches[0].severity).toBe('error')
    })
  })

  describe('soft-deleted direct references', () => {
    it('flags NPC pointing at a soft-deleted loot table as warning by default', () => {
      const loot = insertLootTable(db, { deleted: true })
      insertNpc(db, { lootTableId: loot })
      setSoftDeleteRefSeverity(db, 'Warning')

      const matches = findIssues(validateProject(db), (i) => i.field === 'lootTableId')
      expect(matches).toHaveLength(1)
      expect(matches[0].severity).toBe('warning')
    })

    it('escalates to error when project setting is Error', () => {
      const loot = insertLootTable(db, { deleted: true })
      insertNpc(db, { lootTableId: loot })
      setSoftDeleteRefSeverity(db, 'Error')

      const matches = findIssues(validateProject(db), (i) => i.field === 'lootTableId')
      expect(matches[0].severity).toBe('error')
    })
  })

  // ── Junction reference checks ──────────────────────────────────────────────

  describe('junction references', () => {
    it('flags a loot_table_entry pointing at a soft-deleted item', () => {
      const item = insertItem(db, { deleted: true })
      const loot = insertLootTable(db)
      db.prepare(
        `INSERT INTO loot_table_entries (id, loot_table_id, item_id, weight)
         VALUES ('e1', ?, ?, 1)`,
      ).run(loot, item)

      const matches = findIssues(validateProject(db),
        (i) => i.domain === 'loot-tables' && i.field === 'entries')
      expect(matches).toHaveLength(1)
      expect(matches[0].severity).toBe('warning')
      expect(matches[0].recordId).toBe(loot)
    })

    it('flags NPC class assignment pointing at a soft-deleted class', () => {
      const cls = insertClass(db, { deleted: true })
      const npc = insertNpc(db)
      db.prepare(
        `INSERT INTO npc_class_assignments (npc_id, class_id, level) VALUES (?, ?, 1)`,
      ).run(npc, cls)

      const matches = findIssues(validateProject(db), (i) => i.field === 'classAssignments')
      expect(matches).toHaveLength(1)
      expect(matches[0].recordId).toBe(npc)
    })
  })

  // ── Required custom field check ───────────────────────────────────────────

  describe('required custom fields', () => {
    it('flags an item with a required custom field that is empty', () => {
      db.prepare(
        `INSERT INTO custom_field_definitions
           (id, scope_type, scope_id, field_name, field_type, is_required)
         VALUES ('cfd1', 'item_category', ?, 'damage', 'integer', 1)`,
      ).run(ITEM_CATEGORY_WEAPON)

      const item = insertItem(db)

      const matches = findIssues(validateProject(db),
        (i) => i.domain === 'items' && i.field === 'custom:damage')
      expect(matches).toHaveLength(1)
      expect(matches[0].recordId).toBe(item)
      expect(matches[0].severity).toBe('error')
    })

    it('ignores records that are in a different scope', () => {
      db.prepare(
        `INSERT INTO custom_field_definitions
           (id, scope_type, scope_id, field_name, field_type, is_required)
         VALUES ('cfd1', 'item_category', ?, 'damage', 'integer', 1)`,
      ).run(ITEM_CATEGORY_WEAPON)

      insertItem(db, { categoryId: 'item-category-armor' })
      expect(validateProject(db)).toEqual([])
    })

    it('accepts a non-empty value', () => {
      db.prepare(
        `INSERT INTO custom_field_definitions
           (id, scope_type, scope_id, field_name, field_type, is_required)
         VALUES ('cfd1', 'item_category', ?, 'damage', 'integer', 1)`,
      ).run(ITEM_CATEGORY_WEAPON)

      const item = insertItem(db)
      db.prepare(
        `INSERT INTO custom_field_values (domain, record_id, field_definition_id, value)
         VALUES ('items', ?, 'cfd1', '42')`,
      ).run(item)

      expect(validateProject(db)).toEqual([])
    })

    it('skips soft-deleted records', () => {
      db.prepare(
        `INSERT INTO custom_field_definitions
           (id, scope_type, scope_id, field_name, field_type, is_required)
         VALUES ('cfd1', 'item_category', ?, 'damage', 'integer', 1)`,
      ).run(ITEM_CATEGORY_WEAPON)

      insertItem(db, { deleted: true })
      expect(validateProject(db)).toEqual([])
    })
  })

  // ── Formula checks ─────────────────────────────────────────────────────────

  describe('formula syntax errors', () => {
    it('flags an invalid base formula', () => {
      insertDerivedStat(db, { exportKey: 'test_broken', formula: 'con *' })

      const matches = findIssues(validateProject(db),
        (i) => i.domain === 'derived-stats' && i.field === 'formula')
      expect(matches).toHaveLength(1)
      expect(matches[0].severity).toBe('error')
      expect(matches[0].message).toContain('syntax')
    })

    it('flags an invalid override formula', () => {
      insertDerivedStat(db, { id: 'd1', exportKey: 'test_hp', formula: 'con * 10' })
      const cls = insertClass(db)
      db.prepare(
        `INSERT INTO class_derived_stat_overrides (class_id, derived_stat_id, formula)
         VALUES (?, 'd1', '/ broken')`,
      ).run(cls)

      const matches = findIssues(validateProject(db),
        (i) => i.domain === 'classes' && i.recordId === cls)
      expect(matches).toHaveLength(1)
      expect(matches[0].field).toContain('derivedStat:')
    })
  })

  describe('formula runtime errors', () => {
    it('flags a formula referencing an unknown variable', () => {
      insertDerivedStat(db, { exportKey: 'weird', formula: 'mystery_stat * 2' })
      insertClass(db)

      const matches = findIssues(validateProject(db),
        (i) => i.severity === 'warning' && (i.field ?? '').startsWith('derivedStat:'))
      expect(matches).toHaveLength(1)
      expect(matches[0].message).toContain('mystery_stat')
    })

    it('flags division by zero when the divisor stat is 0 at level 1', () => {
      // con has no growth entry for this class → binds to 0
      insertDerivedStat(db, { exportKey: 'ratio', formula: '100 / con' })
      insertClass(db)

      const matches = findIssues(validateProject(db),
        (i) => i.severity === 'warning' && i.message.includes('Division by zero'))
      expect(matches).toHaveLength(1)
    })

    it('does not false-positive when a stat has a non-zero level-1 growth entry', () => {
      insertDerivedStat(db, { exportKey: 'hp', formula: 'con * 10' })
      const cls = insertClass(db)
      db.prepare(
        `INSERT INTO class_stat_growth (class_id, stat_id, level, value)
         VALUES (?, ?, 1, 5)`,
      ).run(cls, STAT_CON)

      expect(findIssues(validateProject(db), (i) => i.severity === 'warning')).toHaveLength(0)
    })

    it('skips runtime check when syntax is already broken', () => {
      insertDerivedStat(db, { exportKey: 'broken', formula: 'con *' })
      insertClass(db)

      const matches = findIssues(validateProject(db), (i) => i.severity === 'warning')
      expect(matches).toHaveLength(0)
    })

    it('uses override formula over base when present', () => {
      const dsId = insertDerivedStat(db, { exportKey: 'hp', formula: 'con * 10' })
      const cls = insertClass(db)
      // Give this class a real con value so the base formula would be fine
      db.prepare(
        `INSERT INTO class_stat_growth (class_id, stat_id, level, value) VALUES (?, ?, 1, 5)`,
      ).run(cls, STAT_CON)
      // But add a broken override
      db.prepare(
        `INSERT INTO class_derived_stat_overrides (class_id, derived_stat_id, formula)
         VALUES (?, ?, '100 / bogus')`,
      ).run(cls, dsId)

      const matches = findIssues(validateProject(db),
        (i) => i.severity === 'warning' && i.recordId === cls)
      expect(matches).toHaveLength(1)
      expect(matches[0].message).toContain('bogus')
    })
  })

  describe('derived-stat cycles', () => {
    it('detects a two-node cycle in base formulas', () => {
      insertDerivedStat(db, { id: 'a', exportKey: 'a', formula: 'b + 1' })
      insertDerivedStat(db, { id: 'b', exportKey: 'b', formula: 'a + 1' })

      const matches = findIssues(validateProject(db),
        (i) => i.domain === 'derived-stats' && i.message.includes('cycle'))
      expect(matches.length).toBeGreaterThanOrEqual(2)
    })

    it('does not falsely flag an acyclic chain', () => {
      insertDerivedStat(db, { id: 'a', exportKey: 'a', formula: '1' })
      insertDerivedStat(db, { id: 'b', exportKey: 'b', formula: 'a + 1' })
      insertDerivedStat(db, { id: 'c', exportKey: 'c', formula: 'b + 1' })

      const matches = findIssues(validateProject(db), (i) => i.message.includes('cycle'))
      expect(matches).toHaveLength(0)
    })

    it('detects a cycle introduced only by a class override', () => {
      insertDerivedStat(db, { id: 'a', exportKey: 'a', formula: '1' })
      insertDerivedStat(db, { id: 'b', exportKey: 'b', formula: 'a + 1' })

      const cls = insertClass(db)
      // Override a to depend on b → b→a and a→b
      db.prepare(
        `INSERT INTO class_derived_stat_overrides (class_id, derived_stat_id, formula)
         VALUES (?, 'a', 'b + 1')`,
      ).run(cls)

      const matches = findIssues(validateProject(db),
        (i) => i.domain === 'classes' && i.field === 'derivedStatOverrides')
      expect(matches).toHaveLength(1)
      expect(matches[0].recordId).toBe(cls)
    })
  })

  // ── Shape + envelope tests ────────────────────────────────────────────────

  describe('issue shape', () => {
    it('gives every issue a unique id', () => {
      db.pragma('foreign_keys = OFF')
      insertNpc(db, { id: 'n1', lootTableId: 'nope-a' })
      insertNpc(db, { id: 'n2', lootTableId: 'nope-b' })
      db.pragma('foreign_keys = ON')

      const issues = validateProject(db)
      const ids = new Set(issues.map((i) => i.id))
      expect(ids.size).toBe(issues.length)
      expect(ids.size).toBeGreaterThanOrEqual(2)
    })
  })
})

import { randomUUID } from 'node:crypto'
import type { DbConnection } from '../db/connection'
import type {
  ValidationDomain,
  ValidationIssue,
  ValidationSeverity,
} from '../../shared/domain-types'
import {
  evaluateFormula,
  extractVariableNames,
  validateFormula,
} from '../formula/engine'

// ─── Issue builder ────────────────────────────────────────────────────────────

function issue(
  domain: ValidationDomain,
  recordId: string,
  recordDisplayName: string,
  field: string | null,
  severity: ValidationSeverity,
  message: string,
): ValidationIssue {
  return { id: randomUUID(), domain, recordId, recordDisplayName, field, severity, message }
}

// ─── Settings ────────────────────────────────────────────────────────────────

function getSoftDeleteRefSeverity(db: DbConnection): ValidationSeverity {
  const row = db
    .prepare(`SELECT soft_delete_reference_severity AS v FROM project_info LIMIT 1`)
    .get() as { v: string } | undefined
  return row?.v === 'Error' ? 'error' : 'warning'
}

// ─── Reference descriptor ────────────────────────────────────────────────────
//
// Declaratively describes a FK relationship to drive the broken/soft-deleted
// reference checks from a single pair of SQL queries per descriptor.

interface RefCheck {
  domain: ValidationDomain
  fromTable: string
  fromIdCol: string          // column on fromTable that identifies the owner record
  fromNameCol: string | null // column on fromTable for recordDisplayName (null = join needed)
  fromActiveOnly: boolean    // apply AND fromTable.deleted_at IS NULL
  fkCol: string              // FK column on fromTable
  nullable: boolean          // when true, skip rows where fkCol IS NULL
  field: string              // ValidationIssue.field value
  targetTable: string
  targetSoftDeletes: boolean // whether target table has a deleted_at column
  describeTarget: string     // human-readable target noun, e.g. "item"
}

const DOMAIN_REF_CHECKS: RefCheck[] = [
  // Items
  {
    domain: 'items', fromTable: 'items', fromIdCol: 'id', fromNameCol: 'display_name',
    fromActiveOnly: true, fkCol: 'item_category_id', nullable: false, field: 'itemCategoryId',
    targetTable: 'item_categories', targetSoftDeletes: false, describeTarget: 'item category',
  },
  {
    domain: 'items', fromTable: 'items', fromIdCol: 'id', fromNameCol: 'display_name',
    fromActiveOnly: true, fkCol: 'rarity_id', nullable: false, field: 'rarityId',
    targetTable: 'rarities', targetSoftDeletes: false, describeTarget: 'rarity',
  },
  // Recipes
  {
    domain: 'recipes', fromTable: 'recipes', fromIdCol: 'id', fromNameCol: 'display_name',
    fromActiveOnly: true, fkCol: 'output_item_id', nullable: false, field: 'outputItemId',
    targetTable: 'items', targetSoftDeletes: true, describeTarget: 'output item',
  },
  {
    domain: 'recipes', fromTable: 'recipes', fromIdCol: 'id', fromNameCol: 'display_name',
    fromActiveOnly: true, fkCol: 'crafting_station_id', nullable: true, field: 'craftingStationId',
    targetTable: 'crafting_stations', targetSoftDeletes: false, describeTarget: 'crafting station',
  },
  {
    domain: 'recipes', fromTable: 'recipes', fromIdCol: 'id', fromNameCol: 'display_name',
    fromActiveOnly: true, fkCol: 'crafting_specialization_id', nullable: true,
    field: 'craftingSpecializationId', targetTable: 'crafting_specializations',
    targetSoftDeletes: false, describeTarget: 'crafting specialization',
  },
  // NPCs
  {
    domain: 'npcs', fromTable: 'npcs', fromIdCol: 'id', fromNameCol: 'display_name',
    fromActiveOnly: true, fkCol: 'npc_type_id', nullable: false, field: 'npcTypeId',
    targetTable: 'npc_types', targetSoftDeletes: false, describeTarget: 'NPC type',
  },
  {
    domain: 'npcs', fromTable: 'npcs', fromIdCol: 'id', fromNameCol: 'display_name',
    fromActiveOnly: true, fkCol: 'loot_table_id', nullable: true, field: 'lootTableId',
    targetTable: 'loot_tables', targetSoftDeletes: true, describeTarget: 'loot table',
  },
]

/**
 * Broken reference: FK points to a nonexistent target row.
 * Soft-deleted reference: FK target exists but has deleted_at set.
 */
function checkDirectRefs(db: DbConnection, softSeverity: ValidationSeverity): ValidationIssue[] {
  const issues: ValidationIssue[] = []

  for (const c of DOMAIN_REF_CHECKS) {
    const ownerActive = c.fromActiveOnly ? `AND f.deleted_at IS NULL` : ''
    const fkNotNull = c.nullable ? `AND f.${c.fkCol} IS NOT NULL` : ''

    // Broken: join to target, target row is missing
    const brokenRows = db
      .prepare(
        `SELECT f.${c.fromIdCol} AS id,
                f.${c.fromNameCol} AS name,
                f.${c.fkCol} AS ref
         FROM ${c.fromTable} f
         LEFT JOIN ${c.targetTable} t ON t.id = f.${c.fkCol}
         WHERE t.id IS NULL ${fkNotNull} ${ownerActive}`,
      )
      .all() as { id: string; name: string; ref: string }[]

    for (const r of brokenRows) {
      issues.push(
        issue(c.domain, r.id, r.name, c.field, 'error',
          `References nonexistent ${c.describeTarget} '${r.ref}'.`),
      )
    }

    // Soft-deleted: only meaningful if target has deleted_at
    if (c.targetSoftDeletes) {
      const softRows = db
        .prepare(
          `SELECT f.${c.fromIdCol} AS id,
                  f.${c.fromNameCol} AS name,
                  t.display_name AS targetName
           FROM ${c.fromTable} f
           JOIN ${c.targetTable} t ON t.id = f.${c.fkCol}
           WHERE t.deleted_at IS NOT NULL ${ownerActive}`,
        )
        .all() as { id: string; name: string; targetName: string }[]

      for (const r of softRows) {
        issues.push(
          issue(c.domain, r.id, r.name, c.field, softSeverity,
            `References soft-deleted ${c.describeTarget} '${r.targetName}'.`),
        )
      }
    }
  }

  return issues
}

// ─── Junction / multi-assignment references ──────────────────────────────────

function checkJunctionRefs(db: DbConnection, softSeverity: ValidationSeverity): ValidationIssue[] {
  const issues: ValidationIssue[] = []

  interface JunctionCheck {
    domain: ValidationDomain
    ownerTable: string
    junction: string
    ownerFkCol: string   // e.g. class_id
    targetFkCol: string  // e.g. ability_id
    targetTable: string
    targetSoftDeletes: boolean
    field: string
    describeTarget: string
  }

  const checks: JunctionCheck[] = [
    {
      domain: 'classes', ownerTable: 'classes', junction: 'class_ability_assignments',
      ownerFkCol: 'class_id', targetFkCol: 'ability_id', targetTable: 'abilities',
      targetSoftDeletes: true, field: 'abilityAssignments', describeTarget: 'ability',
    },
    {
      domain: 'recipes', ownerTable: 'recipes', junction: 'recipe_ingredients',
      ownerFkCol: 'recipe_id', targetFkCol: 'item_id', targetTable: 'items',
      targetSoftDeletes: true, field: 'ingredients', describeTarget: 'ingredient item',
    },
    {
      domain: 'npcs', ownerTable: 'npcs', junction: 'npc_class_assignments',
      ownerFkCol: 'npc_id', targetFkCol: 'class_id', targetTable: 'classes',
      targetSoftDeletes: true, field: 'classAssignments', describeTarget: 'class',
    },
    {
      domain: 'npcs', ownerTable: 'npcs', junction: 'npc_ability_assignments',
      ownerFkCol: 'npc_id', targetFkCol: 'ability_id', targetTable: 'abilities',
      targetSoftDeletes: true, field: 'abilityAssignments', describeTarget: 'ability',
    },
    {
      domain: 'loot-tables', ownerTable: 'loot_tables', junction: 'loot_table_entries',
      ownerFkCol: 'loot_table_id', targetFkCol: 'item_id', targetTable: 'items',
      targetSoftDeletes: true, field: 'entries', describeTarget: 'item',
    },
  ]

  for (const c of checks) {
    // Broken references
    const broken = db
      .prepare(
        `SELECT o.id AS id, o.display_name AS name, j.${c.targetFkCol} AS ref
         FROM ${c.junction} j
         JOIN ${c.ownerTable} o ON o.id = j.${c.ownerFkCol}
         LEFT JOIN ${c.targetTable} t ON t.id = j.${c.targetFkCol}
         WHERE t.id IS NULL AND o.deleted_at IS NULL`,
      )
      .all() as { id: string; name: string; ref: string }[]

    for (const r of broken) {
      issues.push(
        issue(c.domain, r.id, r.name, c.field, 'error',
          `Assignment references nonexistent ${c.describeTarget} '${r.ref}'.`),
      )
    }

    if (c.targetSoftDeletes) {
      const soft = db
        .prepare(
          `SELECT o.id AS id, o.display_name AS name, t.display_name AS targetName
           FROM ${c.junction} j
           JOIN ${c.ownerTable} o ON o.id = j.${c.ownerFkCol}
           JOIN ${c.targetTable} t ON t.id = j.${c.targetFkCol}
           WHERE t.deleted_at IS NOT NULL AND o.deleted_at IS NULL`,
        )
        .all() as { id: string; name: string; targetName: string }[]

      for (const r of soft) {
        issues.push(
          issue(c.domain, r.id, r.name, c.field, softSeverity,
            `Assignment references soft-deleted ${c.describeTarget} '${r.targetName}'.`),
        )
      }
    }
  }

  return issues
}

// ─── Required custom field checks ────────────────────────────────────────────

function checkRequiredCustomFields(db: DbConnection): ValidationIssue[] {
  const issues: ValidationIssue[] = []

  interface DefRow {
    id: string
    scope_type: 'item_category' | 'npc_type'
    scope_id: string
    field_name: string
  }

  const defs = db
    .prepare(
      `SELECT id, scope_type, scope_id, field_name
       FROM custom_field_definitions
       WHERE is_required = 1`,
    )
    .all() as DefRow[]

  for (const def of defs) {
    const { ownerTable, scopeCol, domain } =
      def.scope_type === 'item_category'
        ? { ownerTable: 'items', scopeCol: 'item_category_id', domain: 'items' as const }
        : { ownerTable: 'npcs', scopeCol: 'npc_type_id', domain: 'npcs' as const }

    // Records in scope whose value for this field is missing or blank.
    const offenders = db
      .prepare(
        `SELECT o.id AS id, o.display_name AS name
         FROM ${ownerTable} o
         LEFT JOIN custom_field_values v
           ON v.domain = ? AND v.record_id = o.id AND v.field_definition_id = ?
         WHERE o.${scopeCol} = ?
           AND o.deleted_at IS NULL
           AND (v.value IS NULL OR v.value = '')`,
      )
      .all(ownerTable, def.id, def.scope_id) as { id: string; name: string }[]

    for (const o of offenders) {
      issues.push(
        issue(domain, o.id, o.name, `custom:${def.field_name}`, 'error',
          `Required field '${def.field_name}' is empty.`),
      )
    }
  }

  return issues
}

// ─── Derived-stat formula checks ─────────────────────────────────────────────

interface DerivedStatRow {
  id: string
  display_name: string
  export_key: string
  formula: string
}

interface ClassOverrideRow {
  class_id: string
  derived_stat_id: string
  formula: string
  class_name: string
  derived_name: string
}

interface ClassRow {
  id: string
  display_name: string
}

/**
 * Check that every derived-stat formula (base + per-class overrides) parses
 * cleanly. Returns both the issues and the set of ids that failed so the
 * runtime and cycle checks can skip them.
 */
function checkFormulaSyntax(
  db: DbConnection,
): { issues: ValidationIssue[]; failedBaseIds: Set<string>; failedOverrideKeys: Set<string> } {
  const issues: ValidationIssue[] = []
  const failedBaseIds = new Set<string>()
  const failedOverrideKeys = new Set<string>()

  const baseRows = db
    .prepare(`SELECT id, display_name, export_key, formula FROM derived_stat_definitions`)
    .all() as DerivedStatRow[]

  for (const r of baseRows) {
    const err = validateFormula(r.formula)
    if (err) {
      failedBaseIds.add(r.id)
      issues.push(
        issue('derived-stats', r.id, r.display_name, 'formula', 'error',
          `Formula syntax error: ${err}`),
      )
    }
  }

  const overrideRows = db
    .prepare(
      `SELECT o.class_id, o.derived_stat_id, o.formula,
              c.display_name AS class_name, d.display_name AS derived_name
       FROM class_derived_stat_overrides o
       JOIN classes c ON c.id = o.class_id
       JOIN derived_stat_definitions d ON d.id = o.derived_stat_id
       WHERE c.deleted_at IS NULL`,
    )
    .all() as ClassOverrideRow[]

  for (const r of overrideRows) {
    const err = validateFormula(r.formula)
    if (err) {
      failedOverrideKeys.add(`${r.class_id}:${r.derived_stat_id}`)
      issues.push(
        issue('classes', r.class_id, r.class_name, `derivedStat:${r.derived_name}`, 'error',
          `Override formula for '${r.derived_name}' has syntax error: ${err}`),
      )
    }
  }

  return { issues, failedBaseIds, failedOverrideKeys }
}

/**
 * Build the bindings map for a class at level 1 (as configured in the project)
 * by summing that class's stat growth entries for level 1, and folding in the
 * class metadata fields. Missing stats default to 0.
 */
function buildClassLevel1Bindings(
  db: DbConnection,
  classId: string,
  resourceMultiplier: number,
): Record<string, number> {
  // Stats keyed by export_key at level 1 (or 0 if no entry)
  const statRows = db
    .prepare(
      `SELECT s.export_key AS key, COALESCE(g.value, 0) AS value
       FROM stats s
       LEFT JOIN class_stat_growth g ON g.stat_id = s.id AND g.class_id = ? AND g.level = 1`,
    )
    .all(classId) as { key: string; value: number }[]

  const bindings: Record<string, number> = {}
  for (const s of statRows) bindings[s.key] = s.value

  // Class metadata fields
  const metaRows = db
    .prepare(`SELECT field_key AS key, value FROM class_metadata_fields WHERE class_id = ?`)
    .all(classId) as { key: string; value: number }[]
  for (const m of metaRows) bindings[m.key] = m.value

  // Always-present class-level multiplier (matches formula engine expectations)
  bindings.resource_multiplier = resourceMultiplier

  return bindings
}

/**
 * For each active class × derived-stat pair, resolve the effective formula
 * (override if present, else base) and evaluate it. Skip entries whose formula
 * already failed syntax.
 */
function checkFormulaRuntime(
  db: DbConnection,
  failedBaseIds: Set<string>,
  failedOverrideKeys: Set<string>,
): ValidationIssue[] {
  const issues: ValidationIssue[] = []

  const baseRows = db
    .prepare(`SELECT id, display_name, export_key, formula FROM derived_stat_definitions`)
    .all() as DerivedStatRow[]

  const classes = db
    .prepare(
      `SELECT id, display_name, resource_multiplier AS rm FROM classes WHERE deleted_at IS NULL`,
    )
    .all() as (ClassRow & { rm: number })[]

  // Overrides keyed by classId:derivedId → formula
  const overrideMap = new Map<string, string>()
  const overrideRows = db
    .prepare(
      `SELECT class_id, derived_stat_id, formula FROM class_derived_stat_overrides`,
    )
    .all() as { class_id: string; derived_stat_id: string; formula: string }[]
  for (const o of overrideRows) overrideMap.set(`${o.class_id}:${o.derived_stat_id}`, o.formula)

  for (const cls of classes) {
    const bindings = buildClassLevel1Bindings(db, cls.id, cls.rm)

    for (const ds of baseRows) {
      const overrideKey = `${cls.id}:${ds.id}`
      const hasOverride = overrideMap.has(overrideKey)
      const formula = hasOverride ? overrideMap.get(overrideKey)! : ds.formula

      // Skip if the formula (override or base) failed syntax
      if (hasOverride ? failedOverrideKeys.has(overrideKey) : failedBaseIds.has(ds.id)) continue

      const result = evaluateFormula(formula, bindings)
      if (result.error && !result.isSyntaxError) {
        issues.push(
          issue('classes', cls.id, cls.display_name,
            `derivedStat:${ds.display_name}`, 'warning',
            `Formula for '${ds.display_name}' failed at level 1: ${result.error}`),
        )
      }
    }
  }

  return issues
}

/**
 * Detect cycles across derived-stat definitions by name reference. A cycle
 * exists when the identifier graph over export_key contains a back-edge.
 * Per-class overrides replace the default edges for that class.
 */
function checkDerivedStatCycles(
  db: DbConnection,
  failedBaseIds: Set<string>,
  failedOverrideKeys: Set<string>,
): ValidationIssue[] {
  const issues: ValidationIssue[] = []

  const baseRows = db
    .prepare(`SELECT id, display_name, export_key, formula FROM derived_stat_definitions`)
    .all() as DerivedStatRow[]

  const byKey = new Map<string, DerivedStatRow>()
  for (const r of baseRows) byKey.set(r.export_key, r)

  const baseEdges = (formula: string): string[] =>
    extractVariableNames(formula).filter((v) => byKey.has(v))

  // First check the base graph for cycles
  const baseGraph = new Map<string, string[]>()
  for (const r of baseRows) {
    if (failedBaseIds.has(r.id)) continue
    baseGraph.set(r.id, baseEdges(r.formula).map((k) => byKey.get(k)!.id))
  }

  const baseCycle = findCycle(baseGraph)
  if (baseCycle) {
    const names = baseCycle.map((id) => baseRows.find((r) => r.id === id)!.display_name)
    for (const id of baseCycle) {
      const row = baseRows.find((r) => r.id === id)!
      issues.push(
        issue('derived-stats', id, row.display_name, 'formula', 'error',
          `Derived stat is part of a dependency cycle: ${names.join(' → ')} → ${names[0]}.`),
      )
    }
  }

  // Per-class: build a graph where the edges out of any overridden node come
  // from the override formula instead of the base formula. A cycle only in the
  // override graph surfaces as a per-class error.
  const classes = db
    .prepare(`SELECT id, display_name FROM classes WHERE deleted_at IS NULL`)
    .all() as ClassRow[]

  const overrideByClass = new Map<string, Map<string, string>>()
  const overrideRows = db
    .prepare(`SELECT class_id, derived_stat_id, formula FROM class_derived_stat_overrides`)
    .all() as { class_id: string; derived_stat_id: string; formula: string }[]
  for (const o of overrideRows) {
    if (!overrideByClass.has(o.class_id)) overrideByClass.set(o.class_id, new Map())
    overrideByClass.get(o.class_id)!.set(o.derived_stat_id, o.formula)
  }

  for (const cls of classes) {
    const overrides = overrideByClass.get(cls.id)
    if (!overrides || overrides.size === 0) continue

    const graph = new Map<string, string[]>()
    for (const r of baseRows) {
      if (overrides.has(r.id)) {
        const key = `${cls.id}:${r.id}`
        if (failedOverrideKeys.has(key)) continue
        graph.set(r.id, baseEdges(overrides.get(r.id)!).map((k) => byKey.get(k)!.id))
      } else {
        if (failedBaseIds.has(r.id)) continue
        graph.set(r.id, baseEdges(r.formula).map((k) => byKey.get(k)!.id))
      }
    }

    const cycle = findCycle(graph)
    if (cycle && !arraysEqual(cycle, baseCycle)) {
      const names = cycle.map((id) => baseRows.find((r) => r.id === id)!.display_name)
      issues.push(
        issue('classes', cls.id, cls.display_name, 'derivedStatOverrides', 'error',
          `Override formulas create a dependency cycle: ${names.join(' → ')} → ${names[0]}.`),
      )
    }
  }

  return issues
}

function arraysEqual(a: string[] | null, b: string[] | null): boolean {
  if (!a || !b) return false
  if (a.length !== b.length) return false
  // Cycles are unordered-rotation-equivalent; normalize by sorting a copy.
  const sa = [...a].sort()
  const sb = [...b].sort()
  return sa.every((x, i) => x === sb[i])
}

/**
 * Returns a cycle (list of node ids in cycle order) or null if the graph is
 * acyclic. Uses an iterative DFS with colors: 0=unvisited, 1=on-stack, 2=done.
 */
function findCycle(graph: Map<string, string[]>): string[] | null {
  const color = new Map<string, number>()
  for (const k of graph.keys()) color.set(k, 0)

  const parent = new Map<string, string | null>()

  for (const start of graph.keys()) {
    if (color.get(start) !== 0) continue

    // iterative DFS
    const stack: { node: string; childIdx: number }[] = [{ node: start, childIdx: 0 }]
    color.set(start, 1)
    parent.set(start, null)

    while (stack.length > 0) {
      const frame = stack[stack.length - 1]
      const children = graph.get(frame.node) ?? []

      if (frame.childIdx >= children.length) {
        color.set(frame.node, 2)
        stack.pop()
        continue
      }

      const child = children[frame.childIdx++]
      const c = color.get(child) ?? 0

      if (c === 1) {
        // Found a back-edge — reconstruct cycle from child back to itself
        const cycle: string[] = [child]
        let n: string | null = frame.node
        while (n !== null && n !== child) {
          cycle.push(n)
          n = parent.get(n) ?? null
        }
        return cycle.reverse()
      }
      if (c === 0) {
        color.set(child, 1)
        parent.set(child, frame.node)
        stack.push({ node: child, childIdx: 0 })
      }
    }
  }

  return null
}

// ─── Public entry point ──────────────────────────────────────────────────────

/**
 * Runs every validation check against the given database connection and
 * returns the flat issue list. The entire run executes inside a read-only
 * transaction so individual checks see a consistent snapshot.
 */
export function validateProject(db: DbConnection): ValidationIssue[] {
  const run = db.transaction((): ValidationIssue[] => {
    const softSeverity = getSoftDeleteRefSeverity(db)
    const syntax = checkFormulaSyntax(db)
    return [
      ...checkDirectRefs(db, softSeverity),
      ...checkJunctionRefs(db, softSeverity),
      ...checkRequiredCustomFields(db),
      ...syntax.issues,
      ...checkFormulaRuntime(db, syntax.failedBaseIds, syntax.failedOverrideKeys),
      ...checkDerivedStatCycles(db, syntax.failedBaseIds, syntax.failedOverrideKeys),
    ]
  })

  return run()
}

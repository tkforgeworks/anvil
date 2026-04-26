import type { DbConnection } from '../db/connection'
import { evaluateFormula } from '../formula/engine'

export interface ExportScope {
  mode: 'full' | 'domain' | 'selection'
  domain?: string
  recordIds?: string[]
}

export interface ExportContext {
  project: Record<string, unknown>
  meta: Record<string, unknown[]>
  classes: Record<string, unknown>[]
  abilities: Record<string, unknown>[]
  items: Record<string, unknown>[]
  recipes: Record<string, unknown>[]
  npcs: Record<string, unknown>[]
  loot_tables: Record<string, unknown>[]
}

export function assembleExportContext(db: DbConnection, scope: ExportScope): ExportContext {
  const project = assembleProjectMeta(db)
  const meta = assembleMetaLayers(db)

  const ctx: ExportContext = {
    project,
    meta,
    classes: [],
    abilities: [],
    items: [],
    recipes: [],
    npcs: [],
    loot_tables: [],
  }

  const domainAssemblers: Record<string, (db: DbConnection, ids?: string[]) => Record<string, unknown>[]> = {
    classes: assembleClasses,
    abilities: assembleAbilities,
    items: assembleItems,
    recipes: assembleRecipes,
    npcs: assembleNpcs,
    loot_tables: assembleLootTables,
  }

  if (scope.mode === 'full') {
    for (const [key, assembler] of Object.entries(domainAssemblers)) {
      (ctx as unknown as Record<string, unknown>)[key] = assembler(db)
    }
  } else if (scope.mode === 'domain' && scope.domain) {
    const normalizedKey = scope.domain.replace(/-/g, '_')
    const assembler = domainAssemblers[normalizedKey]
    if (assembler) {
      (ctx as unknown as Record<string, unknown>)[normalizedKey] = assembler(db)
    }
  } else if (scope.mode === 'selection' && scope.domain && scope.recordIds?.length) {
    const normalizedKey = scope.domain.replace(/-/g, '_')
    const assembler = domainAssemblers[normalizedKey]
    if (assembler) {
      (ctx as unknown as Record<string, unknown>)[normalizedKey] = assembler(db, scope.recordIds)
    }
  }

  if (scope.mode === 'domain' || scope.mode === 'selection') {
    resolveDependencies(db, ctx, domainAssemblers)
  }

  return ctx
}

function assembleProjectMeta(db: DbConnection): Record<string, unknown> {
  const row = db.prepare(
    `SELECT project_name, game_title, schema_version, max_level
     FROM project_info LIMIT 1`,
  ).get() as { project_name: string; game_title: string; schema_version: number; max_level: number } | undefined

  return row
    ? { name: row.project_name, game_title: row.game_title, schema_version: row.schema_version, max_level: row.max_level }
    : { name: '', game_title: '', schema_version: 0, max_level: 20 }
}

function assembleMetaLayers(db: DbConnection): Record<string, unknown[]> {
  return {
    stats: db.prepare(
      `SELECT id, display_name, export_key, sort_order FROM stats ORDER BY sort_order`,
    ).all(),
    rarities: db.prepare(
      `SELECT id, display_name, export_key, color_hex, sort_order FROM rarities ORDER BY sort_order`,
    ).all(),
    item_categories: db.prepare(
      `SELECT id, display_name, export_key, description, sort_order FROM item_categories ORDER BY sort_order`,
    ).all(),
    npc_types: db.prepare(
      `SELECT id, display_name, export_key, description, sort_order FROM npc_types ORDER BY sort_order`,
    ).all(),
    crafting_stations: db.prepare(
      `SELECT id, display_name, export_key, description, sort_order FROM crafting_stations ORDER BY sort_order`,
    ).all(),
    crafting_specializations: db.prepare(
      `SELECT id, display_name, export_key, description, sort_order FROM crafting_specializations ORDER BY sort_order`,
    ).all(),
    derived_stats: db.prepare(
      `SELECT id, display_name, export_key, formula, output_type, rounding_mode, sort_order
       FROM derived_stat_definitions ORDER BY sort_order`,
    ).all(),
  }
}

function whereActive(ids?: string[]): { clause: string; params: unknown[] } {
  if (ids?.length) {
    const placeholders = ids.map(() => '?').join(', ')
    return { clause: `WHERE deleted_at IS NULL AND id IN (${placeholders})`, params: ids }
  }
  return { clause: 'WHERE deleted_at IS NULL', params: [] }
}

function getCustomFields(db: DbConnection, domain: string, recordId: string): Record<string, string | null> {
  const rows = db.prepare(
    `SELECT cfd.field_name, cfv.value
     FROM custom_field_values cfv
     JOIN custom_field_definitions cfd ON cfd.id = cfv.field_definition_id
     WHERE cfv.domain = ? AND cfv.record_id = ?`,
  ).all(domain, recordId) as { field_name: string; value: string | null }[]

  const map: Record<string, string | null> = {}
  for (const row of rows) map[row.field_name] = row.value
  return map
}

function assembleClasses(db: DbConnection, ids?: string[]): Record<string, unknown>[] {
  const { clause, params } = whereActive(ids)
  const rows = db.prepare(
    `SELECT id, display_name, export_key, description, resource_multiplier
     FROM classes ${clause}
     ORDER BY display_name COLLATE NOCASE`,
  ).all(...params) as { id: string; display_name: string; export_key: string; description: string; resource_multiplier: number }[]

  const { max_level: maxLevel } = db.prepare(
    'SELECT max_level FROM project_info LIMIT 1',
  ).get() as { max_level: number }

  return rows.map((row) => {
    const manualStatGrowth = db.prepare(
      `SELECT stat_id, level, value FROM class_stat_growth WHERE class_id = ? ORDER BY stat_id, level`,
    ).all(row.id) as { stat_id: string; level: number; value: number }[]

    const growthFormulas = db.prepare(
      `SELECT stat_id, formula FROM class_stat_growth_formulas WHERE class_id = ?`,
    ).all(row.id) as { stat_id: string; formula: string }[]

    const formulaStatIds = new Set(growthFormulas.map((f) => f.stat_id))
    const statGrowth = manualStatGrowth.filter((sg) => !formulaStatIds.has(sg.stat_id))
    for (const f of growthFormulas) {
      for (let level = 1; level <= maxLevel; level++) {
        const result = evaluateFormula(f.formula, { level, max_level: maxLevel })
        statGrowth.push({ stat_id: f.stat_id, level, value: result.value ?? 0 })
      }
    }

    const abilities = db.prepare(
      `SELECT ability_id, sort_order FROM class_ability_assignments WHERE class_id = ? ORDER BY sort_order`,
    ).all(row.id) as { ability_id: string; sort_order: number }[]

    const derivedStatOverrides = db.prepare(
      `SELECT derived_stat_id, formula FROM class_derived_stat_overrides WHERE class_id = ?`,
    ).all(row.id) as { derived_stat_id: string; formula: string }[]

    const metadataFields = db.prepare(
      `SELECT field_key, value FROM class_metadata_fields WHERE class_id = ?`,
    ).all(row.id) as { field_key: string; value: string }[]

    const metaMap: Record<string, string> = {}
    for (const m of metadataFields) metaMap[m.field_key] = m.value

    return {
      id: row.id,
      display_name: row.display_name,
      export_key: row.export_key,
      description: row.description,
      resource_multiplier: row.resource_multiplier,
      stat_growth: statGrowth.map((sg) => ({
        stat_id: sg.stat_id,
        level: sg.level,
        value: sg.value,
      })),
      abilities: abilities.map((a) => ({
        ability_id: a.ability_id,
        sort_order: a.sort_order,
      })),
      derived_stat_overrides: derivedStatOverrides.map((o) => ({
        derived_stat_id: o.derived_stat_id,
        formula: o.formula,
      })),
      metadata: metaMap,
    }
  })
}

function assembleAbilities(db: DbConnection, ids?: string[]): Record<string, unknown>[] {
  const { clause, params } = whereActive(ids)
  const rows = db.prepare(
    `SELECT id, display_name, export_key, description,
            ability_type, resource_type, resource_cost, cooldown, stat_modifiers_json
     FROM abilities ${clause}
     ORDER BY display_name COLLATE NOCASE`,
  ).all(...params) as {
    id: string; display_name: string; export_key: string; description: string
    ability_type: string; resource_type: string; resource_cost: number; cooldown: number
    stat_modifiers_json: string
  }[]

  return rows.map((row) => ({
    id: row.id,
    display_name: row.display_name,
    export_key: row.export_key,
    description: row.description,
    ability_type: row.ability_type,
    resource_type: row.resource_type,
    resource_cost: row.resource_cost,
    cooldown: row.cooldown,
    stat_modifiers: JSON.parse(row.stat_modifiers_json),
  }))
}

function assembleItems(db: DbConnection, ids?: string[]): Record<string, unknown>[] {
  const { clause, params } = whereActive(ids)
  const rows = db.prepare(
    `SELECT id, display_name, export_key, description, item_category_id, rarity_id
     FROM items ${clause}
     ORDER BY display_name COLLATE NOCASE`,
  ).all(...params) as {
    id: string; display_name: string; export_key: string; description: string
    item_category_id: string; rarity_id: string
  }[]

  return rows.map((row) => ({
    id: row.id,
    display_name: row.display_name,
    export_key: row.export_key,
    description: row.description,
    item_category_id: row.item_category_id,
    rarity_id: row.rarity_id,
    custom_fields: getCustomFields(db, 'items', row.id),
  }))
}

function assembleRecipes(db: DbConnection, ids?: string[]): Record<string, unknown>[] {
  const { clause, params } = whereActive(ids)
  const rows = db.prepare(
    `SELECT id, display_name, export_key, description,
            output_item_id, output_quantity, crafting_station_id, crafting_specialization_id
     FROM recipes ${clause}
     ORDER BY display_name COLLATE NOCASE`,
  ).all(...params) as {
    id: string; display_name: string; export_key: string; description: string
    output_item_id: string; output_quantity: number
    crafting_station_id: string | null; crafting_specialization_id: string | null
  }[]

  return rows.map((row) => {
    const ingredients = db.prepare(
      `SELECT item_id, quantity, sort_order FROM recipe_ingredients WHERE recipe_id = ? ORDER BY sort_order`,
    ).all(row.id) as { item_id: string; quantity: number; sort_order: number }[]

    return {
      id: row.id,
      display_name: row.display_name,
      export_key: row.export_key,
      description: row.description,
      output_item_id: row.output_item_id,
      output_quantity: row.output_quantity,
      crafting_station_id: row.crafting_station_id,
      crafting_specialization_id: row.crafting_specialization_id,
      ingredients: ingredients.map((i) => ({
        item_id: i.item_id,
        quantity: i.quantity,
        sort_order: i.sort_order,
      })),
    }
  })
}

function assembleNpcs(db: DbConnection, ids?: string[]): Record<string, unknown>[] {
  const { clause, params } = whereActive(ids)
  const rows = db.prepare(
    `SELECT id, display_name, export_key, description,
            npc_type_id, loot_table_id, combat_stats_json
     FROM npcs ${clause}
     ORDER BY display_name COLLATE NOCASE`,
  ).all(...params) as {
    id: string; display_name: string; export_key: string; description: string
    npc_type_id: string; loot_table_id: string | null; combat_stats_json: string
  }[]

  return rows.map((row) => {
    const classAssignments = db.prepare(
      `SELECT class_id, level, sort_order FROM npc_class_assignments WHERE npc_id = ? ORDER BY sort_order`,
    ).all(row.id) as { class_id: string; level: number; sort_order: number }[]

    const abilityAssignments = db.prepare(
      `SELECT ability_id, sort_order FROM npc_ability_assignments WHERE npc_id = ? ORDER BY sort_order`,
    ).all(row.id) as { ability_id: string; sort_order: number }[]

    return {
      id: row.id,
      display_name: row.display_name,
      export_key: row.export_key,
      description: row.description,
      npc_type_id: row.npc_type_id,
      loot_table_id: row.loot_table_id,
      combat_stats: JSON.parse(row.combat_stats_json),
      class_assignments: classAssignments.map((a) => ({
        class_id: a.class_id,
        level: a.level,
        sort_order: a.sort_order,
      })),
      ability_assignments: abilityAssignments.map((a) => ({
        ability_id: a.ability_id,
        sort_order: a.sort_order,
      })),
      custom_fields: getCustomFields(db, 'npcs', row.id),
    }
  })
}

const DOMAIN_FK_FIELDS: Record<string, { field: string; targetDomain: string }[]> = {
  classes: [
    { field: 'abilities[].ability_id', targetDomain: 'abilities' },
  ],
  recipes: [
    { field: 'output_item_id', targetDomain: 'items' },
    { field: 'ingredients[].item_id', targetDomain: 'items' },
  ],
  npcs: [
    { field: 'loot_table_id', targetDomain: 'loot_tables' },
    { field: 'class_assignments[].class_id', targetDomain: 'classes' },
    { field: 'ability_assignments[].ability_id', targetDomain: 'abilities' },
  ],
  loot_tables: [
    { field: 'entries[].item_id', targetDomain: 'items' },
  ],
}

function collectReferencedIds(
  records: Record<string, unknown>[],
  fkDefs: { field: string; targetDomain: string }[],
): Map<string, Set<string>> {
  const refs = new Map<string, Set<string>>()
  for (const fk of fkDefs) {
    const set = refs.get(fk.targetDomain) ?? new Set<string>()
    refs.set(fk.targetDomain, set)

    if (fk.field.includes('[].')) {
      const [arrayField, idField] = fk.field.split('[].')
      for (const record of records) {
        const arr = record[arrayField]
        if (Array.isArray(arr)) {
          for (const entry of arr as Record<string, unknown>[]) {
            const id = entry[idField]
            if (typeof id === 'string' && id) set.add(id)
          }
        }
      }
    } else {
      for (const record of records) {
        const id = record[fk.field]
        if (typeof id === 'string' && id) set.add(id)
      }
    }
  }
  return refs
}

function resolveDependencies(
  db: DbConnection,
  ctx: ExportContext,
  assemblers: Record<string, (db: DbConnection, ids?: string[]) => Record<string, unknown>[]>,
): void {
  const allDomains = ['classes', 'abilities', 'items', 'recipes', 'npcs', 'loot_tables'] as const
  const needed = new Map<string, Set<string>>()

  for (const domain of allDomains) {
    const records = ctx[domain]
    if (records.length === 0) continue
    const fkDefs = DOMAIN_FK_FIELDS[domain]
    if (!fkDefs) continue
    const refs = collectReferencedIds(records, fkDefs)
    for (const [targetDomain, ids] of refs) {
      const existing = new Set((ctx[targetDomain as keyof ExportContext] as Record<string, unknown>[])
        .map((r) => r.id as string))
      const missing = new Set([...ids].filter((id) => !existing.has(id)))
      if (missing.size === 0) continue
      const combined = needed.get(targetDomain) ?? new Set<string>()
      for (const id of missing) combined.add(id)
      needed.set(targetDomain, combined)
    }
  }

  for (const [domain, ids] of needed) {
    const assembler = assemblers[domain]
    if (!assembler) continue
    const existing = ctx[domain as keyof ExportContext] as Record<string, unknown>[]
    const fetched = assembler(db, [...ids])
    ;(ctx as unknown as Record<string, unknown>)[domain] = [...existing, ...fetched]
  }
}

function assembleLootTables(db: DbConnection, ids?: string[]): Record<string, unknown>[] {
  const { clause, params } = whereActive(ids)
  const rows = db.prepare(
    `SELECT id, display_name, export_key, description
     FROM loot_tables ${clause}
     ORDER BY display_name COLLATE NOCASE`,
  ).all(...params) as {
    id: string; display_name: string; export_key: string; description: string
  }[]

  return rows.map((row) => {
    const entries = db.prepare(
      `SELECT item_id, weight, quantity_min, quantity_max, sort_order
       FROM loot_table_entries WHERE loot_table_id = ? ORDER BY sort_order`,
    ).all(row.id) as {
      item_id: string; weight: number; quantity_min: number; quantity_max: number; sort_order: number
    }[]

    return {
      id: row.id,
      display_name: row.display_name,
      export_key: row.export_key,
      description: row.description,
      entries: entries.map((e) => ({
        item_id: e.item_id,
        weight: e.weight,
        quantity_min: e.quantity_min,
        quantity_max: e.quantity_max,
        sort_order: e.sort_order,
      })),
    }
  })
}

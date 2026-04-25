import nunjucks from 'nunjucks'
import type { ExportContext } from './context-assembler'

const env = new nunjucks.Environment(null, { autoescape: false, throwOnUndefined: true })

env.addFilter('json', (value: unknown, indent?: number) => JSON.stringify(value, null, indent ?? 2))
env.addFilter('export_key', function (this: { ctx: ExportContext }, id: string) {
  const ctx = this.ctx as ExportContext
  for (const domain of ['classes', 'abilities', 'items', 'recipes', 'npcs', 'loot_tables'] as const) {
    const match = ctx[domain].find((r) => r.id === id)
    if (match) return match.export_key as string
  }
  return id
})

export interface ExportPreset {
  id: string
  name: string
  description: string
  format: 'json' | 'csv'
  builtIn: true
}

export const BUILT_IN_PRESETS: ExportPreset[] = [
  { id: 'nested-json', name: 'Nested JSON', description: 'Hierarchical JSON with nested sub-objects for referenced records', format: 'json', builtIn: true },
  { id: 'flat-json', name: 'Flat JSON', description: 'Flat JSON with all reference fields resolved to export keys', format: 'json', builtIn: true },
  { id: 'csv', name: 'CSV', description: 'One CSV file per domain, references resolved to export keys', format: 'csv', builtIn: true },
]

export interface RenderResult {
  output: string
  files?: { filename: string; content: string }[]
}

export function renderExport(presetId: string, context: ExportContext): RenderResult {
  switch (presetId) {
    case 'nested-json':
      return { output: renderNestedJson(context) }
    case 'flat-json':
      return { output: renderFlatJson(context) }
    case 'csv':
      return renderCsv(context)
    default:
      throw new Error(`Unknown preset: ${presetId}`)
  }
}

export function renderCustomTemplate(templateSource: string, context: ExportContext): RenderResult {
  const output = env.renderString(templateSource, { ...context, ctx: context })
  return { output }
}

function buildExportKeyLookup(context: ExportContext): Map<string, string> {
  const map = new Map<string, string>()
  for (const domain of ['classes', 'abilities', 'items', 'recipes', 'npcs', 'loot_tables'] as const) {
    for (const record of context[domain]) {
      map.set(record.id as string, record.export_key as string)
    }
  }
  for (const domain of ['stats', 'rarities', 'item_categories', 'npc_types', 'crafting_stations', 'crafting_specializations'] as const) {
    for (const record of context.meta[domain] as Record<string, unknown>[]) {
      map.set(record.id as string, record.export_key as string)
    }
  }
  return map
}

function resolveKey(lookup: Map<string, string>, id: string | null | undefined): string | null {
  if (!id) return null
  return lookup.get(id) ?? id
}

function renderNestedJson(context: ExportContext): string {
  const metaLookup = new Map<string, Record<string, unknown>>()
  for (const [domainKey, records] of Object.entries(context.meta)) {
    for (const record of records as Record<string, unknown>[]) {
      metaLookup.set(`${domainKey}:${record.id}`, record)
    }
  }

  const recordLookup = new Map<string, Record<string, unknown>>()
  for (const domain of ['classes', 'abilities', 'items', 'recipes', 'npcs', 'loot_tables'] as const) {
    for (const record of context[domain]) {
      recordLookup.set(record.id as string, record)
    }
  }

  function nestRef(id: string | null | undefined): Record<string, unknown> | null {
    if (!id) return null
    return recordLookup.get(id) ?? null
  }

  function nestMeta(domain: string, id: string | null | undefined): Record<string, unknown> | null {
    if (!id) return null
    return metaLookup.get(`${domain}:${id}`) ?? null
  }

  const output = {
    project: context.project,
    meta: context.meta,
    classes: context.classes.map((c) => ({
      ...c,
      abilities: (c.abilities as { ability_id: string }[]).map((a) => ({
        ...a,
        ability: nestRef(a.ability_id),
      })),
    })),
    abilities: context.abilities,
    items: context.items.map((i) => ({
      ...i,
      item_category: nestMeta('item_categories', i.item_category_id as string),
      rarity: nestMeta('rarities', i.rarity_id as string),
    })),
    recipes: context.recipes.map((r) => ({
      ...r,
      output_item: nestRef(r.output_item_id as string),
      crafting_station: nestMeta('crafting_stations', r.crafting_station_id as string | null),
      crafting_specialization: nestMeta('crafting_specializations', r.crafting_specialization_id as string | null),
      ingredients: (r.ingredients as { item_id: string }[]).map((ing) => ({
        ...ing,
        item: nestRef(ing.item_id),
      })),
    })),
    npcs: context.npcs.map((n) => ({
      ...n,
      npc_type: nestMeta('npc_types', n.npc_type_id as string),
      loot_table: nestRef(n.loot_table_id as string | null),
      class_assignments: (n.class_assignments as { class_id: string }[]).map((a) => ({
        ...a,
        class: nestRef(a.class_id),
      })),
      ability_assignments: (n.ability_assignments as { ability_id: string }[]).map((a) => ({
        ...a,
        ability: nestRef(a.ability_id),
      })),
    })),
    loot_tables: context.loot_tables.map((lt) => ({
      ...lt,
      entries: (lt.entries as { item_id: string }[]).map((e) => ({
        ...e,
        item: nestRef(e.item_id),
      })),
    })),
  }

  return JSON.stringify(output, null, 2)
}

function renderFlatJson(context: ExportContext): string {
  const lookup = buildExportKeyLookup(context)

  const output = {
    project: context.project,
    classes: context.classes.map((c) => ({
      ...c,
      abilities: (c.abilities as { ability_id: string; sort_order: number }[]).map((a) => ({
        ability_export_key: resolveKey(lookup, a.ability_id),
        sort_order: a.sort_order,
      })),
      derived_stat_overrides: (c.derived_stat_overrides as { derived_stat_id: string; formula: string }[]).map((o) => ({
        derived_stat_export_key: resolveKey(lookup, o.derived_stat_id),
        formula: o.formula,
      })),
    })),
    abilities: context.abilities,
    items: context.items.map(({ item_category_id, rarity_id, ...rest }) => ({
      ...rest,
      item_category_export_key: resolveKey(lookup, item_category_id as string),
      rarity_export_key: resolveKey(lookup, rarity_id as string),
    })),
    recipes: context.recipes.map(({ output_item_id, crafting_station_id, crafting_specialization_id, ...rest }) => ({
      ...rest,
      output_item_export_key: resolveKey(lookup, output_item_id as string),
      crafting_station_export_key: resolveKey(lookup, crafting_station_id as string | null),
      crafting_specialization_export_key: resolveKey(lookup, crafting_specialization_id as string | null),
      ingredients: (rest.ingredients as { item_id: string; quantity: number }[]).map((ing) => ({
        item_export_key: resolveKey(lookup, ing.item_id),
        quantity: ing.quantity,
      })),
    })),
    npcs: context.npcs.map(({ npc_type_id, loot_table_id, ...rest }) => ({
      ...rest,
      npc_type_export_key: resolveKey(lookup, npc_type_id as string),
      loot_table_export_key: resolveKey(lookup, loot_table_id as string | null),
      class_assignments: (rest.class_assignments as { class_id: string; level: number }[]).map((a) => ({
        class_export_key: resolveKey(lookup, a.class_id),
        level: a.level,
      })),
      ability_assignments: (rest.ability_assignments as { ability_id: string }[]).map((a) => ({
        ability_export_key: resolveKey(lookup, a.ability_id),
      })),
    })),
    loot_tables: context.loot_tables.map((lt) => ({
      ...lt,
      entries: (lt.entries as { item_id: string; weight: number; quantity_min: number; quantity_max: number }[]).map((e) => ({
        item_export_key: resolveKey(lookup, e.item_id),
        weight: e.weight,
        quantity_min: e.quantity_min,
        quantity_max: e.quantity_max,
      })),
    })),
  }

  return JSON.stringify(output, null, 2)
}

function renderCsv(context: ExportContext): RenderResult {
  const files: { filename: string; content: string }[] = []
  const lookup = buildExportKeyLookup(context)

  if (context.classes.length > 0) {
    files.push({
      filename: 'classes.csv',
      content: toCsv(context.classes.map((c) => ({
        export_key: c.export_key,
        display_name: c.display_name,
        description: c.description,
        resource_multiplier: c.resource_multiplier,
      }))),
    })
  }

  if (context.abilities.length > 0) {
    files.push({
      filename: 'abilities.csv',
      content: toCsv(context.abilities.map((a) => ({
        export_key: a.export_key,
        display_name: a.display_name,
        description: a.description,
        ability_type: a.ability_type,
        resource_type: a.resource_type,
        resource_cost: a.resource_cost,
        cooldown: a.cooldown,
      }))),
    })
  }

  if (context.items.length > 0) {
    files.push({
      filename: 'items.csv',
      content: toCsv(context.items.map((i) => ({
        export_key: i.export_key,
        display_name: i.display_name,
        description: i.description,
        item_category: resolveKey(lookup, i.item_category_id as string),
        rarity: resolveKey(lookup, i.rarity_id as string),
      }))),
    })
  }

  if (context.recipes.length > 0) {
    files.push({
      filename: 'recipes.csv',
      content: toCsv(context.recipes.map((r) => ({
        export_key: r.export_key,
        display_name: r.display_name,
        description: r.description,
        output_item: resolveKey(lookup, r.output_item_id as string),
        output_quantity: r.output_quantity,
        crafting_station: resolveKey(lookup, r.crafting_station_id as string | null),
        crafting_specialization: resolveKey(lookup, r.crafting_specialization_id as string | null),
      }))),
    })
  }

  if (context.npcs.length > 0) {
    files.push({
      filename: 'npcs.csv',
      content: toCsv(context.npcs.map((n) => ({
        export_key: n.export_key,
        display_name: n.display_name,
        description: n.description,
        npc_type: resolveKey(lookup, n.npc_type_id as string),
        loot_table: resolveKey(lookup, n.loot_table_id as string | null),
      }))),
    })
  }

  if (context.loot_tables.length > 0) {
    files.push({
      filename: 'loot_tables.csv',
      content: toCsv(context.loot_tables.map((lt) => ({
        export_key: lt.export_key,
        display_name: lt.display_name,
        description: lt.description,
      }))),
    })
  }

  const summary = files.map((f) => `--- ${f.filename} ---\n${f.content}`).join('\n\n')
  return { output: summary, files }
}

function toCsv(rows: Record<string, unknown>[]): string {
  if (rows.length === 0) return ''
  const headers = Object.keys(rows[0])
  const lines = [headers.join(',')]
  for (const row of rows) {
    lines.push(headers.map((h) => csvEscape(row[h])).join(','))
  }
  return lines.join('\n')
}

function csvEscape(value: unknown): string {
  if (value == null) return ''
  const str = String(value)
  if (str.includes(',') || str.includes('"') || str.includes('\n')) {
    return `"${str.replace(/"/g, '""')}"`
  }
  return str
}

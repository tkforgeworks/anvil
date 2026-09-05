import { randomUUID } from 'crypto'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import { safeHandle } from './safe-handle'
import { getDb } from '../db/connection'
import type { DbConnection } from '../db/connection'
import { markProjectDirty } from '../project/project-service'
import type { ChangeEntry } from '../project/change-accumulator'
import type {
  DerivedStatDefinition,
  DerivedStatInput,
  MetaCraftingSpecialization,
  MetaCraftingStation,
  MetaDeleteResult,
  MetaInUseKind,
  MetaInUseResult,
  MetaItemCategory,
  MetaItemInput,
  MetaNpcType,
  MetaRarity,
  MetaRarityInput,
  MetaReorderItem,
  MetaStat,
  ProjectSettings,
} from '../../shared/domain-types'

interface ItemCategoryRow {
  id: string
  display_name: string
  export_key: string
  description: string
  sort_order: number
}

interface NpcTypeRow {
  id: string
  display_name: string
  export_key: string
  description: string
  sort_order: number
}

interface CraftingStationRow {
  id: string
  display_name: string
  export_key: string
  description: string
  sort_order: number
}

interface CraftingSpecializationRow {
  id: string
  display_name: string
  export_key: string
  description: string
  sort_order: number
}

interface RarityRow {
  id: string
  display_name: string
  export_key: string
  color_hex: string
  sort_order: number
}

interface StatRow {
  id: string
  display_name: string
  export_key: string
  sort_order: number
}

interface ProjectSettingsRow {
  game_title: string
  max_level: number
  soft_delete_reference_severity: 'Warning' | 'Error'
}

function toMetaItemCategory(row: ItemCategoryRow): MetaItemCategory {
  return {
    id: row.id,
    displayName: row.display_name,
    exportKey: row.export_key,
    description: row.description,
    sortOrder: row.sort_order,
  }
}

function toMetaNpcType(row: NpcTypeRow): MetaNpcType {
  return {
    id: row.id,
    displayName: row.display_name,
    exportKey: row.export_key,
    description: row.description,
    sortOrder: row.sort_order,
  }
}

function toMetaCraftingStation(row: CraftingStationRow): MetaCraftingStation {
  return {
    id: row.id,
    displayName: row.display_name,
    exportKey: row.export_key,
    description: row.description,
    sortOrder: row.sort_order,
  }
}

function toMetaCraftingSpecialization(
  row: CraftingSpecializationRow,
): MetaCraftingSpecialization {
  return {
    id: row.id,
    displayName: row.display_name,
    exportKey: row.export_key,
    description: row.description,
    sortOrder: row.sort_order,
  }
}

function toMetaRarity(row: RarityRow): MetaRarity {
  return {
    id: row.id,
    displayName: row.display_name,
    exportKey: row.export_key,
    colorHex: row.color_hex,
    sortOrder: row.sort_order,
  }
}

function toMetaStat(row: StatRow): MetaStat {
  return {
    id: row.id,
    displayName: row.display_name,
    exportKey: row.export_key,
    sortOrder: row.sort_order,
  }
}

// ─── FK in-use checks ────────────────────────────────────────────────────────
//
// Shared by the delete handlers (which refuse to delete a referenced row) and
// the META_CHECK_IN_USE channel (which lets the renderer ask the same question
// without mutating anything — the buffered Project Settings modal uses it to
// reject a delete at click time, before the change is committed on Save).

function countOf(db: DbConnection, sql: string, id: string): number {
  return (db.prepare(sql).get(id) as { c: number }).c
}

export function checkMetaInUse(db: DbConnection, kind: MetaInUseKind, id: string): MetaInUseResult {
  const used = (reason: string): MetaInUseResult => ({ inUse: true, reason })
  const free: MetaInUseResult = { inUse: false, reason: null }
  switch (kind) {
    case 'stat': {
      const c = countOf(
        db,
        `SELECT COUNT(DISTINCT csg.class_id) AS c
         FROM class_stat_growth csg
         JOIN classes c ON c.id = csg.class_id
         WHERE csg.stat_id = ? AND c.deleted_at IS NULL`,
        id,
      )
      return c > 0 ? used(`Stat is used by ${c} class(es) in stat growth definitions.`) : free
    }
    case 'rarity': {
      const c = countOf(db, `SELECT COUNT(*) AS c FROM items WHERE rarity_id = ? AND deleted_at IS NULL`, id)
      return c > 0 ? used(`Rarity is used by ${c} item(s).`) : free
    }
    case 'item-category': {
      const c = countOf(db, `SELECT COUNT(*) AS c FROM items WHERE item_category_id = ? AND deleted_at IS NULL`, id)
      if (c > 0) return used(`Item category is used by ${c} item(s).`)
      const f = countOf(
        db,
        `SELECT COUNT(*) AS c FROM custom_field_definitions WHERE scope_type = 'item_category' AND scope_id = ?`,
        id,
      )
      return f > 0 ? used(`Item category has ${f} custom field definition(s). Delete those fields first.`) : free
    }
    case 'npc-type': {
      const c = countOf(db, `SELECT COUNT(*) AS c FROM npcs WHERE npc_type_id = ? AND deleted_at IS NULL`, id)
      if (c > 0) return used(`NPC type is used by ${c} NPC(s).`)
      const f = countOf(
        db,
        `SELECT COUNT(*) AS c FROM custom_field_definitions WHERE scope_type = 'npc_type' AND scope_id = ?`,
        id,
      )
      return f > 0 ? used(`NPC type has ${f} custom field definition(s). Delete those fields first.`) : free
    }
    case 'crafting-station': {
      const c = countOf(db, `SELECT COUNT(*) AS c FROM recipes WHERE crafting_station_id = ? AND deleted_at IS NULL`, id)
      return c > 0 ? used(`Station is used by ${c} recipe(s).`) : free
    }
    case 'crafting-specialization': {
      const c = countOf(
        db,
        `SELECT COUNT(*) AS c FROM recipes WHERE crafting_specialization_id = ? AND deleted_at IS NULL`,
        id,
      )
      return c > 0 ? used(`Specialization is used by ${c} recipe(s).`) : free
    }
    case 'derived-stat': {
      const c = countOf(
        db,
        `SELECT COUNT(DISTINCT class_id) AS c FROM class_derived_stat_overrides WHERE derived_stat_id = ?`,
        id,
      )
      return c > 0 ? used(`Derived stat has overrides in ${c} class(es).`) : free
    }
  }
}

/** Refuse-or-delete helper shared by every META_DELETE_* handler. */
function deleteMetaRow(kind: MetaInUseKind, table: string, id: string): MetaDeleteResult {
  const db = getDb()
  const check = checkMetaInUse(db, kind, id)
  if (check.inUse) return { deleted: false, reason: check.reason }
  db.prepare(`DELETE FROM ${table} WHERE id = ?`).run(id)
  markProjectDirty({ domain: 'meta', recordId: id, recordName: '', subArea: 'basic-info', action: 'delete' })
  return { deleted: true, reason: null }
}

export function registerMetaHandlers(): void {
  safeHandle(
    IPC_CHANNELS.META_CHECK_IN_USE,
    (_event, kind: MetaInUseKind, id: string): MetaInUseResult => checkMetaInUse(getDb(), kind, id),
  )
  safeHandle(IPC_CHANNELS.META_LIST_ITEM_CATEGORIES, () => {
    const rows = getDb()
      .prepare(
        `SELECT id, display_name, export_key, description, sort_order
         FROM item_categories
         ORDER BY sort_order, display_name COLLATE NOCASE`,
      )
      .all() as ItemCategoryRow[]
    return rows.map(toMetaItemCategory)
  })

  safeHandle(IPC_CHANNELS.META_LIST_RARITIES, () => {
    const rows = getDb()
      .prepare(
        `SELECT id, display_name, export_key, color_hex, sort_order
         FROM rarities
         ORDER BY sort_order, display_name COLLATE NOCASE`,
      )
      .all() as RarityRow[]
    return rows.map(toMetaRarity)
  })

  safeHandle(IPC_CHANNELS.META_LIST_NPC_TYPES, () => {
    const rows = getDb()
      .prepare(
        `SELECT id, display_name, export_key, description, sort_order
         FROM npc_types
         ORDER BY sort_order, display_name COLLATE NOCASE`,
      )
      .all() as NpcTypeRow[]
    return rows.map(toMetaNpcType)
  })

  safeHandle(IPC_CHANNELS.META_LIST_CRAFTING_STATIONS, () => {
    const rows = getDb()
      .prepare(
        `SELECT id, display_name, export_key, description, sort_order
         FROM crafting_stations
         ORDER BY sort_order, display_name COLLATE NOCASE`,
      )
      .all() as CraftingStationRow[]
    return rows.map(toMetaCraftingStation)
  })

  safeHandle(IPC_CHANNELS.META_LIST_CRAFTING_SPECIALIZATIONS, () => {
    const rows = getDb()
      .prepare(
        `SELECT id, display_name, export_key, description, sort_order
         FROM crafting_specializations
         ORDER BY sort_order, display_name COLLATE NOCASE`,
      )
      .all() as CraftingSpecializationRow[]
    return rows.map(toMetaCraftingSpecialization)
  })

  safeHandle(IPC_CHANNELS.META_LIST_STATS, () => {
    const rows = getDb()
      .prepare(
        `SELECT id, display_name, export_key, sort_order
         FROM stats
         ORDER BY sort_order`,
      )
      .all() as StatRow[]
    return rows.map(toMetaStat)
  })

  safeHandle(IPC_CHANNELS.META_LIST_DERIVED_STATS, (): DerivedStatDefinition[] => {
    interface DerivedStatRow {
      id: string; display_name: string; export_key: string
      formula: string; output_type: string; rounding_mode: string; sort_order: number
    }
    const rows = getDb()
      .prepare(
        `SELECT id, display_name, export_key, formula, output_type, rounding_mode, sort_order
         FROM derived_stat_definitions
         ORDER BY sort_order`,
      )
      .all() as DerivedStatRow[]
    return rows.map((r) => ({
      id: r.id,
      displayName: r.display_name,
      exportKey: r.export_key,
      formula: r.formula,
      outputType: r.output_type as 'integer' | 'float',
      roundingMode: r.rounding_mode as 'floor' | 'round' | 'none',
      sortOrder: r.sort_order,
    }))
  })

  safeHandle(IPC_CHANNELS.META_GET_PROJECT_SETTINGS, (): ProjectSettings => {
    const row = getDb()
      .prepare(`SELECT game_title, max_level, soft_delete_reference_severity FROM project_info LIMIT 1`)
      .get() as ProjectSettingsRow
    return {
      gameTitle: row.game_title,
      maxLevel: row.max_level,
      softDeleteReferenceSeverity: row.soft_delete_reference_severity,
    }
  })

  // ─── Project Settings update ─────────────────────────────────────────────────

  safeHandle(
    IPC_CHANNELS.META_SET_PROJECT_SETTINGS,
    (_event, input: Partial<ProjectSettings>): ProjectSettings => {
      const db = getDb()
      if (input.gameTitle !== undefined) {
        db.prepare(`UPDATE project_info SET game_title = ?`).run(input.gameTitle)
      }
      if (input.maxLevel !== undefined) {
        db.prepare(`UPDATE project_info SET max_level = ?`).run(input.maxLevel)
      }
      if (input.softDeleteReferenceSeverity !== undefined) {
        db.prepare(`UPDATE project_info SET soft_delete_reference_severity = ?`).run(
          input.softDeleteReferenceSeverity,
        )
      }
      markProjectDirty({ domain: 'meta', recordId: 'project-settings', recordName: 'project settings', subArea: 'basic-info', action: 'update' })
      const row = db
        .prepare(`SELECT game_title, max_level, soft_delete_reference_severity FROM project_info LIMIT 1`)
        .get() as ProjectSettingsRow
      return {
        gameTitle: row.game_title,
        maxLevel: row.max_level,
        softDeleteReferenceSeverity: row.soft_delete_reference_severity,
      }
    },
  )

  // ─── Stats CRUD ──────────────────────────────────────────────────────────────

  safeHandle(
    IPC_CHANNELS.META_ADD_STAT,
    (_event, input: MetaItemInput): MetaStat => {
      const db = getDb()
      const id = randomUUID()
      const now = new Date().toISOString()
      const maxOrder = (
        db.prepare(`SELECT COALESCE(MAX(sort_order), 0) AS m FROM stats`).get() as { m: number }
      ).m
      db.prepare(
        `INSERT INTO stats (id, display_name, export_key, description, sort_order, created_at, updated_at)
         VALUES (?, ?, ?, '', ?, ?, ?)`,
      ).run(id, input.displayName, input.exportKey, maxOrder + 1, now, now)
      markProjectDirty({ domain: 'meta', recordId: id, recordName: input.displayName, subArea: 'basic-info', action: 'create' })
      const row = db.prepare(`SELECT id, display_name, export_key, sort_order FROM stats WHERE id = ?`).get(id) as StatRow
      return toMetaStat(row)
    },
  )

  safeHandle(
    IPC_CHANNELS.META_UPDATE_STAT,
    (_event, id: string, input: MetaItemInput): MetaStat => {
      const db = getDb()
      const now = new Date().toISOString()
      db.prepare(
        `UPDATE stats SET display_name = ?, export_key = ?, updated_at = ? WHERE id = ?`,
      ).run(input.displayName, input.exportKey, now, id)
      markProjectDirty({ domain: 'meta', recordId: id, recordName: input.displayName, subArea: 'basic-info', action: 'update' })
      const row = db.prepare(`SELECT id, display_name, export_key, sort_order FROM stats WHERE id = ?`).get(id) as StatRow
      return toMetaStat(row)
    },
  )

  safeHandle(
    IPC_CHANNELS.META_DELETE_STAT,
    (_event, id: string): MetaDeleteResult => deleteMetaRow('stat', 'stats', id),
  )

  safeHandle(
    IPC_CHANNELS.META_REORDER_STATS,
    (_event, items: MetaReorderItem[]): void => {
      const db = getDb()
      const stmt = db.prepare(`UPDATE stats SET sort_order = ?, updated_at = ? WHERE id = ?`)
      const now = new Date().toISOString()
      const run = db.transaction(() => {
        for (const item of items) {
          stmt.run(item.sortOrder, now, item.id)
        }
      })
      run()
      markProjectDirty({ domain: 'meta', recordId: 'stats', recordName: 'stats order', subArea: 'basic-info', action: 'update' })
    },
  )

  // ─── Rarities CRUD ───────────────────────────────────────────────────────────

  safeHandle(
    IPC_CHANNELS.META_ADD_RARITY,
    (_event, input: MetaRarityInput): MetaRarity => {
      const db = getDb()
      const id = randomUUID()
      const now = new Date().toISOString()
      const maxOrder = (
        db.prepare(`SELECT COALESCE(MAX(sort_order), 0) AS m FROM rarities`).get() as { m: number }
      ).m
      db.prepare(
        `INSERT INTO rarities (id, display_name, export_key, color_hex, sort_order, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
      ).run(id, input.displayName, input.exportKey, input.colorHex, maxOrder + 1, now, now)
      markProjectDirty({ domain: 'meta', recordId: id, recordName: input.displayName, subArea: 'basic-info', action: 'create' })
      const row = db
        .prepare(`SELECT id, display_name, export_key, color_hex, sort_order FROM rarities WHERE id = ?`)
        .get(id) as RarityRow
      return toMetaRarity(row)
    },
  )

  safeHandle(
    IPC_CHANNELS.META_UPDATE_RARITY,
    (_event, id: string, input: MetaRarityInput): MetaRarity => {
      const db = getDb()
      const now = new Date().toISOString()
      db.prepare(
        `UPDATE rarities SET display_name = ?, export_key = ?, color_hex = ?, updated_at = ? WHERE id = ?`,
      ).run(input.displayName, input.exportKey, input.colorHex, now, id)
      markProjectDirty({ domain: 'meta', recordId: id, recordName: input.displayName, subArea: 'basic-info', action: 'update' })
      const row = db
        .prepare(`SELECT id, display_name, export_key, color_hex, sort_order FROM rarities WHERE id = ?`)
        .get(id) as RarityRow
      return toMetaRarity(row)
    },
  )

  safeHandle(
    IPC_CHANNELS.META_DELETE_RARITY,
    (_event, id: string): MetaDeleteResult => deleteMetaRow('rarity', 'rarities', id),
  )

  safeHandle(
    IPC_CHANNELS.META_REORDER_RARITIES,
    (_event, items: MetaReorderItem[]): void => {
      const db = getDb()
      const stmt = db.prepare(`UPDATE rarities SET sort_order = ?, updated_at = ? WHERE id = ?`)
      const now = new Date().toISOString()
      const run = db.transaction(() => {
        for (const item of items) {
          stmt.run(item.sortOrder, now, item.id)
        }
      })
      run()
      markProjectDirty({ domain: 'meta', recordId: 'rarities', recordName: 'rarities order', subArea: 'basic-info', action: 'update' })
    },
  )

  // ─── Item Categories CRUD ────────────────────────────────────────────────────

  safeHandle(
    IPC_CHANNELS.META_ADD_ITEM_CATEGORY,
    (_event, input: MetaItemInput): MetaItemCategory => {
      const db = getDb()
      const id = randomUUID()
      const now = new Date().toISOString()
      const maxOrder = (
        db.prepare(`SELECT COALESCE(MAX(sort_order), 0) AS m FROM item_categories`).get() as { m: number }
      ).m
      db.prepare(
        `INSERT INTO item_categories (id, display_name, export_key, description, sort_order, created_at, updated_at)
         VALUES (?, ?, ?, '', ?, ?, ?)`,
      ).run(id, input.displayName, input.exportKey, maxOrder + 1, now, now)
      markProjectDirty({ domain: 'meta', recordId: id, recordName: input.displayName, subArea: 'basic-info', action: 'create' })
      const row = db
        .prepare(`SELECT id, display_name, export_key, description, sort_order FROM item_categories WHERE id = ?`)
        .get(id) as ItemCategoryRow
      return toMetaItemCategory(row)
    },
  )

  safeHandle(
    IPC_CHANNELS.META_UPDATE_ITEM_CATEGORY,
    (_event, id: string, input: MetaItemInput): MetaItemCategory => {
      const db = getDb()
      const now = new Date().toISOString()
      db.prepare(
        `UPDATE item_categories SET display_name = ?, export_key = ?, updated_at = ? WHERE id = ?`,
      ).run(input.displayName, input.exportKey, now, id)
      markProjectDirty({ domain: 'meta', recordId: id, recordName: input.displayName, subArea: 'basic-info', action: 'update' })
      const row = db
        .prepare(`SELECT id, display_name, export_key, description, sort_order FROM item_categories WHERE id = ?`)
        .get(id) as ItemCategoryRow
      return toMetaItemCategory(row)
    },
  )

  safeHandle(
    IPC_CHANNELS.META_DELETE_ITEM_CATEGORY,
    (_event, id: string): MetaDeleteResult => deleteMetaRow('item-category', 'item_categories', id),
  )

  safeHandle(
    IPC_CHANNELS.META_REORDER_ITEM_CATEGORIES,
    (_event, items: MetaReorderItem[]): void => {
      const db = getDb()
      const stmt = db.prepare(`UPDATE item_categories SET sort_order = ?, updated_at = ? WHERE id = ?`)
      const now = new Date().toISOString()
      const run = db.transaction(() => {
        for (const item of items) {
          stmt.run(item.sortOrder, now, item.id)
        }
      })
      run()
      markProjectDirty({ domain: 'meta', recordId: 'item-categories', recordName: 'item categories order', subArea: 'basic-info', action: 'update' })
    },
  )

  // ─── NPC Types CRUD ──────────────────────────────────────────────────────────

  safeHandle(
    IPC_CHANNELS.META_ADD_NPC_TYPE,
    (_event, input: MetaItemInput): MetaNpcType => {
      const db = getDb()
      const id = randomUUID()
      const now = new Date().toISOString()
      const maxOrder = (
        db.prepare(`SELECT COALESCE(MAX(sort_order), 0) AS m FROM npc_types`).get() as { m: number }
      ).m
      db.prepare(
        `INSERT INTO npc_types (id, display_name, export_key, description, sort_order, created_at, updated_at)
         VALUES (?, ?, ?, '', ?, ?, ?)`,
      ).run(id, input.displayName, input.exportKey, maxOrder + 1, now, now)
      markProjectDirty({ domain: 'meta', recordId: id, recordName: input.displayName, subArea: 'basic-info', action: 'create' })
      const row = db
        .prepare(`SELECT id, display_name, export_key, description, sort_order FROM npc_types WHERE id = ?`)
        .get(id) as NpcTypeRow
      return toMetaNpcType(row)
    },
  )

  safeHandle(
    IPC_CHANNELS.META_UPDATE_NPC_TYPE,
    (_event, id: string, input: MetaItemInput): MetaNpcType => {
      const db = getDb()
      const now = new Date().toISOString()
      db.prepare(
        `UPDATE npc_types SET display_name = ?, export_key = ?, updated_at = ? WHERE id = ?`,
      ).run(input.displayName, input.exportKey, now, id)
      markProjectDirty({ domain: 'meta', recordId: id, recordName: input.displayName, subArea: 'basic-info', action: 'update' })
      const row = db
        .prepare(`SELECT id, display_name, export_key, description, sort_order FROM npc_types WHERE id = ?`)
        .get(id) as NpcTypeRow
      return toMetaNpcType(row)
    },
  )

  safeHandle(
    IPC_CHANNELS.META_DELETE_NPC_TYPE,
    (_event, id: string): MetaDeleteResult => deleteMetaRow('npc-type', 'npc_types', id),
  )

  safeHandle(
    IPC_CHANNELS.META_REORDER_NPC_TYPES,
    (_event, items: MetaReorderItem[]): void => {
      const db = getDb()
      const stmt = db.prepare(`UPDATE npc_types SET sort_order = ?, updated_at = ? WHERE id = ?`)
      const now = new Date().toISOString()
      const run = db.transaction(() => {
        for (const item of items) {
          stmt.run(item.sortOrder, now, item.id)
        }
      })
      run()
      markProjectDirty({ domain: 'meta', recordId: 'npc-types', recordName: 'NPC types order', subArea: 'basic-info', action: 'update' })
    },
  )

  // ─── Crafting Stations CRUD ──────────────────────────────────────────────────

  safeHandle(
    IPC_CHANNELS.META_ADD_CRAFTING_STATION,
    (_event, input: MetaItemInput): MetaCraftingStation => {
      const db = getDb()
      const id = randomUUID()
      const now = new Date().toISOString()
      const maxOrder = (
        db.prepare(`SELECT COALESCE(MAX(sort_order), 0) AS m FROM crafting_stations`).get() as { m: number }
      ).m
      db.prepare(
        `INSERT INTO crafting_stations (id, display_name, export_key, description, sort_order, created_at, updated_at)
         VALUES (?, ?, ?, '', ?, ?, ?)`,
      ).run(id, input.displayName, input.exportKey, maxOrder + 1, now, now)
      markProjectDirty({ domain: 'meta', recordId: id, recordName: input.displayName, subArea: 'basic-info', action: 'create' })
      const row = db
        .prepare(`SELECT id, display_name, export_key, description, sort_order FROM crafting_stations WHERE id = ?`)
        .get(id) as CraftingStationRow
      return toMetaCraftingStation(row)
    },
  )

  safeHandle(
    IPC_CHANNELS.META_UPDATE_CRAFTING_STATION,
    (_event, id: string, input: MetaItemInput): MetaCraftingStation => {
      const db = getDb()
      const now = new Date().toISOString()
      db.prepare(
        `UPDATE crafting_stations SET display_name = ?, export_key = ?, updated_at = ? WHERE id = ?`,
      ).run(input.displayName, input.exportKey, now, id)
      markProjectDirty({ domain: 'meta', recordId: id, recordName: input.displayName, subArea: 'basic-info', action: 'update' })
      const row = db
        .prepare(`SELECT id, display_name, export_key, description, sort_order FROM crafting_stations WHERE id = ?`)
        .get(id) as CraftingStationRow
      return toMetaCraftingStation(row)
    },
  )

  safeHandle(
    IPC_CHANNELS.META_DELETE_CRAFTING_STATION,
    (_event, id: string): MetaDeleteResult => deleteMetaRow('crafting-station', 'crafting_stations', id),
  )

  safeHandle(
    IPC_CHANNELS.META_REORDER_CRAFTING_STATIONS,
    (_event, items: MetaReorderItem[]): void => {
      const db = getDb()
      const stmt = db.prepare(`UPDATE crafting_stations SET sort_order = ?, updated_at = ? WHERE id = ?`)
      const now = new Date().toISOString()
      const run = db.transaction(() => {
        for (const item of items) {
          stmt.run(item.sortOrder, now, item.id)
        }
      })
      run()
      markProjectDirty({ domain: 'meta', recordId: 'crafting-stations', recordName: 'crafting stations order', subArea: 'basic-info', action: 'update' })
    },
  )

  // ─── Crafting Specializations CRUD ───────────────────────────────────────────

  safeHandle(
    IPC_CHANNELS.META_ADD_CRAFTING_SPECIALIZATION,
    (_event, input: MetaItemInput): MetaCraftingSpecialization => {
      const db = getDb()
      const id = randomUUID()
      const now = new Date().toISOString()
      const maxOrder = (
        db.prepare(`SELECT COALESCE(MAX(sort_order), 0) AS m FROM crafting_specializations`).get() as { m: number }
      ).m
      db.prepare(
        `INSERT INTO crafting_specializations (id, display_name, export_key, description, sort_order, created_at, updated_at)
         VALUES (?, ?, ?, '', ?, ?, ?)`,
      ).run(id, input.displayName, input.exportKey, maxOrder + 1, now, now)
      markProjectDirty({ domain: 'meta', recordId: id, recordName: input.displayName, subArea: 'basic-info', action: 'create' })
      const row = db
        .prepare(`SELECT id, display_name, export_key, description, sort_order FROM crafting_specializations WHERE id = ?`)
        .get(id) as CraftingSpecializationRow
      return toMetaCraftingSpecialization(row)
    },
  )

  safeHandle(
    IPC_CHANNELS.META_UPDATE_CRAFTING_SPECIALIZATION,
    (_event, id: string, input: MetaItemInput): MetaCraftingSpecialization => {
      const db = getDb()
      const now = new Date().toISOString()
      db.prepare(
        `UPDATE crafting_specializations SET display_name = ?, export_key = ?, updated_at = ? WHERE id = ?`,
      ).run(input.displayName, input.exportKey, now, id)
      markProjectDirty({ domain: 'meta', recordId: id, recordName: input.displayName, subArea: 'basic-info', action: 'update' })
      const row = db
        .prepare(`SELECT id, display_name, export_key, description, sort_order FROM crafting_specializations WHERE id = ?`)
        .get(id) as CraftingSpecializationRow
      return toMetaCraftingSpecialization(row)
    },
  )

  safeHandle(
    IPC_CHANNELS.META_DELETE_CRAFTING_SPECIALIZATION,
    (_event, id: string): MetaDeleteResult => deleteMetaRow('crafting-specialization', 'crafting_specializations', id),
  )

  safeHandle(
    IPC_CHANNELS.META_REORDER_CRAFTING_SPECIALIZATIONS,
    (_event, items: MetaReorderItem[]): void => {
      const db = getDb()
      const stmt = db.prepare(`UPDATE crafting_specializations SET sort_order = ?, updated_at = ? WHERE id = ?`)
      const now = new Date().toISOString()
      const run = db.transaction(() => {
        for (const item of items) {
          stmt.run(item.sortOrder, now, item.id)
        }
      })
      run()
      markProjectDirty({ domain: 'meta', recordId: 'crafting-specializations', recordName: 'crafting specializations order', subArea: 'basic-info', action: 'update' })
    },
  )

  // ─── Derived Stat Definitions CRUD ───────────────────────────────────────────

  safeHandle(
    IPC_CHANNELS.META_ADD_DERIVED_STAT,
    (_event, input: DerivedStatInput): DerivedStatDefinition => {
      const db = getDb()
      const id = randomUUID()
      const now = new Date().toISOString()
      const maxOrder = (
        db.prepare(`SELECT COALESCE(MAX(sort_order), 0) AS m FROM derived_stat_definitions`).get() as { m: number }
      ).m
      db.prepare(
        `INSERT INTO derived_stat_definitions (id, display_name, export_key, formula, output_type, rounding_mode, sort_order, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      ).run(id, input.displayName, input.exportKey, input.formula, input.outputType, input.roundingMode, maxOrder + 1, now, now)
      markProjectDirty({ domain: 'meta', recordId: id, recordName: input.displayName, subArea: 'basic-info', action: 'create' })
      return {
        id,
        displayName: input.displayName,
        exportKey: input.exportKey,
        formula: input.formula,
        outputType: input.outputType,
        roundingMode: input.roundingMode,
        sortOrder: maxOrder + 1,
      }
    },
  )

  safeHandle(
    IPC_CHANNELS.META_UPDATE_DERIVED_STAT,
    (_event, id: string, input: DerivedStatInput): DerivedStatDefinition => {
      const db = getDb()
      const now = new Date().toISOString()
      db.prepare(
        `UPDATE derived_stat_definitions
         SET display_name = ?, export_key = ?, formula = ?, output_type = ?, rounding_mode = ?, updated_at = ?
         WHERE id = ?`,
      ).run(input.displayName, input.exportKey, input.formula, input.outputType, input.roundingMode, now, id)
      markProjectDirty({ domain: 'meta', recordId: id, recordName: input.displayName, subArea: 'basic-info', action: 'update' })
      interface DerivedStatRow {
        id: string; display_name: string; export_key: string
        formula: string; output_type: string; rounding_mode: string; sort_order: number
      }
      const row = db
        .prepare(
          `SELECT id, display_name, export_key, formula, output_type, rounding_mode, sort_order
           FROM derived_stat_definitions WHERE id = ?`,
        )
        .get(id) as DerivedStatRow
      return {
        id: row.id,
        displayName: row.display_name,
        exportKey: row.export_key,
        formula: row.formula,
        outputType: row.output_type as 'integer' | 'float',
        roundingMode: row.rounding_mode as 'floor' | 'round' | 'none',
        sortOrder: row.sort_order,
      }
    },
  )

  safeHandle(
    IPC_CHANNELS.META_DELETE_DERIVED_STAT,
    (_event, id: string): MetaDeleteResult => deleteMetaRow('derived-stat', 'derived_stat_definitions', id),
  )

  safeHandle(
    IPC_CHANNELS.META_REORDER_DERIVED_STATS,
    (_event, items: MetaReorderItem[]): void => {
      const db = getDb()
      const stmt = db.prepare(`UPDATE derived_stat_definitions SET sort_order = ?, updated_at = ? WHERE id = ?`)
      const now = new Date().toISOString()
      const run = db.transaction(() => {
        for (const item of items) {
          stmt.run(item.sortOrder, now, item.id)
        }
      })
      run()
      markProjectDirty({ domain: 'meta', recordId: 'derived-stats', recordName: 'derived stats order', subArea: 'basic-info', action: 'update' })
    },
  )
}

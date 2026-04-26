import { randomUUID } from 'crypto'
import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import { getDb } from '../db/connection'
import { markProjectDirty } from '../project/project-service'
import type {
  DerivedStatDefinition,
  DerivedStatInput,
  MetaCraftingSpecialization,
  MetaCraftingStation,
  MetaDeleteResult,
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

export function registerMetaHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.META_LIST_ITEM_CATEGORIES, () => {
    const rows = getDb()
      .prepare(
        `SELECT id, display_name, export_key, description, sort_order
         FROM item_categories
         ORDER BY sort_order, display_name COLLATE NOCASE`,
      )
      .all() as ItemCategoryRow[]
    return rows.map(toMetaItemCategory)
  })

  ipcMain.handle(IPC_CHANNELS.META_LIST_RARITIES, () => {
    const rows = getDb()
      .prepare(
        `SELECT id, display_name, export_key, color_hex, sort_order
         FROM rarities
         ORDER BY sort_order, display_name COLLATE NOCASE`,
      )
      .all() as RarityRow[]
    return rows.map(toMetaRarity)
  })

  ipcMain.handle(IPC_CHANNELS.META_LIST_NPC_TYPES, () => {
    const rows = getDb()
      .prepare(
        `SELECT id, display_name, export_key, description, sort_order
         FROM npc_types
         ORDER BY sort_order, display_name COLLATE NOCASE`,
      )
      .all() as NpcTypeRow[]
    return rows.map(toMetaNpcType)
  })

  ipcMain.handle(IPC_CHANNELS.META_LIST_CRAFTING_STATIONS, () => {
    const rows = getDb()
      .prepare(
        `SELECT id, display_name, export_key, description, sort_order
         FROM crafting_stations
         ORDER BY sort_order, display_name COLLATE NOCASE`,
      )
      .all() as CraftingStationRow[]
    return rows.map(toMetaCraftingStation)
  })

  ipcMain.handle(IPC_CHANNELS.META_LIST_CRAFTING_SPECIALIZATIONS, () => {
    const rows = getDb()
      .prepare(
        `SELECT id, display_name, export_key, description, sort_order
         FROM crafting_specializations
         ORDER BY sort_order, display_name COLLATE NOCASE`,
      )
      .all() as CraftingSpecializationRow[]
    return rows.map(toMetaCraftingSpecialization)
  })

  ipcMain.handle(IPC_CHANNELS.META_LIST_STATS, () => {
    const rows = getDb()
      .prepare(
        `SELECT id, display_name, export_key, sort_order
         FROM stats
         ORDER BY sort_order`,
      )
      .all() as StatRow[]
    return rows.map(toMetaStat)
  })

  ipcMain.handle(IPC_CHANNELS.META_LIST_DERIVED_STATS, (): DerivedStatDefinition[] => {
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

  ipcMain.handle(IPC_CHANNELS.META_GET_PROJECT_SETTINGS, (): ProjectSettings => {
    const row = getDb()
      .prepare(`SELECT max_level, soft_delete_reference_severity FROM project_info LIMIT 1`)
      .get() as ProjectSettingsRow
    return {
      maxLevel: row.max_level,
      softDeleteReferenceSeverity: row.soft_delete_reference_severity,
    }
  })

  // ─── Project Settings update ─────────────────────────────────────────────────

  ipcMain.handle(
    IPC_CHANNELS.META_SET_PROJECT_SETTINGS,
    (_event, input: Partial<ProjectSettings>): ProjectSettings => {
      const db = getDb()
      if (input.maxLevel !== undefined) {
        db.prepare(`UPDATE project_info SET max_level = ?`).run(input.maxLevel)
      }
      if (input.softDeleteReferenceSeverity !== undefined) {
        db.prepare(`UPDATE project_info SET soft_delete_reference_severity = ?`).run(
          input.softDeleteReferenceSeverity,
        )
      }
      markProjectDirty()
      const row = db
        .prepare(`SELECT max_level, soft_delete_reference_severity FROM project_info LIMIT 1`)
        .get() as ProjectSettingsRow
      return {
        maxLevel: row.max_level,
        softDeleteReferenceSeverity: row.soft_delete_reference_severity,
      }
    },
  )

  // ─── Stats CRUD ──────────────────────────────────────────────────────────────

  ipcMain.handle(
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
      markProjectDirty()
      const row = db.prepare(`SELECT id, display_name, export_key, sort_order FROM stats WHERE id = ?`).get(id) as StatRow
      return toMetaStat(row)
    },
  )

  ipcMain.handle(
    IPC_CHANNELS.META_UPDATE_STAT,
    (_event, id: string, input: MetaItemInput): MetaStat => {
      const db = getDb()
      const now = new Date().toISOString()
      db.prepare(
        `UPDATE stats SET display_name = ?, export_key = ?, updated_at = ? WHERE id = ?`,
      ).run(input.displayName, input.exportKey, now, id)
      markProjectDirty()
      const row = db.prepare(`SELECT id, display_name, export_key, sort_order FROM stats WHERE id = ?`).get(id) as StatRow
      return toMetaStat(row)
    },
  )

  ipcMain.handle(
    IPC_CHANNELS.META_DELETE_STAT,
    (_event, id: string): MetaDeleteResult => {
      const db = getDb()
      const { c } = db
        .prepare(
          `SELECT COUNT(DISTINCT csg.class_id) AS c
           FROM class_stat_growth csg
           JOIN classes c ON c.id = csg.class_id
           WHERE csg.stat_id = ? AND c.deleted_at IS NULL`,
        )
        .get(id) as { c: number }
      if (c > 0) {
        return { deleted: false, reason: `Stat is used by ${c} class(es) in stat growth definitions.` }
      }
      db.prepare(`DELETE FROM stats WHERE id = ?`).run(id)
      markProjectDirty()
      return { deleted: true, reason: null }
    },
  )

  ipcMain.handle(
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
      markProjectDirty()
    },
  )

  // ─── Rarities CRUD ───────────────────────────────────────────────────────────

  ipcMain.handle(
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
      markProjectDirty()
      const row = db
        .prepare(`SELECT id, display_name, export_key, color_hex, sort_order FROM rarities WHERE id = ?`)
        .get(id) as RarityRow
      return toMetaRarity(row)
    },
  )

  ipcMain.handle(
    IPC_CHANNELS.META_UPDATE_RARITY,
    (_event, id: string, input: MetaRarityInput): MetaRarity => {
      const db = getDb()
      const now = new Date().toISOString()
      db.prepare(
        `UPDATE rarities SET display_name = ?, export_key = ?, color_hex = ?, updated_at = ? WHERE id = ?`,
      ).run(input.displayName, input.exportKey, input.colorHex, now, id)
      markProjectDirty()
      const row = db
        .prepare(`SELECT id, display_name, export_key, color_hex, sort_order FROM rarities WHERE id = ?`)
        .get(id) as RarityRow
      return toMetaRarity(row)
    },
  )

  ipcMain.handle(
    IPC_CHANNELS.META_DELETE_RARITY,
    (_event, id: string): MetaDeleteResult => {
      const db = getDb()
      const { c } = db
        .prepare(`SELECT COUNT(*) AS c FROM items WHERE rarity_id = ? AND deleted_at IS NULL`)
        .get(id) as { c: number }
      if (c > 0) {
        return { deleted: false, reason: `Rarity is used by ${c} item(s).` }
      }
      db.prepare(`DELETE FROM rarities WHERE id = ?`).run(id)
      markProjectDirty()
      return { deleted: true, reason: null }
    },
  )

  ipcMain.handle(
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
      markProjectDirty()
    },
  )

  // ─── Crafting Stations CRUD ──────────────────────────────────────────────────

  ipcMain.handle(
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
      markProjectDirty()
      const row = db
        .prepare(`SELECT id, display_name, export_key, description, sort_order FROM crafting_stations WHERE id = ?`)
        .get(id) as CraftingStationRow
      return toMetaCraftingStation(row)
    },
  )

  ipcMain.handle(
    IPC_CHANNELS.META_UPDATE_CRAFTING_STATION,
    (_event, id: string, input: MetaItemInput): MetaCraftingStation => {
      const db = getDb()
      const now = new Date().toISOString()
      db.prepare(
        `UPDATE crafting_stations SET display_name = ?, export_key = ?, updated_at = ? WHERE id = ?`,
      ).run(input.displayName, input.exportKey, now, id)
      markProjectDirty()
      const row = db
        .prepare(`SELECT id, display_name, export_key, description, sort_order FROM crafting_stations WHERE id = ?`)
        .get(id) as CraftingStationRow
      return toMetaCraftingStation(row)
    },
  )

  ipcMain.handle(
    IPC_CHANNELS.META_DELETE_CRAFTING_STATION,
    (_event, id: string): MetaDeleteResult => {
      const db = getDb()
      const { c } = db
        .prepare(`SELECT COUNT(*) AS c FROM recipes WHERE crafting_station_id = ? AND deleted_at IS NULL`)
        .get(id) as { c: number }
      if (c > 0) {
        return { deleted: false, reason: `Station is used by ${c} recipe(s).` }
      }
      db.prepare(`DELETE FROM crafting_stations WHERE id = ?`).run(id)
      markProjectDirty()
      return { deleted: true, reason: null }
    },
  )

  ipcMain.handle(
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
      markProjectDirty()
    },
  )

  // ─── Crafting Specializations CRUD ───────────────────────────────────────────

  ipcMain.handle(
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
      markProjectDirty()
      const row = db
        .prepare(`SELECT id, display_name, export_key, description, sort_order FROM crafting_specializations WHERE id = ?`)
        .get(id) as CraftingSpecializationRow
      return toMetaCraftingSpecialization(row)
    },
  )

  ipcMain.handle(
    IPC_CHANNELS.META_UPDATE_CRAFTING_SPECIALIZATION,
    (_event, id: string, input: MetaItemInput): MetaCraftingSpecialization => {
      const db = getDb()
      const now = new Date().toISOString()
      db.prepare(
        `UPDATE crafting_specializations SET display_name = ?, export_key = ?, updated_at = ? WHERE id = ?`,
      ).run(input.displayName, input.exportKey, now, id)
      markProjectDirty()
      const row = db
        .prepare(`SELECT id, display_name, export_key, description, sort_order FROM crafting_specializations WHERE id = ?`)
        .get(id) as CraftingSpecializationRow
      return toMetaCraftingSpecialization(row)
    },
  )

  ipcMain.handle(
    IPC_CHANNELS.META_DELETE_CRAFTING_SPECIALIZATION,
    (_event, id: string): MetaDeleteResult => {
      const db = getDb()
      const { c } = db
        .prepare(`SELECT COUNT(*) AS c FROM recipes WHERE crafting_specialization_id = ? AND deleted_at IS NULL`)
        .get(id) as { c: number }
      if (c > 0) {
        return { deleted: false, reason: `Specialization is used by ${c} recipe(s).` }
      }
      db.prepare(`DELETE FROM crafting_specializations WHERE id = ?`).run(id)
      markProjectDirty()
      return { deleted: true, reason: null }
    },
  )

  ipcMain.handle(
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
      markProjectDirty()
    },
  )

  // ─── Derived Stat Definitions CRUD ───────────────────────────────────────────

  ipcMain.handle(
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
      markProjectDirty()
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

  ipcMain.handle(
    IPC_CHANNELS.META_UPDATE_DERIVED_STAT,
    (_event, id: string, input: DerivedStatInput): DerivedStatDefinition => {
      const db = getDb()
      const now = new Date().toISOString()
      db.prepare(
        `UPDATE derived_stat_definitions
         SET display_name = ?, export_key = ?, formula = ?, output_type = ?, rounding_mode = ?, updated_at = ?
         WHERE id = ?`,
      ).run(input.displayName, input.exportKey, input.formula, input.outputType, input.roundingMode, now, id)
      markProjectDirty()
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

  ipcMain.handle(
    IPC_CHANNELS.META_DELETE_DERIVED_STAT,
    (_event, id: string): MetaDeleteResult => {
      const db = getDb()
      const { c } = db
        .prepare(`SELECT COUNT(DISTINCT class_id) AS c FROM class_derived_stat_overrides WHERE derived_stat_id = ?`)
        .get(id) as { c: number }
      if (c > 0) {
        return { deleted: false, reason: `Derived stat has overrides in ${c} class(es).` }
      }
      db.prepare(`DELETE FROM derived_stat_definitions WHERE id = ?`).run(id)
      markProjectDirty()
      return { deleted: true, reason: null }
    },
  )

  ipcMain.handle(
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
      markProjectDirty()
    },
  )
}

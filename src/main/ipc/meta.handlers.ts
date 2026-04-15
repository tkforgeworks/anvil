import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import { getDb } from '../db/connection'
import type {
  DerivedStatDefinition,
  MetaCraftingSpecialization,
  MetaCraftingStation,
  MetaItemCategory,
  MetaNpcType,
  MetaRarity,
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
      .prepare(`SELECT max_level FROM project_info LIMIT 1`)
      .get() as ProjectSettingsRow
    return { maxLevel: row.max_level }
  })
}

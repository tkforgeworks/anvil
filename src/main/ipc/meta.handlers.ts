import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import { getDb } from '../db/connection'
import type { MetaItemCategory, MetaNpcType, MetaStat, ProjectSettings } from '../../shared/domain-types'

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

  ipcMain.handle(IPC_CHANNELS.META_GET_PROJECT_SETTINGS, (): ProjectSettings => {
    const row = getDb()
      .prepare(`SELECT max_level FROM project_settings LIMIT 1`)
      .get() as ProjectSettingsRow
    return { maxLevel: row.max_level }
  })
}

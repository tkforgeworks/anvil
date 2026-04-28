import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type { BulkOperationInput, LifecycleDomain } from '../../shared/domain-types'
import { getDb } from '../db/connection'
import { markProjectDirty } from '../project/project-service'
import type { ChangeEntry } from '../project/change-accumulator'
import { computeDeleteImpact } from '../lifecycle/impact'

const DOMAIN_TABLES: Record<LifecycleDomain, string> = {
  'classes': 'classes',
  'abilities': 'abilities',
  'items': 'items',
  'recipes': 'recipes',
  'npcs': 'npcs',
  'loot-tables': 'loot_tables',
}

const ALL_DOMAIN_TABLES = Object.values(DOMAIN_TABLES)

function validateDomain(domain: string): asserts domain is LifecycleDomain {
  if (!(domain in DOMAIN_TABLES)) throw new Error(`Unknown domain: ${domain}`)
}

export function registerLifecycleHandlers(): void {
  ipcMain.handle(
    IPC_CHANNELS.LIFECYCLE_BULK_SOFT_DELETE,
    (_event, input: BulkOperationInput) => {
      validateDomain(input.domain)
      const table = DOMAIN_TABLES[input.domain]
      const db = getDb()
      const placeholders = input.ids.map(() => '?').join(', ')
      db.prepare(
        `UPDATE ${table}
         SET deleted_at = COALESCE(deleted_at, datetime('now')),
             updated_at = datetime('now')
         WHERE id IN (${placeholders}) AND deleted_at IS NULL`,
      ).run(...input.ids)
      for (const id of input.ids) {
        markProjectDirty({ domain: input.domain, recordId: id, recordName: '', subArea: 'basic-info', action: 'delete' })
      }
    },
  )

  ipcMain.handle(
    IPC_CHANNELS.LIFECYCLE_BULK_RESTORE,
    (_event, input: BulkOperationInput) => {
      validateDomain(input.domain)
      const table = DOMAIN_TABLES[input.domain]
      const db = getDb()
      const placeholders = input.ids.map(() => '?').join(', ')
      db.prepare(
        `UPDATE ${table}
         SET deleted_at = NULL, updated_at = datetime('now')
         WHERE id IN (${placeholders}) AND deleted_at IS NOT NULL`,
      ).run(...input.ids)
      for (const id of input.ids) {
        markProjectDirty({ domain: input.domain, recordId: id, recordName: '', subArea: 'basic-info', action: 'restore' })
      }
    },
  )

  ipcMain.handle(
    IPC_CHANNELS.LIFECYCLE_BULK_HARD_DELETE,
    (_event, input: BulkOperationInput) => {
      validateDomain(input.domain)
      const table = DOMAIN_TABLES[input.domain]
      const db = getDb()
      const placeholders = input.ids.map(() => '?').join(', ')
      db.prepare(`DELETE FROM ${table} WHERE id IN (${placeholders})`).run(...input.ids)
      for (const id of input.ids) {
        markProjectDirty({ domain: input.domain, recordId: id, recordName: '', subArea: 'basic-info', action: 'hard-delete' })
      }
    },
  )

  ipcMain.handle(IPC_CHANNELS.LIFECYCLE_EMPTY_TRASH, () => {
    const db = getDb()
    const domainKeys = Object.keys(DOMAIN_TABLES) as LifecycleDomain[]
    const tx = db.transaction(() => {
      for (const table of ALL_DOMAIN_TABLES) {
        db.prepare(`DELETE FROM ${table} WHERE deleted_at IS NOT NULL`).run()
      }
    })
    tx()
    for (const domain of domainKeys) {
      markProjectDirty({ domain, recordId: 'all', recordName: '', subArea: 'basic-info', action: 'hard-delete' })
    }
  })

  ipcMain.handle(
    IPC_CHANNELS.LIFECYCLE_COMPUTE_DELETE_IMPACT,
    (_event, input: BulkOperationInput) => {
      validateDomain(input.domain)
      return computeDeleteImpact(getDb(), input.domain, input.ids)
    },
  )

  ipcMain.handle(IPC_CHANNELS.LIFECYCLE_COUNT_DELETED, () => {
    const db = getDb()
    let total = 0
    for (const table of ALL_DOMAIN_TABLES) {
      const row = db
        .prepare(`SELECT COUNT(*) AS cnt FROM ${table} WHERE deleted_at IS NOT NULL`)
        .get() as { cnt: number }
      total += row.cnt
    }
    return total
  })
}

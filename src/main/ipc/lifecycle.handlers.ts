import { IPC_CHANNELS } from '../../shared/ipc-channels'
import { safeHandle } from './safe-handle'
import type { BulkOperationInput, LifecycleDomain } from '../../shared/domain-types'
import { getDb } from '../db/connection'
import { markProjectDirty, markProjectDirtyBulk } from '../project/project-service'
import { recordChange } from '../project/change-accumulator'
import { logDebug, logInfo } from '../logging/app-logger'
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
  safeHandle(
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
      markProjectDirtyBulk(input.domain, 'delete', input.ids)
    },
  )

  safeHandle(
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
      markProjectDirtyBulk(input.domain, 'restore', input.ids)
    },
  )

  safeHandle(
    IPC_CHANNELS.LIFECYCLE_BULK_HARD_DELETE,
    (_event, input: BulkOperationInput) => {
      validateDomain(input.domain)
      const table = DOMAIN_TABLES[input.domain]
      const db = getDb()
      const placeholders = input.ids.map(() => '?').join(', ')
      db.prepare(`DELETE FROM ${table} WHERE id IN (${placeholders})`).run(...input.ids)
      markProjectDirtyBulk(input.domain, 'hard-delete', input.ids)
    },
  )

  safeHandle(IPC_CHANNELS.LIFECYCLE_EMPTY_TRASH, () => {
    const db = getDb()
    const domainKeys = Object.keys(DOMAIN_TABLES) as LifecycleDomain[]
    const tx = db.transaction(() => {
      for (const table of ALL_DOMAIN_TABLES) {
        db.prepare(`DELETE FROM ${table} WHERE deleted_at IS NOT NULL`).run()
      }
    })
    tx()
    for (const domain of domainKeys) {
      recordChange({ domain, recordId: 'all', recordName: '', subArea: 'basic-info', action: 'hard-delete' })
    }
    markProjectDirty()
    logInfo('Trash emptied')
    logDebug('Trash emptied across all domains')
  })

  safeHandle(
    IPC_CHANNELS.LIFECYCLE_COMPUTE_DELETE_IMPACT,
    (_event, input: BulkOperationInput) => {
      validateDomain(input.domain)
      return computeDeleteImpact(getDb(), input.domain, input.ids)
    },
  )

  safeHandle(IPC_CHANNELS.LIFECYCLE_COUNT_DELETED, () => {
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

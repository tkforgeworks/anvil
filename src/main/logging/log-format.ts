import { sep } from 'node:path'
import type { ChangeAction, ChangeEntry, DomainKey } from '../project/change-accumulator'
import { ACTION_LABELS, DOMAIN_LABELS, SUB_AREA_LABELS } from '../project/change-accumulator'
import type { AppSettings } from '../../shared/settings-types'

export function anonymizePath(fullPath: string): string {
  const segments = fullPath.split(/[\\/]/)
  if (segments.length <= 2) return fullPath
  return `…${sep}${segments.slice(-2).join(sep)}`
}

function titleCase(s: string): string {
  return s.replace(/\b\w/g, (c) => c.toUpperCase())
}

function buildChangePrefix(change: ChangeEntry): string {
  const domain = titleCase(DOMAIN_LABELS[change.domain].singular)
  const subLabel = SUB_AREA_LABELS[change.subArea]
  return subLabel ? `${domain} ${subLabel.toLowerCase()}` : domain
}

function actionVerb(action: ChangeAction): string {
  if (action === 'delete') return 'archived'
  return ACTION_LABELS[action] ?? 'changed'
}

export function formatChangeInfo(change: ChangeEntry): string {
  return `${buildChangePrefix(change)} ${actionVerb(change.action)}`
}

export function formatChangeDebug(change: ChangeEntry): string {
  const base = formatChangeInfo(change)
  if (change.recordName) return `${base}: ${change.recordName}`
  return base
}

export function formatBulkInfo(domain: DomainKey, action: ChangeAction, count: number): string {
  const label = count === 1 ? DOMAIN_LABELS[domain].singular : DOMAIN_LABELS[domain].plural
  return `${count} ${label} ${actionVerb(action)}`
}

export function formatBulkDebug(domain: DomainKey, action: ChangeAction, ids: string[]): string {
  const info = formatBulkInfo(domain, action, ids.length)
  return `${info} (ids: ${ids.join(', ')})`
}

const SAFE_SETTINGS_KEYS = new Set<string>(['theme', 'editingMode', 'autoSaveEnabled', 'autoSaveIntervalMs'])

export function formatSettingsDebug(partial: Partial<AppSettings>): string {
  const parts: string[] = []
  for (const [key, value] of Object.entries(partial)) {
    if (value === undefined) continue
    if (SAFE_SETTINGS_KEYS.has(key)) {
      parts.push(`${key}=${value}`)
    } else {
      parts.push(`${key}=${value == null ? '<cleared>' : '<set>'}`)
    }
  }
  return parts.join(', ') || '(no changes)'
}

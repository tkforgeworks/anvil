export type DomainKey =
  | 'classes'
  | 'abilities'
  | 'items'
  | 'recipes'
  | 'npcs'
  | 'loot-tables'
  | 'meta'
  | 'custom-fields'

export type SubArea =
  | 'basic-info'
  | 'stat-growth'
  | 'stat-growth-formulas'
  | 'derived-stat-overrides'
  | 'ability-assignments'
  | 'class-assignments'
  | 'metadata-fields'
  | 'ingredients'
  | 'entries'
  | 'custom-fields'

export type ChangeAction = 'create' | 'update' | 'delete' | 'restore' | 'duplicate' | 'hard-delete'

export interface ChangeEntry {
  domain: DomainKey
  recordId: string
  recordName: string
  subArea: SubArea
  action: ChangeAction
}

let pendingChanges: ChangeEntry[] = []

export function recordChange(entry: ChangeEntry): void {
  pendingChanges.push(entry)
}

export function drainChanges(): ChangeEntry[] {
  const snapshot = pendingChanges
  pendingChanges = []
  return snapshot
}

export function clearChanges(): void {
  pendingChanges = []
}

const OFFSETTING_ACTIONS: [ChangeAction, ChangeAction][] = [
  ['delete', 'restore'],
]

function isOffset(a: ChangeAction, b: ChangeAction): boolean {
  return OFFSETTING_ACTIONS.some(
    ([x, y]) => (a === x && b === y) || (a === y && b === x),
  )
}

export function hasNetPendingChanges(): boolean {
  const actionsByRecord = new Map<string, ChangeAction[]>()
  for (const change of pendingChanges) {
    const key = `${change.domain}:${change.recordId}`
    const actions = actionsByRecord.get(key) ?? []
    actions.push(change.action)
    actionsByRecord.set(key, actions)
  }
  for (const actions of actionsByRecord.values()) {
    const remaining = [...actions]
    for (let i = 0; i < remaining.length; i++) {
      if (remaining[i] === null) continue
      for (let j = i + 1; j < remaining.length; j++) {
        if (remaining[j] === null) continue
        if (isOffset(remaining[i]!, remaining[j]!)) {
          remaining[i] = null as unknown as ChangeAction
          remaining[j] = null as unknown as ChangeAction
          break
        }
      }
    }
    if (remaining.some((a) => a !== null)) return true
  }
  return false
}

const DOMAIN_LABELS: Record<DomainKey, { singular: string; plural: string }> = {
  'classes': { singular: 'class', plural: 'classes' },
  'abilities': { singular: 'ability', plural: 'abilities' },
  'items': { singular: 'item', plural: 'items' },
  'recipes': { singular: 'recipe', plural: 'recipes' },
  'npcs': { singular: 'NPC', plural: 'NPCs' },
  'loot-tables': { singular: 'loot table', plural: 'loot tables' },
  'meta': { singular: 'setting', plural: 'settings' },
  'custom-fields': { singular: 'custom field', plural: 'custom fields' },
}

const SUB_AREA_LABELS: Record<SubArea, string> = {
  'basic-info': '',
  'stat-growth': 'Stat growth',
  'stat-growth-formulas': 'Stat growth formulas',
  'derived-stat-overrides': 'Derived stat overrides',
  'ability-assignments': 'Ability assignments',
  'class-assignments': 'Class assignments',
  'metadata-fields': 'Metadata fields',
  'ingredients': 'Ingredients',
  'entries': 'Entries',
  'custom-fields': 'Custom fields',
}

const ACTION_LABELS: Partial<Record<ChangeAction, string>> = {
  'create': 'created',
  'delete': 'deleted',
  'restore': 'restored',
  'duplicate': 'duplicated',
  'hard-delete': 'permanently deleted',
}

interface RecordGroup {
  domain: DomainKey
  recordId: string
  recordName: string
  subAreas: Set<SubArea>
  actions: Set<ChangeAction>
}

export function generateSaveDescription(changes: ChangeEntry[]): string {
  if (changes.length === 0) return ''

  const hasMeta = changes.some((c) => c.domain === 'meta')
  const hasCustomFields = changes.some((c) => c.domain === 'custom-fields')
  const domainChanges = changes.filter((c) => c.domain !== 'meta' && c.domain !== 'custom-fields')

  const groups = new Map<string, RecordGroup>()
  for (const change of domainChanges) {
    const key = `${change.domain}:${change.recordId}`
    const existing = groups.get(key)
    if (existing) {
      existing.subAreas.add(change.subArea)
      existing.actions.add(change.action)
    } else {
      groups.set(key, {
        domain: change.domain,
        recordId: change.recordId,
        recordName: change.recordName,
        subAreas: new Set([change.subArea]),
        actions: new Set([change.action]),
      })
    }
  }

  const fragments: string[] = []

  for (const [key, group] of groups) {
    if (group.actions.has('delete') && group.actions.has('restore')) {
      group.actions.delete('delete')
      group.actions.delete('restore')
      if (group.actions.size === 0 && group.subAreas.size <= 1) {
        groups.delete(key)
      }
    }
  }

  const groupList = [...groups.values()]
  const domains = new Set(groupList.map((g) => g.domain))

  if (groupList.length === 1) {
    fragments.push(describeSingleRecord(groupList[0]))
  } else if (domains.size === 1 && groupList.length > 1) {
    const domain = groupList[0].domain
    const labels = DOMAIN_LABELS[domain]
    const allSameAction = new Set(groupList.flatMap((g) => [...g.actions]))
    if (allSameAction.size === 1) {
      const actionLabel = ACTION_LABELS[[...allSameAction][0]]
      if (actionLabel) {
        fragments.push(`${groupList.length} ${labels.plural} ${actionLabel}`)
      } else {
        fragments.push(`${groupList.length} ${labels.plural} changed`)
      }
    } else {
      fragments.push(`${groupList.length} ${labels.plural} changed`)
    }
  } else if (groupList.length <= 3) {
    for (const group of groupList) {
      fragments.push(describeSingleRecord(group))
    }
  } else {
    fragments.push(`Changes across ${domains.size} domains`)
  }

  if (hasMeta) fragments.push('Project settings changed')
  if (hasCustomFields) fragments.push('Custom field definitions changed')

  return fragments.join(', ')
}

function describeSingleRecord(group: RecordGroup): string {
  const labels = DOMAIN_LABELS[group.domain]
  const name = group.recordName || labels.singular

  if (group.actions.has('create')) return `${name} ${labels.singular} created`
  if (group.actions.has('delete')) return `${name} ${labels.singular} deleted`
  if (group.actions.has('restore')) return `${name} ${labels.singular} restored`
  if (group.actions.has('duplicate')) return `${name} ${labels.singular} duplicated`
  if (group.actions.has('hard-delete')) return `${name} ${labels.singular} permanently deleted`

  if (group.subAreas.size === 1) {
    const subArea = [...group.subAreas][0]
    const subLabel = SUB_AREA_LABELS[subArea]
    if (subLabel) return `${subLabel} for ${name} changed`
    return `${name} ${labels.singular} changed`
  }

  return `Multiple changes in ${name} ${labels.singular}`
}

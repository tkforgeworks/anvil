import type { MetaDeleteResult, MetaReorderItem } from '../../../../shared/domain-types'

/**
 * Pure buffer logic for the Project Settings meta lists (ANVL-121).
 *
 * The modal holds every meta list (stats, rarities, crafting stations, …) in
 * local state and only talks to the main process on Save. This module owns the
 * id scheme for not-yet-persisted rows, the in-memory mutations, dirty
 * detection, and the sequenced commit that replays the buffer against the
 * per-list IPC API. Nothing here touches React or `window.anvil` so it can be
 * unit-tested in plain Node.
 */

export interface MetaBufferItem {
  id: string
  displayName: string
  exportKey: string
  sortOrder: number
}

/** The per-list IPC surface a buffer is committed through. Matches `metaApi.*` shapes. */
export interface MetaListApi<T, I> {
  add: (input: I) => Promise<T>
  update: (id: string, input: I) => Promise<T>
  delete: (id: string) => Promise<MetaDeleteResult>
  reorder: (items: MetaReorderItem[]) => Promise<void>
}

// ─── Ids ─────────────────────────────────────────────────────────────────────

const NEW_PREFIX = 'new:'

/** Rows added in this session carry a client-side id until Save resolves it. */
export function isNewMetaId(id: string): boolean {
  return id.startsWith(NEW_PREFIX)
}

export function newMetaId(): string {
  return `${NEW_PREFIX}${globalThis.crypto.randomUUID()}`
}

// ─── In-memory mutations ─────────────────────────────────────────────────────

/**
 * Rewrites `sortOrder` to the row's index. Server rows may carry gaps or
 * duplicates; normalizing on load makes the swap-based reorder unambiguous and
 * lets dirty detection compare by position instead of by raw number.
 */
export function normalizeOrder<T extends MetaBufferItem>(items: T[]): T[] {
  return items.map((item, i) => (item.sortOrder === i ? item : { ...item, sortOrder: i }))
}

function assertUniqueExportKey<T extends MetaBufferItem>(items: T[], exportKey: string, exceptId?: string): void {
  const clash = items.find((it) => it.id !== exceptId && it.exportKey === exportKey)
  if (clash) {
    throw new Error(`Export key "${exportKey}" is already used by "${clash.displayName}".`)
  }
}

export function appendToBuffer<T extends MetaBufferItem>(
  items: T[],
  make: (id: string, sortOrder: number) => T,
): { items: T[]; added: T } {
  const added = make(newMetaId(), items.length)
  assertUniqueExportKey(items, added.exportKey)
  return { items: [...items, added], added }
}

export function updateInBuffer<T extends MetaBufferItem>(
  items: T[],
  id: string,
  apply: (item: T) => T,
): { items: T[]; updated: T } {
  const index = items.findIndex((it) => it.id === id)
  if (index === -1) throw new Error('Item no longer exists.')
  const updated = apply(items[index])
  assertUniqueExportKey(items, updated.exportKey, id)
  const next = items.slice()
  next[index] = updated
  return { items: next, updated }
}

export function removeFromBuffer<T extends MetaBufferItem>(items: T[], id: string): T[] {
  return normalizeOrder(items.filter((it) => it.id !== id))
}

/**
 * Applies a reorder payload (the swap that `MetaListSection` emits) and returns
 * the list in its new order with `sortOrder` renormalized to index.
 */
export function reorderBuffer<T extends MetaBufferItem>(items: T[], order: MetaReorderItem[]): T[] {
  const target = new Map(order.map((o) => [o.id, o.sortOrder]))
  const sorted = items
    .map((item, i) => ({ item, key: target.get(item.id) ?? item.sortOrder, i }))
    .sort((a, b) => a.key - b.key || a.i - b.i)
    .map((e) => e.item)
  return normalizeOrder(sorted)
}

// ─── Dirty detection ─────────────────────────────────────────────────────────

/**
 * True when the buffer differs from the loaded state: a row was added, removed,
 * edited (as judged by `contentKey`, which must exclude `sortOrder`), or moved.
 */
export function metaListDirty<T extends MetaBufferItem>(
  original: T[],
  current: T[],
  contentKey: (item: T) => string,
): boolean {
  if (original.length !== current.length) return true
  return original.some((o, i) => o.id !== current[i].id || contentKey(o) !== contentKey(current[i]))
}

// ─── Commit ──────────────────────────────────────────────────────────────────

/**
 * Thrown when a commit fails part-way. `working` is the buffer with every
 * successful add already carrying its server id, so the caller can keep the
 * user's edits on screen without re-adding rows that did land.
 */
export class MetaCommitError extends Error {
  constructor(
    message: string,
    public readonly working: MetaBufferItem[],
  ) {
    super(message)
    this.name = 'MetaCommitError'
  }
}

export interface CommitMetaListOptions<T extends MetaBufferItem, I> {
  original: T[]
  current: T[]
  api: MetaListApi<T, I>
  toInput: (item: T) => I
  /** Content identity excluding id and sortOrder; drives which rows get `update`d. */
  contentKey: (item: T) => string
}

/**
 * Replays a buffer against the API in a fixed order — deletes, updates, adds,
 * then a single reorder if the resulting server order would differ from the
 * buffer — and returns the buffer with server ids resolved.
 */
export async function commitMetaList<T extends MetaBufferItem, I>({
  original,
  current,
  api,
  toInput,
  contentKey,
}: CommitMetaListOptions<T, I>): Promise<T[]> {
  const originalById = new Map(original.map((it) => [it.id, it]))
  const currentIds = new Set(current.map((it) => it.id))
  let working: T[] = current

  try {
    for (const orig of original) {
      if (currentIds.has(orig.id)) continue
      const result = await api.delete(orig.id)
      if (!result.deleted) {
        throw new Error(result.reason ?? `Cannot delete "${orig.displayName}".`)
      }
    }

    for (const item of current) {
      if (isNewMetaId(item.id)) continue
      const orig = originalById.get(item.id)
      if (orig && contentKey(orig) !== contentKey(item)) {
        await api.update(item.id, toInput(item))
      }
    }

    for (const item of current) {
      if (!isNewMetaId(item.id)) continue
      const created = await api.add(toInput(item))
      working = working.map((w) => (w.id === item.id ? { ...w, id: created.id } : w))
    }

    // Server order after the steps above: surviving originals in their original
    // order, then the adds (each appended at MAX(sort_order)+1) in add order.
    const expected = [
      ...original.filter((o) => currentIds.has(o.id)).map((o) => o.id),
      ...current.filter((c) => isNewMetaId(c.id)).map((c) => working[current.indexOf(c)].id),
    ]
    const actual = working.map((w) => w.id)
    const originalHadDuplicateOrders = new Set(original.map((o) => o.sortOrder)).size !== original.length
    const orderChanged = expected.some((id, i) => id !== actual[i])
    if (orderChanged || (originalHadDuplicateOrders && working.length > 0)) {
      await api.reorder(working.map((w, i) => ({ id: w.id, sortOrder: i })))
    }

    return normalizeOrder(working)
  } catch (cause) {
    const message = cause instanceof Error ? cause.message : 'Save failed.'
    throw new MetaCommitError(message, working)
  }
}

import { describe, expect, it, vi } from 'vitest'
import type { MetaDeleteResult, MetaReorderItem } from '../../../../../shared/domain-types'
import {
  MetaCommitError,
  appendToBuffer,
  commitMetaList,
  isNewMetaId,
  metaListDirty,
  normalizeOrder,
  removeFromBuffer,
  reorderBuffer,
  updateInBuffer,
} from '../meta-buffer'
import type { MetaListApi } from '../meta-buffer'

interface Row {
  id: string
  displayName: string
  exportKey: string
  sortOrder: number
}
interface Input {
  displayName: string
  exportKey: string
}

const row = (id: string, name: string, sortOrder: number): Row => ({
  id,
  displayName: name,
  exportKey: name.toLowerCase(),
  sortOrder,
})
const toInput = (r: Row): Input => ({ displayName: r.displayName, exportKey: r.exportKey })
const contentKey = (r: Row): string => `${r.displayName}|${r.exportKey}`
const make = (input: Input) => (id: string, sortOrder: number): Row => ({ id, sortOrder, ...input })

/** In-memory server double that records calls and hands out real ids for adds. */
function fakeApi(opts: { refuseDelete?: Record<string, string> } = {}): MetaListApi<Row, Input> & {
  calls: string[]
} {
  let counter = 0
  const calls: string[] = []
  return {
    calls,
    add: vi.fn(async (input: Input) => {
      calls.push(`add:${input.exportKey}`)
      return { id: `srv-${++counter}`, sortOrder: 100 + counter, ...input }
    }),
    update: vi.fn(async (id: string, input: Input) => {
      calls.push(`update:${id}:${input.exportKey}`)
      return { id, sortOrder: 0, ...input }
    }),
    delete: vi.fn(async (id: string): Promise<MetaDeleteResult> => {
      calls.push(`delete:${id}`)
      const reason = opts.refuseDelete?.[id]
      return reason ? { deleted: false, reason } : { deleted: true, reason: null }
    }),
    reorder: vi.fn(async (items: MetaReorderItem[]) => {
      calls.push(`reorder:${items.map((i) => `${i.id}@${i.sortOrder}`).join(',')}`)
    }),
  }
}

describe('meta-buffer in-memory mutations', () => {
  const base = [row('a', 'Alpha', 0), row('b', 'Beta', 1), row('c', 'Gamma', 2)]

  it('normalizes sortOrder to index without touching already-normalized rows', () => {
    const gappy = [row('a', 'Alpha', 3), row('b', 'Beta', 3), row('c', 'Gamma', 9)]
    expect(normalizeOrder(gappy).map((r) => r.sortOrder)).toEqual([0, 1, 2])
    const already = normalizeOrder(base)
    expect(already[0]).toBe(base[0])
  })

  it('appends with a client-side id and the next index', () => {
    const { items, added } = appendToBuffer(base, make({ displayName: 'Delta', exportKey: 'delta' }))
    expect(isNewMetaId(added.id)).toBe(true)
    expect(added.sortOrder).toBe(3)
    expect(items).toHaveLength(4)
    expect(items[3]).toBe(added)
  })

  it('rejects a duplicate export key on add and on update', () => {
    expect(() => appendToBuffer(base, make({ displayName: 'Other', exportKey: 'beta' }))).toThrow(/beta/)
    expect(() => updateInBuffer(base, 'a', (r) => ({ ...r, exportKey: 'gamma' }))).toThrow(/gamma/)
    // A row keeping its own key is fine.
    expect(() => updateInBuffer(base, 'a', (r) => ({ ...r, displayName: 'Alpha!' }))).not.toThrow()
  })

  it('edits a session-added row in place and removing it leaves no trace', () => {
    const { items: withNew, added } = appendToBuffer(base, make({ displayName: 'Delta', exportKey: 'delta' }))
    const { items: edited, updated } = updateInBuffer(withNew, added.id, (r) => ({ ...r, displayName: 'Delta 2' }))
    expect(updated.id).toBe(added.id)
    expect(edited.filter((r) => r.id === added.id)).toHaveLength(1)
    const removed = removeFromBuffer(edited, added.id)
    expect(removed.map((r) => r.id)).toEqual(['a', 'b', 'c'])
  })

  it('re-editing a persisted row overwrites rather than accumulates', () => {
    const once = updateInBuffer(base, 'b', (r) => ({ ...r, displayName: 'B1' })).items
    const twice = updateInBuffer(once, 'b', (r) => ({ ...r, displayName: 'B2' })).items
    expect(twice.filter((r) => r.id === 'b')).toHaveLength(1)
    expect(twice[1].displayName).toBe('B2')
  })

  it('reorders a mix of persisted and new rows via the swap payload MetaListSection emits', () => {
    const { items: withNew, added } = appendToBuffer(base, make({ displayName: 'Delta', exportKey: 'delta' }))
    // Move the new row (index 3) up one: swap sortOrders with index 2.
    const swap: MetaReorderItem[] = withNew.map((r, i) => {
      if (i === 3) return { id: r.id, sortOrder: withNew[2].sortOrder }
      if (i === 2) return { id: r.id, sortOrder: withNew[3].sortOrder }
      return { id: r.id, sortOrder: r.sortOrder }
    })
    const reordered = reorderBuffer(withNew, swap)
    expect(reordered.map((r) => r.id)).toEqual(['a', 'b', added.id, 'c'])
    expect(reordered.map((r) => r.sortOrder)).toEqual([0, 1, 2, 3])
  })
})

describe('metaListDirty', () => {
  const base = [row('a', 'Alpha', 0), row('b', 'Beta', 1)]

  it('is clean for an identical copy and ignores sortOrder numbers', () => {
    expect(metaListDirty(base, base.map((r) => ({ ...r, sortOrder: r.sortOrder + 10 })), contentKey)).toBe(false)
  })

  it('flags add, remove, edit and move', () => {
    expect(metaListDirty(base, [...base, row('n', 'New', 2)], contentKey)).toBe(true)
    expect(metaListDirty(base, [base[0]], contentKey)).toBe(true)
    expect(metaListDirty(base, [base[0], { ...base[1], displayName: 'Beta 2' }], contentKey)).toBe(true)
    expect(metaListDirty(base, [base[1], base[0]], contentKey)).toBe(true)
  })
})

describe('commitMetaList', () => {
  const original = [row('a', 'Alpha', 0), row('b', 'Beta', 1), row('c', 'Gamma', 2)]

  it('makes no calls when nothing changed', async () => {
    const api = fakeApi()
    await commitMetaList({ original, current: original, api, toInput, contentKey })
    expect(api.calls).toEqual([])
  })

  it('replays deletes, updates, adds in order and resolves new ids without reordering an appended row', async () => {
    const api = fakeApi()
    let current = removeFromBuffer(original, 'b')
    current = updateInBuffer(current, 'c', (r) => ({ ...r, displayName: 'Gamma!' })).items
    const { items: withNew, added } = appendToBuffer(current, make({ displayName: 'Delta', exportKey: 'delta' }))

    const result = await commitMetaList({ original, current: withNew, api, toInput, contentKey })

    expect(api.calls).toEqual(['delete:b', 'update:c:gamma', 'add:delta'])
    expect(result.map((r) => r.id)).toEqual(['a', 'c', 'srv-1'])
    expect(result.some((r) => r.id === added.id)).toBe(false)
    expect(result.map((r) => r.sortOrder)).toEqual([0, 1, 2])
  })

  it('never sends an API call for a row added and removed in the same session', async () => {
    const api = fakeApi()
    const { items: withNew, added } = appendToBuffer(original, make({ displayName: 'Temp', exportKey: 'temp' }))
    const current = removeFromBuffer(withNew, added.id)
    await commitMetaList({ original, current, api, toInput, contentKey })
    expect(api.calls).toEqual([])
  })

  it('issues one index-based reorder when the buffer order differs from what the server would hold', async () => {
    const api = fakeApi()
    const { items: withNew } = appendToBuffer(original, make({ displayName: 'Delta', exportKey: 'delta' }))
    // Move the new row to the front.
    const current = normalizeOrder([withNew[3], withNew[0], withNew[1], withNew[2]])

    await commitMetaList({ original, current, api, toInput, contentKey })

    expect(api.calls).toEqual(['add:delta', 'reorder:srv-1@0,a@1,b@2,c@3'])
  })

  it('reorders when only persisted rows moved', async () => {
    const api = fakeApi()
    const current = normalizeOrder([original[2], original[0], original[1]])
    await commitMetaList({ original, current, api, toInput, contentKey })
    expect(api.calls).toEqual(['reorder:c@0,a@1,b@2'])
  })

  it('surfaces a refused delete as a MetaCommitError carrying the server reason', async () => {
    const api = fakeApi({ refuseDelete: { a: 'Stat is used by 2 class(es).' } })
    const current = removeFromBuffer(original, 'a')
    await expect(commitMetaList({ original, current, api, toInput, contentKey })).rejects.toBeInstanceOf(
      MetaCommitError,
    )
    await expect(commitMetaList({ original, current, api, toInput, contentKey })).rejects.toThrow(
      /used by 2 class/,
    )
  })

  it('on a mid-commit failure, working state keeps the server ids of adds that landed', async () => {
    const api = fakeApi()
    let n = 0
    ;(api.add as ReturnType<typeof vi.fn>).mockImplementation(async (input: Input) => {
      n += 1
      if (n === 2) throw new Error('UNIQUE constraint failed')
      return { id: `srv-${n}`, sortOrder: 100 + n, ...input }
    })
    const step1 = appendToBuffer(original, make({ displayName: 'One', exportKey: 'one' }))
    const step2 = appendToBuffer(step1.items, make({ displayName: 'Two', exportKey: 'two' }))

    let caught: MetaCommitError | null = null
    try {
      await commitMetaList({ original, current: step2.items, api, toInput, contentKey })
    } catch (e) {
      caught = e as MetaCommitError
    }
    expect(caught).toBeInstanceOf(MetaCommitError)
    const ids = caught!.working.map((r) => r.id)
    expect(ids.slice(0, 3)).toEqual(['a', 'b', 'c'])
    expect(ids[3]).toBe('srv-1')
    expect(isNewMetaId(ids[4])).toBe(true)
  })
})

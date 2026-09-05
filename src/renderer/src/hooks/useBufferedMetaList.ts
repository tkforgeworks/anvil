import { metaApi } from '../../api/meta.api'
import type { MetaDeleteResult, MetaInUseKind, MetaReorderItem } from '../../../shared/domain-types'
import {
  appendToBuffer,
  isNewMetaId,
  removeFromBuffer,
  reorderBuffer,
  updateInBuffer,
} from '../components/settings/meta-buffer'
import type { MetaBufferItem, MetaListApi } from '../components/settings/meta-buffer'

export interface UseBufferedMetaListOptions<T extends MetaBufferItem, I> {
  /** Which FK check to run before removing a persisted row. */
  kind: MetaInUseKind
  /** Builds a new buffered row from the dialog input. */
  create: (id: string, sortOrder: number, input: I) => T
  /** Applies dialog input to an existing buffered row. */
  apply: (item: T, input: I) => T
}

/**
 * Adapts a controlled `items`/`onChange` pair to the `MetaListApi` shape the
 * meta section components call, so those components can stay unaware of
 * whether their edits persist immediately or sit in a buffer until Save.
 *
 * Every operation mutates the buffer only. The one IPC call is the FK pre-check
 * on deleting a persisted row, so an in-use row is refused at click time with
 * the server's reason instead of failing later on Save.
 */
export function useBufferedMetaList<T extends MetaBufferItem, I>(
  items: T[],
  onChange: (next: T[]) => void,
  { kind, create, apply }: UseBufferedMetaListOptions<T, I>,
): MetaListApi<T, I> {
  return {
    add: async (input: I): Promise<T> => {
      const { items: next, added } = appendToBuffer(items, (id, sortOrder) => create(id, sortOrder, input))
      onChange(next)
      return added
    },
    update: async (id: string, input: I): Promise<T> => {
      const { items: next, updated } = updateInBuffer(items, id, (item) => apply(item, input))
      onChange(next)
      return updated
    },
    delete: async (id: string): Promise<MetaDeleteResult> => {
      if (!isNewMetaId(id)) {
        const check = await metaApi.checkInUse(kind, id)
        if (check.inUse) return { deleted: false, reason: check.reason }
      }
      onChange(removeFromBuffer(items, id))
      return { deleted: true, reason: null }
    },
    reorder: async (order: MetaReorderItem[]): Promise<void> => {
      onChange(reorderBuffer(items, order))
    },
  }
}

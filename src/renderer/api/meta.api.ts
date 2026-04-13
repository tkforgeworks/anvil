import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type { MetaItemCategory, MetaNpcType } from '../../shared/domain-types'

export const metaApi = {
  listItemCategories: () =>
    window.anvil.invoke<MetaItemCategory[]>(IPC_CHANNELS.META_LIST_ITEM_CATEGORIES),

  listNpcTypes: () =>
    window.anvil.invoke<MetaNpcType[]>(IPC_CHANNELS.META_LIST_NPC_TYPES),
}

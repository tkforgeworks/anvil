import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type { DerivedStatDefinition, MetaItemCategory, MetaNpcType, MetaStat, ProjectSettings } from '../../shared/domain-types'

export const metaApi = {
  listItemCategories: () =>
    window.anvil.invoke<MetaItemCategory[]>(IPC_CHANNELS.META_LIST_ITEM_CATEGORIES),

  listNpcTypes: () =>
    window.anvil.invoke<MetaNpcType[]>(IPC_CHANNELS.META_LIST_NPC_TYPES),

  listStats: () =>
    window.anvil.invoke<MetaStat[]>(IPC_CHANNELS.META_LIST_STATS),

  getProjectSettings: () =>
    window.anvil.invoke<ProjectSettings>(IPC_CHANNELS.META_GET_PROJECT_SETTINGS),

  listDerivedStats: () =>
    window.anvil.invoke<DerivedStatDefinition[]>(IPC_CHANNELS.META_LIST_DERIVED_STATS),
}

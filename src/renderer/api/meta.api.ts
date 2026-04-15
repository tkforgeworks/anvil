import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type {
  DerivedStatDefinition,
  MetaCraftingSpecialization,
  MetaCraftingStation,
  MetaItemCategory,
  MetaNpcType,
  MetaRarity,
  MetaStat,
  ProjectSettings,
} from '../../shared/domain-types'

export const metaApi = {
  listItemCategories: () =>
    window.anvil.invoke<MetaItemCategory[]>(IPC_CHANNELS.META_LIST_ITEM_CATEGORIES),

  listRarities: () =>
    window.anvil.invoke<MetaRarity[]>(IPC_CHANNELS.META_LIST_RARITIES),

  listNpcTypes: () =>
    window.anvil.invoke<MetaNpcType[]>(IPC_CHANNELS.META_LIST_NPC_TYPES),

  listCraftingStations: () =>
    window.anvil.invoke<MetaCraftingStation[]>(IPC_CHANNELS.META_LIST_CRAFTING_STATIONS),

  listCraftingSpecializations: () =>
    window.anvil.invoke<MetaCraftingSpecialization[]>(
      IPC_CHANNELS.META_LIST_CRAFTING_SPECIALIZATIONS,
    ),

  listStats: () =>
    window.anvil.invoke<MetaStat[]>(IPC_CHANNELS.META_LIST_STATS),

  getProjectSettings: () =>
    window.anvil.invoke<ProjectSettings>(IPC_CHANNELS.META_GET_PROJECT_SETTINGS),

  listDerivedStats: () =>
    window.anvil.invoke<DerivedStatDefinition[]>(IPC_CHANNELS.META_LIST_DERIVED_STATS),
}

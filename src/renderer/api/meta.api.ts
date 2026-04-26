import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type {
  DerivedStatDefinition,
  DerivedStatInput,
  MetaCraftingSpecialization,
  MetaCraftingStation,
  MetaDeleteResult,
  MetaItemCategory,
  MetaItemInput,
  MetaNpcType,
  MetaRarity,
  MetaRarityInput,
  MetaReorderItem,
  MetaStat,
  ProjectSettings,
} from '../../shared/domain-types'

export const metaApi = {
  // ─── Read-only queries ──────────────────────────────────────────────────────

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

  // ─── Project settings ───────────────────────────────────────────────────────

  setProjectSettings: (input: Partial<ProjectSettings>) =>
    window.anvil.invoke<ProjectSettings>(IPC_CHANNELS.META_SET_PROJECT_SETTINGS, input),

  // ─── Stats CRUD ─────────────────────────────────────────────────────────────

  addStat: (input: MetaItemInput) =>
    window.anvil.invoke<MetaStat>(IPC_CHANNELS.META_ADD_STAT, input),

  updateStat: (id: string, input: MetaItemInput) =>
    window.anvil.invoke<MetaStat>(IPC_CHANNELS.META_UPDATE_STAT, id, input),

  deleteStat: (id: string) =>
    window.anvil.invoke<MetaDeleteResult>(IPC_CHANNELS.META_DELETE_STAT, id),

  reorderStats: (items: MetaReorderItem[]) =>
    window.anvil.invoke<void>(IPC_CHANNELS.META_REORDER_STATS, items),

  // ─── Rarities CRUD ──────────────────────────────────────────────────────────

  addRarity: (input: MetaRarityInput) =>
    window.anvil.invoke<MetaRarity>(IPC_CHANNELS.META_ADD_RARITY, input),

  updateRarity: (id: string, input: MetaRarityInput) =>
    window.anvil.invoke<MetaRarity>(IPC_CHANNELS.META_UPDATE_RARITY, id, input),

  deleteRarity: (id: string) =>
    window.anvil.invoke<MetaDeleteResult>(IPC_CHANNELS.META_DELETE_RARITY, id),

  reorderRarities: (items: MetaReorderItem[]) =>
    window.anvil.invoke<void>(IPC_CHANNELS.META_REORDER_RARITIES, items),

  // ─── Crafting Stations CRUD ─────────────────────────────────────────────────

  addCraftingStation: (input: MetaItemInput) =>
    window.anvil.invoke<MetaCraftingStation>(IPC_CHANNELS.META_ADD_CRAFTING_STATION, input),

  updateCraftingStation: (id: string, input: MetaItemInput) =>
    window.anvil.invoke<MetaCraftingStation>(IPC_CHANNELS.META_UPDATE_CRAFTING_STATION, id, input),

  deleteCraftingStation: (id: string) =>
    window.anvil.invoke<MetaDeleteResult>(IPC_CHANNELS.META_DELETE_CRAFTING_STATION, id),

  reorderCraftingStations: (items: MetaReorderItem[]) =>
    window.anvil.invoke<void>(IPC_CHANNELS.META_REORDER_CRAFTING_STATIONS, items),

  // ─── Crafting Specializations CRUD ──────────────────────────────────────────

  addCraftingSpecialization: (input: MetaItemInput) =>
    window.anvil.invoke<MetaCraftingSpecialization>(IPC_CHANNELS.META_ADD_CRAFTING_SPECIALIZATION, input),

  updateCraftingSpecialization: (id: string, input: MetaItemInput) =>
    window.anvil.invoke<MetaCraftingSpecialization>(IPC_CHANNELS.META_UPDATE_CRAFTING_SPECIALIZATION, id, input),

  deleteCraftingSpecialization: (id: string) =>
    window.anvil.invoke<MetaDeleteResult>(IPC_CHANNELS.META_DELETE_CRAFTING_SPECIALIZATION, id),

  reorderCraftingSpecializations: (items: MetaReorderItem[]) =>
    window.anvil.invoke<void>(IPC_CHANNELS.META_REORDER_CRAFTING_SPECIALIZATIONS, items),

  // ─── Derived Stat Definitions CRUD ──────────────────────────────────────────

  addDerivedStat: (input: DerivedStatInput) =>
    window.anvil.invoke<DerivedStatDefinition>(IPC_CHANNELS.META_ADD_DERIVED_STAT, input),

  updateDerivedStat: (id: string, input: DerivedStatInput) =>
    window.anvil.invoke<DerivedStatDefinition>(IPC_CHANNELS.META_UPDATE_DERIVED_STAT, id, input),

  deleteDerivedStat: (id: string) =>
    window.anvil.invoke<MetaDeleteResult>(IPC_CHANNELS.META_DELETE_DERIVED_STAT, id),

  reorderDerivedStats: (items: MetaReorderItem[]) =>
    window.anvil.invoke<void>(IPC_CHANNELS.META_REORDER_DERIVED_STATS, items),
}

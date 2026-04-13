import { create } from 'zustand'
import type { BaseRecord } from '../../../shared/domain-types'

// Full CraftingRecipe type defined in the Crafting Recipes epic
type CraftingRecipe = BaseRecord

interface RecipesState {
  records: CraftingRecipe[]
  activeRecord: CraftingRecipe | null
  isLoading: boolean

  setRecords: (records: CraftingRecipe[]) => void
  setActiveRecord: (record: CraftingRecipe | null) => void
  setLoading: (loading: boolean) => void
}

export const useRecipesStore = create<RecipesState>()((set) => ({
  records: [],
  activeRecord: null,
  isLoading: false,

  setRecords: (records) => set({ records }),
  setActiveRecord: (record) => set({ activeRecord: record }),
  setLoading: (loading) => set({ isLoading: loading }),
}))

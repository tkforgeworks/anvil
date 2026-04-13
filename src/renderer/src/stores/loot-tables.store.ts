import { create } from 'zustand'
import type { BaseRecord } from '../../../shared/domain-types'

// Full LootTable type defined in the Loot Tables epic
type LootTable = BaseRecord

interface LootTablesState {
  records: LootTable[]
  activeRecord: LootTable | null
  isLoading: boolean

  setRecords: (records: LootTable[]) => void
  setActiveRecord: (record: LootTable | null) => void
  setLoading: (loading: boolean) => void
}

export const useLootTablesStore = create<LootTablesState>()((set) => ({
  records: [],
  activeRecord: null,
  isLoading: false,

  setRecords: (records) => set({ records }),
  setActiveRecord: (record) => set({ activeRecord: record }),
  setLoading: (loading) => set({ isLoading: loading }),
}))

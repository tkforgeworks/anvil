import { create } from 'zustand'
import type { BaseRecord } from '../../../shared/domain-types'

// Full Item type defined in the Items epic
type Item = BaseRecord

interface ItemsState {
  records: Item[]
  activeRecord: Item | null
  isLoading: boolean

  setRecords: (records: Item[]) => void
  setActiveRecord: (record: Item | null) => void
  setLoading: (loading: boolean) => void
}

export const useItemsStore = create<ItemsState>()((set) => ({
  records: [],
  activeRecord: null,
  isLoading: false,

  setRecords: (records) => set({ records }),
  setActiveRecord: (record) => set({ activeRecord: record }),
  setLoading: (loading) => set({ isLoading: loading }),
}))

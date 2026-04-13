import { create } from 'zustand'
import type { BaseRecord } from '../../../shared/domain-types'

// Full Npc type defined in the NPCs epic
type Npc = BaseRecord

interface NpcsState {
  records: Npc[]
  activeRecord: Npc | null
  isLoading: boolean

  setRecords: (records: Npc[]) => void
  setActiveRecord: (record: Npc | null) => void
  setLoading: (loading: boolean) => void
}

export const useNpcsStore = create<NpcsState>()((set) => ({
  records: [],
  activeRecord: null,
  isLoading: false,

  setRecords: (records) => set({ records }),
  setActiveRecord: (record) => set({ activeRecord: record }),
  setLoading: (loading) => set({ isLoading: loading }),
}))

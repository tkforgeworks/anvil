import { create } from 'zustand'
import type { BaseRecord } from '../../../shared/domain-types'

// Full Ability type defined in the Abilities epic
type Ability = BaseRecord

interface AbilitiesState {
  records: Ability[]
  activeRecord: Ability | null
  isLoading: boolean

  setRecords: (records: Ability[]) => void
  setActiveRecord: (record: Ability | null) => void
  setLoading: (loading: boolean) => void
}

export const useAbilitiesStore = create<AbilitiesState>()((set) => ({
  records: [],
  activeRecord: null,
  isLoading: false,

  setRecords: (records) => set({ records }),
  setActiveRecord: (record) => set({ activeRecord: record }),
  setLoading: (loading) => set({ isLoading: loading }),
}))

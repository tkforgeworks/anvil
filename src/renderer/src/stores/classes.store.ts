import { create } from 'zustand'
import type { BaseRecord } from '../../../shared/domain-types'

// Full CharacterClass type defined in the Character Classes epic
type CharacterClass = BaseRecord

interface ClassesState {
  records: CharacterClass[]
  activeRecord: CharacterClass | null
  isLoading: boolean

  setRecords: (records: CharacterClass[]) => void
  setActiveRecord: (record: CharacterClass | null) => void
  setLoading: (loading: boolean) => void
}

export const useClassesStore = create<ClassesState>()((set) => ({
  records: [],
  activeRecord: null,
  isLoading: false,

  setRecords: (records) => set({ records }),
  setActiveRecord: (record) => set({ activeRecord: record }),
  setLoading: (loading) => set({ isLoading: loading }),
}))

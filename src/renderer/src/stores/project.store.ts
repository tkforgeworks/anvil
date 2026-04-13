import { create } from 'zustand'

export type SaveStatus = 'idle' | 'saving' | 'saved' | 'error'

interface ProjectState {
  projectName: string | null
  gameTitle: string | null
  filePath: string | null
  isDirty: boolean
  saveStatus: SaveStatus

  setProject: (projectName: string, gameTitle: string, filePath: string) => void
  clearProject: () => void
  setDirty: (dirty: boolean) => void
  setSaveStatus: (status: SaveStatus) => void
}

export const useProjectStore = create<ProjectState>()((set) => ({
  projectName: null,
  gameTitle: null,
  filePath: null,
  isDirty: false,
  saveStatus: 'idle',

  setProject: (projectName, gameTitle, filePath) =>
    set({ projectName, gameTitle, filePath, isDirty: false, saveStatus: 'idle' }),
  clearProject: () =>
    set({ projectName: null, gameTitle: null, filePath: null, isDirty: false, saveStatus: 'idle' }),
  setDirty: (dirty) => set({ isDirty: dirty }),
  setSaveStatus: (status) => set({ saveStatus: status }),
}))

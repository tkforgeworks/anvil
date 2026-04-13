import { create } from 'zustand'
import type { ProjectMetadata, ProjectStateSnapshot, RecentProject } from '../../../shared/project-types'

export type SaveStatus = 'idle' | 'saving' | 'saved' | 'error'

interface ProjectState {
  activeProject: ProjectMetadata | null
  recentProjects: RecentProject[]
  isDirty: boolean
  isRecoveryMode: boolean
  saveStatus: SaveStatus

  hydrate: (snapshot: ProjectStateSnapshot) => void
  setProject: (project: ProjectMetadata) => void
  clearProject: () => void
  setDirty: (dirty: boolean) => void
  setSaveStatus: (status: SaveStatus) => void
}

export const useProjectStore = create<ProjectState>()((set) => ({
  activeProject: null,
  recentProjects: [],
  isDirty: false,
  isRecoveryMode: false,
  saveStatus: 'idle',

  hydrate: (snapshot) =>
    set({
      activeProject: snapshot.activeProject,
      recentProjects: snapshot.recentProjects,
      isDirty: snapshot.isDirty,
      isRecoveryMode: snapshot.isRecoveryMode,
      saveStatus: snapshot.isDirty ? 'idle' : 'saved',
    }),
  setProject: (project) =>
    set({ activeProject: project, isDirty: false, isRecoveryMode: false, saveStatus: 'saved' }),
  clearProject: () =>
    set({ activeProject: null, isDirty: false, isRecoveryMode: false, saveStatus: 'idle' }),
  setDirty: (dirty) => set({ isDirty: dirty }),
  setSaveStatus: (status) => set({ saveStatus: status }),
}))

import { create } from 'zustand'
import type {
  ProjectMetadata,
  ProjectSaveStatus,
  ProjectStateSnapshot,
  RecentProject,
} from '../../../shared/project-types'

export type SaveStatus = ProjectSaveStatus

interface ProjectState {
  activeProject: ProjectMetadata | null
  recentProjects: RecentProject[]
  isDirty: boolean
  isRecoveryMode: boolean
  saveStatus: SaveStatus
  saveError: string | null

  hydrate: (snapshot: ProjectStateSnapshot) => void
  setProject: (project: ProjectMetadata) => void
  clearProject: () => void
  setDirty: (dirty: boolean) => void
  setSaveStatus: (status: SaveStatus) => void
  setSaveError: (error: string | null) => void
}

export const useProjectStore = create<ProjectState>()((set) => ({
  activeProject: null,
  recentProjects: [],
  isDirty: false,
  isRecoveryMode: false,
  saveStatus: 'saved',
  saveError: null,

  hydrate: (snapshot) =>
    set({
      activeProject: snapshot.activeProject,
      recentProjects: snapshot.recentProjects,
      isDirty: snapshot.isDirty,
      isRecoveryMode: snapshot.isRecoveryMode,
      saveStatus: snapshot.saveStatus,
      saveError: snapshot.saveError,
    }),
  setProject: (project) =>
    set({
      activeProject: project,
      isDirty: false,
      isRecoveryMode: false,
      saveStatus: 'saved',
      saveError: null,
    }),
  clearProject: () =>
    set({
      activeProject: null,
      isDirty: false,
      isRecoveryMode: false,
      saveStatus: 'saved',
      saveError: null,
    }),
  setDirty: (dirty) => set({ isDirty: dirty, saveStatus: dirty ? 'unsaved' : 'saved' }),
  setSaveStatus: (status) => set({ saveStatus: status }),
  setSaveError: (error) =>
    set((state) => ({
      saveError: error,
      saveStatus: error ? 'error' : state.saveStatus,
    })),
}))

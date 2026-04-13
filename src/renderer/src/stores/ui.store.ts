import { create } from 'zustand'

export type AppTheme = 'dark' | 'light'
export type EditingMode = 'modal' | 'full-page'

interface UiState {
  theme: AppTheme
  editingMode: EditingMode
  sidebarOpen: boolean
  activeModalId: string | null

  setTheme: (theme: AppTheme) => void
  setEditingMode: (mode: EditingMode) => void
  setSidebarOpen: (open: boolean) => void
  openModal: (id: string) => void
  closeModal: () => void
}

export const useUiStore = create<UiState>()((set) => ({
  theme: 'dark',
  editingMode: 'modal',
  sidebarOpen: true,
  activeModalId: null,

  setTheme: (theme) => set({ theme }),
  setEditingMode: (mode) => set({ editingMode: mode }),
  setSidebarOpen: (open) => set({ sidebarOpen: open }),
  openModal: (id) => set({ activeModalId: id }),
  closeModal: () => set({ activeModalId: null }),
}))

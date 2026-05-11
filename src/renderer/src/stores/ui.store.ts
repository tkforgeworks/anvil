import { create } from 'zustand'

export type AppTheme = 'dark' | 'light' | 'custom'
export type EditingMode = 'modal' | 'full-page'

export interface ModalOptions {
  initialTab?: string
}

interface UiState {
  theme: AppTheme
  editingMode: EditingMode
  sidebarOpen: boolean
  activeModalId: string | null
  modalOptions: ModalOptions | null
  menuOpen: boolean

  setTheme: (theme: AppTheme) => void
  setEditingMode: (mode: EditingMode) => void
  setSidebarOpen: (open: boolean) => void
  toggleSidebar: () => void
  openModal: (id: string, options?: ModalOptions) => void
  closeModal: () => void
  setMenuOpen: (open: boolean) => void
}

export const useUiStore = create<UiState>()((set) => ({
  theme: 'dark',
  editingMode: 'modal',
  sidebarOpen: true,
  activeModalId: null,
  modalOptions: null,
  menuOpen: false,

  setTheme: (theme) => set({ theme }),
  setEditingMode: (mode) => set({ editingMode: mode }),
  setSidebarOpen: (open) => set({ sidebarOpen: open }),
  toggleSidebar: () => set((state) => ({ sidebarOpen: !state.sidebarOpen })),
  openModal: (id, options) => set({ activeModalId: id, modalOptions: options ?? null, menuOpen: false }),
  closeModal: () => set({ activeModalId: null, modalOptions: null }),
  setMenuOpen: (open) => set({ menuOpen: open }),
}))

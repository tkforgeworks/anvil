import { create } from 'zustand'
import type { AppTheme, EditingMode } from './ui.store'

export interface AppSettings {
  theme: AppTheme
  editingMode: EditingMode
  autoSaveIntervalMs: number
}

interface SettingsState {
  appSettings: AppSettings | null

  setAppSettings: (settings: AppSettings) => void
}

export const useSettingsStore = create<SettingsState>()((set) => ({
  appSettings: null,

  setAppSettings: (settings) => set({ appSettings: settings }),
}))

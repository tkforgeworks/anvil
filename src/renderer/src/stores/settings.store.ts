import { create } from 'zustand'
import type { AppSettings } from '../../../shared/settings-types'

interface SettingsState {
  appSettings: AppSettings | null

  setAppSettings: (settings: AppSettings) => void
}

export const useSettingsStore = create<SettingsState>()((set) => ({
  appSettings: null,

  setAppSettings: (settings) => set({ appSettings: settings }),
}))

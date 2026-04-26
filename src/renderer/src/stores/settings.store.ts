import { create } from 'zustand'
import type { AppSettings } from '../../../shared/settings-types'
import { settingsApi } from '../../api/settings.api'
import { useUiStore } from './ui.store'

interface SettingsState {
  appSettings: AppSettings | null

  setAppSettings: (settings: AppSettings) => void
  hydrate: () => Promise<void>
}

function applyToUiStore(settings: AppSettings): void {
  const ui = useUiStore.getState()
  ui.setTheme(settings.theme)
  ui.setEditingMode(settings.editingMode)
}

export const useSettingsStore = create<SettingsState>()((set) => ({
  appSettings: null,

  setAppSettings: (settings) => {
    set({ appSettings: settings })
    applyToUiStore(settings)
  },

  hydrate: async () => {
    const settings = await settingsApi.getApp()
    set({ appSettings: settings })
    applyToUiStore(settings)
  },
}))

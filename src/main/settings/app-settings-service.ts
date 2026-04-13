import { app } from 'electron'
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'fs'
import { dirname, join } from 'path'
import type { AppSettings } from '../../shared/settings-types'

const APP_SETTINGS_FILENAME = 'app-settings.json'
const DEFAULT_APP_SETTINGS: AppSettings = {
  theme: 'dark',
  editingMode: 'modal',
  autoSaveIntervalMs: 5000,
}

function appSettingsPath(): string {
  return join(app.getPath('userData'), APP_SETTINGS_FILENAME)
}

function normalizeSettings(settings: Partial<AppSettings>): AppSettings {
  return {
    theme: settings.theme === 'light' ? 'light' : DEFAULT_APP_SETTINGS.theme,
    editingMode: settings.editingMode === 'full-page' ? 'full-page' : DEFAULT_APP_SETTINGS.editingMode,
    autoSaveIntervalMs:
      typeof settings.autoSaveIntervalMs === 'number' && Number.isFinite(settings.autoSaveIntervalMs)
        ? Math.max(1000, Math.trunc(settings.autoSaveIntervalMs))
        : DEFAULT_APP_SETTINGS.autoSaveIntervalMs,
  }
}

export function getAppSettings(): AppSettings {
  const filePath = appSettingsPath()
  if (!existsSync(filePath)) return DEFAULT_APP_SETTINGS

  try {
    return normalizeSettings(JSON.parse(readFileSync(filePath, 'utf8')) as Partial<AppSettings>)
  } catch {
    return DEFAULT_APP_SETTINGS
  }
}

export function setAppSettings(settings: Partial<AppSettings>): AppSettings {
  const merged = normalizeSettings({ ...getAppSettings(), ...settings })
  const filePath = appSettingsPath()
  mkdirSync(dirname(filePath), { recursive: true })
  writeFileSync(filePath, JSON.stringify(merged, null, 2))
  return merged
}

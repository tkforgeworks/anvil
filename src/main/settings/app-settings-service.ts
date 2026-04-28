import { app } from 'electron'
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'fs'
import { dirname, join } from 'path'
import type { AppSettings, CustomThemeColors } from '../../shared/settings-types'

const APP_SETTINGS_FILENAME = 'app-settings.json'
const DEFAULT_APP_SETTINGS: AppSettings = {
  theme: 'dark',
  editingMode: 'modal',
  autoSaveEnabled: true,
  autoSaveIntervalMs: 5000,
  defaultSaveLocation: null,
  customThemePath: null,
  customThemeColors: null,
}

const HEX_COLOR_RE = /^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/

function appSettingsPath(): string {
  return join(app.getPath('userData'), APP_SETTINGS_FILENAME)
}

function isValidHex(value: unknown): value is string {
  return typeof value === 'string' && HEX_COLOR_RE.test(value)
}

function normalizeCustomThemeColors(raw: unknown): CustomThemeColors | null {
  if (!raw || typeof raw !== 'object') return null
  const obj = raw as Record<string, unknown>
  const colors: CustomThemeColors = {}
  if (obj.mode === 'dark' || obj.mode === 'light') colors.mode = obj.mode
  for (const key of [
    'primary', 'secondary', 'backgroundDefault', 'backgroundPaper',
    'textPrimary', 'textSecondary', 'error', 'warning', 'info', 'success', 'divider',
  ] as const) {
    if (isValidHex(obj[key])) {
      (colors as Record<string, string>)[key] = obj[key] as string
    }
  }
  return Object.keys(colors).length > 0 ? colors : null
}

function normalizeSettings(settings: Partial<AppSettings>): AppSettings {
  const theme = settings.theme === 'light' || settings.theme === 'custom'
    ? settings.theme
    : DEFAULT_APP_SETTINGS.theme
  return {
    theme,
    editingMode: settings.editingMode === 'full-page' ? 'full-page' : DEFAULT_APP_SETTINGS.editingMode,
    autoSaveEnabled: typeof settings.autoSaveEnabled === 'boolean' ? settings.autoSaveEnabled : DEFAULT_APP_SETTINGS.autoSaveEnabled,
    autoSaveIntervalMs:
      typeof settings.autoSaveIntervalMs === 'number' && Number.isFinite(settings.autoSaveIntervalMs)
        ? Math.max(1000, Math.trunc(settings.autoSaveIntervalMs))
        : DEFAULT_APP_SETTINGS.autoSaveIntervalMs,
    defaultSaveLocation:
      typeof settings.defaultSaveLocation === 'string' && settings.defaultSaveLocation.length > 0
        ? settings.defaultSaveLocation
        : null,
    customThemePath:
      typeof settings.customThemePath === 'string' && settings.customThemePath.length > 0
        ? settings.customThemePath
        : null,
    customThemeColors: normalizeCustomThemeColors(settings.customThemeColors),
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

export interface CustomThemeParseResult {
  success: boolean
  colors: CustomThemeColors | null
  error: string | null
}

export function parseCustomThemeFile(filePath: string): CustomThemeParseResult {
  try {
    if (!existsSync(filePath)) {
      return { success: false, colors: null, error: `File not found: ${filePath}` }
    }
    const raw = JSON.parse(readFileSync(filePath, 'utf8')) as unknown
    if (!raw || typeof raw !== 'object') {
      return { success: false, colors: null, error: 'Theme file must contain a JSON object.' }
    }
    const obj = raw as Record<string, unknown>
    const validKeys = [
      'mode', 'primary', 'secondary', 'backgroundDefault', 'backgroundPaper',
      'textPrimary', 'textSecondary', 'error', 'warning', 'info', 'success', 'divider',
    ]
    const invalidKeys = Object.keys(obj).filter((k) => !validKeys.includes(k))
    if (invalidKeys.length > 0) {
      return { success: false, colors: null, error: `Unknown keys: ${invalidKeys.join(', ')}. Valid keys: ${validKeys.join(', ')}` }
    }
    for (const [key, value] of Object.entries(obj)) {
      if (key === 'mode') {
        if (value !== 'dark' && value !== 'light') {
          return { success: false, colors: null, error: `"mode" must be "dark" or "light", got "${String(value)}".` }
        }
        continue
      }
      if (!isValidHex(value)) {
        return { success: false, colors: null, error: `"${key}" must be a hex color (#RRGGBB or #RRGGBBAA), got "${String(value)}".` }
      }
    }
    const colors = normalizeCustomThemeColors(obj)
    if (!colors) {
      return { success: false, colors: null, error: 'Theme file has no valid color values.' }
    }
    return { success: true, colors, error: null }
  } catch (cause) {
    return { success: false, colors: null, error: `Invalid JSON: ${cause instanceof Error ? cause.message : 'parse error'}` }
  }
}

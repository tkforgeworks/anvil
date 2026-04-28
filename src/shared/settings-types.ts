export interface CustomThemeColors {
  mode?: 'dark' | 'light'
  primary?: string
  secondary?: string
  backgroundDefault?: string
  backgroundPaper?: string
  textPrimary?: string
  textSecondary?: string
  error?: string
  warning?: string
  info?: string
  success?: string
  divider?: string
}

export interface AppSettings {
  theme: 'dark' | 'light' | 'custom'
  editingMode: 'modal' | 'full-page'
  autoSaveEnabled: boolean
  autoSaveIntervalMs: number
  defaultSaveLocation: string | null
  customThemePath: string | null
  customThemeColors: CustomThemeColors | null
}

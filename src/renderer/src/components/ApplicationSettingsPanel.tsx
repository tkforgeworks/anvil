import {
  ContentCopy as CopyIcon,
  ExpandMore as ExpandIcon,
  FolderOpen as FolderIcon,
  Upload as UploadIcon,
} from '@mui/icons-material'
import {
  Accordion,
  AccordionDetails,
  AccordionSummary,
  Alert,
  Box,
  Button,
  Divider,
  FormControl,
  FormControlLabel,
  Radio,
  RadioGroup,
  Stack,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material'
import { useEffect, useState } from 'react'
import { settingsApi } from '../../api/settings.api'
import type { AppSettings } from '../../../shared/settings-types'
import { useSettingsStore } from '../stores/settings.store'

const SAMPLE_THEME = `{
  "mode": "dark",
  "primary": "#bb86fc",
  "secondary": "#03dac6",
  "backgroundDefault": "#121212",
  "backgroundPaper": "#1e1e1e",
  "textPrimary": "#e0e0e0",
  "textSecondary": "#a0a0a0",
  "error": "#cf6679",
  "warning": "#ffb74d",
  "info": "#64b5f6",
  "success": "#81c784",
  "divider": "#333333"
}`

const THEME_KEY_DESCRIPTIONS: [string, string][] = [
  ['mode', '"dark" or "light" — base palette that fills in any keys you omit'],
  ['primary', 'Main accent color (buttons, links, active indicators)'],
  ['secondary', 'Secondary accent (less prominent highlights)'],
  ['backgroundDefault', 'Page background'],
  ['backgroundPaper', 'Cards, dialogs, and elevated surfaces'],
  ['textPrimary', 'Main body text'],
  ['textSecondary', 'Muted / helper text'],
  ['error', 'Error indicators and destructive actions'],
  ['warning', 'Warning banners and badges'],
  ['info', 'Informational highlights'],
  ['success', 'Success indicators'],
  ['divider', 'Lines between sections'],
]

function CustomThemeGuide(): React.JSX.Element {
  const [copied, setCopied] = useState(false)

  const handleCopy = async (): Promise<void> => {
    await navigator.clipboard.writeText(SAMPLE_THEME)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  return (
    <Accordion
      disableGutters
      elevation={0}
      sx={{
        mt: 1.5,
        bgcolor: 'transparent',
        '&:before': { display: 'none' },
        border: 1,
        borderColor: 'divider',
        borderRadius: 1,
      }}
    >
      <AccordionSummary expandIcon={<ExpandIcon />} sx={{ minHeight: 36, px: 1.5 }}>
        <Typography variant="caption" fontWeight={600}>
          Theme file reference & sample
        </Typography>
      </AccordionSummary>
      <AccordionDetails sx={{ px: 1.5, pt: 0 }}>
        <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 1.5 }}>
          Create a <code>.json</code> file with any combination of the keys below.
          All color values must be hex format (<code>#RRGGBB</code> or <code>#RRGGBBAA</code>).
          Any key you omit will use the default from the chosen <strong>mode</strong>.
        </Typography>

        <Box sx={{ mb: 1.5 }}>
          {THEME_KEY_DESCRIPTIONS.map(([key, desc]) => (
            <Stack key={key} direction="row" spacing={1} sx={{ mb: 0.25 }}>
              <Typography
                variant="caption"
                sx={{ fontFamily: 'monospace', fontWeight: 600, minWidth: 140, flexShrink: 0 }}
              >
                {key}
              </Typography>
              <Typography variant="caption" color="text.secondary">
                {desc}
              </Typography>
            </Stack>
          ))}
        </Box>

        <Typography variant="caption" fontWeight={600} sx={{ display: 'block', mb: 0.5 }}>
          Sample theme (Material Dark variant)
        </Typography>
        <Box sx={{ position: 'relative' }}>
          <Box
            component="pre"
            sx={{
              bgcolor: 'background.default',
              border: 1,
              borderColor: 'divider',
              borderRadius: 1,
              p: 1.5,
              fontSize: '0.75rem',
              fontFamily: 'monospace',
              overflow: 'auto',
              m: 0,
            }}
          >
            {SAMPLE_THEME}
          </Box>
          <Tooltip title={copied ? 'Copied!' : 'Copy to clipboard'}>
            <Button
              size="small"
              variant="outlined"
              startIcon={<CopyIcon />}
              onClick={() => void handleCopy()}
              sx={{ position: 'absolute', top: 8, right: 8, minWidth: 0, px: 1, py: 0.25, fontSize: '0.7rem' }}
            >
              {copied ? 'Copied' : 'Copy'}
            </Button>
          </Tooltip>
        </Box>
      </AccordionDetails>
    </Accordion>
  )
}

export default function ApplicationSettingsPanel(): React.JSX.Element {
  const appSettings = useSettingsStore((s) => s.appSettings)
  const setAppSettings = useSettingsStore((s) => s.setAppSettings)
  const [autoSaveSeconds, setAutoSaveSeconds] = useState('5')
  const [themeParseError, setThemeParseError] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    if (appSettings) {
      setAutoSaveSeconds(String(Math.round(appSettings.autoSaveIntervalMs / 1000)))
    }
  }, [appSettings])

  if (!appSettings) return <Typography color="text.secondary">Loading settings...</Typography>

  const updateSetting = async (patch: Partial<AppSettings>): Promise<void> => {
    setSaving(true)
    try {
      const updated = await settingsApi.setApp(patch)
      setAppSettings(updated)
    } finally {
      setSaving(false)
    }
  }

  const handleAutoSaveBlur = (): void => {
    const seconds = Math.max(1, parseInt(autoSaveSeconds, 10) || 5)
    setAutoSaveSeconds(String(seconds))
    void updateSetting({ autoSaveIntervalMs: seconds * 1000 })
  }

  const handleSelectFolder = async (): Promise<void> => {
    const folder = await settingsApi.selectFolder()
    if (folder) {
      void updateSetting({ defaultSaveLocation: folder })
    }
  }

  const handleClearFolder = (): void => {
    void updateSetting({ defaultSaveLocation: null })
  }

  const handleThemeChange = (value: string): void => {
    setThemeParseError(null)
    void updateSetting({ theme: value as AppSettings['theme'] })
  }

  const handleSelectThemeFile = async (): Promise<void> => {
    setThemeParseError(null)
    const result = await settingsApi.selectThemeFile()
    if (!result) return
    if (!result.success) {
      setThemeParseError(result.error ?? 'Failed to parse theme file.')
      return
    }
    void updateSetting({
      theme: 'custom',
      customThemePath: result.filePath,
      customThemeColors: result.colors,
    })
  }

  const handleEditingModeChange = (value: string): void => {
    void updateSetting({ editingMode: value as AppSettings['editingMode'] })
  }

  return (
    <Stack spacing={4} sx={{ maxWidth: 600 }}>
      <Alert severity="info" variant="outlined" sx={{ mb: 0 }}>
        These settings apply globally to the Anvil application and affect every project you open.
      </Alert>

      {/* Auto-save interval */}
      <Box>
        <Typography variant="subtitle2" gutterBottom>
          Auto-save Interval
        </Typography>
        <Stack direction="row" alignItems="center" spacing={1}>
          <TextField
            type="number"
            size="small"
            value={autoSaveSeconds}
            onChange={(e) => setAutoSaveSeconds(e.target.value)}
            onBlur={handleAutoSaveBlur}
            onKeyDown={(e) => { if (e.key === 'Enter') (e.target as HTMLInputElement).blur() }}
            inputProps={{ min: 1, step: 1 }}
            sx={{ width: 100 }}
            disabled={saving}
          />
          <Typography variant="body2" color="text.secondary">
            seconds
          </Typography>
        </Stack>
        <Typography variant="caption" color="text.secondary">
          How often the project is automatically saved. Minimum 1 second.
        </Typography>
      </Box>

      <Divider />

      {/* Default save location */}
      <Box>
        <Typography variant="subtitle2" gutterBottom>
          Default Save Location
        </Typography>
        <Stack direction="row" alignItems="center" spacing={1}>
          <Typography
            variant="body2"
            color={appSettings.defaultSaveLocation ? 'text.primary' : 'text.secondary'}
            sx={{ fontFamily: 'monospace', fontSize: '0.8rem', flex: 1, minWidth: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}
          >
            {appSettings.defaultSaveLocation ?? 'Not set — uses system default'}
          </Typography>
          <Button
            size="small"
            variant="outlined"
            startIcon={<FolderIcon />}
            onClick={() => void handleSelectFolder()}
            disabled={saving}
          >
            Browse
          </Button>
          {appSettings.defaultSaveLocation && (
            <Button size="small" color="secondary" onClick={handleClearFolder} disabled={saving}>
              Clear
            </Button>
          )}
        </Stack>
        <Typography variant="caption" color="text.secondary">
          Pre-filled path when creating new projects.
        </Typography>
      </Box>

      <Divider />

      {/* Theme */}
      <Box>
        <Typography variant="subtitle2" gutterBottom>
          UI Theme
        </Typography>
        <FormControl>
          <RadioGroup
            value={appSettings.theme}
            onChange={(e) => handleThemeChange(e.target.value)}
          >
            <FormControlLabel value="dark" control={<Radio size="small" />} label="Dark" disabled={saving} />
            <FormControlLabel value="light" control={<Radio size="small" />} label="Light" disabled={saving} />
            <FormControlLabel value="custom" control={<Radio size="small" />} label="Custom" disabled={saving} />
          </RadioGroup>
        </FormControl>

        {appSettings.theme === 'custom' && (
          <Box sx={{ mt: 1.5, pl: 1, borderLeft: 2, borderColor: 'divider' }}>
            <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 0.5 }}>
              <Button
                size="small"
                variant="outlined"
                startIcon={<UploadIcon />}
                onClick={() => void handleSelectThemeFile()}
                disabled={saving}
              >
                {appSettings.customThemePath ? 'Change Theme File' : 'Select Theme File'}
              </Button>
            </Stack>
            {appSettings.customThemePath && (
              <Typography variant="caption" color="text.secondary" sx={{ fontFamily: 'monospace', display: 'block', mb: 0.5 }}>
                {appSettings.customThemePath}
              </Typography>
            )}
            {themeParseError && (
              <Alert severity="error" sx={{ mt: 1 }}>
                {themeParseError}
              </Alert>
            )}
            <CustomThemeGuide />
          </Box>
        )}
      </Box>

      <Divider />

      {/* Editing mode */}
      <Box>
        <Typography variant="subtitle2" gutterBottom>
          Preferred Editing Mode
        </Typography>
        <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 1.5 }}>
          Controls how record editors open when clicking a record in any domain list view.
        </Typography>
        <FormControl>
          <RadioGroup
            value={appSettings.editingMode}
            onChange={(e) => handleEditingModeChange(e.target.value)}
          >
            <FormControlLabel value="modal" control={<Radio size="small" />} label="Modal" disabled={saving} />
            <Typography variant="caption" color="text.secondary" sx={{ pl: 3.75, mt: -0.5, mb: 0.5 }}>
              Opens the editor in a dialog overlay on top of the list view.
            </Typography>
            <FormControlLabel value="full-page" control={<Radio size="small" />} label="Full Page" disabled={saving} />
            <Typography variant="caption" color="text.secondary" sx={{ pl: 3.75, mt: -0.5 }}>
              Navigates to a dedicated editor page.
            </Typography>
          </RadioGroup>
        </FormControl>
      </Box>
    </Stack>
  )
}

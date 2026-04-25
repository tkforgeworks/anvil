import {
  FileDownload as ExportIcon,
  Preview as PreviewIcon,
} from '@mui/icons-material'
import {
  Alert,
  Box,
  Button,
  FormControl,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  Typography,
} from '@mui/material'
import { useCallback, useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { exportApi, type ExportPresetInfo, type ExportScope } from '../../api/export.api'

const DOMAIN_OPTIONS = [
  { value: 'classes', label: 'Classes' },
  { value: 'abilities', label: 'Abilities' },
  { value: 'items', label: 'Items' },
  { value: 'recipes', label: 'Recipes' },
  { value: 'npcs', label: 'NPCs' },
  { value: 'loot-tables', label: 'Loot Tables' },
]

export default function ExportPage(): React.JSX.Element {
  const navigate = useNavigate()
  const [presets, setPresets] = useState<ExportPresetInfo[]>([])
  const [selectedPreset, setSelectedPreset] = useState('')
  const [scopeMode, setScopeMode] = useState<'full' | 'domain'>('full')
  const [scopeDomain, setScopeDomain] = useState('')
  const [preview, setPreview] = useState<string | null>(null)
  const [isLoading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState<string | null>(null)
  const [validationBlocked, setValidationBlocked] = useState(false)

  useEffect(() => {
    void exportApi.getPresets().then((list) => {
      setPresets(list)
      if (list.length > 0) setSelectedPreset(list[0].id)
    })
  }, [])

  const buildScope = useCallback((): ExportScope => {
    if (scopeMode === 'domain' && scopeDomain) {
      return { mode: 'domain', domain: scopeDomain }
    }
    return { mode: 'full' }
  }, [scopeMode, scopeDomain])

  const handlePreview = async (): Promise<void> => {
    if (!selectedPreset) return
    setLoading(true)
    setError(null)
    setSuccess(null)
    setPreview(null)
    setValidationBlocked(false)
    try {
      const result = await exportApi.preview(selectedPreset, buildScope())
      if (result.error) {
        if (result.error.startsWith('Export blocked:')) {
          setValidationBlocked(true)
        }
        setError(result.error)
      } else {
        setPreview(result.output)
      }
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Preview failed.')
    } finally {
      setLoading(false)
    }
  }

  const handleExport = async (): Promise<void> => {
    if (!selectedPreset) return
    setLoading(true)
    setError(null)
    setSuccess(null)
    setValidationBlocked(false)
    try {
      const result = await exportApi.execute(selectedPreset, buildScope())
      if (result.error) {
        if (result.error.startsWith('Export blocked:')) {
          setValidationBlocked(true)
        }
        setError(result.error)
      } else if (result.success) {
        setSuccess(`Exported to ${result.path}`)
      }
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Export failed.')
    } finally {
      setLoading(false)
    }
  }

  const currentPreset = presets.find((p) => p.id === selectedPreset)

  return (
    <Stack spacing={3}>
      <Typography variant="h5" component="h1" sx={{ fontWeight: 700 }}>
        Export
      </Typography>

      {error && (
        <Alert
          severity="error"
          onClose={() => { setError(null); setValidationBlocked(false) }}
        >
          {error}
          {validationBlocked && (
            <Button
              size="small"
              sx={{ ml: 2 }}
              onClick={() => navigate('/validation')}
            >
              Open Validation Panel
            </Button>
          )}
        </Alert>
      )}

      {success && (
        <Alert severity="success" onClose={() => setSuccess(null)}>
          {success}
        </Alert>
      )}

      <Stack spacing={3} sx={{ maxWidth: 600 }}>
        <FormControl fullWidth>
          <InputLabel id="export-preset-label">Export Preset</InputLabel>
          <Select
            labelId="export-preset-label"
            label="Export Preset"
            value={selectedPreset}
            onChange={(e) => { setSelectedPreset(e.target.value); setPreview(null) }}
          >
            {presets.map((preset) => (
              <MenuItem key={preset.id} value={preset.id}>
                {preset.name}
              </MenuItem>
            ))}
          </Select>
        </FormControl>
        {currentPreset && (
          <Typography variant="body2" color="text.secondary">
            {currentPreset.description}
          </Typography>
        )}

        <FormControl fullWidth>
          <InputLabel id="export-scope-label">Scope</InputLabel>
          <Select
            labelId="export-scope-label"
            label="Scope"
            value={scopeMode}
            onChange={(e) => { setScopeMode(e.target.value as 'full' | 'domain'); setPreview(null) }}
          >
            <MenuItem value="full">Full Project</MenuItem>
            <MenuItem value="domain">Single Domain</MenuItem>
          </Select>
        </FormControl>

        {scopeMode === 'domain' && (
          <FormControl fullWidth>
            <InputLabel id="export-domain-label">Domain</InputLabel>
            <Select
              labelId="export-domain-label"
              label="Domain"
              value={scopeDomain}
              onChange={(e) => { setScopeDomain(e.target.value); setPreview(null) }}
            >
              {DOMAIN_OPTIONS.map((opt) => (
                <MenuItem key={opt.value} value={opt.value}>
                  {opt.label}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
        )}

        <Stack direction="row" spacing={2}>
          <Button
            variant="outlined"
            startIcon={<PreviewIcon />}
            onClick={() => void handlePreview()}
            disabled={isLoading || !selectedPreset || (scopeMode === 'domain' && !scopeDomain)}
          >
            {isLoading ? 'Loading...' : 'Preview'}
          </Button>
          <Button
            variant="contained"
            startIcon={<ExportIcon />}
            onClick={() => void handleExport()}
            disabled={isLoading || !selectedPreset || (scopeMode === 'domain' && !scopeDomain)}
          >
            Export to File
          </Button>
        </Stack>
      </Stack>

      {preview != null && (
        <Box>
          <Typography variant="subtitle1" sx={{ mb: 1, fontWeight: 600 }}>
            Preview
          </Typography>
          <Box
            sx={{
              bgcolor: 'grey.900',
              color: 'grey.100',
              p: 2,
              borderRadius: 1,
              fontFamily: 'monospace',
              fontSize: '0.8rem',
              whiteSpace: 'pre',
              overflow: 'auto',
              maxHeight: 600,
            }}
          >
            {preview}
          </Box>
        </Box>
      )}
    </Stack>
  )
}

import {
  Add as AddIcon,
  Delete as DeleteIcon,
  Edit as EditIcon,
  FolderOpen as FolderIcon,
  Upload as UploadIcon,
} from '@mui/icons-material'
import {
  Alert,
  Box,
  Button,
  Checkbox,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Divider,
  FormControl,
  FormControlLabel,
  IconButton,
  InputLabel,
  List,
  ListItemButton,
  ListItemText,
  MenuItem,
  Radio,
  RadioGroup,
  Select,
  Stack,
  Tab,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  Tabs,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material'
import { useCallback, useEffect, useState } from 'react'
import { customFieldsApi } from '../../api/custom-fields.api'
import { metaApi } from '../../api/meta.api'
import { settingsApi } from '../../api/settings.api'
import type {
  CreateCustomFieldDefinitionInput,
  CustomFieldDefinition,
  CustomFieldScope,
  CustomFieldType,
  MetaItemCategory,
  MetaNpcType,
  UpdateCustomFieldDefinitionInput,
} from '../../../shared/domain-types'
import type { AppSettings } from '../../../shared/settings-types'
import { useProjectStore } from '../stores/project.store'
import { useSettingsStore } from '../stores/settings.store'

const FIELD_TYPE_LABELS: Record<CustomFieldType, string> = {
  text: 'Text',
  integer: 'Integer',
  decimal: 'Decimal',
  boolean: 'Boolean',
  enum: 'Enum',
}

// ─── Tab panel ────────────────────────────────────────────────────────────────

interface TabPanelProps {
  index: number
  value: number
  children: React.ReactNode
}

function TabPanel({ index, value, children }: TabPanelProps): React.JSX.Element {
  return (
    <Box role="tabpanel" hidden={value !== index} sx={{ pt: 3 }}>
      {value === index && children}
    </Box>
  )
}

// ─── Application Settings tab ─────────────────────────────────────────────────

function ApplicationSettingsTab(): React.JSX.Element {
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
            <Typography variant="caption" color="text.secondary">
              JSON file with hex color values. Valid keys: mode, primary, secondary, backgroundDefault, backgroundPaper, textPrimary, textSecondary, error, warning, info, success, divider.
            </Typography>
          </Box>
        )}
      </Box>

      <Divider />

      {/* Editing mode */}
      <Box>
        <Typography variant="subtitle2" gutterBottom>
          Preferred Editing Mode
        </Typography>
        <FormControl>
          <RadioGroup
            value={appSettings.editingMode}
            onChange={(e) => handleEditingModeChange(e.target.value)}
          >
            <FormControlLabel value="modal" control={<Radio size="small" />} label="Modal (opens editor in a dialog overlay)" disabled={saving} />
            <FormControlLabel value="full-page" control={<Radio size="small" />} label="Full Page (navigates to a dedicated editor page)" disabled={saving} />
          </RadioGroup>
        </FormControl>
        <Typography variant="caption" color="text.secondary">
          Controls how record editors open when clicking a record in any domain list view.
        </Typography>
      </Box>
    </Stack>
  )
}

// ─── Field definition dialog ──────────────────────────────────────────────────

interface FieldDialogProps {
  open: boolean
  editing: CustomFieldDefinition | null
  scopeType: CustomFieldScope
  scopeId: string
  onClose: () => void
  onSaved: () => void
}

function FieldDialog({ open, editing, scopeType, scopeId, onClose, onSaved }: FieldDialogProps): React.JSX.Element {
  const [fieldName, setFieldName] = useState('')
  const [fieldType, setFieldType] = useState<CustomFieldType>('text')
  const [defaultValue, setDefaultValue] = useState('')
  const [isRequired, setIsRequired] = useState(false)
  const [isSearchable, setIsSearchable] = useState(false)
  const [enumOptions, setEnumOptions] = useState<string[]>([])
  const [newOption, setNewOption] = useState('')
  const [isBusy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    if (editing) {
      setFieldName(editing.fieldName)
      setFieldType(editing.fieldType)
      setDefaultValue(editing.defaultValue ?? '')
      setIsRequired(editing.isRequired)
      setIsSearchable(editing.isSearchable)
      setEnumOptions([...editing.enumOptions])
    } else {
      setFieldName('')
      setFieldType('text')
      setDefaultValue('')
      setIsRequired(false)
      setIsSearchable(false)
      setEnumOptions([])
    }
    setNewOption('')
    setError(null)
  }, [open, editing])

  const addEnumOption = (): void => {
    const trimmed = newOption.trim()
    if (!trimmed || enumOptions.includes(trimmed)) return
    setEnumOptions([...enumOptions, trimmed])
    setNewOption('')
  }

  const removeEnumOption = (option: string): void => {
    setEnumOptions(enumOptions.filter((o) => o !== option))
  }

  const handleSave = async (): Promise<void> => {
    if (!fieldName.trim()) return
    setBusy(true)
    setError(null)
    try {
      if (editing) {
        const input: UpdateCustomFieldDefinitionInput = {
          fieldName: fieldName.trim(),
          defaultValue: defaultValue || null,
          isRequired,
          isSearchable,
          ...(editing.fieldType === 'enum' ? { enumOptions } : {}),
        }
        await customFieldsApi.updateDefinition(editing.id, input)
      } else {
        const input: CreateCustomFieldDefinitionInput = {
          scopeType,
          scopeId,
          fieldName: fieldName.trim(),
          fieldType,
          defaultValue: defaultValue || null,
          isRequired,
          isSearchable,
          ...(fieldType === 'enum' ? { enumOptions } : {}),
        }
        await customFieldsApi.createDefinition(input)
      }
      onSaved()
      onClose()
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to save field.')
    } finally {
      setBusy(false)
    }
  }

  const isEnum = fieldType === 'enum'
  const canSave =
    fieldName.trim().length > 0 &&
    (!isEnum || enumOptions.length > 0) &&
    !isBusy

  return (
    <Dialog open={open} onClose={onClose} fullWidth maxWidth="sm">
      <DialogTitle>{editing ? `Edit Field: ${editing.fieldName}` : 'Add Custom Field'}</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ pt: 1 }}>
          {error && <Alert severity="error">{error}</Alert>}

          <TextField
            label="Field Name"
            value={fieldName}
            onChange={(e) => setFieldName(e.target.value)}
            required
            autoFocus
          />

          <FormControl fullWidth>
            <InputLabel id="field-type-label">Field Type</InputLabel>
            <Select
              labelId="field-type-label"
              label="Field Type"
              value={fieldType}
              onChange={(e) => setFieldType(e.target.value as CustomFieldType)}
              disabled={!!editing}
            >
              {(Object.entries(FIELD_TYPE_LABELS) as [CustomFieldType, string][]).map(
                ([value, label]) => (
                  <MenuItem key={value} value={value}>
                    {label}
                  </MenuItem>
                ),
              )}
            </Select>
            {editing && (
              <Typography variant="caption" color="text.secondary" sx={{ mt: 0.5 }}>
                Field type cannot be changed after creation.
              </Typography>
            )}
          </FormControl>

          {isEnum ? (
            <Box>
              <Typography variant="subtitle2" gutterBottom>
                Enum Options
              </Typography>
              <Stack direction="row" spacing={1} sx={{ mb: 1 }}>
                <TextField
                  size="small"
                  label="New option"
                  value={newOption}
                  onChange={(e) => setNewOption(e.target.value)}
                  onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); addEnumOption() } }}
                  sx={{ flex: 1 }}
                />
                <Button variant="outlined" size="small" onClick={addEnumOption} disabled={!newOption.trim()}>
                  Add
                </Button>
              </Stack>
              <Stack direction="row" flexWrap="wrap" gap={1}>
                {enumOptions.length === 0 && (
                  <Typography variant="body2" color="text.secondary">
                    No options defined. Add at least one.
                  </Typography>
                )}
                {enumOptions.map((opt) => (
                  <Chip
                    key={opt}
                    label={opt}
                    onDelete={() => removeEnumOption(opt)}
                    size="small"
                  />
                ))}
              </Stack>
            </Box>
          ) : (
            <TextField
              label="Default Value"
              value={defaultValue}
              onChange={(e) => setDefaultValue(e.target.value)}
              helperText="Optional. Pre-populated when a new record is created."
            />
          )}

          <Stack direction="row" spacing={2}>
            <FormControlLabel
              control={
                <Checkbox
                  checked={isRequired}
                  onChange={(e) => setIsRequired(e.target.checked)}
                />
              }
              label="Required"
            />
            <FormControlLabel
              control={
                <Checkbox
                  checked={isSearchable}
                  onChange={(e) => setIsSearchable(e.target.checked)}
                />
              }
              label="Searchable / Filterable"
            />
          </Stack>
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} disabled={isBusy}>Cancel</Button>
        <Button onClick={() => void handleSave()} variant="contained" disabled={!canSave}>
          {editing ? 'Save Changes' : 'Add Field'}
        </Button>
      </DialogActions>
    </Dialog>
  )
}

// ─── Field definition list for a scope ───────────────────────────────────────

interface FieldListProps {
  scopeType: CustomFieldScope
  scopeId: string
}

function FieldList({ scopeType, scopeId }: FieldListProps): React.JSX.Element {
  const [definitions, setDefinitions] = useState<CustomFieldDefinition[]>([])
  const [dialogOpen, setDialogOpen] = useState(false)
  const [editing, setEditing] = useState<CustomFieldDefinition | null>(null)
  const [deleteError, setDeleteError] = useState<string | null>(null)

  const loadDefinitions = useCallback(async () => {
    const defs = await customFieldsApi.listDefinitions(scopeType, scopeId)
    setDefinitions(defs)
  }, [scopeType, scopeId])

  useEffect(() => {
    void loadDefinitions()
  }, [loadDefinitions])

  const handleDelete = async (def: CustomFieldDefinition): Promise<void> => {
    setDeleteError(null)
    const result = await customFieldsApi.deleteDefinition(def.id)
    if (!result.deleted) {
      setDeleteError(
        `Cannot delete "${def.fieldName}": ${result.affectedCount} record(s) currently have values for this field. Clear those values first.`,
      )
      return
    }
    await loadDefinitions()
  }

  const openEdit = (def: CustomFieldDefinition): void => {
    setEditing(def)
    setDialogOpen(true)
  }

  const openAdd = (): void => {
    setEditing(null)
    setDialogOpen(true)
  }

  const handleDialogClose = (): void => {
    setDialogOpen(false)
    setEditing(null)
    setDeleteError(null)
  }

  return (
    <Box>
      {deleteError && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setDeleteError(null)}>
          {deleteError}
        </Alert>
      )}

      {definitions.length === 0 ? (
        <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
          No custom fields defined.
        </Typography>
      ) : (
        <Table size="small" sx={{ mb: 2 }}>
          <TableHead>
            <TableRow>
              <TableCell>Field Name</TableCell>
              <TableCell>Type</TableCell>
              <TableCell align="center">Required</TableCell>
              <TableCell align="center">Searchable</TableCell>
              <TableCell align="right">Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {definitions.map((def) => (
              <TableRow key={def.id}>
                <TableCell>{def.fieldName}</TableCell>
                <TableCell>
                  <Chip
                    label={FIELD_TYPE_LABELS[def.fieldType]}
                    size="small"
                    variant="outlined"
                  />
                </TableCell>
                <TableCell align="center">{def.isRequired ? '✓' : '—'}</TableCell>
                <TableCell align="center">{def.isSearchable ? '✓' : '—'}</TableCell>
                <TableCell align="right">
                  <Tooltip title="Edit">
                    <IconButton size="small" onClick={() => openEdit(def)}>
                      <EditIcon fontSize="small" />
                    </IconButton>
                  </Tooltip>
                  <Tooltip title="Delete">
                    <IconButton size="small" color="error" onClick={() => void handleDelete(def)}>
                      <DeleteIcon fontSize="small" />
                    </IconButton>
                  </Tooltip>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}

      <Button startIcon={<AddIcon />} variant="outlined" size="small" onClick={openAdd}>
        Add Field
      </Button>

      <FieldDialog
        open={dialogOpen}
        editing={editing}
        scopeType={scopeType}
        scopeId={scopeId}
        onClose={handleDialogClose}
        onSaved={() => void loadDefinitions()}
      />
    </Box>
  )
}

// ─── Project Settings tab (custom fields) ────────────────────────────────────

function ProjectSettingsTab(): React.JSX.Element {
  const projectFilePath = useProjectStore((state) => state.activeProject?.filePath ?? null)
  const [itemCategories, setItemCategories] = useState<MetaItemCategory[]>([])
  const [npcTypes, setNpcTypes] = useState<MetaNpcType[]>([])
  const [selectedScope, setSelectedScope] = useState<{
    type: CustomFieldScope
    id: string
    label: string
  } | null>(null)

  useEffect(() => {
    if (!projectFilePath) return
    void Promise.all([metaApi.listItemCategories(), metaApi.listNpcTypes()]).then(
      ([cats, types]) => {
        setItemCategories(cats)
        setNpcTypes(types)
        if (cats.length > 0) {
          setSelectedScope({ type: 'item_category', id: cats[0].id, label: cats[0].displayName })
        }
      },
    )
  }, [projectFilePath])

  return (
    <>
      <Typography color="text.secondary" sx={{ mb: 3 }}>
        Define custom fields for item categories and NPC types.
      </Typography>

      <Box sx={{ display: 'flex', gap: 3, alignItems: 'flex-start' }}>
        <Box sx={{ width: 220, flexShrink: 0 }}>
          <Typography variant="overline" color="text.secondary">
            Item Categories
          </Typography>
          <List dense disablePadding>
            {itemCategories.map((cat) => (
              <ListItemButton
                key={cat.id}
                selected={selectedScope?.type === 'item_category' && selectedScope.id === cat.id}
                onClick={() =>
                  setSelectedScope({ type: 'item_category', id: cat.id, label: cat.displayName })
                }
                sx={{ borderRadius: 1 }}
              >
                <ListItemText primary={cat.displayName} />
              </ListItemButton>
            ))}
          </List>

          <Divider sx={{ my: 1.5 }} />

          <Typography variant="overline" color="text.secondary">
            NPC Types
          </Typography>
          <List dense disablePadding>
            {npcTypes.map((t) => (
              <ListItemButton
                key={t.id}
                selected={selectedScope?.type === 'npc_type' && selectedScope.id === t.id}
                onClick={() =>
                  setSelectedScope({ type: 'npc_type', id: t.id, label: t.displayName })
                }
                sx={{ borderRadius: 1 }}
              >
                <ListItemText primary={t.displayName} />
              </ListItemButton>
            ))}
          </List>
        </Box>

        <Box sx={{ flex: 1 }}>
          {selectedScope ? (
            <>
              <Stack direction="row" alignItems="center" justifyContent="space-between" sx={{ mb: 2 }}>
                <Typography variant="h6">{selectedScope.label}</Typography>
                <Typography variant="caption" color="text.secondary">
                  {selectedScope.type === 'item_category' ? 'Item Category' : 'NPC Type'}
                </Typography>
              </Stack>
              <FieldList
                key={`${selectedScope.type}:${selectedScope.id}`}
                scopeType={selectedScope.type}
                scopeId={selectedScope.id}
              />
            </>
          ) : (
            <Typography color="text.secondary">
              Select a category or type on the left to manage its custom fields.
            </Typography>
          )}
        </Box>
      </Box>
    </>
  )
}

// ─── Settings page ────────────────────────────────────────────────────────────

export default function SettingsPage(): React.JSX.Element {
  const activeProject = useProjectStore((state) => state.activeProject)
  const [activeTab, setActiveTab] = useState(0)

  if (!activeProject) {
    return (
      <Box sx={{ p: 4 }}>
        <Typography color="text.secondary">Open a project to manage settings.</Typography>
      </Box>
    )
  }

  return (
    <Box sx={{ maxWidth: 1100, mx: 'auto' }}>
      <Typography variant="h4" sx={{ mb: 0.5 }}>
        Settings
      </Typography>

      <Tabs value={activeTab} onChange={(_, v: number) => setActiveTab(v)} sx={{ mb: 0 }}>
        <Tab label="Application" />
        <Tab label="Project" />
      </Tabs>
      <Divider />

      <TabPanel index={0} value={activeTab}>
        <ApplicationSettingsTab />
      </TabPanel>

      <TabPanel index={1} value={activeTab}>
        <ProjectSettingsTab />
      </TabPanel>
    </Box>
  )
}

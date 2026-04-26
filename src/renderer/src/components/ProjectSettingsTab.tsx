import {
  Add as AddIcon,
  ArrowDownward as DownIcon,
  ArrowUpward as UpIcon,
  Delete as DeleteIcon,
  Edit as EditIcon,
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
  InputAdornment,
  InputLabel,
  List,
  ListItemButton,
  ListItemText,
  MenuItem,
  Radio,
  RadioGroup,
  Select,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material'
import { useCallback, useEffect, useState } from 'react'
import { customFieldsApi } from '../../api/custom-fields.api'
import { metaApi } from '../../api/meta.api'
import type {
  CreateCustomFieldDefinitionInput,
  CustomFieldDefinition,
  CustomFieldScope,
  CustomFieldType,
  DerivedStatDefinition,
  DerivedStatInput,
  MetaDeleteResult,
  MetaItemCategory,
  MetaNpcType,
  MetaRarity,
  MetaRarityInput,
  MetaReorderItem,
  MetaStat,
  MetaCraftingStation,
  MetaCraftingSpecialization,
  ProjectSettings,
  UpdateCustomFieldDefinitionInput,
} from '../../../shared/domain-types'
import { useProjectStore } from '../stores/project.store'
import MetaListSection from './MetaListSection'

// ─── Helpers ─────────────────────────────────────────────────────────────────

function slugify(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_|_$/g, '')
}

const FIELD_TYPE_LABELS: Record<CustomFieldType, string> = {
  text: 'Text',
  integer: 'Integer',
  decimal: 'Decimal',
  boolean: 'Boolean',
  enum: 'Enum',
}

// ─── Rarity section ──────────────────────────────────────────────────────────

interface RaritySectionProps {
  rarities: MetaRarity[]
  onRefresh: () => void
}

function RaritySection({ rarities, onRefresh }: RaritySectionProps): React.JSX.Element {
  const [dialogOpen, setDialogOpen] = useState(false)
  const [editing, setEditing] = useState<MetaRarity | null>(null)
  const [displayName, setDisplayName] = useState('')
  const [exportKey, setExportKey] = useState('')
  const [exportKeyTouched, setExportKeyTouched] = useState(false)
  const [colorHex, setColorHex] = useState('#ffffff')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const openAdd = (): void => {
    setEditing(null)
    setDisplayName('')
    setExportKey('')
    setExportKeyTouched(false)
    setColorHex('#ffffff')
    setError(null)
    setDialogOpen(true)
  }

  const openEdit = (r: MetaRarity): void => {
    setEditing(r)
    setDisplayName(r.displayName)
    setExportKey(r.exportKey)
    setExportKeyTouched(true)
    setColorHex(r.colorHex)
    setError(null)
    setDialogOpen(true)
  }

  const handleClose = (): void => {
    setDialogOpen(false)
    setEditing(null)
  }

  const handleNameChange = (value: string): void => {
    setDisplayName(value)
    if (!exportKeyTouched) setExportKey(slugify(value))
  }

  const handleSave = async (): Promise<void> => {
    if (!displayName.trim() || !exportKey.trim() || !colorHex.trim()) return
    setBusy(true)
    setError(null)
    try {
      const input: MetaRarityInput = {
        displayName: displayName.trim(),
        exportKey: exportKey.trim(),
        colorHex: colorHex.trim(),
      }
      if (editing) {
        await metaApi.updateRarity(editing.id, input)
      } else {
        await metaApi.addRarity(input)
      }
      handleClose()
      onRefresh()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Operation failed.')
    } finally {
      setBusy(false)
    }
  }

  const handleDelete = async (r: MetaRarity): Promise<void> => {
    setError(null)
    const result = await metaApi.deleteRarity(r.id)
    if (!result.deleted) {
      setError(result.reason ?? `Cannot delete "${r.displayName}".`)
      return
    }
    onRefresh()
  }

  const handleMove = async (index: number, direction: 'up' | 'down'): Promise<void> => {
    const targetIndex = direction === 'up' ? index - 1 : index + 1
    if (targetIndex < 0 || targetIndex >= rarities.length) return
    const reordered: MetaReorderItem[] = rarities.map((item, i) => {
      if (i === index) return { id: item.id, sortOrder: rarities[targetIndex].sortOrder }
      if (i === targetIndex) return { id: item.id, sortOrder: rarities[index].sortOrder }
      return { id: item.id, sortOrder: item.sortOrder }
    })
    await metaApi.reorderRarities(reordered)
    onRefresh()
  }

  const canSave = displayName.trim().length > 0 && exportKey.trim().length > 0 && /^#[0-9a-fA-F]{6}$/.test(colorHex.trim()) && !busy

  return (
    <Box>
      <Stack direction="row" alignItems="center" justifyContent="space-between" sx={{ mb: 1 }}>
        <Box>
          <Typography variant="subtitle2">Rarities</Typography>
          <Typography variant="caption" color="text.secondary" sx={{ display: 'block' }}>
            Rarity tiers used by items. Each has a display color shown in list views.
          </Typography>
        </Box>
        <Button startIcon={<AddIcon />} variant="outlined" size="small" onClick={openAdd}>
          Add
        </Button>
      </Stack>

      {error && (
        <Alert severity="error" sx={{ mb: 1.5 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      {rarities.length === 0 ? (
        <Typography variant="body2" color="text.secondary">None defined.</Typography>
      ) : (
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell sx={{ width: 40 }}>Color</TableCell>
              <TableCell>Name</TableCell>
              <TableCell>Export Key</TableCell>
              <TableCell align="right" sx={{ width: 150 }}>Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {rarities.map((r, index) => (
              <TableRow key={r.id}>
                <TableCell>
                  <Box sx={{ width: 20, height: 20, borderRadius: 0.5, bgcolor: r.colorHex, border: 1, borderColor: 'divider' }} />
                </TableCell>
                <TableCell>{r.displayName}</TableCell>
                <TableCell>
                  <Typography variant="body2" sx={{ fontFamily: 'monospace', fontSize: '0.8rem' }}>
                    {r.exportKey}
                  </Typography>
                </TableCell>
                <TableCell align="right">
                  <Tooltip title="Move up">
                    <span>
                      <IconButton size="small" disabled={index === 0} onClick={() => void handleMove(index, 'up')}>
                        <UpIcon fontSize="small" />
                      </IconButton>
                    </span>
                  </Tooltip>
                  <Tooltip title="Move down">
                    <span>
                      <IconButton size="small" disabled={index === rarities.length - 1} onClick={() => void handleMove(index, 'down')}>
                        <DownIcon fontSize="small" />
                      </IconButton>
                    </span>
                  </Tooltip>
                  <Tooltip title="Edit">
                    <IconButton size="small" onClick={() => openEdit(r)}>
                      <EditIcon fontSize="small" />
                    </IconButton>
                  </Tooltip>
                  <Tooltip title="Delete">
                    <IconButton size="small" color="error" onClick={() => void handleDelete(r)}>
                      <DeleteIcon fontSize="small" />
                    </IconButton>
                  </Tooltip>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}

      <Dialog open={dialogOpen} onClose={handleClose} fullWidth maxWidth="xs">
        <DialogTitle>{editing ? 'Edit Rarity' : 'Add Rarity'}</DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ pt: 1 }}>
            <TextField
              label="Display Name"
              value={displayName}
              onChange={(e) => handleNameChange(e.target.value)}
              required
              autoFocus
            />
            <TextField
              label="Export Key"
              value={exportKey}
              onChange={(e) => { setExportKey(e.target.value); setExportKeyTouched(true) }}
              required
              slotProps={{
                input: {
                  startAdornment: exportKey ? undefined : (
                    <InputAdornment position="start">
                      <Typography variant="caption" color="text.secondary">auto</Typography>
                    </InputAdornment>
                  ),
                },
              }}
            />
            <Stack direction="row" spacing={1.5} alignItems="center">
              <TextField
                label="Color (hex)"
                value={colorHex}
                onChange={(e) => setColorHex(e.target.value)}
                required
                placeholder="#RRGGBB"
                sx={{ flex: 1 }}
                error={colorHex.trim().length > 0 && !/^#[0-9a-fA-F]{6}$/.test(colorHex.trim())}
                helperText="Hex format: #RRGGBB"
              />
              <Box sx={{ flexShrink: 0, pt: 1 }}>
                <Box
                  component="input"
                  type="color"
                  value={/^#[0-9a-fA-F]{6}$/.test(colorHex) ? colorHex : '#ffffff'}
                  onChange={(e: React.ChangeEvent<HTMLInputElement>) => setColorHex(e.target.value)}
                  sx={{ width: 40, height: 40, border: 'none', cursor: 'pointer', p: 0, bgcolor: 'transparent' }}
                />
              </Box>
            </Stack>
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={handleClose} disabled={busy}>Cancel</Button>
          <Button onClick={() => void handleSave()} variant="contained" disabled={!canSave}>
            {editing ? 'Save' : 'Add'}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  )
}

// ─── Derived stat section ────────────────────────────────────────────────────

interface DerivedStatSectionProps {
  derivedStats: DerivedStatDefinition[]
  onRefresh: () => void
}

function DerivedStatSection({ derivedStats, onRefresh }: DerivedStatSectionProps): React.JSX.Element {
  const [dialogOpen, setDialogOpen] = useState(false)
  const [editing, setEditing] = useState<DerivedStatDefinition | null>(null)
  const [displayName, setDisplayName] = useState('')
  const [exportKey, setExportKey] = useState('')
  const [exportKeyTouched, setExportKeyTouched] = useState(false)
  const [formula, setFormula] = useState('')
  const [outputType, setOutputType] = useState<'integer' | 'float'>('integer')
  const [roundingMode, setRoundingMode] = useState<'floor' | 'round' | 'none'>('floor')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const openAdd = (): void => {
    setEditing(null)
    setDisplayName('')
    setExportKey('')
    setExportKeyTouched(false)
    setFormula('')
    setOutputType('integer')
    setRoundingMode('floor')
    setError(null)
    setDialogOpen(true)
  }

  const openEdit = (ds: DerivedStatDefinition): void => {
    setEditing(ds)
    setDisplayName(ds.displayName)
    setExportKey(ds.exportKey)
    setExportKeyTouched(true)
    setFormula(ds.formula)
    setOutputType(ds.outputType)
    setRoundingMode(ds.roundingMode)
    setError(null)
    setDialogOpen(true)
  }

  const handleClose = (): void => {
    setDialogOpen(false)
    setEditing(null)
  }

  const handleNameChange = (value: string): void => {
    setDisplayName(value)
    if (!exportKeyTouched) setExportKey(slugify(value))
  }

  const handleSave = async (): Promise<void> => {
    if (!displayName.trim() || !exportKey.trim() || !formula.trim()) return
    setBusy(true)
    setError(null)
    try {
      const input: DerivedStatInput = {
        displayName: displayName.trim(),
        exportKey: exportKey.trim(),
        formula: formula.trim(),
        outputType,
        roundingMode,
      }
      if (editing) {
        await metaApi.updateDerivedStat(editing.id, input)
      } else {
        await metaApi.addDerivedStat(input)
      }
      handleClose()
      onRefresh()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Operation failed.')
    } finally {
      setBusy(false)
    }
  }

  const handleDelete = async (ds: DerivedStatDefinition): Promise<void> => {
    setError(null)
    const result = await metaApi.deleteDerivedStat(ds.id)
    if (!result.deleted) {
      setError(result.reason ?? `Cannot delete "${ds.displayName}".`)
      return
    }
    onRefresh()
  }

  const handleMove = async (index: number, direction: 'up' | 'down'): Promise<void> => {
    const targetIndex = direction === 'up' ? index - 1 : index + 1
    if (targetIndex < 0 || targetIndex >= derivedStats.length) return
    const reordered: MetaReorderItem[] = derivedStats.map((item, i) => {
      if (i === index) return { id: item.id, sortOrder: derivedStats[targetIndex].sortOrder }
      if (i === targetIndex) return { id: item.id, sortOrder: derivedStats[index].sortOrder }
      return { id: item.id, sortOrder: item.sortOrder }
    })
    await metaApi.reorderDerivedStats(reordered)
    onRefresh()
  }

  const canSave = displayName.trim().length > 0 && exportKey.trim().length > 0 && formula.trim().length > 0 && !busy

  return (
    <Box>
      <Stack direction="row" alignItems="center" justifyContent="space-between" sx={{ mb: 1 }}>
        <Box>
          <Typography variant="subtitle2">Derived Stat Definitions</Typography>
          <Typography variant="caption" color="text.secondary" sx={{ display: 'block' }}>
            Calculated stats with formulas referencing primary stats. Per-class overrides are managed in the class editor.
          </Typography>
        </Box>
        <Button startIcon={<AddIcon />} variant="outlined" size="small" onClick={openAdd}>
          Add
        </Button>
      </Stack>

      {error && (
        <Alert severity="error" sx={{ mb: 1.5 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      {derivedStats.length === 0 ? (
        <Typography variant="body2" color="text.secondary">None defined.</Typography>
      ) : (
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Name</TableCell>
              <TableCell>Export Key</TableCell>
              <TableCell>Formula</TableCell>
              <TableCell>Output</TableCell>
              <TableCell>Rounding</TableCell>
              <TableCell align="right" sx={{ width: 150 }}>Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {derivedStats.map((ds, index) => (
              <TableRow key={ds.id}>
                <TableCell>{ds.displayName}</TableCell>
                <TableCell>
                  <Typography variant="body2" sx={{ fontFamily: 'monospace', fontSize: '0.8rem' }}>
                    {ds.exportKey}
                  </Typography>
                </TableCell>
                <TableCell>
                  <Typography
                    variant="body2"
                    sx={{ fontFamily: 'monospace', fontSize: '0.75rem', maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}
                  >
                    {ds.formula}
                  </Typography>
                </TableCell>
                <TableCell>
                  <Chip label={ds.outputType} size="small" variant="outlined" />
                </TableCell>
                <TableCell>
                  <Chip label={ds.roundingMode} size="small" variant="outlined" />
                </TableCell>
                <TableCell align="right">
                  <Tooltip title="Move up">
                    <span>
                      <IconButton size="small" disabled={index === 0} onClick={() => void handleMove(index, 'up')}>
                        <UpIcon fontSize="small" />
                      </IconButton>
                    </span>
                  </Tooltip>
                  <Tooltip title="Move down">
                    <span>
                      <IconButton size="small" disabled={index === derivedStats.length - 1} onClick={() => void handleMove(index, 'down')}>
                        <DownIcon fontSize="small" />
                      </IconButton>
                    </span>
                  </Tooltip>
                  <Tooltip title="Edit">
                    <IconButton size="small" onClick={() => openEdit(ds)}>
                      <EditIcon fontSize="small" />
                    </IconButton>
                  </Tooltip>
                  <Tooltip title="Delete">
                    <IconButton size="small" color="error" onClick={() => void handleDelete(ds)}>
                      <DeleteIcon fontSize="small" />
                    </IconButton>
                  </Tooltip>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}

      <Dialog open={dialogOpen} onClose={handleClose} fullWidth maxWidth="sm">
        <DialogTitle>{editing ? 'Edit Derived Stat' : 'Add Derived Stat'}</DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ pt: 1 }}>
            <TextField
              label="Display Name"
              value={displayName}
              onChange={(e) => handleNameChange(e.target.value)}
              required
              autoFocus
            />
            <TextField
              label="Export Key"
              value={exportKey}
              onChange={(e) => { setExportKey(e.target.value); setExportKeyTouched(true) }}
              required
              slotProps={{
                input: {
                  startAdornment: exportKey ? undefined : (
                    <InputAdornment position="start">
                      <Typography variant="caption" color="text.secondary">auto</Typography>
                    </InputAdornment>
                  ),
                },
              }}
            />
            <TextField
              label="Formula"
              value={formula}
              onChange={(e) => setFormula(e.target.value)}
              required
              multiline
              minRows={2}
              maxRows={4}
              helperText="Reference primary stats by export key. E.g., (strength * 2) + (vitality * 5)"
              sx={{ '& .MuiInputBase-input': { fontFamily: 'monospace', fontSize: '0.85rem' } }}
            />
            <Stack direction="row" spacing={2}>
              <FormControl sx={{ minWidth: 140 }}>
                <InputLabel>Output Type</InputLabel>
                <Select
                  label="Output Type"
                  value={outputType}
                  onChange={(e) => setOutputType(e.target.value as 'integer' | 'float')}
                >
                  <MenuItem value="integer">Integer</MenuItem>
                  <MenuItem value="float">Float</MenuItem>
                </Select>
              </FormControl>
              <FormControl sx={{ minWidth: 140 }}>
                <InputLabel>Rounding</InputLabel>
                <Select
                  label="Rounding"
                  value={roundingMode}
                  onChange={(e) => setRoundingMode(e.target.value as 'floor' | 'round' | 'none')}
                >
                  <MenuItem value="floor">Floor</MenuItem>
                  <MenuItem value="round">Round</MenuItem>
                  <MenuItem value="none">None</MenuItem>
                </Select>
              </FormControl>
            </Stack>
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={handleClose} disabled={busy}>Cancel</Button>
          <Button onClick={() => void handleSave()} variant="contained" disabled={!canSave}>
            {editing ? 'Save' : 'Add'}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  )
}

// ─── Custom field definition dialog ──────────────────────────────────────────

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

// ─── Custom field definition list for a scope ───────────────────────────────

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

// ─── Custom fields scope selector ────────────────────────────────────────────

interface CustomFieldsSectionProps {
  itemCategories: MetaItemCategory[]
  npcTypes: MetaNpcType[]
}

function CustomFieldsSection({ itemCategories, npcTypes }: CustomFieldsSectionProps): React.JSX.Element {
  const [selectedScope, setSelectedScope] = useState<{
    type: CustomFieldScope
    id: string
    label: string
  } | null>(null)

  useEffect(() => {
    if (!selectedScope && itemCategories.length > 0) {
      setSelectedScope({ type: 'item_category', id: itemCategories[0].id, label: itemCategories[0].displayName })
    }
  }, [itemCategories, selectedScope])

  return (
    <Box>
      <Typography variant="subtitle2" sx={{ mb: 0.5 }}>Custom Fields</Typography>
      <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 2 }}>
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
    </Box>
  )
}

// ─── Project Settings Tab ────────────────────────────────────────────────────

export default function ProjectSettingsTab(): React.JSX.Element {
  const projectFilePath = useProjectStore((state) => state.activeProject?.filePath ?? null)

  const [projectSettings, setProjectSettings] = useState<ProjectSettings | null>(null)
  const [maxLevelStr, setMaxLevelStr] = useState('100')
  const [stats, setStats] = useState<MetaStat[]>([])
  const [rarities, setRarities] = useState<MetaRarity[]>([])
  const [craftingStations, setCraftingStations] = useState<MetaCraftingStation[]>([])
  const [craftingSpecializations, setCraftingSpecializations] = useState<MetaCraftingSpecialization[]>([])
  const [derivedStats, setDerivedStats] = useState<DerivedStatDefinition[]>([])
  const [itemCategories, setItemCategories] = useState<MetaItemCategory[]>([])
  const [npcTypes, setNpcTypes] = useState<MetaNpcType[]>([])

  useEffect(() => {
    if (!projectFilePath) return
    void Promise.all([
      metaApi.getProjectSettings(),
      metaApi.listStats(),
      metaApi.listRarities(),
      metaApi.listCraftingStations(),
      metaApi.listCraftingSpecializations(),
      metaApi.listDerivedStats(),
      metaApi.listItemCategories(),
      metaApi.listNpcTypes(),
    ]).then(([settings, s, r, cs, csp, ds, cats, types]) => {
      setProjectSettings(settings)
      setMaxLevelStr(String(settings.maxLevel))
      setStats(s)
      setRarities(r)
      setCraftingStations(cs)
      setCraftingSpecializations(csp)
      setDerivedStats(ds)
      setItemCategories(cats)
      setNpcTypes(types)
    })
  }, [projectFilePath])

  const refreshStats = (): void => { void metaApi.listStats().then(setStats) }
  const refreshRarities = (): void => { void metaApi.listRarities().then(setRarities) }
  const refreshCraftingStations = (): void => { void metaApi.listCraftingStations().then(setCraftingStations) }
  const refreshCraftingSpecializations = (): void => { void metaApi.listCraftingSpecializations().then(setCraftingSpecializations) }
  const refreshNpcTypes = (): void => { void metaApi.listNpcTypes().then(setNpcTypes) }
  const refreshDerivedStats = (): void => { void metaApi.listDerivedStats().then(setDerivedStats) }

  if (!projectSettings) {
    return <Typography color="text.secondary">Loading project settings...</Typography>
  }

  const handleMaxLevelBlur = (): void => {
    const value = Math.max(1, parseInt(maxLevelStr, 10) || 100)
    setMaxLevelStr(String(value))
    void metaApi.setProjectSettings({ maxLevel: value }).then(setProjectSettings)
  }

  const handleSeverityChange = (value: string): void => {
    void metaApi
      .setProjectSettings({ softDeleteReferenceSeverity: value as 'Warning' | 'Error' })
      .then(setProjectSettings)
  }

  return (
    <Stack spacing={4} sx={{ maxWidth: 900 }}>
      {/* ── General ────────────────────────────────────────────────────────────── */}
      <Box>
        <Typography variant="subtitle2" gutterBottom>Max Level</Typography>
        <Stack direction="row" alignItems="center" spacing={1}>
          <TextField
            type="number"
            size="small"
            value={maxLevelStr}
            onChange={(e) => setMaxLevelStr(e.target.value)}
            onBlur={handleMaxLevelBlur}
            onKeyDown={(e) => { if (e.key === 'Enter') (e.target as HTMLInputElement).blur() }}
            inputProps={{ min: 1, step: 1 }}
            sx={{ width: 100 }}
          />
        </Stack>
        <Typography variant="caption" color="text.secondary">
          The maximum character level for stat growth curves and derived stat calculations.
        </Typography>
      </Box>

      <Box>
        <Typography variant="subtitle2" gutterBottom>Soft-Delete Reference Severity</Typography>
        <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 1.5 }}>
          Controls how the validation engine treats references to soft-deleted (archived) records.
        </Typography>
        <FormControl>
          <RadioGroup
            value={projectSettings.softDeleteReferenceSeverity}
            onChange={(e) => handleSeverityChange(e.target.value)}
          >
            <FormControlLabel value="Warning" control={<Radio size="small" />} label="Warning" />
            <Typography variant="caption" color="text.secondary" sx={{ pl: 3.75, mt: -0.5, mb: 0.5 }}>
              Flag references to archived records, but allow export.
            </Typography>
            <FormControlLabel value="Error" control={<Radio size="small" />} label="Error" />
            <Typography variant="caption" color="text.secondary" sx={{ pl: 3.75, mt: -0.5 }}>
              Block export when references to archived records exist.
            </Typography>
          </RadioGroup>
        </FormControl>
      </Box>

      <Divider />

      {/* ── Stats ──────────────────────────────────────────────────────────────── */}
      <MetaListSection
        title="Primary Stats"
        singularName="Stat"
        description="Stats used in class growth curves and derived stat formulas."
        items={stats}
        onAdd={metaApi.addStat}
        onUpdate={metaApi.updateStat}
        onDelete={metaApi.deleteStat}
        onReorder={metaApi.reorderStats}
        onRefresh={refreshStats}
      />

      <Divider />

      {/* ── Rarities ───────────────────────────────────────────────────────────── */}
      <RaritySection rarities={rarities} onRefresh={refreshRarities} />

      <Divider />

      {/* ── Crafting Stations ──────────────────────────────────────────────────── */}
      <MetaListSection
        title="Crafting Stations"
        singularName="Crafting Station"
        description="Stations that recipes can require."
        items={craftingStations}
        onAdd={metaApi.addCraftingStation}
        onUpdate={metaApi.updateCraftingStation}
        onDelete={metaApi.deleteCraftingStation}
        onReorder={metaApi.reorderCraftingStations}
        onRefresh={refreshCraftingStations}
      />

      <Divider />

      {/* ── Crafting Specializations ───────────────────────────────────────────── */}
      <MetaListSection
        title="Crafting Specializations"
        singularName="Crafting Specialization"
        description="Specializations that recipes can require."
        items={craftingSpecializations}
        onAdd={metaApi.addCraftingSpecialization}
        onUpdate={metaApi.updateCraftingSpecialization}
        onDelete={metaApi.deleteCraftingSpecialization}
        onReorder={metaApi.reorderCraftingSpecializations}
        onRefresh={refreshCraftingSpecializations}
      />

      <Divider />

      {/* ── NPC Types ──────────────────────────────────────────────────────────── */}
      <MetaListSection
        title="NPC Types"
        singularName="NPC Type"
        description="Types used to categorize NPCs. Each NPC type can have its own custom fields."
        items={npcTypes}
        onAdd={metaApi.addNpcType}
        onUpdate={metaApi.updateNpcType}
        onDelete={metaApi.deleteNpcType}
        onReorder={metaApi.reorderNpcTypes}
        onRefresh={refreshNpcTypes}
      />

      <Divider />

      {/* ── Derived Stats ──────────────────────────────────────────────────────── */}
      <DerivedStatSection derivedStats={derivedStats} onRefresh={refreshDerivedStats} />

      <Divider />

      {/* ── Custom Fields ──────────────────────────────────────────────────────── */}
      <CustomFieldsSection itemCategories={itemCategories} npcTypes={npcTypes} />
    </Stack>
  )
}

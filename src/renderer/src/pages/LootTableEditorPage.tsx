import {
  Add as AddIcon,
  ArrowBack as BackIcon,
  ArrowDownward as MoveDownIcon,
  ArrowUpward as MoveUpIcon,
  Delete as DeleteIcon,
} from '@mui/icons-material'
import {
  Alert,
  Autocomplete,
  Box,
  Button,
  Divider,
  IconButton,
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
import { useCallback, useEffect, useMemo, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { itemsApi } from '../../api/items.api'
import { lootTablesApi } from '../../api/loot-tables.api'
import { npcsApi } from '../../api/npcs.api'
import type {
  CreateLootTableEntryInput,
  ItemRecord,
  LootTableEntry,
  LootTableRecord,
  NpcRecord,
} from '../../../shared/domain-types'

interface EntryDraft {
  itemId: string
  weight: number
  quantityMin: number
  quantityMax: number
  conditionalFlagsText: string
  sortOrder: number
}

function itemLabel(item: ItemRecord | null): string {
  if (!item) return ''
  return item.deletedAt ? `${item.displayName} (deleted)` : item.displayName
}

function flagsToText(flags: Record<string, unknown>): string {
  const text = flags.text
  if (typeof text === 'string') return text
  return Object.keys(flags).length > 0 ? JSON.stringify(flags) : ''
}

function flagsFromText(value: string): Record<string, unknown> {
  const trimmed = value.trim()
  return trimmed ? { text: trimmed } : {}
}

function toDraft(entry: LootTableEntry): EntryDraft {
  return {
    itemId: entry.itemId,
    weight: entry.weight,
    quantityMin: entry.quantityMin,
    quantityMax: entry.quantityMax,
    conditionalFlagsText: flagsToText(entry.conditionalFlags),
    sortOrder: entry.sortOrder,
  }
}

function formatPercent(value: number): string {
  return `${value.toFixed(value >= 10 ? 1 : 2)}%`
}

export default function LootTableEditorPage(): React.JSX.Element {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()

  const [record, setRecord] = useState<LootTableRecord | null>(null)
  const [items, setItems] = useState<ItemRecord[]>([])
  const [npcs, setNpcs] = useState<NpcRecord[]>([])
  const [displayName, setDisplayName] = useState('')
  const [exportKey, setExportKey] = useState('')
  const [description, setDescription] = useState('')
  const [entries, setEntries] = useState<EntryDraft[]>([])
  const [isDirty, setDirty] = useState(false)
  const [isSaving, setSaving] = useState(false)
  const [isLoading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [savedAt, setSavedAt] = useState<Date | null>(null)

  const itemById = useMemo(() => new Map(items.map((item) => [item.id, item])), [items])
  const activeItems = useMemo(() => items.filter((item) => !item.deletedAt), [items])
  const assignedNpcs = useMemo(
    () => npcs.filter((npc) => !npc.deletedAt && npc.lootTableId === id),
    [id, npcs],
  )
  const totalWeight = useMemo(
    () => entries.reduce((sum, entry) => sum + Math.max(1, Math.floor(entry.weight || 1)), 0),
    [entries],
  )
  const hasDeletedReferences = entries.some((entry) => itemById.get(entry.itemId)?.deletedAt)

  const load = useCallback(async () => {
    if (!id) return
    setLoading(true)
    setError(null)
    try {
      const [data, entryList, itemList, npcList] = await Promise.all([
        lootTablesApi.get(id),
        lootTablesApi.getEntries(id),
        itemsApi.list(true),
        npcsApi.list(),
      ])
      if (!data) {
        setError('Loot table not found.')
        return
      }
      setRecord(data)
      setDisplayName(data.displayName)
      setExportKey(data.exportKey)
      setDescription(data.description)
      setEntries(entryList.map(toDraft))
      setItems(itemList)
      setNpcs(npcList)
      setDirty(false)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to load loot table.')
    } finally {
      setLoading(false)
    }
  }, [id])

  useEffect(() => {
    void load()
  }, [load])

  const markDirty = (): void => {
    setDirty(true)
    setSavedAt(null)
  }

  const setEntryAt = (index: number, update: Partial<EntryDraft>): void => {
    setEntries((prev) => prev.map((entry, i) => (i === index ? { ...entry, ...update } : entry)))
    markDirty()
  }

  const moveEntry = (index: number, direction: -1 | 1): void => {
    const nextIndex = index + direction
    if (nextIndex < 0 || nextIndex >= entries.length) return
    setEntries((prev) => {
      const next = [...prev]
      const [entry] = next.splice(index, 1)
      next.splice(nextIndex, 0, entry)
      return next
    })
    markDirty()
  }

  const removeEntry = (index: number): void => {
    setEntries((prev) => prev.filter((_, i) => i !== index))
    markDirty()
  }

  const addEntry = (): void => {
    const itemId = activeItems[0]?.id
    if (!itemId) return
    setEntries((prev) => [
      ...prev,
      {
        itemId,
        weight: 1,
        quantityMin: 1,
        quantityMax: 1,
        conditionalFlagsText: '',
        sortOrder: prev.length,
      },
    ])
    markDirty()
  }

  const handleSave = async (): Promise<void> => {
    if (!id) return
    const normalizedEntries: CreateLootTableEntryInput[] = entries.map((entry, index) => {
      const quantityMin = Math.max(1, Math.floor(entry.quantityMin || 1))
      return {
        itemId: entry.itemId,
        weight: Math.max(1, Math.floor(entry.weight || 1)),
        quantityMin,
        quantityMax: Math.max(quantityMin, Math.floor(entry.quantityMax || quantityMin)),
        conditionalFlags: flagsFromText(entry.conditionalFlagsText),
        sortOrder: index,
      }
    })

    setSaving(true)
    setError(null)
    try {
      const updated = await lootTablesApi.update(id, {
        displayName: displayName.trim(),
        exportKey: exportKey.trim(),
        description: description.trim(),
      })
      const savedEntries = await lootTablesApi.setEntries(id, normalizedEntries)
      if (updated) {
        setRecord(updated)
        setEntries(savedEntries.map(toDraft))
        setDirty(false)
        setSavedAt(new Date())
      }
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to save loot table.')
    } finally {
      setSaving(false)
    }
  }

  if (isLoading) {
    return (
      <Box sx={{ p: 4 }}>
        <Typography color="text.secondary">Loading...</Typography>
      </Box>
    )
  }

  if (!record) {
    return (
      <Box sx={{ p: 4 }}>
        <Alert severity="error">{error ?? 'Loot table not found.'}</Alert>
        <Button sx={{ mt: 2 }} onClick={() => void navigate('/loot-tables')}>
          Back to Loot Tables
        </Button>
      </Box>
    )
  }

  return (
    <Box>
      <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1 }}>
        <Tooltip title="Back to Loot Tables">
          <IconButton size="small" onClick={() => void navigate('/loot-tables')}>
            <BackIcon fontSize="small" />
          </IconButton>
        </Tooltip>
        <Typography variant="caption" color="text.secondary">
          Loot Tables
        </Typography>
      </Stack>

      <Stack direction="row" alignItems="flex-start" justifyContent="space-between" sx={{ mb: 3 }} spacing={2}>
        <Box sx={{ flex: 1, minWidth: 0 }}>
          <TextField
            variant="standard"
            value={displayName}
            onChange={(e) => { setDisplayName(e.target.value); markDirty() }}
            inputProps={{ style: { fontSize: '1.5rem', fontWeight: 600 } }}
            placeholder="Loot Table Name"
            fullWidth
            sx={{ mb: 0.5 }}
          />
          <TextField
            variant="standard"
            value={exportKey}
            onChange={(e) => { setExportKey(e.target.value); markDirty() }}
            inputProps={{ style: { fontFamily: 'monospace', fontSize: '0.8rem' } }}
            placeholder="export-key"
            helperText="Export key - used in exported files"
            sx={{ maxWidth: 360 }}
          />
        </Box>
        <Stack direction="row" alignItems="center" spacing={2} sx={{ pt: 0.5 }}>
          {savedAt && <Typography variant="caption" color="success.main">Saved at {savedAt.toLocaleTimeString()}</Typography>}
          <Button variant="contained" onClick={() => void handleSave()} disabled={!isDirty || isSaving || !displayName.trim() || !exportKey.trim()}>
            Save
          </Button>
        </Stack>
      </Stack>

      {error && <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>{error}</Alert>}
      {hasDeletedReferences && <Alert severity="warning" sx={{ mb: 2 }}>This loot table references a soft-deleted item. Validation will flag this loot table.</Alert>}

      <Stack spacing={3}>
        <TextField label="Description" value={description} onChange={(e) => { setDescription(e.target.value); markDirty() }} multiline minRows={3} fullWidth sx={{ maxWidth: 760 }} />

        <Divider />

        <Stack spacing={2}>
          <Stack direction="row" justifyContent="space-between" alignItems="center">
            <Box>
              <Typography variant="subtitle1">Entries</Typography>
              <Typography variant="caption" color="text.secondary">Drop percentages are calculated from the current weights.</Typography>
            </Box>
            <Button startIcon={<AddIcon />} variant="outlined" size="small" onClick={addEntry} disabled={activeItems.length === 0}>
              Add Entry
            </Button>
          </Stack>
          {activeItems.length === 0 && <Alert severity="info">Create an active item before adding loot entries.</Alert>}
          {entries.length === 0 ? (
            <Typography variant="body2" color="text.secondary">No entries yet.</Typography>
          ) : (
            <Table size="small">
              <TableHead>
                <TableRow>
                  <TableCell>Item</TableCell>
                  <TableCell width={110}>Weight</TableCell>
                  <TableCell width={120}>Drop</TableCell>
                  <TableCell width={120}>Min Qty</TableCell>
                  <TableCell width={120}>Max Qty</TableCell>
                  <TableCell>Conditional Flags</TableCell>
                  <TableCell width={140} align="right">Actions</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {entries.map((entry, index) => {
                  const item = itemById.get(entry.itemId) ?? null
                  const isDeleted = Boolean(item?.deletedAt)
                  const weight = Math.max(1, Math.floor(entry.weight || 1))
                  const percent = totalWeight > 0 ? (weight / totalWeight) * 100 : 0
                  return (
                    <TableRow key={`${entry.itemId}:${index}`}>
                      <TableCell>
                        <Autocomplete
                          options={activeItems}
                          value={item}
                          getOptionLabel={itemLabel}
                          isOptionEqualToValue={(option, value) => option.id === value.id}
                          onChange={(_, selectedItem) => {
                            if (!selectedItem) return
                            setEntryAt(index, { itemId: selectedItem.id })
                          }}
                          renderInput={(params) => (
                            <TextField {...params} label="Item" size="small" error={isDeleted} helperText={isDeleted ? 'Soft-deleted item reference' : undefined} />
                          )}
                        />
                        {isDeleted && <Typography variant="caption" color="warning.main" sx={{ textDecoration: 'line-through' }}>{item?.displayName}</Typography>}
                      </TableCell>
                      <TableCell>
                        <TextField
                          type="number"
                          size="small"
                          value={entry.weight}
                          onChange={(e) => setEntryAt(index, { weight: Math.max(1, parseInt(e.target.value, 10) || 1) })}
                          inputProps={{ min: 1, step: 1 }}
                          fullWidth
                        />
                      </TableCell>
                      <TableCell>
                        <Typography variant="body2" color="text.secondary">{formatPercent(percent)}</Typography>
                      </TableCell>
                      <TableCell>
                        <TextField
                          type="number"
                          size="small"
                          value={entry.quantityMin}
                          onChange={(e) => setEntryAt(index, { quantityMin: Math.max(1, parseInt(e.target.value, 10) || 1) })}
                          inputProps={{ min: 1, step: 1 }}
                          fullWidth
                        />
                      </TableCell>
                      <TableCell>
                        <TextField
                          type="number"
                          size="small"
                          value={entry.quantityMax}
                          onChange={(e) => setEntryAt(index, { quantityMax: Math.max(1, parseInt(e.target.value, 10) || 1) })}
                          inputProps={{ min: 1, step: 1 }}
                          fullWidth
                        />
                      </TableCell>
                      <TableCell>
                        <TextField
                          size="small"
                          value={entry.conditionalFlagsText}
                          onChange={(e) => setEntryAt(index, { conditionalFlagsText: e.target.value })}
                          placeholder="Optional"
                          fullWidth
                        />
                      </TableCell>
                      <TableCell align="right">
                        <Tooltip title="Move up"><span><IconButton size="small" onClick={() => moveEntry(index, -1)} disabled={index === 0}><MoveUpIcon fontSize="small" /></IconButton></span></Tooltip>
                        <Tooltip title="Move down"><span><IconButton size="small" onClick={() => moveEntry(index, 1)} disabled={index === entries.length - 1}><MoveDownIcon fontSize="small" /></IconButton></span></Tooltip>
                        <Tooltip title="Remove"><IconButton size="small" color="error" onClick={() => removeEntry(index)}><DeleteIcon fontSize="small" /></IconButton></Tooltip>
                      </TableCell>
                    </TableRow>
                  )
                })}
              </TableBody>
            </Table>
          )}
        </Stack>

        <Divider />

        <Stack spacing={1}>
          <Typography variant="subtitle1">Assigned To</Typography>
          {assignedNpcs.length === 0 ? (
            <Typography variant="body2" color="text.secondary">No NPCs currently use this loot table.</Typography>
          ) : (
            <Stack spacing={0.5}>
              {assignedNpcs.map((npc) => (
                <Typography key={npc.id} variant="body2">{npc.displayName}</Typography>
              ))}
            </Stack>
          )}
        </Stack>
      </Stack>
    </Box>
  )
}

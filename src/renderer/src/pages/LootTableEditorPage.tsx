import {
  Add as AddIcon,
  ArrowDownward as MoveDownIcon,
  ArrowUpward as MoveUpIcon,
  Delete as DeleteIcon,
} from '@mui/icons-material'
import {
  Alert,
  Autocomplete,
  Box,
  Button,
  Chip,
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
import { useUndoRedo } from '../hooks/useUndoRedo'
import { useNavigate, useParams } from 'react-router-dom'
import { itemsApi } from '../../api/items.api'
import { lootTablesApi } from '../../api/loot-tables.api'
import { metaApi } from '../../api/meta.api'
import EditHeader from '../components/EditHeader'
import InspectorRail from '../components/InspectorRail'
import type { UsedBySection } from '../components/InspectorRail'
import SaveBar from '../components/SaveBar'
import ValidationBanner from '../components/ValidationBanner'
import { useRecordValidation } from '../hooks/useRecordValidation'
import type {
  CreateLootTableEntryInput,
  ItemRecord,
  LootTableEntry,
  LootTableRecord,
  LootTableUsedBy,
  MetaRarity,
} from '../../../shared/domain-types'

interface FormSnapshot {
  displayName: string
  exportKey: string
  description: string
  entries: EntryDraft[]
}

interface EntryDraft {
  itemId: string
  weight: number
  quantityMin: number
  quantityMax: number
  sortOrder: number
}

function itemLabel(item: ItemRecord | null): string {
  if (!item) return ''
  return item.deletedAt ? `${item.displayName} (deleted)` : item.displayName
}

function toDraft(entry: LootTableEntry): EntryDraft {
  return {
    itemId: entry.itemId,
    weight: entry.weight,
    quantityMin: entry.quantityMin,
    quantityMax: entry.quantityMax,
    sortOrder: entry.sortOrder,
  }
}

function formatPercent(value: number): string {
  return `${value.toFixed(value >= 10 ? 1 : 2)}%`
}

interface LootTableEditorPageProps {
  recordId?: string
  onClose?: () => void
}

export default function LootTableEditorPage({ recordId, onClose }: LootTableEditorPageProps = {}): React.JSX.Element {
  const { id: paramId } = useParams<{ id: string }>()
  const id = recordId ?? paramId
  const navigate = useNavigate()
  const goBack = onClose ?? (() => void navigate('/loot-tables'))

  const [record, setRecord] = useState<LootTableRecord | null>(null)
  const [items, setItems] = useState<ItemRecord[]>([])
  const [rarities, setRarities] = useState<MetaRarity[]>([])
  const [displayName, setDisplayName] = useState('')
  const [exportKey, setExportKey] = useState('')
  const [description, setDescription] = useState('')
  const [entries, setEntries] = useState<EntryDraft[]>([])
  const [isDirty, setDirty] = useState(false)
  const [isSaving, setSaving] = useState(false)
  const [isLoading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [savedAt, setSavedAt] = useState<Date | null>(null)
  const [usedBy, setUsedBy] = useState<LootTableUsedBy | null>(null)
  const [usedByLoading, setUsedByLoading] = useState(false)
  const { recordIssues, runValidation } = useRecordValidation('loot-tables', id)

  const applySnapshot = useCallback((snapshot: FormSnapshot) => {
    setDisplayName(snapshot.displayName)
    setExportKey(snapshot.exportKey)
    setDescription(snapshot.description)
    setEntries(snapshot.entries)
    setDirty(true)
    setSavedAt(null)
  }, [])

  const undoRedo = useUndoRedo<FormSnapshot>(applySnapshot)

  const pushSnapshot = (overrides: Partial<FormSnapshot> = {}): void => {
    setDirty(true)
    setSavedAt(null)
    undoRedo.pushState({ displayName, exportKey, description, entries, ...overrides })
  }

  const itemById = useMemo(() => new Map(items.map((item) => [item.id, item])), [items])
  const rarityById = useMemo(() => new Map(rarities.map((rarity) => [rarity.id, rarity])), [rarities])
  const activeItems = useMemo(() => items.filter((item) => !item.deletedAt), [items])
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
      const [data, entryList, itemList, rarityList] = await Promise.all([
        lootTablesApi.get(id),
        lootTablesApi.getEntries(id),
        itemsApi.list(true),
        metaApi.listRarities(),
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
      setRarities(rarityList)
      setDirty(false)
      undoRedo.reset({
        displayName: data.displayName,
        exportKey: data.exportKey,
        description: data.description,
        entries: entryList.map(toDraft),
      })
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to load loot table.')
    } finally {
      setLoading(false)
    }
  }, [id])

  useEffect(() => {
    void load()
  }, [load])

  // Load "Used By" data eagerly for InspectorRail
  useEffect(() => {
    if (!id) return
    setUsedByLoading(true)
    lootTablesApi
      .getUsedBy(id)
      .then((result) => setUsedBy(result))
      .catch((cause) =>
        setError(cause instanceof Error ? cause.message : 'Failed to load Used By data.'),
      )
      .finally(() => setUsedByLoading(false))
  }, [id])

  const setEntryAt = (index: number, update: Partial<EntryDraft>): void => {
    const nextEntries = entries.map((entry, i) => (i === index ? { ...entry, ...update } : entry))
    setEntries(nextEntries)
    pushSnapshot({ entries: nextEntries })
  }

  const moveEntry = (index: number, direction: -1 | 1): void => {
    const nextIndex = index + direction
    if (nextIndex < 0 || nextIndex >= entries.length) return
    const next = [...entries]
    const [entry] = next.splice(index, 1)
    next.splice(nextIndex, 0, entry)
    setEntries(next)
    pushSnapshot({ entries: next })
  }

  const removeEntry = (index: number): void => {
    const nextEntries = entries.filter((_, i) => i !== index)
    setEntries(nextEntries)
    pushSnapshot({ entries: nextEntries })
  }

  const addEntry = (): void => {
    const itemId = activeItems[0]?.id
    if (!itemId) return
    const nextEntries = [
      ...entries,
      {
        itemId,
        weight: 1,
        quantityMin: 1,
        quantityMax: 1,
        sortOrder: entries.length,
      },
    ]
    setEntries(nextEntries)
    pushSnapshot({ entries: nextEntries })
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
        await runValidation()
      }
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to save loot table.')
    } finally {
      setSaving(false)
    }
  }

  const renderRarityChip = (rarity: MetaRarity | undefined): React.JSX.Element => (
    rarity ? (
      <Tooltip title={rarity.displayName}>
        <Chip
          label={rarity.displayName.slice(0, 1).toUpperCase()}
          size="small"
          variant="outlined"
          sx={{
            borderColor: rarity.colorHex,
            color: rarity.colorHex,
            minWidth: 32,
            fontWeight: 700,
          }}
        />
      </Tooltip>
    ) : (
      <Chip label="?" size="small" variant="outlined" sx={{ minWidth: 32 }} />
    )
  )

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
        <Button sx={{ mt: 2 }} onClick={goBack}>
          Back to Loot Tables
        </Button>
      </Box>
    )
  }

  const handleBack = goBack
  const handleDiscard = (): void => void load()

  const usedBySections: UsedBySection[] = useMemo(() => {
    if (!usedBy) return []
    const sections: UsedBySection[] = []
    if (usedBy.npcs.length > 0) {
      sections.push({
        label: 'NPCs',
        items: usedBy.npcs.map((n) => ({ id: n.id, displayName: n.displayName, route: `/npcs/${n.id}` })),
      })
    }
    return sections
  }, [usedBy])

  return (
    <Box>
      <EditHeader
        backLabel="Loot Tables"
        onBack={handleBack}
        displayName={displayName}
        onDisplayNameChange={(value) => {
          setDisplayName(value)
          pushSnapshot({ displayName: value })
        }}
        exportKey={exportKey}
        isDirty={isDirty}
        isSaving={isSaving}
        onSave={() => void handleSave()}
        savedAt={savedAt}
        canUndo={undoRedo.canUndo}
        canRedo={undoRedo.canRedo}
        onUndo={undoRedo.triggerUndo}
        onRedo={undoRedo.triggerRedo}
      />

      {error && <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>{error}</Alert>}
      <ValidationBanner issues={recordIssues} />
      {hasDeletedReferences && <Alert severity="warning" sx={{ mb: 2 }}>This loot table references a soft-deleted item. Validation will flag this loot table.</Alert>}

      <Box sx={{ display: 'flex' }}>
        <Box sx={{ flex: 1, overflow: 'auto' }}>
          <Stack spacing={3}>
            <TextField
              label="Export Key"
              value={exportKey}
              onChange={(e) => {
                setExportKey(e.target.value)
                pushSnapshot({ exportKey: e.target.value })
              }}
              inputProps={{ style: { fontFamily: '"JetBrains Mono", monospace', fontSize: '0.85rem' } }}
              placeholder="export-key"
              helperText="Export key — used in exported files"
              sx={{ maxWidth: 360 }}
            />
            <TextField label="Description" value={description} onChange={(e) => { setDescription(e.target.value); pushSnapshot({ description: e.target.value }) }} multiline minRows={3} fullWidth sx={{ maxWidth: 760 }} />

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
                <Box sx={{ overflowX: 'auto', pb: 1 }}>
                  <Table size="small" sx={{ minWidth: 980 }}>
                    <TableHead>
                      <TableRow>
                        <TableCell width={460}>Item</TableCell>
                        <TableCell width={110}>Weight</TableCell>
                        <TableCell width={120}>Drop</TableCell>
                        <TableCell width={120}>Min Qty</TableCell>
                        <TableCell width={120}>Max Qty</TableCell>
                        <TableCell width={140} align="right">Actions</TableCell>
                      </TableRow>
                    </TableHead>
                  <TableBody>
                    {entries.map((entry, index) => {
                      const item = itemById.get(entry.itemId) ?? null
                      const isDeleted = Boolean(item?.deletedAt)
                      const rarity = item ? rarityById.get(item.rarityId) : undefined
                      const weight = Math.max(1, Math.floor(entry.weight || 1))
                      const percent = totalWeight > 0 ? (weight / totalWeight) * 100 : 0
                      return (
                        <TableRow key={`${entry.itemId}:${index}`}>
                          <TableCell>
                            <Stack direction="row" spacing={1} alignItems="flex-start" sx={{ minWidth: 420 }}>
                              <Box sx={{ pt: 0.75, width: 40, flex: '0 0 auto' }}>
                                {renderRarityChip(rarity)}
                              </Box>
                              <Autocomplete
                                options={activeItems}
                                value={item}
                                getOptionLabel={itemLabel}
                                isOptionEqualToValue={(option, value) => option.id === value.id}
                                onChange={(_, selectedItem) => {
                                  if (!selectedItem) return
                                  setEntryAt(index, { itemId: selectedItem.id })
                                }}
                                renderOption={(props, option) => {
                                  const optionRarity = rarityById.get(option.rarityId)
                                  return (
                                    <Box component="li" {...props}>
                                      <Stack direction="row" spacing={1} alignItems="center" sx={{ width: '100%' }}>
                                        {renderRarityChip(optionRarity)}
                                        <Box sx={{ minWidth: 0 }}>
                                          <Typography variant="body2">{option.displayName}</Typography>
                                          <Typography variant="caption" color="text.secondary">
                                            {optionRarity?.displayName ?? option.rarityId}
                                          </Typography>
                                        </Box>
                                      </Stack>
                                    </Box>
                                  )
                                }}
                                renderInput={(params) => (
                                  <TextField {...params} label="Item" size="small" error={isDeleted} helperText={isDeleted ? 'Soft-deleted item reference' : undefined} />
                                )}
                                sx={{ flex: 1, minWidth: 360 }}
                              />
                            </Stack>
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
                </Box>
              )}
            </Stack>
          </Stack>
        </Box>

        <InspectorRail sections={usedBySections} isLoading={usedByLoading} />
      </Box>

      <SaveBar
        isDirty={isDirty}
        isSaving={isSaving}
        onSave={() => void handleSave()}
        onDiscard={handleDiscard}
      />
    </Box>
  )
}

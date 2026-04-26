import {
  Add as AddIcon,
  ContentCopy as DuplicateIcon,
  Delete as DeleteIcon,
  Edit as EditIcon,
} from '@mui/icons-material'
import {
  Alert,
  Box,
  Button,
  Checkbox,
  Dialog,
  DialogActions,
  DialogContent,
  DialogContentText,
  DialogTitle,
  FormControl,
  IconButton,
  InputAdornment,
  InputLabel,
  MenuItem,
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
import { useCallback, useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { lifecycleApi } from '../../api/lifecycle.api'
import { lootTablesApi } from '../../api/loot-tables.api'
import { npcsApi } from '../../api/npcs.api'
import type { LootTableEntry, LootTableRecord, NpcRecord } from '../../../shared/domain-types'
import { ArchiveToggle, ArchiveTable, type ViewMode } from '../components/ArchiveView'
import { BulkActionToolbar, BulkDeleteDialog } from '../components/BulkActions'
import EditorModal from '../components/EditorModal'
import { useMultiSelect } from '../hooks/useMultiSelect'
import { useUiStore } from '../stores/ui.store'
import LootTableEditorPage from './LootTableEditorPage'

function slugify(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '')
}

interface CreateDialogProps {
  open: boolean
  onClose: () => void
  onCreated: (record: LootTableRecord) => void
}

function CreateDialog({ open, onClose, onCreated }: CreateDialogProps): React.JSX.Element {
  const [displayName, setDisplayName] = useState('')
  const [exportKey, setExportKey] = useState('')
  const [exportKeyTouched, setExportKeyTouched] = useState(false)
  const [isBusy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    setDisplayName('')
    setExportKey('')
    setExportKeyTouched(false)
    setError(null)
  }, [open])

  const handleDisplayNameChange = (value: string): void => {
    setDisplayName(value)
    if (!exportKeyTouched) setExportKey(slugify(value))
  }

  const handleCreate = async (): Promise<void> => {
    if (!displayName.trim()) return
    setBusy(true)
    setError(null)
    try {
      const record = await lootTablesApi.create({
        displayName: displayName.trim(),
        exportKey: exportKey.trim() || slugify(displayName.trim()),
      })
      onCreated(record)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to create loot table.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <Dialog open={open} onClose={onClose} fullWidth maxWidth="sm">
      <DialogTitle>New Loot Table</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ pt: 1 }}>
          {error && <Alert severity="error">{error}</Alert>}
          <TextField label="Display Name" value={displayName} onChange={(e) => handleDisplayNameChange(e.target.value)} required autoFocus fullWidth />
          <TextField
            label="Export Key"
            value={exportKey}
            onChange={(e) => { setExportKey(e.target.value); setExportKeyTouched(true) }}
            fullWidth
            helperText="Used in exported files. Auto-generated from the display name."
            InputProps={{
              startAdornment: exportKey ? undefined : (
                <InputAdornment position="start"><Typography variant="caption" color="text.disabled">auto</Typography></InputAdornment>
              ),
            }}
          />
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} disabled={isBusy}>Cancel</Button>
        <Button variant="contained" onClick={() => void handleCreate()} disabled={!displayName.trim() || isBusy}>Create Loot Table</Button>
      </DialogActions>
    </Dialog>
  )
}

interface DeleteDialogProps {
  record: LootTableRecord | null
  onClose: () => void
  onDeleted: (id: string) => void
}

function DeleteDialog({ record, onClose, onDeleted }: DeleteDialogProps): React.JSX.Element {
  const [isBusy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!record) setError(null)
  }, [record])

  const handleDelete = async (): Promise<void> => {
    if (!record) return
    setBusy(true)
    setError(null)
    try {
      await lootTablesApi.delete(record.id)
      onDeleted(record.id)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to delete loot table.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <Dialog open={Boolean(record)} onClose={onClose}>
      <DialogTitle>Delete Loot Table?</DialogTitle>
      <DialogContent>
        {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
        <DialogContentText>
          <strong>{record?.displayName}</strong> will be moved to the archive. NPCs that reference it will be flagged by validation.
        </DialogContentText>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} disabled={isBusy}>Cancel</Button>
        <Button color="error" variant="contained" onClick={() => void handleDelete()} disabled={isBusy}>Delete</Button>
      </DialogActions>
    </Dialog>
  )
}

export default function LootTablesPage(): React.JSX.Element {
  const navigate = useNavigate()
  const editingMode = useUiStore((s) => s.editingMode)
  const [lootTables, setLootTables] = useState<LootTableRecord[]>([])
  const [archivedLootTables, setArchivedLootTables] = useState<LootTableRecord[]>([])
  const [viewMode, setViewMode] = useState<ViewMode>('active')
  const [entriesByTableId, setEntriesByTableId] = useState<Map<string, LootTableEntry[]>>(new Map())
  const [npcs, setNpcs] = useState<NpcRecord[]>([])
  const [search, setSearch] = useState('')
  const [sortBy, setSortBy] = useState<'name' | 'updated'>('name')
  const [createOpen, setCreateOpen] = useState(false)
  const [deleteTarget, setDeleteTarget] = useState<LootTableRecord | null>(null)
  const [bulkDeleteOpen, setBulkDeleteOpen] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [modalRecordId, setModalRecordId] = useState<string | null>(null)
  const multiSelect = useMultiSelect()

  const openEditor = (id: string): void => {
    if (editingMode === 'modal') setModalRecordId(id)
    else void navigate(`/loot-tables/${id}`)
  }

  const assignmentCounts = useMemo(() => {
    const counts = new Map<string, number>()
    for (const npc of npcs) {
      if (!npc.deletedAt && npc.lootTableId) counts.set(npc.lootTableId, (counts.get(npc.lootTableId) ?? 0) + 1)
    }
    return counts
  }, [npcs])

  const load = useCallback(async () => {
    setError(null)
    try {
      const [records, npcList] = await Promise.all([
        lootTablesApi.list(),
        npcsApi.list(),
      ])
      const entryPairs = await Promise.all(records.map(async (record) => [record.id, await lootTablesApi.getEntries(record.id)] as const))
      setLootTables(records)
      setNpcs(npcList)
      setEntriesByTableId(new Map(entryPairs))
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to load loot tables.')
    }
  }, [])

  const loadArchived = useCallback(async () => {
    try {
      const records = await lootTablesApi.list(false, true)
      setArchivedLootTables(records)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to load archived loot tables.')
    }
  }, [])

  useEffect(() => {
    multiSelect.clear()
    if (viewMode === 'active') void load()
    else void loadArchived()
  }, [load, loadArchived, viewMode])

  const handleCreated = (record: LootTableRecord): void => {
    setCreateOpen(false)
    openEditor(record.id)
  }

  const handleDeleted = (id: string): void => {
    setDeleteTarget(null)
    setLootTables((prev) => prev.filter((table) => table.id !== id))
  }

  const handleArchiveRestore = async (id: string): Promise<void> => {
    await lootTablesApi.restore(id)
    setArchivedLootTables((prev) => prev.filter((r) => r.id !== id))
  }

  const handleArchiveHardDelete = async (id: string): Promise<void> => {
    await lootTablesApi.hardDelete(id)
    setArchivedLootTables((prev) => prev.filter((r) => r.id !== id))
  }

  const handleArchiveBulkRestore = async (ids: string[]): Promise<void> => {
    await lifecycleApi.bulkRestore('loot-tables', ids)
    void loadArchived()
  }

  const handleArchiveBulkHardDelete = async (ids: string[]): Promise<void> => {
    await lifecycleApi.bulkHardDelete('loot-tables', ids)
    void loadArchived()
  }

  const handleDuplicate = async (record: LootTableRecord): Promise<void> => {
    setError(null)
    try {
      const copy = await lootTablesApi.duplicate(record.id)
      if (!copy) return
      const entries = await lootTablesApi.getEntries(copy.id)
      setLootTables((prev) => [...prev, copy])
      setEntriesByTableId((prev) => new Map(prev).set(copy.id, entries))
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to duplicate loot table.')
    }
  }

  const handleBulkDelete = async (): Promise<void> => {
    setError(null)
    try {
      await lifecycleApi.bulkSoftDelete('loot-tables', [...multiSelect.selected])
      setBulkDeleteOpen(false)
      multiSelect.clear()
      void load()
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Bulk delete failed.')
    }
  }

  const filtered = lootTables
    .filter((table) => table.displayName.toLowerCase().includes(search.toLowerCase()))
    .sort((a, b) => {
      if (sortBy === 'updated') return b.updatedAt.localeCompare(a.updatedAt)
      return a.displayName.localeCompare(b.displayName, undefined, { sensitivity: 'base' })
    })

  const filteredIds = filtered.map((table) => table.id)

  return (
    <Box>
      <Stack direction="row" alignItems="center" justifyContent="space-between" sx={{ mb: 3 }}>
        <Typography variant="h5">Loot Tables</Typography>
        <Stack direction="row" spacing={2} alignItems="center">
          <ArchiveToggle value={viewMode} onChange={setViewMode} />
          {viewMode === 'active' && (
            <Button startIcon={<AddIcon />} variant="contained" onClick={() => setCreateOpen(true)}>New Loot Table</Button>
          )}
        </Stack>
      </Stack>

      {error && <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>{error}</Alert>}

      {viewMode === 'archived' ? (
        <ArchiveTable
          records={archivedLootTables}
          domainLabel="Loot Table"
          emptyMessage="No archived loot tables."
          error={error}
          onClearError={() => setError(null)}
          onRestore={handleArchiveRestore}
          onHardDelete={handleArchiveHardDelete}
          onBulkRestore={handleArchiveBulkRestore}
          onBulkHardDelete={handleArchiveBulkHardDelete}
        />
      ) : (
        <>
      <Stack direction="row" spacing={2} sx={{ mb: 2 }} flexWrap="wrap" useFlexGap>
        <TextField size="small" placeholder="Search loot tables..." value={search} onChange={(e) => setSearch(e.target.value)} sx={{ flex: 1, minWidth: 220, maxWidth: 360 }} />
        <FormControl size="small" sx={{ minWidth: 180 }}>
          <InputLabel id="loot-table-sort-label">Sort</InputLabel>
          <Select labelId="loot-table-sort-label" label="Sort" value={sortBy} onChange={(e) => setSortBy(e.target.value as 'name' | 'updated')}>
            <MenuItem value="name">Name</MenuItem>
            <MenuItem value="updated">Last Modified</MenuItem>
          </Select>
        </FormControl>
      </Stack>

      <BulkActionToolbar
        count={multiSelect.count}
        mode="active"
        onBulkDelete={() => setBulkDeleteOpen(true)}
      />

      {filtered.length === 0 ? (
        <Typography variant="body2" color="text.secondary">
          {lootTables.length === 0 ? 'No loot tables yet. Click "New Loot Table" to create one.' : 'No loot tables match your search.'}
        </Typography>
      ) : (
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell padding="checkbox">
                <Checkbox
                  size="small"
                  checked={multiSelect.isAllSelected(filteredIds)}
                  indeterminate={multiSelect.count > 0 && !multiSelect.isAllSelected(filteredIds)}
                  onChange={() => multiSelect.toggleAll(filteredIds)}
                />
              </TableCell>
              <TableCell>Name</TableCell>
              <TableCell>Export Key</TableCell>
              <TableCell>Entries</TableCell>
              <TableCell>Assigned</TableCell>
              <TableCell>Last Modified</TableCell>
              <TableCell align="right">Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {filtered.map((table) => (
              <TableRow key={table.id} hover sx={{ cursor: 'pointer' }} onClick={() => openEditor(table.id)}>
                <TableCell padding="checkbox" onClick={(e) => e.stopPropagation()}>
                  <Checkbox
                    size="small"
                    checked={multiSelect.isSelected(table.id)}
                    onChange={() => multiSelect.toggle(table.id)}
                  />
                </TableCell>
                <TableCell><Typography variant="body2" fontWeight={500}>{table.displayName}</Typography></TableCell>
                <TableCell><Typography variant="body2" color="text.secondary" fontFamily="monospace">{table.exportKey}</Typography></TableCell>
                <TableCell><Typography variant="body2" color="text.secondary">{entriesByTableId.get(table.id)?.length ?? 0}</Typography></TableCell>
                <TableCell><Typography variant="body2" color="text.secondary">Used by {assignmentCounts.get(table.id) ?? 0} NPCs</Typography></TableCell>
                <TableCell><Typography variant="body2" color="text.secondary">{new Date(table.updatedAt).toLocaleString()}</Typography></TableCell>
                <TableCell align="right" onClick={(e) => e.stopPropagation()}>
                  <Tooltip title="Edit"><IconButton size="small" onClick={() => openEditor(table.id)}><EditIcon fontSize="small" /></IconButton></Tooltip>
                  <Tooltip title="Duplicate"><IconButton size="small" onClick={() => void handleDuplicate(table)}><DuplicateIcon fontSize="small" /></IconButton></Tooltip>
                  <Tooltip title="Delete"><IconButton size="small" color="error" onClick={() => setDeleteTarget(table)}><DeleteIcon fontSize="small" /></IconButton></Tooltip>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}
        </>
      )}

      <CreateDialog open={createOpen} onClose={() => setCreateOpen(false)} onCreated={handleCreated} />
      <DeleteDialog record={deleteTarget} onClose={() => setDeleteTarget(null)} onDeleted={handleDeleted} />

      <BulkDeleteDialog
        open={bulkDeleteOpen}
        domain="loot-tables"
        ids={[...multiSelect.selected]}
        onClose={() => setBulkDeleteOpen(false)}
        onConfirm={() => void handleBulkDelete()}
      />

      <EditorModal
        open={modalRecordId !== null}
        title="Edit Loot Table"
        onClose={() => { setModalRecordId(null); void load() }}
      >
        {modalRecordId && (
          <LootTableEditorPage
            recordId={modalRecordId}
            onClose={() => { setModalRecordId(null); void load() }}
          />
        )}
      </EditorModal>
    </Box>
  )
}

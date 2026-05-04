import {
  Casino as LootTablesIcon,
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
  IconButton,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  Tooltip,
  Typography,
} from '@mui/material'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { lifecycleApi } from '../../api/lifecycle.api'
import { lootTablesApi } from '../../api/loot-tables.api'
import { npcsApi } from '../../api/npcs.api'
import type { LootTableEntry, LootTableRecord, NpcRecord } from '../../../shared/domain-types'
import { ArchiveTable, type ViewMode } from '../components/ArchiveView'
import { BulkActionToolbar, BulkDeleteDialog } from '../components/BulkActions'
import { CreateLootTableDialog } from '../components/create-dialogs'
import EditorModal from '../components/EditorModal'
import DeferredLoader from '../components/DeferredLoader'
import EmptyState from '../components/EmptyState'
import ListToolbar from '../components/ListToolbar'
import PageHeader from '../components/PageHeader'
import { useMultiSelect } from '../hooks/useMultiSelect'
import { useUiStore } from '../stores/ui.store'
import LootTableEditorPage from './LootTableEditorPage'

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
        <Button data-tid="dialog-delete-confirm" color="error" variant="contained" onClick={() => void handleDelete()} disabled={isBusy}>Delete</Button>
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
  const [isLoading, setLoading] = useState(true)
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
    setLoading(true)
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
    } finally {
      setLoading(false)
    }
  }, [])

  const loadArchived = useCallback(async () => {
    setLoading(true)
    try {
      const records = await lootTablesApi.list(false, true)
      setArchivedLootTables(records)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to load archived loot tables.')
    } finally {
      setLoading(false)
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
      <PageHeader title="Loot Tables" />
      <ListToolbar
        search={search}
        onSearchChange={setSearch}
        sortKey={sortBy}
        onSortChange={(v) => setSortBy(v as 'name' | 'updated')}
        sortOptions={[
          { value: 'name', label: 'Name' },
          { value: 'updated', label: 'Last Modified' },
        ]}
        viewMode={viewMode}
        onViewModeChange={setViewMode}
        onNew={() => setCreateOpen(true)}
        newLabel="+ New Loot Table"
      />

      {error && <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>{error}</Alert>}

      {isLoading ? (
        <DeferredLoader />
      ) : viewMode === 'archived' ? (
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
      <BulkActionToolbar
        count={multiSelect.count}
        mode="active"
        onBulkDelete={() => setBulkDeleteOpen(true)}
      />

      <Paper variant="outlined" sx={{ borderRadius: 2.5 }}>
        {filtered.length === 0 ? (
          lootTables.length === 0 ? (
            <EmptyState
              icon={<LootTablesIcon sx={{ fontSize: 'inherit' }} />}
              title="No loot tables yet"
              body="Create your first loot table to get started."
              ctaLabel="+ Create First Loot Table"
              onCtaClick={() => setCreateOpen(true)}
            />
          ) : (
            <EmptyState title="No results match your search" />
          )
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
                    <Tooltip title="Duplicate"><IconButton data-tid="list-row-duplicate" size="small" onClick={() => void handleDuplicate(table)}><DuplicateIcon fontSize="small" /></IconButton></Tooltip>
                    <Tooltip title="Delete"><IconButton data-tid="list-row-delete" size="small" color="error" onClick={() => setDeleteTarget(table)}><DeleteIcon fontSize="small" /></IconButton></Tooltip>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        )}
      </Paper>
        </>
      )}

      <CreateLootTableDialog open={createOpen} onClose={() => setCreateOpen(false)} onCreated={handleCreated} />
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

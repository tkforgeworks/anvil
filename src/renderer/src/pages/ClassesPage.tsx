import {
  ContentCopy as DuplicateIcon,
  Delete as DeleteIcon,
  Edit as EditIcon,
  People as ClassesIcon,
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
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  Tooltip,
  Typography,
} from '@mui/material'
import { useCallback, useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { classesApi } from '../../api/classes.api'
import { lifecycleApi } from '../../api/lifecycle.api'
import type { ClassRecord } from '../../../shared/domain-types'
import { ArchiveTable, type ViewMode } from '../components/ArchiveView'
import { BulkActionToolbar, BulkDeleteDialog } from '../components/BulkActions'
import { CreateClassDialog } from '../components/create-dialogs'
import EditorModal from '../components/EditorModal'
import EmptyState from '../components/EmptyState'
import ListToolbar from '../components/ListToolbar'
import { useMultiSelect } from '../hooks/useMultiSelect'
import { useUiStore } from '../stores/ui.store'
import ClassEditorPage from './ClassEditorPage'

// ─── Delete confirm dialog ────────────────────────────────────────────────────

interface DeleteDialogProps {
  record: ClassRecord | null
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
      await classesApi.delete(record.id)
      onDeleted(record.id)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to delete class.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <Dialog open={Boolean(record)} onClose={onClose}>
      <DialogTitle>Delete Class?</DialogTitle>
      <DialogContent>
        {error && (
          <Alert severity="error" sx={{ mb: 2 }}>
            {error}
          </Alert>
        )}
        <DialogContentText>
          <strong>{record?.displayName}</strong> will be moved to the archive. You can restore it
          from the Recycle Bin.
        </DialogContentText>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} disabled={isBusy}>
          Cancel
        </Button>
        <Button color="error" variant="contained" onClick={() => void handleDelete()} disabled={isBusy}>
          Delete
        </Button>
      </DialogActions>
    </Dialog>
  )
}

// ─── Classes page ─────────���─────────────────────────────���─────────────────────

type SortKey = 'name' | 'updated'

export default function ClassesPage(): React.JSX.Element {
  const navigate = useNavigate()
  const editingMode = useUiStore((s) => s.editingMode)
  const [classes, setClasses] = useState<ClassRecord[]>([])
  const [archivedClasses, setArchivedClasses] = useState<ClassRecord[]>([])
  const [viewMode, setViewMode] = useState<ViewMode>('active')
  const [search, setSearch] = useState('')
  const [sortKey, setSortKey] = useState<SortKey>('name')
  const [createOpen, setCreateOpen] = useState(false)
  const [deleteTarget, setDeleteTarget] = useState<ClassRecord | null>(null)
  const [bulkDeleteOpen, setBulkDeleteOpen] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [modalRecordId, setModalRecordId] = useState<string | null>(null)
  const multiSelect = useMultiSelect()

  const openEditor = (id: string): void => {
    if (editingMode === 'modal') setModalRecordId(id)
    else void navigate(`/classes/${id}`)
  }

  const load = useCallback(async () => {
    try {
      const records = await classesApi.list()
      setClasses(records)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to load classes.')
    }
  }, [])

  const loadArchived = useCallback(async () => {
    try {
      const records = await classesApi.list(false, true)
      setArchivedClasses(records)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to load archived classes.')
    }
  }, [])

  useEffect(() => {
    multiSelect.clear()
    if (viewMode === 'active') void load()
    else void loadArchived()
  }, [load, loadArchived, viewMode])

  const handleCreated = (record: ClassRecord): void => {
    setCreateOpen(false)
    openEditor(record.id)
  }

  const handleDeleted = (id: string): void => {
    setDeleteTarget(null)
    setClasses((prev) => prev.filter((c) => c.id !== id))
  }

  const handleArchiveRestore = async (id: string): Promise<void> => {
    await classesApi.restore(id)
    setArchivedClasses((prev) => prev.filter((c) => c.id !== id))
  }

  const handleArchiveHardDelete = async (id: string): Promise<void> => {
    await classesApi.hardDelete(id)
    setArchivedClasses((prev) => prev.filter((c) => c.id !== id))
  }

  const handleArchiveBulkRestore = async (ids: string[]): Promise<void> => {
    await lifecycleApi.bulkRestore('classes', ids)
    void loadArchived()
  }

  const handleArchiveBulkHardDelete = async (ids: string[]): Promise<void> => {
    await lifecycleApi.bulkHardDelete('classes', ids)
    void loadArchived()
  }

  const handleDuplicate = async (record: ClassRecord): Promise<void> => {
    setError(null)
    try {
      const copy = await classesApi.duplicate(record.id)
      if (copy) setClasses((prev) => [...prev, copy])
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to duplicate class.')
    }
  }

  const handleBulkDelete = async (): Promise<void> => {
    setError(null)
    try {
      await lifecycleApi.bulkSoftDelete('classes', [...multiSelect.selected])
      setBulkDeleteOpen(false)
      multiSelect.clear()
      void load()
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Bulk delete failed.')
    }
  }

  const filtered = classes
    .filter((c) => c.displayName.toLowerCase().includes(search.toLowerCase()))
    .sort((a, b) => {
      if (sortKey === 'updated') return b.updatedAt.localeCompare(a.updatedAt)
      return a.displayName.localeCompare(b.displayName, undefined, { sensitivity: 'base' })
    })

  const filteredIds = filtered.map((c) => c.id)

  return (
    <Box>
      <ListToolbar
        search={search}
        onSearchChange={setSearch}
        sortKey={sortKey}
        onSortChange={(v) => setSortKey(v as SortKey)}
        sortOptions={[
          { value: 'name', label: 'Name' },
          { value: 'updated', label: 'Last Modified' },
        ]}
        viewMode={viewMode}
        onViewModeChange={setViewMode}
        onNew={() => setCreateOpen(true)}
        newLabel="+ New Class"
      />

      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      {viewMode === 'archived' ? (
        <ArchiveTable
          records={archivedClasses}
          domainLabel="Class"
          emptyMessage="No archived classes."
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

          {filtered.length === 0 ? (
            classes.length === 0 ? (
              <EmptyState
                icon={<ClassesIcon sx={{ fontSize: 'inherit' }} />}
                title="No classes yet"
                body="Create your first character class to get started."
                ctaLabel="+ Create First Class"
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
                  <TableCell>Description</TableCell>
                  <TableCell align="right">Actions</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {filtered.map((cls) => (
                  <TableRow
                    key={cls.id}
                    hover
                    sx={{ cursor: 'pointer' }}
                    onClick={() => openEditor(cls.id)}
                  >
                    <TableCell padding="checkbox" onClick={(e) => e.stopPropagation()}>
                      <Checkbox
                        size="small"
                        checked={multiSelect.isSelected(cls.id)}
                        onChange={() => multiSelect.toggle(cls.id)}
                      />
                    </TableCell>
                    <TableCell>
                      <Typography variant="body2" fontWeight={500}>
                        {cls.displayName}
                      </Typography>
                    </TableCell>
                    <TableCell>
                      <Typography variant="body2" color="text.secondary" fontFamily="monospace">
                        {cls.exportKey}
                      </Typography>
                    </TableCell>
                    <TableCell>
                      <Typography
                        variant="body2"
                        color="text.secondary"
                        sx={{
                          maxWidth: 300,
                          overflow: 'hidden',
                          textOverflow: 'ellipsis',
                          whiteSpace: 'nowrap',
                        }}
                      >
                        {cls.description || '—'}
                      </Typography>
                    </TableCell>
                    <TableCell align="right" onClick={(e) => e.stopPropagation()}>
                      <Tooltip title="Edit">
                        <IconButton size="small" onClick={() => openEditor(cls.id)}>
                          <EditIcon fontSize="small" />
                        </IconButton>
                      </Tooltip>
                      <Tooltip title="Duplicate">
                        <IconButton size="small" onClick={() => void handleDuplicate(cls)}>
                          <DuplicateIcon fontSize="small" />
                        </IconButton>
                      </Tooltip>
                      <Tooltip title="Delete">
                        <IconButton
                          size="small"
                          color="error"
                          onClick={() => setDeleteTarget(cls)}
                        >
                          <DeleteIcon fontSize="small" />
                        </IconButton>
                      </Tooltip>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </>
      )}

      <CreateClassDialog
        open={createOpen}
        onClose={() => setCreateOpen(false)}
        onCreated={handleCreated}
      />

      <DeleteDialog
        record={deleteTarget}
        onClose={() => setDeleteTarget(null)}
        onDeleted={handleDeleted}
      />

      <BulkDeleteDialog
        open={bulkDeleteOpen}
        domain="classes"
        ids={[...multiSelect.selected]}
        onClose={() => setBulkDeleteOpen(false)}
        onConfirm={() => void handleBulkDelete()}
      />

      <EditorModal
        open={modalRecordId !== null}
        title="Edit Class"
        onClose={() => { setModalRecordId(null); void load() }}
      >
        {modalRecordId && (
          <ClassEditorPage
            recordId={modalRecordId}
            onClose={() => { setModalRecordId(null); void load() }}
          />
        )}
      </EditorModal>
    </Box>
  )
}

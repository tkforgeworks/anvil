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
import { useCallback, useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { abilitiesApi } from '../../api/abilities.api'
import { lifecycleApi } from '../../api/lifecycle.api'
import type { AbilityRecord } from '../../../shared/domain-types'
import { ArchiveToggle, ArchiveTable, type ViewMode } from '../components/ArchiveView'
import { BulkActionToolbar, BulkDeleteDialog } from '../components/BulkActions'
import { CreateAbilityDialog } from '../components/create-dialogs'
import EditorModal from '../components/EditorModal'
import { useMultiSelect } from '../hooks/useMultiSelect'
import { useUiStore } from '../stores/ui.store'
import AbilityEditorPage from './AbilityEditorPage'

// ─── Delete confirm dialog ────────────────────────────────────────────────────

interface DeleteDialogProps {
  record: AbilityRecord | null
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
      await abilitiesApi.delete(record.id)
      onDeleted(record.id)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to delete ability.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <Dialog open={Boolean(record)} onClose={onClose}>
      <DialogTitle>Delete Ability?</DialogTitle>
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

// ─── Abilities page ───────────────────────────────────────────────────────────

type SortKey = 'name' | 'updated'

export default function AbilitiesPage(): React.JSX.Element {
  const navigate = useNavigate()
  const editingMode = useUiStore((s) => s.editingMode)
  const [abilities, setAbilities] = useState<AbilityRecord[]>([])
  const [archivedAbilitys, setArchivedAbilitys] = useState<AbilityRecord[]>([])
  const [viewMode, setViewMode] = useState<ViewMode>('active')
  const [search, setSearch] = useState('')
  const [sortKey, setSortKey] = useState<SortKey>('name')
  const [createOpen, setCreateOpen] = useState(false)
  const [deleteTarget, setDeleteTarget] = useState<AbilityRecord | null>(null)
  const [bulkDeleteOpen, setBulkDeleteOpen] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [modalRecordId, setModalRecordId] = useState<string | null>(null)
  const multiSelect = useMultiSelect()

  const openEditor = (id: string): void => {
    if (editingMode === 'modal') setModalRecordId(id)
    else void navigate(`/abilities/${id}`)
  }

  const load = useCallback(async () => {
    try {
      const records = await abilitiesApi.list()
      setAbilities(records)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to load abilities.')
    }
  }, [])

  const loadArchived = useCallback(async () => {
    try {
      const records = await abilitiesApi.list(false, true)
      setArchivedAbilitys(records)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to load archived abilitys.')
    }
  }, [])

  useEffect(() => {
    multiSelect.clear()
    if (viewMode === 'active') void load()
    else void loadArchived()
  }, [load, loadArchived, viewMode])

  const handleCreated = (record: AbilityRecord): void => {
    setCreateOpen(false)
    openEditor(record.id)
  }

  const handleDeleted = (id: string): void => {
    setDeleteTarget(null)
    setAbilities((prev) => prev.filter((a) => a.id !== id))
  }

  const handleArchiveRestore = async (id: string): Promise<void> => {
    await abilitiesApi.restore(id)
    setArchivedAbilitys((prev) => prev.filter((r) => r.id !== id))
  }

  const handleArchiveHardDelete = async (id: string): Promise<void> => {
    await abilitiesApi.hardDelete(id)
    setArchivedAbilitys((prev) => prev.filter((r) => r.id !== id))
  }

  const handleArchiveBulkRestore = async (ids: string[]): Promise<void> => {
    await lifecycleApi.bulkRestore('abilities', ids)
    void loadArchived()
  }

  const handleArchiveBulkHardDelete = async (ids: string[]): Promise<void> => {
    await lifecycleApi.bulkHardDelete('abilities', ids)
    void loadArchived()
  }

  const handleDuplicate = async (record: AbilityRecord): Promise<void> => {
    setError(null)
    try {
      const copy = await abilitiesApi.duplicate(record.id)
      if (copy) setAbilities((prev) => [...prev, copy])
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to duplicate ability.')
    }
  }

  const handleBulkDelete = async (): Promise<void> => {
    setError(null)
    try {
      await lifecycleApi.bulkSoftDelete('abilities', [...multiSelect.selected])
      setBulkDeleteOpen(false)
      multiSelect.clear()
      void load()
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Bulk delete failed.')
    }
  }

  const filtered = abilities
    .filter((a) => a.displayName.toLowerCase().includes(search.toLowerCase()))
    .sort((a, b) => {
      if (sortKey === 'updated') return b.updatedAt.localeCompare(a.updatedAt)
      return a.displayName.localeCompare(b.displayName, undefined, { sensitivity: 'base' })
    })

  const filteredIds = filtered.map((a) => a.id)

  return (
    <Box>
      {/* Header */}
      <Stack direction="row" alignItems="center" justifyContent="space-between" sx={{ mb: 3 }}>
        <Typography variant="h5">Abilities</Typography>
        <Stack direction="row" spacing={2} alignItems="center">
          <ArchiveToggle value={viewMode} onChange={setViewMode} />
          {viewMode === 'active' && (
            <Button startIcon={<AddIcon />} variant="contained" onClick={() => setCreateOpen(true)}>
              New Ability
            </Button>
          )}
        </Stack>
      </Stack>

      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      {viewMode === 'archived' ? (
        <ArchiveTable
          records={archivedAbilitys}
          domainLabel="Ability"
          emptyMessage="No archived abilitys."
          error={error}
          onClearError={() => setError(null)}
          onRestore={handleArchiveRestore}
          onHardDelete={handleArchiveHardDelete}
          onBulkRestore={handleArchiveBulkRestore}
          onBulkHardDelete={handleArchiveBulkHardDelete}
        />
      ) : (
        <>
          {/* Toolbar */}
          <Stack direction="row" spacing={2} sx={{ mb: 2 }}>
            <TextField
              size="small"
              placeholder="Search abilities…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              sx={{ flex: 1, maxWidth: 360 }}
            />
            <FormControl size="small" sx={{ minWidth: 180 }}>
              <InputLabel id="sort-label">Sort by</InputLabel>
              <Select
                labelId="sort-label"
                label="Sort by"
                value={sortKey}
                onChange={(e) => setSortKey(e.target.value as SortKey)}
              >
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

          {/* List */}
          {filtered.length === 0 ? (
            <Typography variant="body2" color="text.secondary">
              {abilities.length === 0
                ? 'No abilities yet. Click "New Ability" to create one.'
                : 'No abilities match your search.'}
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
                  <TableCell>Type</TableCell>
                  <TableCell>Description</TableCell>
                  <TableCell align="right">Actions</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {filtered.map((ability) => (
                  <TableRow
                    key={ability.id}
                    hover
                    sx={{ cursor: 'pointer' }}
                    onClick={() => openEditor(ability.id)}
                  >
                    <TableCell padding="checkbox" onClick={(e) => e.stopPropagation()}>
                      <Checkbox
                        size="small"
                        checked={multiSelect.isSelected(ability.id)}
                        onChange={() => multiSelect.toggle(ability.id)}
                      />
                    </TableCell>
                    <TableCell>
                      <Typography variant="body2" fontWeight={500}>
                        {ability.displayName}
                      </Typography>
                    </TableCell>
                    <TableCell>
                      <Typography variant="body2" color="text.secondary" fontFamily="monospace">
                        {ability.exportKey}
                      </Typography>
                    </TableCell>
                    <TableCell>
                      <Typography variant="body2" color="text.secondary">
                        {ability.abilityType || '—'}
                      </Typography>
                    </TableCell>
                    <TableCell>
                      <Typography
                        variant="body2"
                        color="text.secondary"
                        sx={{
                          maxWidth: 260,
                          overflow: 'hidden',
                          textOverflow: 'ellipsis',
                          whiteSpace: 'nowrap',
                        }}
                      >
                        {ability.description || '—'}
                      </Typography>
                    </TableCell>
                    <TableCell align="right" onClick={(e) => e.stopPropagation()}>
                      <Tooltip title="Edit">
                        <IconButton
                          size="small"
                          onClick={() => openEditor(ability.id)}
                        >
                          <EditIcon fontSize="small" />
                        </IconButton>
                      </Tooltip>
                      <Tooltip title="Duplicate">
                        <IconButton size="small" onClick={() => void handleDuplicate(ability)}>
                          <DuplicateIcon fontSize="small" />
                        </IconButton>
                      </Tooltip>
                      <Tooltip title="Delete">
                        <IconButton
                          size="small"
                          color="error"
                          onClick={() => setDeleteTarget(ability)}
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

      <CreateAbilityDialog
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
        domain="abilities"
        ids={[...multiSelect.selected]}
        onClose={() => setBulkDeleteOpen(false)}
        onConfirm={() => void handleBulkDelete()}
      />

      <EditorModal
        open={modalRecordId !== null}
        title="Edit Ability"
        onClose={() => { setModalRecordId(null); void load() }}
      >
        {modalRecordId && (
          <AbilityEditorPage
            recordId={modalRecordId}
            onClose={() => { setModalRecordId(null); void load() }}
          />
        )}
      </EditorModal>
    </Box>
  )
}

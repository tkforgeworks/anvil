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
import { useCallback, useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { classesApi } from '../../api/classes.api'
import type { ClassRecord } from '../../../shared/domain-types'
import { ArchiveToggle, ArchiveTable, type ViewMode } from '../components/ArchiveView'

function slugify(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
}

// ─── Create dialog ────────────────────────────────────────────────────────────

interface CreateDialogProps {
  open: boolean
  onClose: () => void
  onCreated: (record: ClassRecord) => void
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

  const handleExportKeyChange = (value: string): void => {
    setExportKey(value)
    setExportKeyTouched(true)
  }

  const handleCreate = async (): Promise<void> => {
    if (!displayName.trim()) return
    setBusy(true)
    setError(null)
    try {
      const record = await classesApi.create({
        displayName: displayName.trim(),
        exportKey: exportKey.trim() || slugify(displayName.trim()),
      })
      onCreated(record)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to create class.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <Dialog open={open} onClose={onClose} fullWidth maxWidth="sm">
      <DialogTitle>New Character Class</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ pt: 1 }}>
          {error && <Alert severity="error">{error}</Alert>}
          <TextField
            label="Display Name"
            value={displayName}
            onChange={(e) => handleDisplayNameChange(e.target.value)}
            required
            autoFocus
            fullWidth
          />
          <TextField
            label="Export Key"
            value={exportKey}
            onChange={(e) => handleExportKeyChange(e.target.value)}
            fullWidth
            helperText="Used in exported files. Auto-generated from the display name."
            InputProps={{
              startAdornment: exportKey ? undefined : (
                <InputAdornment position="start">
                  <Typography variant="caption" color="text.disabled">
                    auto
                  </Typography>
                </InputAdornment>
              ),
            }}
          />
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} disabled={isBusy}>
          Cancel
        </Button>
        <Button
          variant="contained"
          onClick={() => void handleCreate()}
          disabled={!displayName.trim() || isBusy}
        >
          Create Class
        </Button>
      </DialogActions>
    </Dialog>
  )
}

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

// ─── Classes page ─────────────────────────────────────────────────────────────

type SortKey = 'name' | 'updated'

export default function ClassesPage(): React.JSX.Element {
  const navigate = useNavigate()
  const [classes, setClasses] = useState<ClassRecord[]>([])
  const [archivedClasses, setArchivedClasses] = useState<ClassRecord[]>([])
  const [viewMode, setViewMode] = useState<ViewMode>('active')
  const [search, setSearch] = useState('')
  const [sortKey, setSortKey] = useState<SortKey>('name')
  const [createOpen, setCreateOpen] = useState(false)
  const [deleteTarget, setDeleteTarget] = useState<ClassRecord | null>(null)
  const [error, setError] = useState<string | null>(null)

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
    if (viewMode === 'active') void load()
    else void loadArchived()
  }, [load, loadArchived, viewMode])

  const handleCreated = (record: ClassRecord): void => {
    setCreateOpen(false)
    void navigate(`/classes/${record.id}`)
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

  const handleDuplicate = async (record: ClassRecord): Promise<void> => {
    setError(null)
    try {
      const copy = await classesApi.duplicate(record.id)
      if (copy) setClasses((prev) => [...prev, copy])
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to duplicate class.')
    }
  }

  const filtered = classes
    .filter((c) => c.displayName.toLowerCase().includes(search.toLowerCase()))
    .sort((a, b) => {
      if (sortKey === 'updated') return b.updatedAt.localeCompare(a.updatedAt)
      return a.displayName.localeCompare(b.displayName, undefined, { sensitivity: 'base' })
    })

  return (
    <Box>
      {/* Header */}
      <Stack direction="row" alignItems="center" justifyContent="space-between" sx={{ mb: 3 }}>
        <Typography variant="h5">Character Classes</Typography>
        <Stack direction="row" spacing={2} alignItems="center">
          <ArchiveToggle value={viewMode} onChange={setViewMode} />
          {viewMode === 'active' && (
            <Button startIcon={<AddIcon />} variant="contained" onClick={() => setCreateOpen(true)}>
              New Class
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
          records={archivedClasses}
          domainLabel="Class"
          emptyMessage="No archived classes."
          error={error}
          onClearError={() => setError(null)}
          onRestore={handleArchiveRestore}
          onHardDelete={handleArchiveHardDelete}
        />
      ) : (
        <>
          {/* Toolbar */}
          <Stack direction="row" spacing={2} sx={{ mb: 2 }}>
            <TextField
              size="small"
              placeholder="Search classes…"
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

          {/* List */}
          {filtered.length === 0 ? (
            <Typography variant="body2" color="text.secondary">
              {classes.length === 0
                ? 'No classes yet. Click "New Class" to create one.'
                : 'No classes match your search.'}
            </Typography>
          ) : (
            <Table size="small">
              <TableHead>
                <TableRow>
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
                    onClick={() => void navigate(`/classes/${cls.id}`)}
                  >
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
                        <IconButton size="small" onClick={() => void navigate(`/classes/${cls.id}`)}>
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

      <CreateDialog
        open={createOpen}
        onClose={() => setCreateOpen(false)}
        onCreated={handleCreated}
      />

      <DeleteDialog
        record={deleteTarget}
        onClose={() => setDeleteTarget(null)}
        onDeleted={handleDeleted}
      />
    </Box>
  )
}

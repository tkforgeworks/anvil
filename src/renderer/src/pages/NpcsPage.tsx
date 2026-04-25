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
import { useCallback, useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { metaApi } from '../../api/meta.api'
import { npcsApi } from '../../api/npcs.api'
import type { MetaNpcType, NpcRecord } from '../../../shared/domain-types'
import { ArchiveToggle, ArchiveTable, type ViewMode } from '../components/ArchiveView'

function slugify(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '')
}

interface CreateDialogProps {
  open: boolean
  npcTypes: MetaNpcType[]
  onClose: () => void
  onCreated: (record: NpcRecord) => void
}

function CreateDialog({ open, npcTypes, onClose, onCreated }: CreateDialogProps): React.JSX.Element {
  const [displayName, setDisplayName] = useState('')
  const [exportKey, setExportKey] = useState('')
  const [exportKeyTouched, setExportKeyTouched] = useState(false)
  const [npcTypeId, setNpcTypeId] = useState('')
  const [isBusy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    setDisplayName('')
    setExportKey('')
    setExportKeyTouched(false)
    setNpcTypeId(npcTypes[0]?.id ?? '')
    setError(null)
  }, [open, npcTypes])

  const handleDisplayNameChange = (value: string): void => {
    setDisplayName(value)
    if (!exportKeyTouched) setExportKey(slugify(value))
  }

  const handleCreate = async (): Promise<void> => {
    if (!displayName.trim() || !npcTypeId) return
    setBusy(true)
    setError(null)
    try {
      const record = await npcsApi.create({
        displayName: displayName.trim(),
        exportKey: exportKey.trim() || slugify(displayName.trim()),
        npcTypeId,
      })
      onCreated(record)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to create NPC.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <Dialog open={open} onClose={onClose} fullWidth maxWidth="sm">
      <DialogTitle>New NPC</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ pt: 1 }}>
          {error && <Alert severity="error">{error}</Alert>}
          {npcTypes.length === 0 && <Alert severity="info">Create an NPC type before adding NPCs.</Alert>}
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
          <FormControl fullWidth required>
            <InputLabel id="create-npc-type-label">NPC Type</InputLabel>
            <Select labelId="create-npc-type-label" label="NPC Type" value={npcTypeId} onChange={(e) => setNpcTypeId(e.target.value)}>
              {npcTypes.map((type) => <MenuItem key={type.id} value={type.id}>{type.displayName}</MenuItem>)}
            </Select>
          </FormControl>
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} disabled={isBusy}>Cancel</Button>
        <Button variant="contained" onClick={() => void handleCreate()} disabled={!displayName.trim() || !npcTypeId || isBusy}>Create NPC</Button>
      </DialogActions>
    </Dialog>
  )
}

interface DeleteDialogProps {
  record: NpcRecord | null
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
      await npcsApi.delete(record.id)
      onDeleted(record.id)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to delete NPC.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <Dialog open={Boolean(record)} onClose={onClose}>
      <DialogTitle>Delete NPC?</DialogTitle>
      <DialogContent>
        {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
        <DialogContentText>
          <strong>{record?.displayName}</strong> will be moved to the archive.
        </DialogContentText>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} disabled={isBusy}>Cancel</Button>
        <Button color="error" variant="contained" onClick={() => void handleDelete()} disabled={isBusy}>Delete</Button>
      </DialogActions>
    </Dialog>
  )
}

export default function NpcsPage(): React.JSX.Element {
  const navigate = useNavigate()
  const [npcs, setNpcs] = useState<NpcRecord[]>([])
  const [archivedNPCs, setArchivedNPCs] = useState<NpcRecord[]>([])
  const [viewMode, setViewMode] = useState<ViewMode>('active')
  const [npcTypes, setNpcTypes] = useState<MetaNpcType[]>([])
  const [search, setSearch] = useState('')
  const [typeFilter, setTypeFilter] = useState('all')
  const [sortBy, setSortBy] = useState<'name' | 'updated'>('name')
  const [createOpen, setCreateOpen] = useState(false)
  const [deleteTarget, setDeleteTarget] = useState<NpcRecord | null>(null)
  const [error, setError] = useState<string | null>(null)

  const typeById = useMemo(() => new Map(npcTypes.map((type) => [type.id, type])), [npcTypes])

  const load = useCallback(async () => {
    setError(null)
    try {
      const [records, typeList] = await Promise.all([
        npcsApi.list(),
        metaApi.listNpcTypes(),
      ])
      setNpcs(records)
      setNpcTypes(typeList)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to load NPCs.')
    }
  }, [])

  const loadArchived = useCallback(async () => {
    try {
      const records = await npcsApi.list(false, true)
      setArchivedNPCs(records)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to load archived NPCs.')
    }
  }, [])

  useEffect(() => {
    if (viewMode === 'active') void load()
    else void loadArchived()
  }, [load, loadArchived, viewMode])

  const handleCreated = (record: NpcRecord): void => {
    setCreateOpen(false)
    void navigate(`/npcs/${record.id}`)
  }

  const handleDeleted = (id: string): void => {
    setDeleteTarget(null)
    setNpcs((prev) => prev.filter((npc) => npc.id !== id))
  }

  const handleArchiveRestore = async (id: string): Promise<void> => {
    await npcsApi.restore(id)
    setArchivedNPCs((prev) => prev.filter((r) => r.id !== id))
  }

  const handleArchiveHardDelete = async (id: string): Promise<void> => {
    await npcsApi.hardDelete(id)
    setArchivedNPCs((prev) => prev.filter((r) => r.id !== id))
  }

  const handleDuplicate = async (record: NpcRecord): Promise<void> => {
    setError(null)
    try {
      const copy = await npcsApi.duplicate(record.id)
      if (copy) setNpcs((prev) => [...prev, copy])
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to duplicate NPC.')
    }
  }

  const filtered = npcs
    .filter((npc) => npc.displayName.toLowerCase().includes(search.toLowerCase()))
    .filter((npc) => typeFilter === 'all' || npc.npcTypeId === typeFilter)
    .sort((a, b) => {
      if (sortBy === 'updated') return b.updatedAt.localeCompare(a.updatedAt)
      return a.displayName.localeCompare(b.displayName, undefined, { sensitivity: 'base' })
    })

  return (
    <Box>
      <Stack direction="row" alignItems="center" justifyContent="space-between" sx={{ mb: 3 }}>
        <Typography variant="h5">NPCs</Typography>
        <Stack direction="row" spacing={2} alignItems="center">
          <ArchiveToggle value={viewMode} onChange={setViewMode} />
          {viewMode === 'active' && (
            <Button startIcon={<AddIcon />} variant="contained" onClick={() => setCreateOpen(true)}>New NPC</Button>
          )}
        </Stack>
      </Stack>

      {error && <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>{error}</Alert>}

      {viewMode === 'archived' ? (
        <ArchiveTable
          records={archivedNPCs}
          domainLabel="NPC"
          emptyMessage="No archived NPCs."
          error={error}
          onClearError={() => setError(null)}
          onRestore={handleArchiveRestore}
          onHardDelete={handleArchiveHardDelete}
        />
      ) : (
        <>
      <Stack direction="row" spacing={2} sx={{ mb: 2 }} flexWrap="wrap" useFlexGap>
        <TextField size="small" placeholder="Search NPCs..." value={search} onChange={(e) => setSearch(e.target.value)} sx={{ flex: 1, minWidth: 220, maxWidth: 360 }} />
        <FormControl size="small" sx={{ minWidth: 190 }}>
          <InputLabel id="npc-type-filter-label">NPC Type</InputLabel>
          <Select labelId="npc-type-filter-label" label="NPC Type" value={typeFilter} onChange={(e) => setTypeFilter(e.target.value)}>
            <MenuItem value="all">All NPC Types</MenuItem>
            {npcTypes.map((type) => <MenuItem key={type.id} value={type.id}>{type.displayName}</MenuItem>)}
          </Select>
        </FormControl>
        <FormControl size="small" sx={{ minWidth: 180 }}>
          <InputLabel id="npc-sort-label">Sort</InputLabel>
          <Select labelId="npc-sort-label" label="Sort" value={sortBy} onChange={(e) => setSortBy(e.target.value as 'name' | 'updated')}>
            <MenuItem value="name">Name</MenuItem>
            <MenuItem value="updated">Last Modified</MenuItem>
          </Select>
        </FormControl>
      </Stack>

      {filtered.length === 0 ? (
        <Typography variant="body2" color="text.secondary">
          {npcs.length === 0 ? 'No NPCs yet. Click "New NPC" to create one.' : 'No NPCs match your filters.'}
        </Typography>
      ) : (
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Name</TableCell>
              <TableCell>Export Key</TableCell>
              <TableCell>NPC Type</TableCell>
              <TableCell>Last Modified</TableCell>
              <TableCell align="right">Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {filtered.map((npc) => (
              <TableRow key={npc.id} hover sx={{ cursor: 'pointer' }} onClick={() => void navigate(`/npcs/${npc.id}`)}>
                <TableCell><Typography variant="body2" fontWeight={500}>{npc.displayName}</Typography></TableCell>
                <TableCell><Typography variant="body2" color="text.secondary" fontFamily="monospace">{npc.exportKey}</Typography></TableCell>
                <TableCell><Typography variant="body2" color="text.secondary">{typeById.get(npc.npcTypeId)?.displayName ?? npc.npcTypeId}</Typography></TableCell>
                <TableCell><Typography variant="body2" color="text.secondary">{new Date(npc.updatedAt).toLocaleString()}</Typography></TableCell>
                <TableCell align="right" onClick={(e) => e.stopPropagation()}>
                  <Tooltip title="Edit"><IconButton size="small" onClick={() => void navigate(`/npcs/${npc.id}`)}><EditIcon fontSize="small" /></IconButton></Tooltip>
                  <Tooltip title="Duplicate"><IconButton size="small" onClick={() => void handleDuplicate(npc)}><DuplicateIcon fontSize="small" /></IconButton></Tooltip>
                  <Tooltip title="Delete"><IconButton size="small" color="error" onClick={() => setDeleteTarget(npc)}><DeleteIcon fontSize="small" /></IconButton></Tooltip>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}
        </>
      )}

      <CreateDialog open={createOpen} npcTypes={npcTypes} onClose={() => setCreateOpen(false)} onCreated={handleCreated} />
      <DeleteDialog record={deleteTarget} onClose={() => setDeleteTarget(null)} onDeleted={handleDeleted} />
    </Box>
  )
}

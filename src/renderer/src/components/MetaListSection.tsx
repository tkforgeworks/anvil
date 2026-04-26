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
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  IconButton,
  InputAdornment,
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
import { useState } from 'react'
import type { MetaDeleteResult, MetaReorderItem } from '../../../shared/domain-types'

function slugify(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_|_$/g, '')
}

interface MetaListItem {
  id: string
  displayName: string
  exportKey: string
  sortOrder: number
}

interface MetaListSectionProps {
  title: string
  singularName: string
  description?: string
  items: MetaListItem[]
  onAdd: (input: { displayName: string; exportKey: string }) => Promise<MetaListItem>
  onUpdate: (id: string, input: { displayName: string; exportKey: string }) => Promise<MetaListItem>
  onDelete: (id: string) => Promise<MetaDeleteResult>
  onReorder: (items: MetaReorderItem[]) => Promise<void>
  onRefresh: () => void
}

export default function MetaListSection({
  title,
  singularName,
  description,
  items,
  onAdd,
  onUpdate,
  onDelete,
  onReorder,
  onRefresh,
}: MetaListSectionProps): React.JSX.Element {
  const [dialogOpen, setDialogOpen] = useState(false)
  const [editing, setEditing] = useState<MetaListItem | null>(null)
  const [displayName, setDisplayName] = useState('')
  const [exportKey, setExportKey] = useState('')
  const [exportKeyTouched, setExportKeyTouched] = useState(false)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const openAdd = (): void => {
    setEditing(null)
    setDisplayName('')
    setExportKey('')
    setExportKeyTouched(false)
    setError(null)
    setDialogOpen(true)
  }

  const openEdit = (item: MetaListItem): void => {
    setEditing(item)
    setDisplayName(item.displayName)
    setExportKey(item.exportKey)
    setExportKeyTouched(true)
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

  const handleExportKeyChange = (value: string): void => {
    setExportKey(value)
    setExportKeyTouched(true)
  }

  const handleSave = async (): Promise<void> => {
    if (!displayName.trim() || !exportKey.trim()) return
    setBusy(true)
    setError(null)
    try {
      const input = { displayName: displayName.trim(), exportKey: exportKey.trim() }
      if (editing) {
        await onUpdate(editing.id, input)
      } else {
        await onAdd(input)
      }
      handleClose()
      onRefresh()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Operation failed.')
    } finally {
      setBusy(false)
    }
  }

  const handleDelete = async (item: MetaListItem): Promise<void> => {
    setError(null)
    const result = await onDelete(item.id)
    if (!result.deleted) {
      setError(result.reason ?? `Cannot delete "${item.displayName}".`)
      return
    }
    onRefresh()
  }

  const handleMove = async (index: number, direction: 'up' | 'down'): Promise<void> => {
    const targetIndex = direction === 'up' ? index - 1 : index + 1
    if (targetIndex < 0 || targetIndex >= items.length) return
    const reordered = items.map((item, i) => {
      if (i === index) return { id: item.id, sortOrder: items[targetIndex].sortOrder }
      if (i === targetIndex) return { id: item.id, sortOrder: items[index].sortOrder }
      return { id: item.id, sortOrder: item.sortOrder }
    })
    await onReorder(reordered)
    onRefresh()
  }

  const canSave = displayName.trim().length > 0 && exportKey.trim().length > 0 && !busy

  return (
    <Box>
      <Stack direction="row" alignItems="center" justifyContent="space-between" sx={{ mb: 1 }}>
        <Box>
          <Typography variant="subtitle2">{title}</Typography>
          {description && (
            <Typography variant="caption" color="text.secondary" sx={{ display: 'block' }}>
              {description}
            </Typography>
          )}
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

      {items.length === 0 ? (
        <Typography variant="body2" color="text.secondary">
          None defined.
        </Typography>
      ) : (
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Name</TableCell>
              <TableCell>Export Key</TableCell>
              <TableCell align="right" sx={{ width: 150 }}>Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {items.map((item, index) => (
              <TableRow key={item.id}>
                <TableCell>{item.displayName}</TableCell>
                <TableCell>
                  <Typography variant="body2" sx={{ fontFamily: 'monospace', fontSize: '0.8rem' }}>
                    {item.exportKey}
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
                      <IconButton size="small" disabled={index === items.length - 1} onClick={() => void handleMove(index, 'down')}>
                        <DownIcon fontSize="small" />
                      </IconButton>
                    </span>
                  </Tooltip>
                  <Tooltip title="Edit">
                    <IconButton size="small" onClick={() => openEdit(item)}>
                      <EditIcon fontSize="small" />
                    </IconButton>
                  </Tooltip>
                  <Tooltip title="Delete">
                    <IconButton size="small" color="error" onClick={() => void handleDelete(item)}>
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
        <DialogTitle>{editing ? `Edit ${singularName}` : `Add ${singularName}`}</DialogTitle>
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
              onChange={(e) => handleExportKeyChange(e.target.value)}
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

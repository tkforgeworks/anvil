import {
  DeleteForever as PermanentDeleteIcon,
  RestoreFromTrash as RestoreIcon,
} from '@mui/icons-material'
import {
  Alert,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogContentText,
  DialogTitle,
  IconButton,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  ToggleButton,
  ToggleButtonGroup,
  Tooltip,
  Typography,
} from '@mui/material'
import { useState } from 'react'
import type { BaseRecord } from '../../../shared/domain-types'

export type ViewMode = 'active' | 'archived'

interface ArchiveToggleProps {
  value: ViewMode
  onChange: (mode: ViewMode) => void
}

export function ArchiveToggle({ value, onChange }: ArchiveToggleProps): React.JSX.Element {
  return (
    <ToggleButtonGroup
      value={value}
      exclusive
      onChange={(_e, v) => { if (v) onChange(v as ViewMode) }}
      size="small"
    >
      <ToggleButton value="active">Active</ToggleButton>
      <ToggleButton value="archived">Archived</ToggleButton>
    </ToggleButtonGroup>
  )
}

interface PermanentDeleteDialogProps {
  record: BaseRecord | null
  domainLabel: string
  onClose: () => void
  onConfirm: (id: string) => void
}

export function PermanentDeleteDialog({
  record,
  domainLabel,
  onClose,
  onConfirm,
}: PermanentDeleteDialogProps): React.JSX.Element {
  const [isBusy, setBusy] = useState(false)

  const handleConfirm = (): void => {
    if (!record) return
    setBusy(true)
    onConfirm(record.id)
    setBusy(false)
  }

  return (
    <Dialog open={Boolean(record)} onClose={onClose}>
      <DialogTitle>Permanently Delete {domainLabel}?</DialogTitle>
      <DialogContent>
        <DialogContentText>
          <strong>{record?.displayName}</strong> will be permanently deleted.
          This action cannot be undone.
        </DialogContentText>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} disabled={isBusy}>Cancel</Button>
        <Button
          color="error"
          variant="contained"
          onClick={handleConfirm}
          disabled={isBusy}
        >
          Permanently Delete
        </Button>
      </DialogActions>
    </Dialog>
  )
}

function formatDeletedAt(iso: string | null): string {
  if (!iso) return '—'
  try {
    return new Date(iso + 'Z').toLocaleString()
  } catch {
    return iso
  }
}

interface ArchiveTableProps<T extends BaseRecord> {
  records: T[]
  domainLabel: string
  emptyMessage?: string
  error?: string | null
  onClearError?: () => void
  onRestore: (id: string) => Promise<void>
  onHardDelete: (id: string) => Promise<void>
}

export function ArchiveTable<T extends BaseRecord>({
  records,
  domainLabel,
  emptyMessage,
  error,
  onClearError,
  onRestore,
  onHardDelete,
}: ArchiveTableProps<T>): React.JSX.Element {
  const [deleteTarget, setDeleteTarget] = useState<T | null>(null)
  const [actionError, setActionError] = useState<string | null>(null)

  const handleRestore = async (id: string): Promise<void> => {
    setActionError(null)
    try {
      await onRestore(id)
    } catch (cause) {
      setActionError(cause instanceof Error ? cause.message : 'Restore failed.')
    }
  }

  const handlePermanentDelete = async (id: string): Promise<void> => {
    setActionError(null)
    try {
      await onHardDelete(id)
      setDeleteTarget(null)
    } catch (cause) {
      setActionError(cause instanceof Error ? cause.message : 'Delete failed.')
    }
  }

  const displayError = error ?? actionError

  return (
    <>
      {displayError && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => { onClearError?.(); setActionError(null) }}>
          {displayError}
        </Alert>
      )}

      {records.length === 0 ? (
        <Typography variant="body2" color="text.secondary">
          {emptyMessage ?? 'No archived records.'}
        </Typography>
      ) : (
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Name</TableCell>
              <TableCell>Export Key</TableCell>
              <TableCell>Deleted At</TableCell>
              <TableCell align="right">Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {records.map((record) => (
              <TableRow key={record.id}>
                <TableCell>
                  <Typography variant="body2" fontWeight={500} color="text.secondary">
                    {record.displayName}
                  </Typography>
                </TableCell>
                <TableCell>
                  <Typography variant="body2" color="text.secondary" fontFamily="monospace">
                    {record.exportKey}
                  </Typography>
                </TableCell>
                <TableCell>
                  <Typography variant="body2" color="text.secondary">
                    {formatDeletedAt(record.deletedAt)}
                  </Typography>
                </TableCell>
                <TableCell align="right">
                  <Stack direction="row" spacing={0.5} justifyContent="flex-end">
                    <Tooltip title="Restore">
                      <IconButton size="small" color="primary" onClick={() => void handleRestore(record.id)}>
                        <RestoreIcon fontSize="small" />
                      </IconButton>
                    </Tooltip>
                    <Tooltip title="Permanently Delete">
                      <IconButton size="small" color="error" onClick={() => setDeleteTarget(record)}>
                        <PermanentDeleteIcon fontSize="small" />
                      </IconButton>
                    </Tooltip>
                  </Stack>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}

      <PermanentDeleteDialog
        record={deleteTarget}
        domainLabel={domainLabel}
        onClose={() => setDeleteTarget(null)}
        onConfirm={(id) => void handlePermanentDelete(id)}
      />
    </>
  )
}

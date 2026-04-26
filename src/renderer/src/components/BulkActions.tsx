import {
  Delete as DeleteIcon,
  DeleteForever as PermanentDeleteIcon,
  RestoreFromTrash as RestoreIcon,
} from '@mui/icons-material'
import {
  Alert,
  Box,
  Button,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogContentText,
  DialogTitle,
  Paper,
  Stack,
  Typography,
} from '@mui/material'
import { useEffect, useState } from 'react'
import type { DeleteImpactSummary, LifecycleDomain } from '../../../shared/domain-types'
import { lifecycleApi } from '../../api/lifecycle.api'

// ─── Bulk Action Toolbar ─────────────────────────────────────────────────────

interface BulkActionToolbarProps {
  count: number
  mode: 'active' | 'archived' | 'recycle-bin'
  onBulkDelete?: () => void
  onBulkRestore?: () => void
  onBulkHardDelete?: () => void
}

export function BulkActionToolbar({
  count,
  mode,
  onBulkDelete,
  onBulkRestore,
  onBulkHardDelete,
}: BulkActionToolbarProps): React.JSX.Element | null {
  if (count === 0) return null

  return (
    <Paper
      elevation={3}
      sx={{ px: 2, py: 1, mb: 2, display: 'flex', alignItems: 'center', gap: 2 }}
    >
      <Typography variant="body2" fontWeight={600}>
        {count} selected
      </Typography>
      <Box sx={{ flex: 1 }} />
      {mode === 'active' && onBulkDelete && (
        <Button
          size="small"
          color="error"
          variant="outlined"
          startIcon={<DeleteIcon />}
          onClick={onBulkDelete}
        >
          Delete Selected
        </Button>
      )}
      {(mode === 'archived' || mode === 'recycle-bin') && onBulkRestore && (
        <Button
          size="small"
          color="primary"
          variant="outlined"
          startIcon={<RestoreIcon />}
          onClick={onBulkRestore}
        >
          Restore Selected
        </Button>
      )}
      {(mode === 'archived' || mode === 'recycle-bin') && onBulkHardDelete && (
        <Button
          size="small"
          color="error"
          variant="outlined"
          startIcon={<PermanentDeleteIcon />}
          onClick={onBulkHardDelete}
        >
          Permanently Delete
        </Button>
      )}
    </Paper>
  )
}

// ─── Bulk Delete Dialog (with impact summary) ────────────────────────────────

interface BulkDeleteDialogProps {
  open: boolean
  domain: LifecycleDomain
  ids: string[]
  onClose: () => void
  onConfirm: () => void
}

export function BulkDeleteDialog({
  open,
  domain,
  ids,
  onClose,
  onConfirm,
}: BulkDeleteDialogProps): React.JSX.Element {
  const [impact, setImpact] = useState<DeleteImpactSummary | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [isBusy, setBusy] = useState(false)

  useEffect(() => {
    if (!open || ids.length === 0) {
      setImpact(null)
      setError(null)
      return
    }
    setLoading(true)
    lifecycleApi
      .computeDeleteImpact(domain, ids)
      .then(setImpact)
      .catch((e) => setError(e instanceof Error ? e.message : 'Failed to compute impact.'))
      .finally(() => setLoading(false))
  }, [open, domain, ids])

  const handleConfirm = async (): Promise<void> => {
    setBusy(true)
    onConfirm()
    setBusy(false)
  }

  return (
    <Dialog open={open} onClose={onClose} maxWidth="sm" fullWidth>
      <DialogTitle>Delete {ids.length} Record{ids.length !== 1 ? 's' : ''}?</DialogTitle>
      <DialogContent>
        {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

        {loading ? (
          <Stack alignItems="center" py={2}>
            <CircularProgress size={24} />
            <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
              Computing impact...
            </Typography>
          </Stack>
        ) : (
          <>
            <DialogContentText>
              {ids.length} record{ids.length !== 1 ? 's' : ''} will be moved to the archive.
              You can restore them from the Recycle Bin.
            </DialogContentText>

            {impact && impact.references.length > 0 && (
              <Alert severity="warning" sx={{ mt: 2 }}>
                <Typography variant="body2" fontWeight={600} gutterBottom>
                  This will affect references in other domains:
                </Typography>
                <ul style={{ margin: 0, paddingLeft: 20 }}>
                  {impact.references.map((ref) => (
                    <li key={`${ref.domain}-${ref.field}`}>
                      <Typography variant="body2">
                        {ref.recordCount} {ref.description}
                      </Typography>
                    </li>
                  ))}
                </ul>
              </Alert>
            )}
          </>
        )}
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} disabled={isBusy}>Cancel</Button>
        <Button
          color="error"
          variant="contained"
          onClick={() => void handleConfirm()}
          disabled={loading || isBusy}
        >
          Delete
        </Button>
      </DialogActions>
    </Dialog>
  )
}

// ─── Bulk Hard Delete Dialog (double-confirmation) ───────────────────────────

interface BulkHardDeleteDialogProps {
  open: boolean
  count: number
  onClose: () => void
  onConfirm: () => void
}

export function BulkHardDeleteDialog({
  open,
  count,
  onClose,
  onConfirm,
}: BulkHardDeleteDialogProps): React.JSX.Element {
  const [isBusy, setBusy] = useState(false)

  const handleConfirm = (): void => {
    setBusy(true)
    onConfirm()
    setBusy(false)
  }

  return (
    <Dialog open={open} onClose={onClose}>
      <DialogTitle>Permanently Delete {count} Record{count !== 1 ? 's' : ''}?</DialogTitle>
      <DialogContent>
        <DialogContentText>
          <strong>{count} record{count !== 1 ? 's' : ''}</strong> will be permanently deleted.
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

// ─── Empty Trash Dialog (double-confirmation) ────────────────────────────────

interface EmptyTrashDialogProps {
  open: boolean
  totalCount: number
  onClose: () => void
  onConfirm: () => void
}

export function EmptyTrashDialog({
  open,
  totalCount,
  onClose,
  onConfirm,
}: EmptyTrashDialogProps): React.JSX.Element {
  const [step, setStep] = useState<1 | 2>(1)
  const [isBusy, setBusy] = useState(false)

  useEffect(() => {
    if (open) setStep(1)
  }, [open])

  const handleConfirm = async (): Promise<void> => {
    if (step === 1) {
      setStep(2)
      return
    }
    setBusy(true)
    onConfirm()
    setBusy(false)
  }

  return (
    <Dialog open={open} onClose={onClose}>
      <DialogTitle>Empty Trash?</DialogTitle>
      <DialogContent>
        {step === 1 ? (
          <DialogContentText>
            This will permanently delete <strong>all {totalCount} archived record{totalCount !== 1 ? 's' : ''}</strong> across
            all domains. This action cannot be undone.
          </DialogContentText>
        ) : (
          <Alert severity="error">
            <Typography variant="body2" fontWeight={600}>
              Are you absolutely sure? This will permanently remove {totalCount} record{totalCount !== 1 ? 's' : ''}.
              There is no way to recover them.
            </Typography>
          </Alert>
        )}
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} disabled={isBusy}>Cancel</Button>
        <Button
          color="error"
          variant="contained"
          onClick={() => void handleConfirm()}
          disabled={isBusy}
        >
          {step === 1 ? 'Continue' : 'Permanently Delete All'}
        </Button>
      </DialogActions>
    </Dialog>
  )
}

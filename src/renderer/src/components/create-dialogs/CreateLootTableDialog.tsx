import {
  Alert,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  InputAdornment,
  Stack,
  TextField,
  Typography,
} from '@mui/material'
import { useEffect, useState } from 'react'
import { lootTablesApi } from '../../../api/loot-tables.api'
import type { LootTableRecord } from '../../../../shared/domain-types'
import { slugify } from '../../utils/slugify'

interface CreateLootTableDialogProps {
  open: boolean
  onClose: () => void
  onCreated: (record: LootTableRecord) => void
}

export function CreateLootTableDialog({ open, onClose, onCreated }: CreateLootTableDialogProps): React.JSX.Element {
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
        <Button data-tid="dialog-create-cancel" onClick={onClose} disabled={isBusy}>Cancel</Button>
        <Button data-tid="dialog-create-confirm" variant="contained" onClick={() => void handleCreate()} disabled={!displayName.trim() || isBusy}>Create Loot Table</Button>
      </DialogActions>
    </Dialog>
  )
}

import {
  Alert,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControl,
  InputAdornment,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  TextField,
  Typography,
} from '@mui/material'
import { useEffect, useState } from 'react'
import { npcsApi } from '../../../api/npcs.api'
import type { MetaNpcType, NpcRecord } from '../../../../shared/domain-types'
import { slugify } from '../../utils/slugify'

interface CreateNpcDialogProps {
  open: boolean
  npcTypes: MetaNpcType[]
  onClose: () => void
  onCreated: (record: NpcRecord) => void
}

export function CreateNpcDialog({ open, npcTypes, onClose, onCreated }: CreateNpcDialogProps): React.JSX.Element {
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

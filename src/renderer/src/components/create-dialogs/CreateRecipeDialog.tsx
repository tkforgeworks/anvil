import {
  Alert,
  Autocomplete,
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
import { recipesApi } from '../../../api/recipes.api'
import type {
  ItemRecord,
  MetaCraftingSpecialization,
  MetaCraftingStation,
  RecipeRecord,
} from '../../../../shared/domain-types'
import { slugify } from '../../utils/slugify'

interface CreateRecipeDialogProps {
  open: boolean
  items: ItemRecord[]
  stations: MetaCraftingStation[]
  specializations: MetaCraftingSpecialization[]
  onClose: () => void
  onCreated: (record: RecipeRecord) => void
}

export function CreateRecipeDialog({
  open,
  items,
  stations,
  specializations,
  onClose,
  onCreated,
}: CreateRecipeDialogProps): React.JSX.Element {
  const [displayName, setDisplayName] = useState('')
  const [exportKey, setExportKey] = useState('')
  const [exportKeyTouched, setExportKeyTouched] = useState(false)
  const [outputItemId, setOutputItemId] = useState('')
  const [outputQuantity, setOutputQuantity] = useState('1')
  const [craftingStationId, setCraftingStationId] = useState('')
  const [craftingSpecializationId, setCraftingSpecializationId] = useState('')
  const [isBusy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const outputItem = items.find((item) => item.id === outputItemId) ?? null

  useEffect(() => {
    if (!open) return
    setDisplayName('')
    setExportKey('')
    setExportKeyTouched(false)
    setOutputItemId(items[0]?.id ?? '')
    setOutputQuantity('1')
    setCraftingStationId('')
    setCraftingSpecializationId('')
    setError(null)
  }, [open, items])

  const handleDisplayNameChange = (value: string): void => {
    setDisplayName(value)
    if (!exportKeyTouched) setExportKey(slugify(value))
  }

  const handleCreate = async (): Promise<void> => {
    if (!displayName.trim() || !outputItemId) return
    setBusy(true)
    setError(null)
    try {
      const record = await recipesApi.create({
        displayName: displayName.trim(),
        exportKey: exportKey.trim() || slugify(displayName.trim()),
        outputItemId,
        outputQuantity: Math.max(1, parseInt(outputQuantity, 10) || 1),
        craftingStationId: craftingStationId || null,
        craftingSpecializationId: craftingSpecializationId || null,
      })
      onCreated(record)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to create recipe.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <Dialog open={open} onClose={onClose} fullWidth maxWidth="sm">
      <DialogTitle>New Recipe</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ pt: 1 }}>
          {error && <Alert severity="error">{error}</Alert>}
          {items.length === 0 && <Alert severity="info">Create an item before adding a recipe.</Alert>}
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
          <Stack direction="row" spacing={2}>
            <Autocomplete
              options={items}
              value={outputItem}
              getOptionLabel={(item) => item.displayName}
              isOptionEqualToValue={(option, value) => option.id === value.id}
              onChange={(_, item) => setOutputItemId(item?.id ?? '')}
              renderInput={(params) => <TextField {...params} label="Output Item" required />}
              sx={{ flex: 1 }}
            />
            <TextField label="Output Quantity" type="number" value={outputQuantity} onChange={(e) => setOutputQuantity(e.target.value)} inputProps={{ min: 1, step: 1 }} sx={{ width: 180 }} />
          </Stack>
          <Stack direction="row" spacing={2}>
            <FormControl fullWidth>
              <InputLabel id="create-station-label">Crafting Station</InputLabel>
              <Select labelId="create-station-label" label="Crafting Station" value={craftingStationId} onChange={(e) => setCraftingStationId(e.target.value)}>
                <MenuItem value="">None</MenuItem>
                {stations.map((station) => <MenuItem key={station.id} value={station.id}>{station.displayName}</MenuItem>)}
              </Select>
            </FormControl>
            <FormControl fullWidth>
              <InputLabel id="create-specialization-label">Specialization</InputLabel>
              <Select labelId="create-specialization-label" label="Specialization" value={craftingSpecializationId} onChange={(e) => setCraftingSpecializationId(e.target.value)}>
                <MenuItem value="">None</MenuItem>
                {specializations.map((specialization) => <MenuItem key={specialization.id} value={specialization.id}>{specialization.displayName}</MenuItem>)}
              </Select>
            </FormControl>
          </Stack>
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button data-tid="dialog-create-cancel" onClick={onClose} disabled={isBusy}>Cancel</Button>
        <Button data-tid="dialog-create-confirm" variant="contained" onClick={() => void handleCreate()} disabled={!displayName.trim() || !outputItemId || isBusy}>Create Recipe</Button>
      </DialogActions>
    </Dialog>
  )
}

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
import { itemsApi } from '../../../api/items.api'
import type { ItemRecord, MetaItemCategory, MetaRarity } from '../../../../shared/domain-types'
import { slugify } from '../../utils/slugify'

interface CreateItemDialogProps {
  open: boolean
  categories: MetaItemCategory[]
  rarities: MetaRarity[]
  onClose: () => void
  onCreated: (record: ItemRecord) => void
}

export function CreateItemDialog({
  open,
  categories,
  rarities,
  onClose,
  onCreated,
}: CreateItemDialogProps): React.JSX.Element {
  const [displayName, setDisplayName] = useState('')
  const [exportKey, setExportKey] = useState('')
  const [exportKeyTouched, setExportKeyTouched] = useState(false)
  const [itemCategoryId, setItemCategoryId] = useState('')
  const [rarityId, setRarityId] = useState('')
  const [description, setDescription] = useState('')
  const [isBusy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    setDisplayName('')
    setExportKey('')
    setExportKeyTouched(false)
    setItemCategoryId(categories[0]?.id ?? '')
    setRarityId(rarities[0]?.id ?? '')
    setDescription('')
    setError(null)
  }, [open, categories, rarities])

  const handleDisplayNameChange = (value: string): void => {
    setDisplayName(value)
    if (!exportKeyTouched) setExportKey(slugify(value))
  }

  const handleExportKeyChange = (value: string): void => {
    setExportKey(value)
    setExportKeyTouched(true)
  }

  const handleCreate = async (): Promise<void> => {
    if (!displayName.trim() || !itemCategoryId || !rarityId) return
    setBusy(true)
    setError(null)
    try {
      const record = await itemsApi.create({
        displayName: displayName.trim(),
        exportKey: exportKey.trim() || slugify(displayName.trim()),
        description: description.trim(),
        itemCategoryId,
        rarityId,
      })
      onCreated(record)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to create item.')
    } finally {
      setBusy(false)
    }
  }

  const canCreate = Boolean(displayName.trim() && itemCategoryId && rarityId && !isBusy)

  return (
    <Dialog open={open} onClose={onClose} fullWidth maxWidth="sm">
      <DialogTitle>New Item</DialogTitle>
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
          <Stack direction="row" spacing={2}>
            <FormControl fullWidth required>
              <InputLabel id="create-item-category-label">Category</InputLabel>
              <Select
                labelId="create-item-category-label"
                label="Category"
                value={itemCategoryId}
                onChange={(e) => setItemCategoryId(e.target.value)}
              >
                {categories.map((category) => (
                  <MenuItem key={category.id} value={category.id}>
                    {category.displayName}
                  </MenuItem>
                ))}
              </Select>
            </FormControl>
            <FormControl fullWidth required>
              <InputLabel id="create-item-rarity-label">Rarity</InputLabel>
              <Select
                labelId="create-item-rarity-label"
                label="Rarity"
                value={rarityId}
                onChange={(e) => setRarityId(e.target.value)}
              >
                {rarities.map((rarity) => (
                  <MenuItem key={rarity.id} value={rarity.id}>
                    {rarity.displayName}
                  </MenuItem>
                ))}
              </Select>
            </FormControl>
          </Stack>
          <TextField
            label="Description"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            multiline
            minRows={3}
            fullWidth
          />
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} disabled={isBusy}>
          Cancel
        </Button>
        <Button variant="contained" onClick={() => void handleCreate()} disabled={!canCreate}>
          Create Item
        </Button>
      </DialogActions>
    </Dialog>
  )
}

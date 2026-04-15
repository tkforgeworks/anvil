import {
  Add as AddIcon,
  ContentCopy as DuplicateIcon,
  Delete as DeleteIcon,
  Edit as EditIcon,
} from '@mui/icons-material'
import {
  Alert,
  Autocomplete,
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
import { itemsApi } from '../../api/items.api'
import { metaApi } from '../../api/meta.api'
import { recipesApi } from '../../api/recipes.api'
import type {
  ItemRecord,
  MetaCraftingSpecialization,
  MetaCraftingStation,
  RecipeRecord,
} from '../../../shared/domain-types'

function slugify(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '')
}

interface CreateDialogProps {
  open: boolean
  items: ItemRecord[]
  stations: MetaCraftingStation[]
  specializations: MetaCraftingSpecialization[]
  onClose: () => void
  onCreated: (record: RecipeRecord) => void
}

function CreateDialog({
  open,
  items,
  stations,
  specializations,
  onClose,
  onCreated,
}: CreateDialogProps): React.JSX.Element {
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
        <Button onClick={onClose} disabled={isBusy}>Cancel</Button>
        <Button variant="contained" onClick={() => void handleCreate()} disabled={!displayName.trim() || !outputItemId || isBusy}>Create Recipe</Button>
      </DialogActions>
    </Dialog>
  )
}

interface DeleteDialogProps {
  record: RecipeRecord | null
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
      await recipesApi.delete(record.id)
      onDeleted(record.id)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to delete recipe.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <Dialog open={Boolean(record)} onClose={onClose}>
      <DialogTitle>Delete Recipe?</DialogTitle>
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

export default function RecipesPage(): React.JSX.Element {
  const navigate = useNavigate()
  const [recipes, setRecipes] = useState<RecipeRecord[]>([])
  const [items, setItems] = useState<ItemRecord[]>([])
  const [stations, setStations] = useState<MetaCraftingStation[]>([])
  const [specializations, setSpecializations] = useState<MetaCraftingSpecialization[]>([])
  const [search, setSearch] = useState('')
  const [stationFilter, setStationFilter] = useState('all')
  const [specializationFilter, setSpecializationFilter] = useState('all')
  const [createOpen, setCreateOpen] = useState(false)
  const [deleteTarget, setDeleteTarget] = useState<RecipeRecord | null>(null)
  const [error, setError] = useState<string | null>(null)

  const itemById = useMemo(() => new Map(items.map((item) => [item.id, item])), [items])
  const stationById = useMemo(() => new Map(stations.map((station) => [station.id, station])), [stations])
  const specializationById = useMemo(
    () => new Map(specializations.map((specialization) => [specialization.id, specialization])),
    [specializations],
  )

  const load = useCallback(async () => {
    setError(null)
    try {
      const [records, itemList, stationList, specializationList] = await Promise.all([
        recipesApi.list(),
        itemsApi.list(),
        metaApi.listCraftingStations(),
        metaApi.listCraftingSpecializations(),
      ])
      setRecipes(records)
      setItems(itemList)
      setStations(stationList)
      setSpecializations(specializationList)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to load recipes.')
    }
  }, [])

  useEffect(() => {
    void load()
  }, [load])

  const handleCreated = (record: RecipeRecord): void => {
    setCreateOpen(false)
    void navigate(`/recipes/${record.id}`)
  }

  const handleDeleted = (id: string): void => {
    setDeleteTarget(null)
    setRecipes((prev) => prev.filter((recipe) => recipe.id !== id))
  }

  const handleDuplicate = async (record: RecipeRecord): Promise<void> => {
    setError(null)
    try {
      const copy = await recipesApi.duplicate(record.id)
      if (copy) setRecipes((prev) => [...prev, copy])
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to duplicate recipe.')
    }
  }

  const filtered = recipes
    .filter((recipe) => recipe.displayName.toLowerCase().includes(search.toLowerCase()))
    .filter((recipe) => stationFilter === 'all' || (recipe.craftingStationId ?? '') === stationFilter)
    .filter((recipe) => specializationFilter === 'all' || (recipe.craftingSpecializationId ?? '') === specializationFilter)
    .sort((a, b) => a.displayName.localeCompare(b.displayName, undefined, { sensitivity: 'base' }))

  return (
    <Box>
      <Stack direction="row" alignItems="center" justifyContent="space-between" sx={{ mb: 3 }}>
        <Typography variant="h5">Crafting Recipes</Typography>
        <Button startIcon={<AddIcon />} variant="contained" onClick={() => setCreateOpen(true)}>New Recipe</Button>
      </Stack>

      {error && <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>{error}</Alert>}

      <Stack direction="row" spacing={2} sx={{ mb: 2 }} flexWrap="wrap" useFlexGap>
        <TextField size="small" placeholder="Search recipes..." value={search} onChange={(e) => setSearch(e.target.value)} sx={{ flex: 1, minWidth: 220, maxWidth: 360 }} />
        <FormControl size="small" sx={{ minWidth: 190 }}>
          <InputLabel id="station-filter-label">Station</InputLabel>
          <Select labelId="station-filter-label" label="Station" value={stationFilter} onChange={(e) => setStationFilter(e.target.value)}>
            <MenuItem value="all">All Stations</MenuItem>
            <MenuItem value="">No Station</MenuItem>
            {stations.map((station) => <MenuItem key={station.id} value={station.id}>{station.displayName}</MenuItem>)}
          </Select>
        </FormControl>
        <FormControl size="small" sx={{ minWidth: 210 }}>
          <InputLabel id="specialization-filter-label">Specialization</InputLabel>
          <Select labelId="specialization-filter-label" label="Specialization" value={specializationFilter} onChange={(e) => setSpecializationFilter(e.target.value)}>
            <MenuItem value="all">All Specializations</MenuItem>
            <MenuItem value="">No Specialization</MenuItem>
            {specializations.map((specialization) => <MenuItem key={specialization.id} value={specialization.id}>{specialization.displayName}</MenuItem>)}
          </Select>
        </FormControl>
      </Stack>

      {filtered.length === 0 ? (
        <Typography variant="body2" color="text.secondary">
          {recipes.length === 0 ? 'No recipes yet. Click "New Recipe" to create one.' : 'No recipes match your filters.'}
        </Typography>
      ) : (
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Name</TableCell>
              <TableCell>Export Key</TableCell>
              <TableCell>Output</TableCell>
              <TableCell>Station</TableCell>
              <TableCell>Specialization</TableCell>
              <TableCell align="right">Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {filtered.map((recipe) => (
              <TableRow key={recipe.id} hover sx={{ cursor: 'pointer' }} onClick={() => void navigate(`/recipes/${recipe.id}`)}>
                <TableCell><Typography variant="body2" fontWeight={500}>{recipe.displayName}</Typography></TableCell>
                <TableCell><Typography variant="body2" color="text.secondary" fontFamily="monospace">{recipe.exportKey}</Typography></TableCell>
                <TableCell><Typography variant="body2" color="text.secondary">{itemById.get(recipe.outputItemId)?.displayName ?? recipe.outputItemId} x{recipe.outputQuantity}</Typography></TableCell>
                <TableCell><Typography variant="body2" color="text.secondary">{recipe.craftingStationId ? stationById.get(recipe.craftingStationId)?.displayName ?? recipe.craftingStationId : '-'}</Typography></TableCell>
                <TableCell><Typography variant="body2" color="text.secondary">{recipe.craftingSpecializationId ? specializationById.get(recipe.craftingSpecializationId)?.displayName ?? recipe.craftingSpecializationId : '-'}</Typography></TableCell>
                <TableCell align="right" onClick={(e) => e.stopPropagation()}>
                  <Tooltip title="Edit"><IconButton size="small" onClick={() => void navigate(`/recipes/${recipe.id}`)}><EditIcon fontSize="small" /></IconButton></Tooltip>
                  <Tooltip title="Duplicate"><IconButton size="small" onClick={() => void handleDuplicate(recipe)}><DuplicateIcon fontSize="small" /></IconButton></Tooltip>
                  <Tooltip title="Delete"><IconButton size="small" color="error" onClick={() => setDeleteTarget(recipe)}><DeleteIcon fontSize="small" /></IconButton></Tooltip>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}

      <CreateDialog open={createOpen} items={items} stations={stations} specializations={specializations} onClose={() => setCreateOpen(false)} onCreated={handleCreated} />
      <DeleteDialog record={deleteTarget} onClose={() => setDeleteTarget(null)} onDeleted={handleDeleted} />
    </Box>
  )
}

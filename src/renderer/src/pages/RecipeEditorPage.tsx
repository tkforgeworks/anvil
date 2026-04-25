import {
  Add as AddIcon,
  ArrowBack as BackIcon,
  ArrowDownward as MoveDownIcon,
  ArrowUpward as MoveUpIcon,
  Delete as DeleteIcon,
} from '@mui/icons-material'
import {
  Alert,
  Autocomplete,
  Box,
  Button,
  Divider,
  FormControl,
  IconButton,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  Tab,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  Tabs,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { itemsApi } from '../../api/items.api'
import { metaApi } from '../../api/meta.api'
import { recipesApi } from '../../api/recipes.api'
import type {
  ItemRecord,
  MetaCraftingSpecialization,
  MetaCraftingStation,
  RecipeIngredient,
  RecipeRecord,
} from '../../../shared/domain-types'
import ValidationBanner from '../components/ValidationBanner'
import { useRecordValidation } from '../hooks/useRecordValidation'
import { fieldValidationProps } from '../hooks/fieldValidationProps'

interface TabPanelProps {
  index: number
  value: number
  children: React.ReactNode
}

function TabPanel({ index, value, children }: TabPanelProps): React.JSX.Element {
  return (
    <Box role="tabpanel" hidden={value !== index} sx={{ pt: 3 }}>
      {value === index && children}
    </Box>
  )
}

function itemLabel(item: ItemRecord | null): string {
  if (!item) return ''
  return item.deletedAt ? `${item.displayName} (deleted)` : item.displayName
}

export default function RecipeEditorPage(): React.JSX.Element {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()

  const [record, setRecord] = useState<RecipeRecord | null>(null)
  const [items, setItems] = useState<ItemRecord[]>([])
  const [stations, setStations] = useState<MetaCraftingStation[]>([])
  const [specializations, setSpecializations] = useState<MetaCraftingSpecialization[]>([])
  const [displayName, setDisplayName] = useState('')
  const [exportKey, setExportKey] = useState('')
  const [description, setDescription] = useState('')
  const [outputItemId, setOutputItemId] = useState('')
  const [outputQuantity, setOutputQuantity] = useState('1')
  const [craftingStationId, setCraftingStationId] = useState('')
  const [craftingSpecializationId, setCraftingSpecializationId] = useState('')
  const [ingredients, setIngredients] = useState<RecipeIngredient[]>([])
  const [isDirty, setDirty] = useState(false)
  const [isSaving, setSaving] = useState(false)
  const [isLoading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [savedAt, setSavedAt] = useState<Date | null>(null)
  const [activeTab, setActiveTab] = useState(0)
  const { recordIssues, issuesForField, runValidation } = useRecordValidation('recipes', id)

  const itemById = useMemo(() => new Map(items.map((item) => [item.id, item])), [items])
  const activeItems = useMemo(() => items.filter((item) => !item.deletedAt), [items])

  const load = useCallback(async () => {
    if (!id) return
    setLoading(true)
    setError(null)
    try {
      const [data, ingredientList, itemList, stationList, specializationList] = await Promise.all([
        recipesApi.get(id),
        recipesApi.getIngredients(id),
        itemsApi.list(true),
        metaApi.listCraftingStations(),
        metaApi.listCraftingSpecializations(),
      ])
      if (!data) {
        setError('Recipe not found.')
        return
      }
      setRecord(data)
      setDisplayName(data.displayName)
      setExportKey(data.exportKey)
      setDescription(data.description)
      setOutputItemId(data.outputItemId)
      setOutputQuantity(String(data.outputQuantity))
      setCraftingStationId(data.craftingStationId ?? '')
      setCraftingSpecializationId(data.craftingSpecializationId ?? '')
      setIngredients(ingredientList)
      setItems(itemList)
      setStations(stationList)
      setSpecializations(specializationList)
      setDirty(false)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to load recipe.')
    } finally {
      setLoading(false)
    }
  }, [id])

  useEffect(() => {
    void load()
  }, [load])

  const markDirty = (): void => {
    setDirty(true)
    setSavedAt(null)
  }

  const setIngredientAt = (index: number, update: Partial<RecipeIngredient>): void => {
    setIngredients((prev) =>
      prev.map((ingredient, i) => (i === index ? { ...ingredient, ...update } : ingredient)),
    )
    markDirty()
  }

  const moveIngredient = (index: number, direction: -1 | 1): void => {
    const nextIndex = index + direction
    if (nextIndex < 0 || nextIndex >= ingredients.length) return
    setIngredients((prev) => {
      const next = [...prev]
      const [entry] = next.splice(index, 1)
      next.splice(nextIndex, 0, entry)
      return next
    })
    markDirty()
  }

  const removeIngredient = (index: number): void => {
    setIngredients((prev) => prev.filter((_, i) => i !== index))
    markDirty()
  }

  const addIngredient = (): void => {
    const itemId = activeItems[0]?.id
    if (!itemId) return
    setIngredients((prev) => [...prev, { itemId, quantity: 1, sortOrder: prev.length }])
    markDirty()
  }

  const handleSave = async (): Promise<void> => {
    if (!id) return
    const normalizedIngredients = ingredients.map((ingredient, index) => ({
      itemId: ingredient.itemId,
      quantity: Math.max(1, Math.floor(ingredient.quantity || 1)),
      sortOrder: index,
    }))
    if (normalizedIngredients.some((ingredient) => ingredient.itemId === outputItemId)) {
      setActiveTab(1)
      setError('A recipe ingredient cannot be the same item as the output item.')
      return
    }

    setSaving(true)
    setError(null)
    try {
      const updated = await recipesApi.update(id, {
        displayName: displayName.trim(),
        exportKey: exportKey.trim(),
        description: description.trim(),
        outputItemId,
        outputQuantity: Math.max(1, parseInt(outputQuantity, 10) || 1),
        craftingStationId: craftingStationId || null,
        craftingSpecializationId: craftingSpecializationId || null,
      })
      await recipesApi.setIngredients(id, normalizedIngredients)
      if (updated) {
        setRecord(updated)
        setOutputQuantity(String(updated.outputQuantity))
        setIngredients(normalizedIngredients)
        setDirty(false)
        setSavedAt(new Date())
        await runValidation()
      }
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to save recipe.')
    } finally {
      setSaving(false)
    }
  }

  if (isLoading) {
    return (
      <Box sx={{ p: 4 }}>
        <Typography color="text.secondary">Loading...</Typography>
      </Box>
    )
  }

  if (!record) {
    return (
      <Box sx={{ p: 4 }}>
        <Alert severity="error">{error ?? 'Recipe not found.'}</Alert>
        <Button sx={{ mt: 2 }} onClick={() => void navigate('/recipes')}>
          Back to Recipes
        </Button>
      </Box>
    )
  }

  const outputItem = itemById.get(outputItemId) ?? null
  const hasDeletedReferences =
    Boolean(outputItem?.deletedAt) ||
    ingredients.some((ingredient) => itemById.get(ingredient.itemId)?.deletedAt)
  const hasOutputAsIngredient = ingredients.some((ingredient) => ingredient.itemId === outputItemId)

  return (
    <Box>
      <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1 }}>
        <Tooltip title="Back to Recipes">
          <IconButton size="small" onClick={() => void navigate('/recipes')}>
            <BackIcon fontSize="small" />
          </IconButton>
        </Tooltip>
        <Typography variant="caption" color="text.secondary">
          Crafting Recipes
        </Typography>
      </Stack>

      <Stack direction="row" alignItems="flex-start" justifyContent="space-between" sx={{ mb: 3 }} spacing={2}>
        <Box sx={{ flex: 1, minWidth: 0 }}>
          <TextField
            variant="standard"
            value={displayName}
            onChange={(e) => { setDisplayName(e.target.value); markDirty() }}
            inputProps={{ style: { fontSize: '1.5rem', fontWeight: 600 } }}
            placeholder="Recipe Name"
            fullWidth
            sx={{ mb: 0.5 }}
          />
          <TextField
            variant="standard"
            value={exportKey}
            onChange={(e) => { setExportKey(e.target.value); markDirty() }}
            inputProps={{ style: { fontFamily: 'monospace', fontSize: '0.8rem' } }}
            placeholder="export-key"
            helperText="Export key - used in exported files"
            sx={{ maxWidth: 360 }}
          />
        </Box>
        <Stack direction="row" alignItems="center" spacing={2} sx={{ pt: 0.5 }}>
          {savedAt && <Typography variant="caption" color="success.main">Saved at {savedAt.toLocaleTimeString()}</Typography>}
          <Button variant="contained" onClick={() => void handleSave()} disabled={!isDirty || isSaving || !displayName.trim() || !exportKey.trim() || !outputItemId || hasOutputAsIngredient}>
            Save
          </Button>
        </Stack>
      </Stack>

      {error && <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>{error}</Alert>}
      <ValidationBanner issues={recordIssues} />
      {hasDeletedReferences && <Alert severity="warning" sx={{ mb: 2 }}>This recipe references a soft-deleted item. Validation will flag this recipe.</Alert>}
      {hasOutputAsIngredient && <Alert severity="error" sx={{ mb: 2 }}>The output item cannot also be an ingredient.</Alert>}

      <Divider sx={{ mb: 0 }} />
      <Tabs value={activeTab} onChange={(_, value: number) => setActiveTab(value)}>
        <Tab label="Details" />
        <Tab label="Ingredients" />
      </Tabs>
      <Divider />

      <TabPanel index={0} value={activeTab}>
        <Stack spacing={3} sx={{ maxWidth: 760 }}>
          <Stack direction="row" spacing={2}>
            <Autocomplete
              options={activeItems}
              value={outputItem}
              getOptionLabel={itemLabel}
              isOptionEqualToValue={(option, value) => option.id === value.id}
              onChange={(_, item) => { setOutputItemId(item?.id ?? ''); markDirty() }}
              renderInput={(params) => <TextField {...params} label="Output Item" required {...fieldValidationProps(issuesForField('outputItemId'))} />}
              sx={{ flex: 1 }}
            />
            <TextField
              label="Output Quantity"
              type="number"
              value={outputQuantity}
              onChange={(e) => { setOutputQuantity(e.target.value); markDirty() }}
              inputProps={{ min: 1, step: 1 }}
              sx={{ width: 180 }}
            />
          </Stack>

          {outputItem?.deletedAt && <Alert severity="warning">The selected output item is soft-deleted.</Alert>}

          <Stack direction="row" spacing={2}>
            <FormControl fullWidth error={issuesForField('craftingStationId').length > 0}>
              <InputLabel id="recipe-station-label">Crafting Station</InputLabel>
              <Select labelId="recipe-station-label" label="Crafting Station" value={craftingStationId} onChange={(e) => { setCraftingStationId(e.target.value); markDirty() }}>
                <MenuItem value="">None</MenuItem>
                {stations.map((station) => <MenuItem key={station.id} value={station.id}>{station.displayName}</MenuItem>)}
              </Select>
            </FormControl>
            <FormControl fullWidth error={issuesForField('craftingSpecializationId').length > 0}>
              <InputLabel id="recipe-specialization-label">Specialization</InputLabel>
              <Select labelId="recipe-specialization-label" label="Specialization" value={craftingSpecializationId} onChange={(e) => { setCraftingSpecializationId(e.target.value); markDirty() }}>
                <MenuItem value="">None</MenuItem>
                {specializations.map((specialization) => <MenuItem key={specialization.id} value={specialization.id}>{specialization.displayName}</MenuItem>)}
              </Select>
            </FormControl>
          </Stack>

          <TextField label="Description" value={description} onChange={(e) => { setDescription(e.target.value); markDirty() }} multiline minRows={4} fullWidth />
        </Stack>
      </TabPanel>

      <TabPanel index={1} value={activeTab}>
        <Stack spacing={2} sx={{ maxWidth: 860 }}>
          <Stack direction="row" justifyContent="space-between" alignItems="center">
            <Typography variant="subtitle1">Ingredients</Typography>
            <Button startIcon={<AddIcon />} variant="outlined" size="small" onClick={addIngredient} disabled={activeItems.length === 0}>
              Add Ingredient
            </Button>
          </Stack>
          {activeItems.length === 0 && <Alert severity="info">Create an active item before adding ingredients.</Alert>}
          {ingredients.length === 0 ? (
            <Typography variant="body2" color="text.secondary">No ingredients yet.</Typography>
          ) : (
            <Table size="small">
              <TableHead>
                <TableRow>
                  <TableCell>Item</TableCell>
                  <TableCell width={140}>Quantity</TableCell>
                  <TableCell width={140} align="right">Actions</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {ingredients.map((ingredient, index) => {
                  const item = itemById.get(ingredient.itemId) ?? null
                  const isDeleted = Boolean(item?.deletedAt)
                  const matchesOutput = ingredient.itemId === outputItemId
                  return (
                    <TableRow key={`${ingredient.itemId}:${index}`}>
                      <TableCell>
                        <Autocomplete
                          options={activeItems}
                          value={item}
                          getOptionLabel={itemLabel}
                          isOptionEqualToValue={(option, value) => option.id === value.id}
                          onChange={(_, selectedItem) => {
                            if (!selectedItem) return
                            setIngredientAt(index, { itemId: selectedItem.id })
                          }}
                          renderInput={(params) => (
                            <TextField
                              {...params}
                              label="Ingredient Item"
                              size="small"
                              error={isDeleted || matchesOutput}
                              helperText={matchesOutput ? 'Output item cannot be an ingredient' : isDeleted ? 'Soft-deleted item reference' : undefined}
                            />
                          )}
                        />
                        {isDeleted && <Typography variant="caption" color="warning.main" sx={{ textDecoration: 'line-through' }}>{item?.displayName}</Typography>}
                      </TableCell>
                      <TableCell>
                        <TextField
                          type="number"
                          size="small"
                          value={ingredient.quantity}
                          onChange={(e) => setIngredientAt(index, { quantity: Math.max(1, parseInt(e.target.value, 10) || 1) })}
                          inputProps={{ min: 1, step: 1 }}
                          fullWidth
                        />
                      </TableCell>
                      <TableCell align="right">
                        <Tooltip title="Move up"><span><IconButton size="small" onClick={() => moveIngredient(index, -1)} disabled={index === 0}><MoveUpIcon fontSize="small" /></IconButton></span></Tooltip>
                        <Tooltip title="Move down"><span><IconButton size="small" onClick={() => moveIngredient(index, 1)} disabled={index === ingredients.length - 1}><MoveDownIcon fontSize="small" /></IconButton></span></Tooltip>
                        <Tooltip title="Remove"><IconButton size="small" color="error" onClick={() => removeIngredient(index)}><DeleteIcon fontSize="small" /></IconButton></Tooltip>
                      </TableCell>
                    </TableRow>
                  )
                })}
              </TableBody>
            </Table>
          )}
        </Stack>
      </TabPanel>
    </Box>
  )
}

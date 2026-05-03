import {
  Add as AddIcon,
  ArrowDownward as MoveDownIcon,
  ArrowUpward as MoveUpIcon,
  Delete as DeleteIcon,
} from '@mui/icons-material'
import {
  Alert,
  Autocomplete,
  Box,
  Button,
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
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useUndoRedo } from '../hooks/useUndoRedo'
import { useTabDirtyTracking } from '../hooks/useTabDirtyTracking'
import DirtyDot from '../components/DirtyDot'
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
import EditHeader from '../components/EditHeader'
import OverviewTab from '../components/OverviewTab'
import SaveBar from '../components/SaveBar'
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

interface FormSnapshot {
  displayName: string
  exportKey: string
  description: string
  outputItemId: string
  outputQuantity: string
  craftingStationId: string
  craftingSpecializationId: string
  ingredients: RecipeIngredient[]
}

function itemLabel(item: ItemRecord | null): string {
  if (!item) return ''
  return item.deletedAt ? `${item.displayName} (deleted)` : item.displayName
}

interface RecipeEditorPageProps {
  recordId?: string
  onClose?: () => void
}

export default function RecipeEditorPage({ recordId, onClose }: RecipeEditorPageProps = {}): React.JSX.Element {
  const { id: paramId } = useParams<{ id: string }>()
  const id = recordId ?? paramId
  const navigate = useNavigate()
  const goBack = onClose ?? (() => void navigate('/recipes'))

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

  type TabFields = Omit<FormSnapshot, 'displayName' | 'exportKey'>
  const baselineRef = useRef<TabFields | null>(null)

  const tabFieldMap: Record<number, (keyof TabFields)[]> = useMemo(() => ({
    1: ['description', 'outputItemId', 'outputQuantity', 'craftingStationId', 'craftingSpecializationId'],
    2: ['ingredients'],
  }), [])

  const currentTabFields: TabFields = useMemo(() => ({
    description,
    outputItemId,
    outputQuantity,
    craftingStationId,
    craftingSpecializationId,
    ingredients,
  }), [description, outputItemId, outputQuantity, craftingStationId, craftingSpecializationId, ingredients])

  const dirtyTabs = useTabDirtyTracking(currentTabFields, baselineRef.current, tabFieldMap)

  const applySnapshot = useCallback((snapshot: FormSnapshot) => {
    setDisplayName(snapshot.displayName)
    setExportKey(snapshot.exportKey)
    setDescription(snapshot.description)
    setOutputItemId(snapshot.outputItemId)
    setOutputQuantity(snapshot.outputQuantity)
    setCraftingStationId(snapshot.craftingStationId)
    setCraftingSpecializationId(snapshot.craftingSpecializationId)
    setIngredients(snapshot.ingredients)
    setDirty(true)
    setSavedAt(null)
  }, [])

  const undoRedo = useUndoRedo<FormSnapshot>(applySnapshot)

  const pushSnapshot = (overrides: Partial<FormSnapshot> = {}): void => {
    setDirty(true)
    setSavedAt(null)
    undoRedo.pushState({
      displayName,
      exportKey,
      description,
      outputItemId,
      outputQuantity,
      craftingStationId,
      craftingSpecializationId,
      ingredients,
      ...overrides,
    })
  }

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
      baselineRef.current = {
        description: data.description,
        outputItemId: data.outputItemId,
        outputQuantity: String(data.outputQuantity),
        craftingStationId: data.craftingStationId ?? '',
        craftingSpecializationId: data.craftingSpecializationId ?? '',
        ingredients: ingredientList,
      }
      undoRedo.reset({
        displayName: data.displayName,
        exportKey: data.exportKey,
        description: data.description,
        outputItemId: data.outputItemId,
        outputQuantity: String(data.outputQuantity),
        craftingStationId: data.craftingStationId ?? '',
        craftingSpecializationId: data.craftingSpecializationId ?? '',
        ingredients: ingredientList,
      })
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to load recipe.')
    } finally {
      setLoading(false)
    }
  }, [id])

  useEffect(() => {
    void load()
  }, [load])

  const setIngredientAt = (index: number, update: Partial<RecipeIngredient>): void => {
    const nextIngredients = ingredients.map((ingredient, i) =>
      i === index ? { ...ingredient, ...update } : ingredient,
    )
    setIngredients(nextIngredients)
    pushSnapshot({ ingredients: nextIngredients })
  }

  const moveIngredient = (index: number, direction: -1 | 1): void => {
    const nextIndex = index + direction
    if (nextIndex < 0 || nextIndex >= ingredients.length) return
    const next = [...ingredients]
    const [entry] = next.splice(index, 1)
    next.splice(nextIndex, 0, entry)
    setIngredients(next)
    pushSnapshot({ ingredients: next })
  }

  const removeIngredient = (index: number): void => {
    const nextIngredients = ingredients.filter((_, i) => i !== index)
    setIngredients(nextIngredients)
    pushSnapshot({ ingredients: nextIngredients })
  }

  const addIngredient = (): void => {
    const itemId = activeItems[0]?.id
    if (!itemId) return
    const nextIngredients = [...ingredients, { itemId, quantity: 1, sortOrder: ingredients.length }]
    setIngredients(nextIngredients)
    pushSnapshot({ ingredients: nextIngredients })
  }

  const handleSave = async (): Promise<void> => {
    if (!id) return
    const normalizedIngredients = ingredients.map((ingredient, index) => ({
      itemId: ingredient.itemId,
      quantity: Math.max(1, Math.floor(ingredient.quantity || 1)),
      sortOrder: index,
    }))
    if (normalizedIngredients.some((ingredient) => ingredient.itemId === outputItemId)) {
      setActiveTab(2)
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
        baselineRef.current = {
          description: description.trim(),
          outputItemId,
          outputQuantity: String(updated.outputQuantity),
          craftingStationId,
          craftingSpecializationId,
          ingredients: normalizedIngredients,
        }
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
        <Button sx={{ mt: 2 }} onClick={goBack}>
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

  const handleBack = goBack
  const handleDiscard = (): void => void load()

  return (
    <Box>
      <Box sx={{ position: 'sticky', top: 0, zIndex: 10, bgcolor: 'background.default', mt: -3, pt: 3 }}>
        <EditHeader
          backLabel="Crafting Recipes"
          onBack={handleBack}
          displayName={displayName}
          onDisplayNameChange={(value) => {
            setDisplayName(value)
            pushSnapshot({ displayName: value })
          }}
          exportKey={exportKey}
          isDirty={isDirty}
          isSaving={isSaving}
          onSave={() => void handleSave()}
          savedAt={savedAt}
          canUndo={undoRedo.canUndo}
          canRedo={undoRedo.canRedo}
          onUndo={undoRedo.triggerUndo}
          onRedo={undoRedo.triggerRedo}
        />

        <Tabs value={activeTab} onChange={(_, value: number) => setActiveTab(value)}>
          <Tab label="Overview" data-tid="tab-recipe-overview" />
          <Tab label={<span>Details<DirtyDot visible={dirtyTabs.has(1)} /></span>} data-tid="tab-recipe-details" />
          <Tab label={<span>Ingredients<DirtyDot visible={dirtyTabs.has(2)} /></span>} data-tid="tab-recipe-ingredients" />
        </Tabs>
      </Box>

      {error && <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>{error}</Alert>}
      <ValidationBanner issues={recordIssues} />
      {hasDeletedReferences && <Alert severity="warning" sx={{ mb: 2 }}>This recipe references a soft-deleted item. Validation will flag this recipe.</Alert>}
      {hasOutputAsIngredient && <Alert severity="error" sx={{ mb: 2 }}>The output item cannot also be an ingredient.</Alert>}

      <TabPanel index={0} value={activeTab}>
        <OverviewTab displayName={displayName} description={description} />
      </TabPanel>

      <TabPanel index={1} value={activeTab}>
        <Stack spacing={3} sx={{ maxWidth: 760 }}>
          <TextField
            label="Export Key"
            value={exportKey}
            onChange={(e) => {
              setExportKey(e.target.value)
              pushSnapshot({ exportKey: e.target.value })
            }}
            inputProps={{ style: { fontFamily: '"JetBrains Mono", monospace', fontSize: '0.85rem' } }}
            placeholder="export-key"
            helperText="Export key — used in exported files"
            sx={{ maxWidth: 360 }}
          />
          <Stack direction="row" spacing={2}>
            <Autocomplete
              options={activeItems}
              value={outputItem}
              getOptionLabel={itemLabel}
              isOptionEqualToValue={(option, value) => option.id === value.id}
              onChange={(_, item) => { setOutputItemId(item?.id ?? ''); pushSnapshot({ outputItemId: item?.id ?? '' }) }}
              renderInput={(params) => <TextField {...params} label="Output Item" required {...fieldValidationProps(issuesForField('outputItemId'))} />}
              sx={{ flex: 1 }}
            />
            <TextField
              label="Output Quantity"
              type="number"
              value={outputQuantity}
              onChange={(e) => { setOutputQuantity(e.target.value); pushSnapshot({ outputQuantity: e.target.value }) }}
              inputProps={{ min: 1, step: 1 }}
              sx={{ width: 180 }}
            />
          </Stack>

          {outputItem?.deletedAt && <Alert severity="warning">The selected output item is soft-deleted.</Alert>}

          <Stack direction="row" spacing={2}>
            <FormControl fullWidth error={issuesForField('craftingStationId').length > 0}>
              <InputLabel id="recipe-station-label">Crafting Station</InputLabel>
              <Select labelId="recipe-station-label" label="Crafting Station" value={craftingStationId} onChange={(e) => { setCraftingStationId(e.target.value); pushSnapshot({ craftingStationId: e.target.value }) }}>
                <MenuItem value="">None</MenuItem>
                {stations.map((station) => <MenuItem key={station.id} value={station.id}>{station.displayName}</MenuItem>)}
              </Select>
            </FormControl>
            <FormControl fullWidth error={issuesForField('craftingSpecializationId').length > 0}>
              <InputLabel id="recipe-specialization-label">Specialization</InputLabel>
              <Select labelId="recipe-specialization-label" label="Specialization" value={craftingSpecializationId} onChange={(e) => { setCraftingSpecializationId(e.target.value); pushSnapshot({ craftingSpecializationId: e.target.value }) }}>
                <MenuItem value="">None</MenuItem>
                {specializations.map((specialization) => <MenuItem key={specialization.id} value={specialization.id}>{specialization.displayName}</MenuItem>)}
              </Select>
            </FormControl>
          </Stack>

          <TextField label="Description" value={description} onChange={(e) => { setDescription(e.target.value); pushSnapshot({ description: e.target.value }) }} multiline minRows={4} fullWidth />
        </Stack>
      </TabPanel>

      <TabPanel index={2} value={activeTab}>
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

      <SaveBar
        isDirty={isDirty}
        isSaving={isSaving}
        onSave={() => void handleSave()}
        onDiscard={handleDiscard}
      />
    </Box>
  )
}

import {
  Construction as RecipesIcon,
  ContentCopy as DuplicateIcon,
  Delete as DeleteIcon,
  Edit as EditIcon,
} from '@mui/icons-material'
import {
  Alert,
  Box,
  Button,
  Checkbox,
  Dialog,
  DialogActions,
  DialogContent,
  DialogContentText,
  DialogTitle,
  FormControl,
  IconButton,
  InputLabel,
  MenuItem,
  Paper,
  Select,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  Tooltip,
  Typography,
} from '@mui/material'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { itemsApi } from '../../api/items.api'
import { lifecycleApi } from '../../api/lifecycle.api'
import { metaApi } from '../../api/meta.api'
import { recipesApi } from '../../api/recipes.api'
import type {
  ItemRecord,
  MetaCraftingSpecialization,
  MetaCraftingStation,
  RecipeRecord,
} from '../../../shared/domain-types'
import { ArchiveTable, type ViewMode } from '../components/ArchiveView'
import { BulkActionToolbar, BulkDeleteDialog } from '../components/BulkActions'
import { CreateRecipeDialog } from '../components/create-dialogs'
import EditorModal from '../components/EditorModal'
import DeferredLoader from '../components/DeferredLoader'
import EmptyState from '../components/EmptyState'
import ListToolbar from '../components/ListToolbar'
import PageHeader from '../components/PageHeader'
import { useMultiSelect } from '../hooks/useMultiSelect'
import { useUiStore } from '../stores/ui.store'
import RecipeEditorPage from './RecipeEditorPage'

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
  const editingMode = useUiStore((s) => s.editingMode)
  const [recipes, setRecipes] = useState<RecipeRecord[]>([])
  const [archivedRecipes, setArchivedRecipes] = useState<RecipeRecord[]>([])
  const [viewMode, setViewMode] = useState<ViewMode>('active')
  const [items, setItems] = useState<ItemRecord[]>([])
  const [stations, setStations] = useState<MetaCraftingStation[]>([])
  const [specializations, setSpecializations] = useState<MetaCraftingSpecialization[]>([])
  const [search, setSearch] = useState('')
  const [stationFilter, setStationFilter] = useState('all')
  const [specializationFilter, setSpecializationFilter] = useState('all')
  const [createOpen, setCreateOpen] = useState(false)
  const [deleteTarget, setDeleteTarget] = useState<RecipeRecord | null>(null)
  const [bulkDeleteOpen, setBulkDeleteOpen] = useState(false)
  const [isLoading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [modalRecordId, setModalRecordId] = useState<string | null>(null)
  const multiSelect = useMultiSelect()

  const openEditor = (id: string): void => {
    if (editingMode === 'modal') setModalRecordId(id)
    else void navigate(`/recipes/${id}`)
  }

  const itemById = useMemo(() => new Map(items.map((item) => [item.id, item])), [items])
  const stationById = useMemo(() => new Map(stations.map((station) => [station.id, station])), [stations])
  const specializationById = useMemo(
    () => new Map(specializations.map((specialization) => [specialization.id, specialization])),
    [specializations],
  )

  const load = useCallback(async () => {
    setLoading(true)
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
    } finally {
      setLoading(false)
    }
  }, [])

  const loadArchived = useCallback(async () => {
    setLoading(true)
    try {
      const records = await recipesApi.list(false, true)
      setArchivedRecipes(records)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to load archived recipes.')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    multiSelect.clear()
    if (viewMode === 'active') void load()
    else void loadArchived()
  }, [load, loadArchived, viewMode])

  const handleCreated = (record: RecipeRecord): void => {
    setCreateOpen(false)
    openEditor(record.id)
  }

  const handleDeleted = (id: string): void => {
    setDeleteTarget(null)
    setRecipes((prev) => prev.filter((recipe) => recipe.id !== id))
  }

  const handleArchiveRestore = async (id: string): Promise<void> => {
    await recipesApi.restore(id)
    setArchivedRecipes((prev) => prev.filter((r) => r.id !== id))
  }

  const handleArchiveHardDelete = async (id: string): Promise<void> => {
    await recipesApi.hardDelete(id)
    setArchivedRecipes((prev) => prev.filter((r) => r.id !== id))
  }

  const handleArchiveBulkRestore = async (ids: string[]): Promise<void> => {
    await lifecycleApi.bulkRestore('recipes', ids)
    void loadArchived()
  }

  const handleArchiveBulkHardDelete = async (ids: string[]): Promise<void> => {
    await lifecycleApi.bulkHardDelete('recipes', ids)
    void loadArchived()
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

  const handleBulkDelete = async (): Promise<void> => {
    setError(null)
    try {
      await lifecycleApi.bulkSoftDelete('recipes', [...multiSelect.selected])
      setBulkDeleteOpen(false)
      multiSelect.clear()
      void load()
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Bulk delete failed.')
    }
  }

  const filtered = recipes
    .filter((recipe) => recipe.displayName.toLowerCase().includes(search.toLowerCase()))
    .filter((recipe) => stationFilter === 'all' || (recipe.craftingStationId ?? '') === stationFilter)
    .filter((recipe) => specializationFilter === 'all' || (recipe.craftingSpecializationId ?? '') === specializationFilter)
    .sort((a, b) => a.displayName.localeCompare(b.displayName, undefined, { sensitivity: 'base' }))

  const filteredIds = filtered.map((recipe) => recipe.id)

  const recipeFilterSlot = (
    <>
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
    </>
  )

  return (
    <Box>
      <PageHeader title="Crafting Recipes" />
      <ListToolbar
        search={search}
        onSearchChange={setSearch}
        sortKey="name"
        onSortChange={() => {}}
        sortOptions={[{ value: 'name', label: 'Name' }]}
        viewMode={viewMode}
        onViewModeChange={setViewMode}
        onNew={() => setCreateOpen(true)}
        newLabel="+ New Recipe"
        filterSlot={recipeFilterSlot}
      />

      {error && <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>{error}</Alert>}

      {isLoading ? (
        <DeferredLoader />
      ) : viewMode === 'archived' ? (
        <ArchiveTable
          records={archivedRecipes}
          domainLabel="Recipe"
          emptyMessage="No archived recipes."
          error={error}
          onClearError={() => setError(null)}
          onRestore={handleArchiveRestore}
          onHardDelete={handleArchiveHardDelete}
          onBulkRestore={handleArchiveBulkRestore}
          onBulkHardDelete={handleArchiveBulkHardDelete}
        />
      ) : (
        <>
      <BulkActionToolbar
        count={multiSelect.count}
        mode="active"
        onBulkDelete={() => setBulkDeleteOpen(true)}
      />

      <Paper variant="outlined" sx={{ borderRadius: 2.5 }}>
        {filtered.length === 0 ? (
          recipes.length === 0 ? (
            <EmptyState
              icon={<RecipesIcon sx={{ fontSize: 'inherit' }} />}
              title="No recipes yet"
              body="Create your first crafting recipe to get started."
              ctaLabel="+ Create First Recipe"
              onCtaClick={() => setCreateOpen(true)}
            />
          ) : (
            <EmptyState title="No results match your filters" />
          )
        ) : (
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell padding="checkbox">
                  <Checkbox
                    size="small"
                    checked={multiSelect.isAllSelected(filteredIds)}
                    indeterminate={multiSelect.count > 0 && !multiSelect.isAllSelected(filteredIds)}
                    onChange={() => multiSelect.toggleAll(filteredIds)}
                  />
                </TableCell>
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
                <TableRow key={recipe.id} hover sx={{ cursor: 'pointer' }} onClick={() => openEditor(recipe.id)}>
                  <TableCell padding="checkbox" onClick={(e) => e.stopPropagation()}>
                    <Checkbox
                      size="small"
                      checked={multiSelect.isSelected(recipe.id)}
                      onChange={() => multiSelect.toggle(recipe.id)}
                    />
                  </TableCell>
                  <TableCell><Typography variant="body2" fontWeight={500}>{recipe.displayName}</Typography></TableCell>
                  <TableCell><Typography variant="body2" color="text.secondary" fontFamily="monospace">{recipe.exportKey}</Typography></TableCell>
                  <TableCell><Typography variant="body2" color="text.secondary">{itemById.get(recipe.outputItemId)?.displayName ?? recipe.outputItemId} x{recipe.outputQuantity}</Typography></TableCell>
                  <TableCell><Typography variant="body2" color="text.secondary">{recipe.craftingStationId ? stationById.get(recipe.craftingStationId)?.displayName ?? recipe.craftingStationId : '-'}</Typography></TableCell>
                  <TableCell><Typography variant="body2" color="text.secondary">{recipe.craftingSpecializationId ? specializationById.get(recipe.craftingSpecializationId)?.displayName ?? recipe.craftingSpecializationId : '-'}</Typography></TableCell>
                  <TableCell align="right" onClick={(e) => e.stopPropagation()}>
                    <Tooltip title="Edit"><IconButton size="small" onClick={() => openEditor(recipe.id)}><EditIcon fontSize="small" /></IconButton></Tooltip>
                    <Tooltip title="Duplicate"><IconButton size="small" onClick={() => void handleDuplicate(recipe)}><DuplicateIcon fontSize="small" /></IconButton></Tooltip>
                    <Tooltip title="Delete"><IconButton size="small" color="error" onClick={() => setDeleteTarget(recipe)}><DeleteIcon fontSize="small" /></IconButton></Tooltip>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        )}
      </Paper>
        </>
      )}

      <CreateRecipeDialog open={createOpen} items={items} stations={stations} specializations={specializations} onClose={() => setCreateOpen(false)} onCreated={handleCreated} />
      <DeleteDialog record={deleteTarget} onClose={() => setDeleteTarget(null)} onDeleted={handleDeleted} />

      <BulkDeleteDialog
        open={bulkDeleteOpen}
        domain="recipes"
        ids={[...multiSelect.selected]}
        onClose={() => setBulkDeleteOpen(false)}
        onConfirm={() => void handleBulkDelete()}
      />

      <EditorModal
        open={modalRecordId !== null}
        title="Edit Recipe"
        onClose={() => { setModalRecordId(null); void load() }}
      >
        {modalRecordId && (
          <RecipeEditorPage
            recordId={modalRecordId}
            onClose={() => { setModalRecordId(null); void load() }}
          />
        )}
      </EditorModal>
    </Box>
  )
}

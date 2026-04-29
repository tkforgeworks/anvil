import {
  ContentCopy as DuplicateIcon,
  Delete as DeleteIcon,
  Edit as EditIcon,
  Inventory as ItemsIcon,
} from '@mui/icons-material'
import {
  Alert,
  Box,
  Button,
  Checkbox,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogContentText,
  DialogTitle,
  FormControl,
  IconButton,
  InputLabel,
  MenuItem,
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
import type { ItemRecord, MetaItemCategory, MetaRarity } from '../../../shared/domain-types'
import { ArchiveTable, type ViewMode } from '../components/ArchiveView'
import { BulkActionToolbar, BulkDeleteDialog } from '../components/BulkActions'
import { CreateItemDialog } from '../components/create-dialogs'
import EditorModal from '../components/EditorModal'
import EmptyState from '../components/EmptyState'
import ListToolbar from '../components/ListToolbar'
import { useMultiSelect } from '../hooks/useMultiSelect'
import { useUiStore } from '../stores/ui.store'
import ItemEditorPage from './ItemEditorPage'

interface DeleteDialogProps {
  record: ItemRecord | null
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
      await itemsApi.delete(record.id)
      onDeleted(record.id)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to delete item.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <Dialog open={Boolean(record)} onClose={onClose}>
      <DialogTitle>Delete Item?</DialogTitle>
      <DialogContent>
        {error && (
          <Alert severity="error" sx={{ mb: 2 }}>
            {error}
          </Alert>
        )}
        <DialogContentText>
          <strong>{record?.displayName}</strong> will be moved to the archive. Recipes and loot
          tables that reference it will be flagged by validation.
        </DialogContentText>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} disabled={isBusy}>
          Cancel
        </Button>
        <Button
          color="error"
          variant="contained"
          onClick={() => void handleDelete()}
          disabled={isBusy}
        >
          Delete
        </Button>
      </DialogActions>
    </Dialog>
  )
}

type SortKey = 'name' | 'updated'

export default function ItemsPage(): React.JSX.Element {
  const navigate = useNavigate()
  const editingMode = useUiStore((s) => s.editingMode)
  const [items, setItems] = useState<ItemRecord[]>([])
  const [archivedItems, setArchivedItems] = useState<ItemRecord[]>([])
  const [viewMode, setViewMode] = useState<ViewMode>('active')
  const [categories, setCategories] = useState<MetaItemCategory[]>([])
  const [rarities, setRarities] = useState<MetaRarity[]>([])
  const [search, setSearch] = useState('')
  const [categoryFilter, setCategoryFilter] = useState('all')
  const [rarityFilter, setRarityFilter] = useState('all')
  const [sortKey, setSortKey] = useState<SortKey>('name')
  const [createOpen, setCreateOpen] = useState(false)
  const [deleteTarget, setDeleteTarget] = useState<ItemRecord | null>(null)
  const [bulkDeleteOpen, setBulkDeleteOpen] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [modalRecordId, setModalRecordId] = useState<string | null>(null)
  const multiSelect = useMultiSelect()

  const openEditor = (id: string): void => {
    if (editingMode === 'modal') setModalRecordId(id)
    else void navigate(`/items/${id}`)
  }

  const categoryById = useMemo(
    () => new Map(categories.map((category) => [category.id, category])),
    [categories],
  )
  const rarityById = useMemo(
    () => new Map(rarities.map((rarity) => [rarity.id, rarity])),
    [rarities],
  )

  const load = useCallback(async () => {
    setError(null)
    try {
      const [records, categoryList, rarityList] = await Promise.all([
        itemsApi.list(),
        metaApi.listItemCategories(),
        metaApi.listRarities(),
      ])
      setItems(records)
      setCategories(categoryList)
      setRarities(rarityList)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to load items.')
    }
  }, [])

  const loadArchived = useCallback(async () => {
    try {
      const records = await itemsApi.list(false, true)
      setArchivedItems(records)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to load archived items.')
    }
  }, [])

  useEffect(() => {
    multiSelect.clear()
    if (viewMode === 'active') void load()
    else void loadArchived()
  }, [load, loadArchived, viewMode])

  const handleCreated = (record: ItemRecord): void => {
    setCreateOpen(false)
    openEditor(record.id)
  }

  const handleDeleted = (id: string): void => {
    setDeleteTarget(null)
    setItems((prev) => prev.filter((item) => item.id !== id))
  }

  const handleArchiveRestore = async (id: string): Promise<void> => {
    await itemsApi.restore(id)
    setArchivedItems((prev) => prev.filter((r) => r.id !== id))
  }

  const handleArchiveHardDelete = async (id: string): Promise<void> => {
    await itemsApi.hardDelete(id)
    setArchivedItems((prev) => prev.filter((r) => r.id !== id))
  }

  const handleArchiveBulkRestore = async (ids: string[]): Promise<void> => {
    await lifecycleApi.bulkRestore('items', ids)
    void loadArchived()
  }

  const handleArchiveBulkHardDelete = async (ids: string[]): Promise<void> => {
    await lifecycleApi.bulkHardDelete('items', ids)
    void loadArchived()
  }

  const handleDuplicate = async (record: ItemRecord): Promise<void> => {
    setError(null)
    try {
      const copy = await itemsApi.duplicate(record.id)
      if (copy) setItems((prev) => [...prev, copy])
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to duplicate item.')
    }
  }

  const handleBulkDelete = async (): Promise<void> => {
    setError(null)
    try {
      await lifecycleApi.bulkSoftDelete('items', [...multiSelect.selected])
      setBulkDeleteOpen(false)
      multiSelect.clear()
      void load()
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Bulk delete failed.')
    }
  }

  const filtered = items
    .filter((item) => item.displayName.toLowerCase().includes(search.toLowerCase()))
    .filter((item) => categoryFilter === 'all' || item.itemCategoryId === categoryFilter)
    .filter((item) => rarityFilter === 'all' || item.rarityId === rarityFilter)
    .sort((a, b) => {
      if (sortKey === 'updated') return b.updatedAt.localeCompare(a.updatedAt)
      return a.displayName.localeCompare(b.displayName, undefined, { sensitivity: 'base' })
    })

  const filteredIds = filtered.map((item) => item.id)

  const itemFilterSlot = (
    <>
      <FormControl size="small" sx={{ minWidth: 180 }}>
        <InputLabel id="category-filter-label">Category</InputLabel>
        <Select
          labelId="category-filter-label"
          label="Category"
          value={categoryFilter}
          onChange={(e) => setCategoryFilter(e.target.value)}
        >
          <MenuItem value="all">All Categories</MenuItem>
          {categories.map((category) => (
            <MenuItem key={category.id} value={category.id}>
              {category.displayName}
            </MenuItem>
          ))}
        </Select>
      </FormControl>
      <FormControl size="small" sx={{ minWidth: 160 }}>
        <InputLabel id="rarity-filter-label">Rarity</InputLabel>
        <Select
          labelId="rarity-filter-label"
          label="Rarity"
          value={rarityFilter}
          onChange={(e) => setRarityFilter(e.target.value)}
        >
          <MenuItem value="all">All Rarities</MenuItem>
          {rarities.map((rarity) => (
            <MenuItem key={rarity.id} value={rarity.id}>
              {rarity.displayName}
            </MenuItem>
          ))}
        </Select>
      </FormControl>
    </>
  )

  return (
    <Box>
      <ListToolbar
        search={search}
        onSearchChange={setSearch}
        sortKey={sortKey}
        onSortChange={(v) => setSortKey(v as SortKey)}
        sortOptions={[
          { value: 'name', label: 'Name' },
          { value: 'updated', label: 'Last Modified' },
        ]}
        viewMode={viewMode}
        onViewModeChange={setViewMode}
        onNew={() => setCreateOpen(true)}
        newLabel="+ New Item"
        filterSlot={itemFilterSlot}
      />

      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      {viewMode === 'archived' ? (
        <ArchiveTable
          records={archivedItems}
          domainLabel="Item"
          emptyMessage="No archived items."
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

      {filtered.length === 0 ? (
        items.length === 0 ? (
          <EmptyState
            icon={<ItemsIcon sx={{ fontSize: 'inherit' }} />}
            title="No items yet"
            body="Create your first item to get started."
            ctaLabel="+ Create First Item"
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
              <TableCell>Category</TableCell>
              <TableCell>Rarity</TableCell>
              <TableCell>Description</TableCell>
              <TableCell align="right">Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {filtered.map((item) => {
              const category = categoryById.get(item.itemCategoryId)
              const rarity = rarityById.get(item.rarityId)
              return (
                <TableRow
                  key={item.id}
                  hover
                  sx={{ cursor: 'pointer' }}
                  onClick={() => openEditor(item.id)}
                >
                  <TableCell padding="checkbox" onClick={(e) => e.stopPropagation()}>
                    <Checkbox
                      size="small"
                      checked={multiSelect.isSelected(item.id)}
                      onChange={() => multiSelect.toggle(item.id)}
                    />
                  </TableCell>
                  <TableCell>
                    <Typography variant="body2" fontWeight={500}>
                      {item.displayName}
                    </Typography>
                  </TableCell>
                  <TableCell>
                    <Typography variant="body2" color="text.secondary" fontFamily="monospace">
                      {item.exportKey}
                    </Typography>
                  </TableCell>
                  <TableCell>
                    <Typography variant="body2" color="text.secondary">
                      {category?.displayName ?? item.itemCategoryId}
                    </Typography>
                  </TableCell>
                  <TableCell>
                    {rarity ? (
                      <Chip
                        label={rarity.displayName}
                        size="small"
                        variant="outlined"
                        sx={{ borderColor: rarity.colorHex }}
                      />
                    ) : (
                      <Typography variant="body2" color="text.secondary">
                        {item.rarityId}
                      </Typography>
                    )}
                  </TableCell>
                  <TableCell>
                    <Typography
                      variant="body2"
                      color="text.secondary"
                      sx={{
                        maxWidth: 260,
                        overflow: 'hidden',
                        textOverflow: 'ellipsis',
                        whiteSpace: 'nowrap',
                      }}
                    >
                      {item.description || '-'}
                    </Typography>
                  </TableCell>
                  <TableCell align="right" onClick={(e) => e.stopPropagation()}>
                    <Tooltip title="Edit">
                      <IconButton size="small" onClick={() => openEditor(item.id)}>
                        <EditIcon fontSize="small" />
                      </IconButton>
                    </Tooltip>
                    <Tooltip title="Duplicate">
                      <IconButton size="small" onClick={() => void handleDuplicate(item)}>
                        <DuplicateIcon fontSize="small" />
                      </IconButton>
                    </Tooltip>
                    <Tooltip title="Delete">
                      <IconButton size="small" color="error" onClick={() => setDeleteTarget(item)}>
                        <DeleteIcon fontSize="small" />
                      </IconButton>
                    </Tooltip>
                  </TableCell>
                </TableRow>
              )
            })}
          </TableBody>
        </Table>
      )}
        </>
      )}

      <CreateItemDialog
        open={createOpen}
        categories={categories}
        rarities={rarities}
        onClose={() => setCreateOpen(false)}
        onCreated={handleCreated}
      />

      <DeleteDialog
        record={deleteTarget}
        onClose={() => setDeleteTarget(null)}
        onDeleted={handleDeleted}
      />

      <BulkDeleteDialog
        open={bulkDeleteOpen}
        domain="items"
        ids={[...multiSelect.selected]}
        onClose={() => setBulkDeleteOpen(false)}
        onConfirm={() => void handleBulkDelete()}
      />

      <EditorModal
        open={modalRecordId !== null}
        title="Edit Item"
        onClose={() => { setModalRecordId(null); void load() }}
      >
        {modalRecordId && (
          <ItemEditorPage
            recordId={modalRecordId}
            onClose={() => { setModalRecordId(null); void load() }}
          />
        )}
      </EditorModal>
    </Box>
  )
}

import {
  Add as AddIcon,
  ContentCopy as DuplicateIcon,
  Delete as DeleteIcon,
  Edit as EditIcon,
} from '@mui/icons-material'
import {
  Alert,
  Box,
  Button,
  Chip,
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
import type { ItemRecord, MetaItemCategory, MetaRarity } from '../../../shared/domain-types'

function slugify(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
}

interface CreateDialogProps {
  open: boolean
  categories: MetaItemCategory[]
  rarities: MetaRarity[]
  onClose: () => void
  onCreated: (record: ItemRecord) => void
}

function CreateDialog({
  open,
  categories,
  rarities,
  onClose,
  onCreated,
}: CreateDialogProps): React.JSX.Element {
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
  const [items, setItems] = useState<ItemRecord[]>([])
  const [categories, setCategories] = useState<MetaItemCategory[]>([])
  const [rarities, setRarities] = useState<MetaRarity[]>([])
  const [search, setSearch] = useState('')
  const [categoryFilter, setCategoryFilter] = useState('all')
  const [rarityFilter, setRarityFilter] = useState('all')
  const [sortKey, setSortKey] = useState<SortKey>('name')
  const [createOpen, setCreateOpen] = useState(false)
  const [deleteTarget, setDeleteTarget] = useState<ItemRecord | null>(null)
  const [error, setError] = useState<string | null>(null)

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

  useEffect(() => {
    void load()
  }, [load])

  const handleCreated = (record: ItemRecord): void => {
    setCreateOpen(false)
    void navigate(`/items/${record.id}`)
  }

  const handleDeleted = (id: string): void => {
    setDeleteTarget(null)
    setItems((prev) => prev.filter((item) => item.id !== id))
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

  const filtered = items
    .filter((item) => item.displayName.toLowerCase().includes(search.toLowerCase()))
    .filter((item) => categoryFilter === 'all' || item.itemCategoryId === categoryFilter)
    .filter((item) => rarityFilter === 'all' || item.rarityId === rarityFilter)
    .sort((a, b) => {
      if (sortKey === 'updated') return b.updatedAt.localeCompare(a.updatedAt)
      return a.displayName.localeCompare(b.displayName, undefined, { sensitivity: 'base' })
    })

  return (
    <Box>
      <Stack direction="row" alignItems="center" justifyContent="space-between" sx={{ mb: 3 }}>
        <Typography variant="h5">Items</Typography>
        <Button startIcon={<AddIcon />} variant="contained" onClick={() => setCreateOpen(true)}>
          New Item
        </Button>
      </Stack>

      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      <Stack direction="row" spacing={2} sx={{ mb: 2 }} flexWrap="wrap" useFlexGap>
        <TextField
          size="small"
          placeholder="Search items..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          sx={{ flex: 1, minWidth: 220, maxWidth: 360 }}
        />
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
        <FormControl size="small" sx={{ minWidth: 180 }}>
          <InputLabel id="sort-label">Sort by</InputLabel>
          <Select
            labelId="sort-label"
            label="Sort by"
            value={sortKey}
            onChange={(e) => setSortKey(e.target.value as SortKey)}
          >
            <MenuItem value="name">Name</MenuItem>
            <MenuItem value="updated">Last Modified</MenuItem>
          </Select>
        </FormControl>
      </Stack>

      {filtered.length === 0 ? (
        <Typography variant="body2" color="text.secondary">
          {items.length === 0
            ? 'No items yet. Click "New Item" to create one.'
            : 'No items match your filters.'}
        </Typography>
      ) : (
        <Table size="small">
          <TableHead>
            <TableRow>
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
                  onClick={() => void navigate(`/items/${item.id}`)}
                >
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
                      <IconButton size="small" onClick={() => void navigate(`/items/${item.id}`)}>
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

      <CreateDialog
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
    </Box>
  )
}

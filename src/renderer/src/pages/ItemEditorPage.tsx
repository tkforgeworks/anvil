import { ArrowBack as BackIcon } from '@mui/icons-material'
import {
  Alert,
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
  Tabs,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material'
import { useCallback, useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { itemsApi } from '../../api/items.api'
import { metaApi } from '../../api/meta.api'
import type { ItemRecord, MetaItemCategory, MetaRarity } from '../../../shared/domain-types'
import CustomFieldsPanel from '../components/CustomFieldsPanel'

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

export default function ItemEditorPage(): React.JSX.Element {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()

  const [record, setRecord] = useState<ItemRecord | null>(null)
  const [categories, setCategories] = useState<MetaItemCategory[]>([])
  const [rarities, setRarities] = useState<MetaRarity[]>([])
  const [displayName, setDisplayName] = useState('')
  const [exportKey, setExportKey] = useState('')
  const [description, setDescription] = useState('')
  const [itemCategoryId, setItemCategoryId] = useState('')
  const [rarityId, setRarityId] = useState('')
  const [isDirty, setDirty] = useState(false)
  const [isSaving, setSaving] = useState(false)
  const [isLoading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [savedAt, setSavedAt] = useState<Date | null>(null)
  const [activeTab, setActiveTab] = useState(0)

  const load = useCallback(async () => {
    if (!id) return
    setLoading(true)
    setError(null)
    try {
      const [data, categoryList, rarityList] = await Promise.all([
        itemsApi.get(id),
        metaApi.listItemCategories(),
        metaApi.listRarities(),
      ])
      if (!data) {
        setError('Item not found.')
        return
      }
      setRecord(data)
      setDisplayName(data.displayName)
      setExportKey(data.exportKey)
      setDescription(data.description)
      setItemCategoryId(data.itemCategoryId)
      setRarityId(data.rarityId)
      setCategories(categoryList)
      setRarities(rarityList)
      setDirty(false)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to load item.')
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

  const handleSave = async (): Promise<void> => {
    if (!id) return
    setSaving(true)
    setError(null)
    try {
      const updated = await itemsApi.update(id, {
        displayName: displayName.trim(),
        exportKey: exportKey.trim(),
        description: description.trim(),
        itemCategoryId,
        rarityId,
      })
      if (updated) {
        setRecord(updated)
        setDirty(false)
        setSavedAt(new Date())
      }
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to save item.')
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
        <Alert severity="error">{error ?? 'Item not found.'}</Alert>
        <Button sx={{ mt: 2 }} onClick={() => void navigate('/items')}>
          Back to Items
        </Button>
      </Box>
    )
  }

  return (
    <Box>
      <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1 }}>
        <Tooltip title="Back to Items">
          <IconButton size="small" onClick={() => void navigate('/items')}>
            <BackIcon fontSize="small" />
          </IconButton>
        </Tooltip>
        <Typography variant="caption" color="text.secondary">
          Items
        </Typography>
      </Stack>

      <Stack
        direction="row"
        alignItems="flex-start"
        justifyContent="space-between"
        sx={{ mb: 3 }}
        spacing={2}
      >
        <Box sx={{ flex: 1, minWidth: 0 }}>
          <TextField
            variant="standard"
            value={displayName}
            onChange={(e) => {
              setDisplayName(e.target.value)
              markDirty()
            }}
            inputProps={{ style: { fontSize: '1.5rem', fontWeight: 600 } }}
            placeholder="Item Name"
            fullWidth
            sx={{ mb: 0.5 }}
          />
          <TextField
            variant="standard"
            value={exportKey}
            onChange={(e) => {
              setExportKey(e.target.value)
              markDirty()
            }}
            inputProps={{ style: { fontFamily: 'monospace', fontSize: '0.8rem' } }}
            placeholder="export-key"
            helperText="Export key - used in exported files"
            sx={{ maxWidth: 360 }}
          />
        </Box>

        <Stack direction="row" alignItems="center" spacing={2} sx={{ pt: 0.5 }}>
          {savedAt && (
            <Typography variant="caption" color="success.main">
              Saved at {savedAt.toLocaleTimeString()}
            </Typography>
          )}
          <Button
            variant="contained"
            onClick={() => void handleSave()}
            disabled={
              !isDirty ||
              isSaving ||
              !displayName.trim() ||
              !exportKey.trim() ||
              !itemCategoryId ||
              !rarityId
            }
          >
            Save
          </Button>
        </Stack>
      </Stack>

      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      <Divider sx={{ mb: 0 }} />
      <Tabs value={activeTab} onChange={(_, value: number) => setActiveTab(value)}>
        <Tab label="Details" />
        <Tab label="Custom Fields" />
      </Tabs>
      <Divider />

      <TabPanel index={0} value={activeTab}>
        <Stack spacing={3} sx={{ maxWidth: 680 }}>
          <Stack direction="row" spacing={2}>
            <FormControl fullWidth required>
              <InputLabel id="item-category-label">Category</InputLabel>
              <Select
                labelId="item-category-label"
                label="Category"
                value={itemCategoryId}
                onChange={(e) => {
                  setItemCategoryId(e.target.value)
                  markDirty()
                }}
              >
                {categories.map((category) => (
                  <MenuItem key={category.id} value={category.id}>
                    {category.displayName}
                  </MenuItem>
                ))}
              </Select>
            </FormControl>
            <FormControl fullWidth required>
              <InputLabel id="item-rarity-label">Rarity</InputLabel>
              <Select
                labelId="item-rarity-label"
                label="Rarity"
                value={rarityId}
                onChange={(e) => {
                  setRarityId(e.target.value)
                  markDirty()
                }}
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
            onChange={(e) => {
              setDescription(e.target.value)
              markDirty()
            }}
            multiline
            minRows={4}
            fullWidth
          />
        </Stack>
      </TabPanel>

      <TabPanel index={1} value={activeTab}>
        <Box sx={{ maxWidth: 680 }}>
          {isDirty ? (
            <Alert severity="info">
              Save item details before editing custom fields for this category.
            </Alert>
          ) : (
            <CustomFieldsPanel
              key={`${record.id}:${itemCategoryId}`}
              domain="items"
              recordId={record.id}
              scopeType="item_category"
              scopeId={itemCategoryId}
            />
          )}
        </Box>
      </TabPanel>
    </Box>
  )
}

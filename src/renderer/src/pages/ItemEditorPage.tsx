import { ArrowBack as BackIcon, Redo as RedoIcon, Undo as UndoIcon } from '@mui/icons-material'
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
import { useUndoRedo } from '../hooks/useUndoRedo'
import { useNavigate, useParams } from 'react-router-dom'
import { itemsApi } from '../../api/items.api'
import { metaApi } from '../../api/meta.api'
import type { ItemRecord, MetaItemCategory, MetaRarity } from '../../../shared/domain-types'
import CustomFieldsPanel from '../components/CustomFieldsPanel'
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
  itemCategoryId: string
  rarityId: string
}

interface ItemEditorPageProps {
  recordId?: string
  onClose?: () => void
}

export default function ItemEditorPage({ recordId, onClose }: ItemEditorPageProps = {}): React.JSX.Element {
  const { id: paramId } = useParams<{ id: string }>()
  const id = recordId ?? paramId
  const navigate = useNavigate()
  const goBack = onClose ?? (() => void navigate('/items'))

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
  const { recordIssues, issuesForField, runValidation } = useRecordValidation('items', id)

  const applySnapshot = useCallback((snapshot: FormSnapshot) => {
    setDisplayName(snapshot.displayName)
    setExportKey(snapshot.exportKey)
    setDescription(snapshot.description)
    setItemCategoryId(snapshot.itemCategoryId)
    setRarityId(snapshot.rarityId)
    setDirty(true)
    setSavedAt(null)
  }, [])

  const undoRedo = useUndoRedo<FormSnapshot>(applySnapshot)

  const pushSnapshot = (overrides: Partial<FormSnapshot> = {}): void => {
    setDirty(true)
    setSavedAt(null)
    undoRedo.pushState({ displayName, exportKey, description, itemCategoryId, rarityId, ...overrides })
  }

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
      undoRedo.reset({
        displayName: data.displayName,
        exportKey: data.exportKey,
        description: data.description,
        itemCategoryId: data.itemCategoryId,
        rarityId: data.rarityId,
      })
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to load item.')
    } finally {
      setLoading(false)
    }
  }, [id])

  useEffect(() => {
    void load()
  }, [load])

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
        await runValidation()
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
        <Button sx={{ mt: 2 }} onClick={goBack}>
          Back to Items
        </Button>
      </Box>
    )
  }

  return (
    <Box>
      <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1 }}>
        <Tooltip title="Back to Items">
          <IconButton size="small" onClick={goBack}>
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
              pushSnapshot({ displayName: e.target.value })
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
              pushSnapshot({ exportKey: e.target.value })
            }}
            inputProps={{ style: { fontFamily: 'monospace', fontSize: '0.8rem' } }}
            placeholder="export-key"
            helperText="Export key - used in exported files"
            sx={{ maxWidth: 360 }}
          />
        </Box>

        <Stack direction="row" alignItems="center" spacing={1} sx={{ pt: 0.5 }}>
          <Tooltip title="Undo (Ctrl+Z)">
            <span>
              <IconButton size="small" onClick={undoRedo.triggerUndo} disabled={!undoRedo.canUndo}>
                <UndoIcon fontSize="small" />
              </IconButton>
            </span>
          </Tooltip>
          <Tooltip title="Redo (Ctrl+Y)">
            <span>
              <IconButton size="small" onClick={undoRedo.triggerRedo} disabled={!undoRedo.canRedo}>
                <RedoIcon fontSize="small" />
              </IconButton>
            </span>
          </Tooltip>
          {savedAt && (
            <Typography variant="caption" color="success.main" sx={{ ml: 1 }}>
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
            sx={{ ml: 1 }}
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

      <ValidationBanner issues={recordIssues} />

      <Divider sx={{ mb: 0 }} />
      <Tabs value={activeTab} onChange={(_, value: number) => setActiveTab(value)}>
        <Tab label="Details" />
        <Tab label="Custom Fields" />
      </Tabs>
      <Divider />

      <TabPanel index={0} value={activeTab}>
        <Stack spacing={3} sx={{ maxWidth: 680 }}>
          <Stack direction="row" spacing={2}>
            <FormControl fullWidth required error={issuesForField('itemCategoryId').length > 0}>
              <InputLabel id="item-category-label">Category</InputLabel>
              <Select
                labelId="item-category-label"
                label="Category"
                value={itemCategoryId}
                onChange={(e) => {
                  setItemCategoryId(e.target.value)
                  pushSnapshot({ itemCategoryId: e.target.value })
                }}
              >
                {categories.map((category) => (
                  <MenuItem key={category.id} value={category.id}>
                    {category.displayName}
                  </MenuItem>
                ))}
              </Select>
            </FormControl>
            <FormControl fullWidth required error={issuesForField('rarityId').length > 0}>
              <InputLabel id="item-rarity-label">Rarity</InputLabel>
              <Select
                labelId="item-rarity-label"
                label="Rarity"
                value={rarityId}
                onChange={(e) => {
                  setRarityId(e.target.value)
                  pushSnapshot({ rarityId: e.target.value })
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
              pushSnapshot({ description: e.target.value })
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

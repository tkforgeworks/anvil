import {
  Alert,
  Box,
  Button,
  FormControl,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  Tab,
  Tabs,
  TextField,
  Typography,
} from '@mui/material'
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useUndoRedo } from '../hooks/useUndoRedo'
import { useTabDirtyTracking } from '../hooks/useTabDirtyTracking'
import DirtyDot from '../components/DirtyDot'
import { useNavigate, useParams } from 'react-router-dom'
import { itemsApi } from '../../api/items.api'
import { metaApi } from '../../api/meta.api'
import type { ItemRecord, ItemUsedBy, MetaItemCategory, MetaRarity } from '../../../shared/domain-types'
import CustomFieldsPanel from '../components/CustomFieldsPanel'
import EditHeader from '../components/EditHeader'
import type { UsedBySection } from '../components/InspectorRail'
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
  const [usedBy, setUsedBy] = useState<ItemUsedBy | null>(null)
  const [usedByLoading, setUsedByLoading] = useState(false)
  const { recordIssues, issuesForField, runValidation } = useRecordValidation('items', id)

  type TabFields = Omit<FormSnapshot, 'displayName' | 'exportKey'>
  const baselineRef = useRef<TabFields | null>(null)

  const tabFieldMap: Record<number, (keyof TabFields)[]> = useMemo(() => ({
    1: ['description', 'itemCategoryId', 'rarityId'],
  }), [])

  const currentTabFields: TabFields = useMemo(() => ({
    description,
    itemCategoryId,
    rarityId,
  }), [description, itemCategoryId, rarityId])

  const dirtyTabs = useTabDirtyTracking(currentTabFields, baselineRef.current, tabFieldMap)

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
      baselineRef.current = {
        description: data.description,
        itemCategoryId: data.itemCategoryId,
        rarityId: data.rarityId,
      }
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

  // Load "Used By" data eagerly for InspectorRail
  useEffect(() => {
    if (!id) return
    setUsedByLoading(true)
    itemsApi
      .getUsedBy(id)
      .then((result) => setUsedBy(result))
      .catch((cause) =>
        setError(cause instanceof Error ? cause.message : 'Failed to load Used By data.'),
      )
      .finally(() => setUsedByLoading(false))
  }, [id])

  const usedBySections: UsedBySection[] = useMemo(() => {
    if (!usedBy) return []
    return [
      {
        label: 'Crafting Recipes',
        items: usedBy.recipes.map((r) => ({ id: r.id, displayName: r.displayName, route: `/recipes/${r.id}` })),
      },
      {
        label: 'Loot Tables',
        items: usedBy.lootTables.map((lt) => ({ id: lt.id, displayName: lt.displayName, route: `/loot-tables/${lt.id}` })),
      },
    ]
  }, [usedBy])

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
        baselineRef.current = {
          description: description.trim(),
          itemCategoryId,
          rarityId,
        }
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

  const handleBack = goBack
  const handleDiscard = (): void => void load()

  return (
    <Box>
      <Box sx={{ position: 'sticky', top: 0, zIndex: 10, bgcolor: 'background.default', mt: -3, pt: 3 }}>
        <EditHeader
          backLabel="Items"
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
          <Tab label="Overview" data-tid="tab-item-overview" />
          <Tab label={<span>Details<DirtyDot visible={dirtyTabs.has(1)} /></span>} data-tid="tab-item-details" />
          <Tab label="Custom Fields" data-tid="tab-item-custom-fields" />
        </Tabs>
      </Box>

      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      <ValidationBanner issues={recordIssues} />

      <TabPanel index={0} value={activeTab}>
        <OverviewTab
          displayName={displayName}
          description={description}
          usedBySections={usedBySections}
          usedByLoading={usedByLoading}
        />
      </TabPanel>

      <TabPanel index={1} value={activeTab}>
        <Stack spacing={3} sx={{ maxWidth: 680 }}>
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

      <TabPanel index={2} value={activeTab}>
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

      <SaveBar
        isDirty={isDirty}
        isSaving={isSaving}
        onSave={() => void handleSave()}
        onDiscard={handleDiscard}
      />
    </Box>
  )
}

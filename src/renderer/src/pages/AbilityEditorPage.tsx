import {
  Alert,
  Box,
  Button,
  InputAdornment,
  Stack,
  Tab,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  Tabs,
  TextField,
  Typography,
} from '@mui/material'
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useUndoRedo } from '../hooks/useUndoRedo'
import { useTabDirtyTracking } from '../hooks/useTabDirtyTracking'
import DirtyDot from '../components/DirtyDot'
import { useNavigate, useParams } from 'react-router-dom'
import { abilitiesApi } from '../../api/abilities.api'
import { metaApi } from '../../api/meta.api'
import type { AbilityRecord, AbilityUsedBy, MetaStat } from '../../../shared/domain-types'
import EditHeader from '../components/EditHeader'
import type { UsedBySection } from '../components/InspectorRail'
import OverviewTab from '../components/OverviewTab'
import SaveBar from '../components/SaveBar'
import ValidationBanner from '../components/ValidationBanner'
import { useRecordValidation } from '../hooks/useRecordValidation'

// ─── Tab panel ────────────────────────────────────────────────────────────────

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

// ─── Editor ───────────────────────────────────────────────────────────────────

interface FormSnapshot {
  displayName: string
  exportKey: string
  description: string
  abilityType: string
  resourceType: string
  resourceCost: string
  cooldown: string
  statModifiers: Record<string, string>
}

interface AbilityEditorPageProps {
  recordId?: string
  onClose?: () => void
}

export default function AbilityEditorPage({ recordId, onClose }: AbilityEditorPageProps = {}): React.JSX.Element {
  const { id: paramId } = useParams<{ id: string }>()
  const id = recordId ?? paramId
  const navigate = useNavigate()
  const goBack = onClose ?? (() => void navigate('/abilities'))

  const [record, setRecord] = useState<AbilityRecord | null>(null)
  const [displayName, setDisplayName] = useState('')
  const [exportKey, setExportKey] = useState('')
  const [description, setDescription] = useState('')
  const [abilityType, setAbilityType] = useState('')
  const [resourceType, setResourceType] = useState('')
  const [resourceCost, setResourceCost] = useState('0')
  const [cooldown, setCooldown] = useState('0')
  // stat modifier values kept as strings for controlled TextField inputs
  const [statModifiers, setStatModifiers] = useState<Record<string, string>>({})
  const [stats, setStats] = useState<MetaStat[]>([])
  const [isDirty, setDirty] = useState(false)
  const [isSaving, setSaving] = useState(false)
  const [isLoading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [savedAt, setSavedAt] = useState<Date | null>(null)
  const [activeTab, setActiveTab] = useState(0)
  const [usedBy, setUsedBy] = useState<AbilityUsedBy | null>(null)
  const [usedByLoading, setUsedByLoading] = useState(false)
  const { recordIssues, runValidation } = useRecordValidation('abilities', id)

  type TabFields = Omit<FormSnapshot, 'displayName' | 'exportKey'>
  const baselineRef = useRef<TabFields | null>(null)

  const tabFieldMap: Record<number, (keyof TabFields)[]> = useMemo(() => ({
    1: ['description', 'abilityType', 'resourceType', 'resourceCost', 'cooldown'],
    2: ['statModifiers'],
  }), [])

  const currentTabFields: TabFields = useMemo(() => ({
    description,
    abilityType,
    resourceType,
    resourceCost,
    cooldown,
    statModifiers,
  }), [description, abilityType, resourceType, resourceCost, cooldown, statModifiers])

  const dirtyTabs = useTabDirtyTracking(currentTabFields, baselineRef.current, tabFieldMap)

  const applySnapshot = useCallback((snapshot: FormSnapshot) => {
    setDisplayName(snapshot.displayName)
    setExportKey(snapshot.exportKey)
    setDescription(snapshot.description)
    setAbilityType(snapshot.abilityType)
    setResourceType(snapshot.resourceType)
    setResourceCost(snapshot.resourceCost)
    setCooldown(snapshot.cooldown)
    setStatModifiers(snapshot.statModifiers)
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
      abilityType,
      resourceType,
      resourceCost,
      cooldown,
      statModifiers,
      ...overrides,
    })
  }

  const load = useCallback(async () => {
    if (!id) return
    setLoading(true)
    setError(null)
    try {
      const [data, statList] = await Promise.all([abilitiesApi.get(id), metaApi.listStats()])
      if (!data) {
        setError('Ability not found.')
        return
      }
      setRecord(data)
      setDisplayName(data.displayName)
      setExportKey(data.exportKey)
      setDescription(data.description)
      setAbilityType(data.abilityType)
      setResourceType(data.resourceType)
      setResourceCost(String(data.resourceCost))
      setCooldown(String(data.cooldown))
      const modStrings: Record<string, string> = {}
      for (const stat of statList) {
        modStrings[stat.id] = String(data.statModifiers[stat.id] ?? 0)
      }
      setStatModifiers(modStrings)
      setStats(statList)
      setUsedBy(null)
      setDirty(false)
      baselineRef.current = {
        description: data.description,
        abilityType: data.abilityType,
        resourceType: data.resourceType,
        resourceCost: String(data.resourceCost),
        cooldown: String(data.cooldown),
        statModifiers: modStrings,
      }
      undoRedo.reset({
        displayName: data.displayName,
        exportKey: data.exportKey,
        description: data.description,
        abilityType: data.abilityType,
        resourceType: data.resourceType,
        resourceCost: String(data.resourceCost),
        cooldown: String(data.cooldown),
        statModifiers: modStrings,
      })
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to load ability.')
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
    abilitiesApi
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
        label: 'Character Classes',
        items: usedBy.classes.map((c) => ({ id: c.id, displayName: c.displayName, route: `/classes/${c.id}` })),
      },
      {
        label: 'NPCs',
        items: usedBy.npcs.map((n) => ({ id: n.id, displayName: n.displayName, route: `/npcs/${n.id}` })),
      },
    ]
  }, [usedBy])

  const handleSave = async (): Promise<void> => {
    if (!id) return
    setSaving(true)
    setError(null)
    try {
      // Only export non-zero modifiers
      const numericModifiers: Record<string, number> = {}
      for (const [statId, val] of Object.entries(statModifiers)) {
        const n = parseFloat(val)
        if (!isNaN(n) && n !== 0) numericModifiers[statId] = n
      }
      const updated = await abilitiesApi.update(id, {
        displayName: displayName.trim(),
        exportKey: exportKey.trim(),
        description: description.trim(),
        abilityType: abilityType.trim(),
        resourceType: resourceType.trim(),
        resourceCost: parseFloat(resourceCost) || 0,
        cooldown: parseFloat(cooldown) || 0,
        statModifiers: numericModifiers,
      })
      if (updated) {
        setRecord(updated)
        setDirty(false)
        setSavedAt(new Date())
        baselineRef.current = {
          description: description.trim(),
          abilityType: abilityType.trim(),
          resourceType: resourceType.trim(),
          resourceCost,
          cooldown,
          statModifiers,
        }
        await runValidation()
      }
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to save ability.')
    } finally {
      setSaving(false)
    }
  }

  if (isLoading) {
    return (
      <Box sx={{ p: 4 }}>
        <Typography color="text.secondary">Loading…</Typography>
      </Box>
    )
  }

  if (!record) {
    return (
      <Box sx={{ p: 4 }}>
        <Alert severity="error">{error ?? 'Ability not found.'}</Alert>
        <Button sx={{ mt: 2 }} onClick={goBack}>
          Back to Abilities
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
          backLabel="Abilities"
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

        <Tabs value={activeTab} onChange={(_, v: number) => setActiveTab(v)}>
          <Tab label="Overview" data-tid="tab-ability-overview" />
          <Tab label={<span>Details<DirtyDot visible={dirtyTabs.has(1)} /></span>} data-tid="tab-ability-details" />
          <Tab label={<span>Stat Modifiers<DirtyDot visible={dirtyTabs.has(2)} /></span>} data-tid="tab-ability-stat-modifiers" />
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
        <Stack spacing={2} sx={{ maxWidth: 600 }}>
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
          <TextField
            label="Description"
            value={description}
            onChange={(e) => {
              setDescription(e.target.value)
              pushSnapshot({ description: e.target.value })
            }}
            multiline
            minRows={3}
            fullWidth
          />
          <TextField
            label="Ability Type"
            value={abilityType}
            onChange={(e) => {
              setAbilityType(e.target.value)
              pushSnapshot({ abilityType: e.target.value })
            }}
            fullWidth
            helperText="e.g. active, passive, ultimate"
          />
          <TextField
            label="Resource Type"
            value={resourceType}
            onChange={(e) => {
              setResourceType(e.target.value)
              pushSnapshot({ resourceType: e.target.value })
            }}
            fullWidth
            helperText="e.g. mana, stamina, rage"
          />
          <Stack direction="row" spacing={2}>
            <TextField
              label="Resource Cost"
              type="number"
              value={resourceCost}
              onChange={(e) => {
                setResourceCost(e.target.value)
                pushSnapshot({ resourceCost: e.target.value })
              }}
              inputProps={{ min: 0 }}
              sx={{ flex: 1 }}
            />
            <TextField
              label="Cooldown"
              type="number"
              value={cooldown}
              onChange={(e) => {
                setCooldown(e.target.value)
                pushSnapshot({ cooldown: e.target.value })
              }}
              inputProps={{ min: 0 }}
              helperText="In turns or seconds"
              sx={{ flex: 1 }}
            />
          </Stack>
        </Stack>
      </TabPanel>

      <TabPanel index={2} value={activeTab}>
        {stats.length === 0 ? (
          <Typography variant="body2" color="text.secondary">
            No stats defined in this project.
          </Typography>
        ) : (
          <>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
              Flat modifiers applied when this ability is active. Zero values are not exported.
            </Typography>
            <Table size="small" sx={{ maxWidth: 400 }}>
              <TableHead>
                <TableRow>
                  <TableCell>Stat</TableCell>
                  <TableCell>Modifier</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {stats.map((stat) => (
                  <TableRow key={stat.id}>
                    <TableCell>
                      <Typography variant="body2">{stat.displayName}</Typography>
                    </TableCell>
                    <TableCell>
                      <TextField
                        type="number"
                        size="small"
                        value={statModifiers[stat.id] ?? '0'}
                        onChange={(e) => {
                          const nextModifiers = { ...statModifiers, [stat.id]: e.target.value }
                          setStatModifiers(nextModifiers)
                          pushSnapshot({ statModifiers: nextModifiers })
                        }}
                        sx={{ width: 120 }}
                        InputProps={{
                          startAdornment: (
                            <InputAdornment position="start">
                              <Typography variant="caption" color="text.secondary">
                                ±
                              </Typography>
                            </InputAdornment>
                          ),
                        }}
                      />
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </>
        )}
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

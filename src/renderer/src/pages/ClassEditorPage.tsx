import {
  Alert,
  Box,
  Button,
  Stack,
  Tab,
  Tabs,
  TextField,
  Typography,
} from '@mui/material'
import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { abilitiesApi } from '../../api/abilities.api'
import { classesApi } from '../../api/classes.api'
import type {
  AbilityRecord,
  ClassAbilityAssignment,
  ClassRecord,
  ClassUsedBy,
} from '../../../shared/domain-types'
import AbilityAssignmentPanel, { type AbilityAssignmentRef } from '../components/AbilityAssignmentPanel'
import DerivedStatsEditor, { type DerivedStatsEditorRef } from '../components/DerivedStatsEditor'
import EditHeader from '../components/EditHeader'
import type { UsedBySection } from '../components/InspectorRail'
import OverviewTab from '../components/OverviewTab'
import SaveBar from '../components/SaveBar'
import StatGrowthEditor, { type StatGrowthEditorRef } from '../components/StatGrowthEditor'
import ValidationBanner from '../components/ValidationBanner'
import { useRecordValidation } from '../hooks/useRecordValidation'
import { useUndoRedo } from '../hooks/useUndoRedo'
import { useTabDirtyTracking } from '../hooks/useTabDirtyTracking'
import DirtyDot from '../components/DirtyDot'

interface FormSnapshot {
  displayName: string
  exportKey: string
  description: string
  resourceMultiplier: string
}

// ─── Tab panels ───────────────────────────────────────────────────────────────

interface TabPanelProps {
  index: number
  value: number
  children: ReactNode
}

function TabPanel({ index, value, children }: TabPanelProps): React.JSX.Element {
  const [hasBeenActive, setHasBeenActive] = useState(value === index)
  useEffect(() => {
    if (value === index) setHasBeenActive(true)
  }, [value, index])

  return (
    <Box role="tabpanel" hidden={value !== index} sx={{ pt: 3 }}>
      {hasBeenActive && children}
    </Box>
  )
}

// ─── Editor ───────────────────────────────────────────────────────────────────

interface ClassEditorPageProps {
  recordId?: string
  onClose?: () => void
}

export default function ClassEditorPage({ recordId, onClose }: ClassEditorPageProps = {}): React.JSX.Element {
  const { id: paramId } = useParams<{ id: string }>()
  const id = recordId ?? paramId
  const navigate = useNavigate()
  const goBack = onClose ?? (() => void navigate('/classes'))

  const [record, setRecord] = useState<ClassRecord | null>(null)
  const [displayName, setDisplayName] = useState('')
  const [exportKey, setExportKey] = useState('')
  const [description, setDescription] = useState('')
  const [resourceMultiplier, setResourceMultiplier] = useState('1')
  const [isDirty, setDirty] = useState(false)
  const [isSaving, setSaving] = useState(false)
  const [isLoading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [savedAt, setSavedAt] = useState<Date | null>(null)
  const [activeTab, setActiveTab] = useState(0)
  const [abilityAssignments, setAbilityAssignments] = useState<ClassAbilityAssignment[]>([])
  const [allAbilities, setAllAbilities] = useState<AbilityRecord[]>([])
  const [usedBy, setUsedBy] = useState<ClassUsedBy | null>(null)
  const [usedByLoading, setUsedByLoading] = useState(false)
  const [statGrowthDirty, setStatGrowthDirty] = useState(false)
  const [derivedStatsDirty, setDerivedStatsDirty] = useState(false)
  const statGrowthRef = useRef<StatGrowthEditorRef>(null)
  const derivedStatsRef = useRef<DerivedStatsEditorRef>(null)
  const { recordIssues, runValidation } = useRecordValidation('classes', id)

  const isAnyDirty = isDirty || statGrowthDirty || derivedStatsDirty

  type TabFields = Omit<FormSnapshot, 'displayName' | 'exportKey'>
  const baselineRef = useRef<TabFields | null>(null)

  const tabFieldMap: Record<number, (keyof TabFields)[]> = useMemo(() => ({
    1: ['description', 'resourceMultiplier'],
  }), [])

  const currentTabFields: TabFields = useMemo(() => ({
    description,
    resourceMultiplier,
  }), [description, resourceMultiplier])

  const dirtyTabs = useTabDirtyTracking(currentTabFields, baselineRef.current, tabFieldMap)

  const applySnapshot = useCallback((snapshot: FormSnapshot) => {
    setDisplayName(snapshot.displayName)
    setExportKey(snapshot.exportKey)
    setDescription(snapshot.description)
    setResourceMultiplier(snapshot.resourceMultiplier)
    setDirty(true)
    setSavedAt(null)
  }, [])

  const undoRedo = useUndoRedo<FormSnapshot>(applySnapshot)

  const pushSnapshot = (overrides: Partial<FormSnapshot> = {}): void => {
    setDirty(true)
    setSavedAt(null)
    undoRedo.pushState({ displayName, exportKey, description, resourceMultiplier, ...overrides })
  }

  const load = useCallback(async () => {
    if (!id) return
    setLoading(true)
    setError(null)
    try {
      const [data, assignments, abilities] = await Promise.all([
        classesApi.get(id),
        classesApi.getAbilityAssignments(id),
        abilitiesApi.list(true),
      ])
      if (!data) {
        setError('Class not found.')
        return
      }
      setRecord(data)
      setDisplayName(data.displayName)
      setExportKey(data.exportKey)
      setDescription(data.description)
      setResourceMultiplier(String(data.resourceMultiplier))
      setAbilityAssignments(assignments)
      setAllAbilities(abilities)
      setDirty(false)
      baselineRef.current = {
        description: data.description,
        resourceMultiplier: String(data.resourceMultiplier),
      }
      undoRedo.reset({
        displayName: data.displayName,
        exportKey: data.exportKey,
        description: data.description,
        resourceMultiplier: String(data.resourceMultiplier),
      })
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to load class.')
    } finally {
      setLoading(false)
    }
  }, [id])

  const handleAbilityAssignmentsChange = async (next: AbilityAssignmentRef[]): Promise<void> => {
    if (!id) return
    try {
      await classesApi.setAbilityAssignments(id, next)
      setAbilityAssignments(next)
      await runValidation()
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to save ability assignments.')
    }
  }

  useEffect(() => {
    void load()
  }, [load])

  // Load "Used By" data eagerly for InspectorRail
  useEffect(() => {
    if (!id) return
    setUsedByLoading(true)
    classesApi
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
      if (isDirty) {
        const updated = await classesApi.update(id, {
          displayName: displayName.trim(),
          exportKey: exportKey.trim(),
          description: description.trim(),
          resourceMultiplier: parseFloat(resourceMultiplier) || 1,
        })
        if (updated) {
          setRecord(updated)
          setDirty(false)
          baselineRef.current = {
            description: description.trim(),
            resourceMultiplier,
          }
        }
      }
      const subSaves: Promise<void>[] = []
      if (statGrowthDirty && statGrowthRef.current) subSaves.push(statGrowthRef.current.save())
      if (derivedStatsDirty && derivedStatsRef.current) subSaves.push(derivedStatsRef.current.save())
      if (subSaves.length > 0) await Promise.all(subSaves)
      setSavedAt(new Date())
      await runValidation()
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to save class.')
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
        <Alert severity="error">{error ?? 'Class not found.'}</Alert>
        <Button sx={{ mt: 2 }} onClick={goBack}>
          Back to Classes
        </Button>
      </Box>
    )
  }

  const handleBack = goBack
  const handleDiscard = (): void => {
    void load()
    statGrowthRef.current?.reload()
    derivedStatsRef.current?.reload()
  }

  return (
    <Box>
      <Box sx={{ position: 'sticky', top: 0, zIndex: 10, bgcolor: 'background.default', mt: -3, pt: 3 }}>
        <EditHeader
          backLabel="Character Classes"
          onBack={handleBack}
          displayName={displayName}
          onDisplayNameChange={(value) => {
            setDisplayName(value)
            pushSnapshot({ displayName: value })
          }}
          exportKey={exportKey}
          isDirty={isAnyDirty}
          isSaving={isSaving}
          onSave={() => void handleSave()}
          savedAt={savedAt}
          canUndo={undoRedo.canUndo}
          canRedo={undoRedo.canRedo}
          onUndo={undoRedo.triggerUndo}
          onRedo={undoRedo.triggerRedo}
        />

        <Tabs value={activeTab} onChange={(_, v: number) => setActiveTab(v)} sx={{ mb: 0 }}>
          <Tab label="Overview" data-tid="tab-class-overview" />
          <Tab label={<span>Details<DirtyDot visible={dirtyTabs.has(1)} /></span>} data-tid="tab-class-details" />
          <Tab label={<span>Stat Growth<DirtyDot visible={statGrowthDirty} /></span>} data-tid="tab-class-stat-growth" />
          <Tab label={<span>Derived Stats<DirtyDot visible={derivedStatsDirty} /></span>} data-tid="tab-class-derived-stats" />
          <Tab label="Abilities" data-tid="tab-class-abilities" />
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
        <Stack spacing={3} sx={{ maxWidth: 600 }}>
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
            label="Resource Multiplier"
            value={resourceMultiplier}
            onChange={(e) => {
              setResourceMultiplier(e.target.value)
              pushSnapshot({ resourceMultiplier: e.target.value })
            }}
            type="number"
            inputProps={{ step: 0.1, min: 0 }}
            helperText="Class-level metadata field — usable as a variable in derived stat formulas"
            sx={{ maxWidth: 240 }}
          />
        </Stack>
      </TabPanel>

      <TabPanel index={2} value={activeTab}>
        <StatGrowthEditor ref={statGrowthRef} classId={record.id} onDirtyChange={setStatGrowthDirty} />
      </TabPanel>

      <TabPanel index={3} value={activeTab}>
        <DerivedStatsEditor
          ref={derivedStatsRef}
          classId={record.id}
          resourceMultiplier={parseFloat(resourceMultiplier) || 1}
          onDirtyChange={setDerivedStatsDirty}
        />
      </TabPanel>

      <TabPanel index={4} value={activeTab}>
        <AbilityAssignmentPanel
          assignments={abilityAssignments}
          abilities={allAbilities}
          onChange={(next) => void handleAbilityAssignmentsChange(next)}
          disabled={isSaving}
        />
      </TabPanel>

      <SaveBar
        isDirty={isAnyDirty}
        isSaving={isSaving}
        onSave={() => void handleSave()}
        onDiscard={handleDiscard}
      />
    </Box>
  )
}

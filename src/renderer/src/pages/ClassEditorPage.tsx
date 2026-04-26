import { ArrowBack as BackIcon, Redo as RedoIcon, Undo as UndoIcon } from '@mui/icons-material'
import {
  Alert,
  Box,
  Button,
  Divider,
  IconButton,
  Stack,
  Tab,
  Tabs,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material'
import { useCallback, useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { abilitiesApi } from '../../api/abilities.api'
import { classesApi } from '../../api/classes.api'
import type {
  AbilityRecord,
  ClassAbilityAssignment,
  ClassRecord,
} from '../../../shared/domain-types'
import AbilityAssignmentPanel, { type AbilityAssignmentRef } from '../components/AbilityAssignmentPanel'
import DerivedStatsEditor from '../components/DerivedStatsEditor'
import StatGrowthEditor from '../components/StatGrowthEditor'
import ValidationBanner from '../components/ValidationBanner'
import { useRecordValidation } from '../hooks/useRecordValidation'
import { useUndoRedo } from '../hooks/useUndoRedo'

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
  const { recordIssues, runValidation } = useRecordValidation('classes', id)

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

  const handleSave = async (): Promise<void> => {
    if (!id) return
    setSaving(true)
    setError(null)
    try {
      const updated = await classesApi.update(id, {
        displayName: displayName.trim(),
        exportKey: exportKey.trim(),
        description: description.trim(),
        resourceMultiplier: parseFloat(resourceMultiplier) || 1,
      })
      if (updated) {
        setRecord(updated)
        setDirty(false)
        setSavedAt(new Date())
        await runValidation()
      }
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

  return (
    <Box>
      {/* Header */}
      <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1 }}>
        <Tooltip title="Back to Classes">
          <IconButton size="small" onClick={goBack}>
            <BackIcon fontSize="small" />
          </IconButton>
        </Tooltip>
        <Typography variant="caption" color="text.secondary">
          Character Classes
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
            placeholder="Class Name"
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
            helperText="Export key — used in exported files"
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
            disabled={!isDirty || isSaving}
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

      {/* Tabs */}
      <Tabs value={activeTab} onChange={(_, v: number) => setActiveTab(v)} sx={{ mb: 0 }}>
        <Tab label="Overview" />
        <Tab label="Stat Growth" />
        <Tab label="Derived Stats" />
        <Tab label="Abilities" />
      </Tabs>

      <Divider />

      {/* Overview tab */}
      <TabPanel index={0} value={activeTab}>
        <Stack spacing={3} sx={{ maxWidth: 600 }}>
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

      {/* Stat Growth tab */}
      <TabPanel index={1} value={activeTab}>
        <StatGrowthEditor classId={record.id} />
      </TabPanel>

      {/* Derived Stats tab */}
      <TabPanel index={2} value={activeTab}>
        <DerivedStatsEditor
          classId={record.id}
          resourceMultiplier={parseFloat(resourceMultiplier) || 1}
        />
      </TabPanel>

      {/* Abilities tab */}
      <TabPanel index={3} value={activeTab}>
        <AbilityAssignmentPanel
          assignments={abilityAssignments}
          abilities={allAbilities}
          onChange={(next) => void handleAbilityAssignmentsChange(next)}
          disabled={isSaving}
        />
      </TabPanel>
    </Box>
  )
}

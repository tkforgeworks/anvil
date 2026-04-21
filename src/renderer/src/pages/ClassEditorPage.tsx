import { ArrowBack as BackIcon } from '@mui/icons-material'
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

export default function ClassEditorPage(): React.JSX.Element {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()

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
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to save ability assignments.')
    }
  }

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
        <Button sx={{ mt: 2 }} onClick={() => void navigate('/classes')}>
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
          <IconButton size="small" onClick={() => void navigate('/classes')}>
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
              markDirty()
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
              markDirty()
            }}
            inputProps={{ style: { fontFamily: 'monospace', fontSize: '0.8rem' } }}
            placeholder="export-key"
            helperText="Export key — used in exported files"
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
            disabled={!isDirty || isSaving}
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
              markDirty()
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
              markDirty()
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

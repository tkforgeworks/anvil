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
  TextField,
  Tooltip,
  Typography,
} from '@mui/material'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { classesApi } from '../../api/classes.api'
import { metaApi } from '../../api/meta.api'
import { npcsApi } from '../../api/npcs.api'
import ClassAssignmentPanel from '../components/ClassAssignmentPanel'
import CustomFieldsPanel from '../components/CustomFieldsPanel'
import NpcStatBlockPanel from '../components/NpcStatBlockPanel'
import type {
  ClassRecord,
  MetaNpcType,
  MetaStat,
  NpcClassAssignment,
  NpcRecord,
  StatGrowthEntry,
} from '../../../shared/domain-types'

const DEFAULT_MAX_LEVEL = 20

export default function NpcEditorPage(): React.JSX.Element {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()

  const [record, setRecord] = useState<NpcRecord | null>(null)
  const [npcTypes, setNpcTypes] = useState<MetaNpcType[]>([])
  const [classes, setClasses] = useState<ClassRecord[]>([])
  const [stats, setStats] = useState<MetaStat[]>([])
  const [maxLevel, setMaxLevel] = useState(DEFAULT_MAX_LEVEL)
  const [assignments, setAssignments] = useState<NpcClassAssignment[]>([])
  const [growthByClass, setGrowthByClass] = useState<Map<string, StatGrowthEntry[]>>(new Map())
  const [overrides, setOverrides] = useState<Record<string, number | null>>({})

  const [displayName, setDisplayName] = useState('')
  const [exportKey, setExportKey] = useState('')
  const [description, setDescription] = useState('')
  const [npcTypeId, setNpcTypeId] = useState('')
  const [isDirty, setDirty] = useState(false)
  const [isSaving, setSaving] = useState(false)
  const [isLoading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [savedAt, setSavedAt] = useState<Date | null>(null)

  const typeById = useMemo(() => new Map(npcTypes.map((type) => [type.id, type])), [npcTypes])

  const loadGrowthFor = useCallback(
    async (classIds: string[], existing: Map<string, StatGrowthEntry[]>): Promise<Map<string, StatGrowthEntry[]>> => {
      const next = new Map(existing)
      const missing = classIds.filter((classId) => !next.has(classId))
      if (missing.length === 0) return next
      const fetched = await Promise.all(
        missing.map(async (classId) => [classId, await classesApi.getStatGrowth(classId)] as const),
      )
      for (const [classId, entries] of fetched) next.set(classId, entries)
      return next
    },
    [],
  )

  const load = useCallback(async () => {
    if (!id) return
    setLoading(true)
    setError(null)
    try {
      const [data, typeList, classList, statList, settings, assignmentList] = await Promise.all([
        npcsApi.get(id),
        metaApi.listNpcTypes(),
        classesApi.list(true),
        metaApi.listStats(),
        metaApi.getProjectSettings(),
        npcsApi.getClassAssignments(id),
      ])
      if (!data) {
        setError('NPC not found.')
        return
      }
      setRecord(data)
      setDisplayName(data.displayName)
      setExportKey(data.exportKey)
      setDescription(data.description)
      setNpcTypeId(data.npcTypeId)
      setNpcTypes(typeList)
      setClasses(classList)
      setStats(statList)
      setMaxLevel(settings.maxLevel)
      setAssignments(assignmentList)
      setOverrides({ ...data.combatStats })

      const growth = await loadGrowthFor(
        assignmentList.map((a) => a.classId),
        new Map(),
      )
      setGrowthByClass(growth)
      setDirty(false)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to load NPC.')
    } finally {
      setLoading(false)
    }
  }, [id, loadGrowthFor])

  useEffect(() => {
    void load()
  }, [load])

  const markDirty = (): void => {
    setDirty(true)
    setSavedAt(null)
  }

  const handleTypeChange = (nextNpcTypeId: string): void => {
    if (record && nextNpcTypeId !== record.npcTypeId) {
      const confirmed = window.confirm(
        'Changing NPC type can remove custom field values that do not belong to the new type. Continue?',
      )
      if (!confirmed) return
    }
    setNpcTypeId(nextNpcTypeId)
    markDirty()
  }

  const handleAssignmentsChange = async (next: NpcClassAssignment[]): Promise<void> => {
    if (!id) return
    try {
      await npcsApi.setClassAssignments(id, next)
      setAssignments(next)
      const growth = await loadGrowthFor(
        next.map((a) => a.classId),
        growthByClass,
      )
      setGrowthByClass(growth)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to save class assignments.')
    }
  }

  const handleOverrideChange = (statId: string, value: number | null): void => {
    setOverrides((prev) => {
      const next = { ...prev }
      if (value == null) delete next[statId]
      else next[statId] = value
      return next
    })
    markDirty()
  }

  const handleSave = async (): Promise<void> => {
    if (!id) return
    setSaving(true)
    setError(null)
    try {
      const updated = await npcsApi.update(id, {
        displayName: displayName.trim(),
        exportKey: exportKey.trim(),
        description: description.trim(),
        npcTypeId,
        combatStats: overrides,
      })
      if (updated) {
        setRecord(updated)
        setOverrides({ ...updated.combatStats })
        setDirty(false)
        setSavedAt(new Date())
      }
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to save NPC.')
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
        <Alert severity="error">{error ?? 'NPC not found.'}</Alert>
        <Button sx={{ mt: 2 }} onClick={() => void navigate('/npcs')}>
          Back to NPCs
        </Button>
      </Box>
    )
  }

  const deletedAssignedClasses = assignments
    .map((a) => classes.find((c) => c.id === a.classId))
    .filter((c): c is ClassRecord => c != null && c.deletedAt != null)

  return (
    <Box>
      <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1 }}>
        <Tooltip title="Back to NPCs">
          <IconButton size="small" onClick={() => void navigate('/npcs')}>
            <BackIcon fontSize="small" />
          </IconButton>
        </Tooltip>
        <Typography variant="caption" color="text.secondary">
          NPCs
        </Typography>
      </Stack>

      <Stack direction="row" alignItems="flex-start" justifyContent="space-between" sx={{ mb: 3 }} spacing={2}>
        <Box sx={{ flex: 1, minWidth: 0 }}>
          <TextField
            variant="standard"
            value={displayName}
            onChange={(e) => { setDisplayName(e.target.value); markDirty() }}
            inputProps={{ style: { fontSize: '1.5rem', fontWeight: 600 } }}
            placeholder="NPC Name"
            fullWidth
            sx={{ mb: 0.5 }}
          />
          <TextField
            variant="standard"
            value={exportKey}
            onChange={(e) => { setExportKey(e.target.value); markDirty() }}
            inputProps={{ style: { fontFamily: 'monospace', fontSize: '0.8rem' } }}
            placeholder="export-key"
            helperText="Export key - used in exported files"
            sx={{ maxWidth: 360 }}
          />
        </Box>
        <Stack direction="row" alignItems="center" spacing={2} sx={{ pt: 0.5 }}>
          {savedAt && <Typography variant="caption" color="success.main">Saved at {savedAt.toLocaleTimeString()}</Typography>}
          <Button variant="contained" onClick={() => void handleSave()} disabled={!isDirty || isSaving || !displayName.trim() || !exportKey.trim() || !npcTypeId}>
            Save
          </Button>
        </Stack>
      </Stack>

      {error && <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>{error}</Alert>}

      <Stack spacing={3} sx={{ maxWidth: 900 }}>
        <FormControl fullWidth required sx={{ maxWidth: 760 }}>
          <InputLabel id="npc-type-label">NPC Type</InputLabel>
          <Select labelId="npc-type-label" label="NPC Type" value={npcTypeId} onChange={(e) => handleTypeChange(e.target.value)}>
            {npcTypes.map((type) => <MenuItem key={type.id} value={type.id}>{type.displayName}</MenuItem>)}
          </Select>
        </FormControl>

        <TextField label="Description" value={description} onChange={(e) => { setDescription(e.target.value); markDirty() }} multiline minRows={4} fullWidth sx={{ maxWidth: 760 }} />

        <Divider />

        <Box>
          <Typography variant="subtitle1" gutterBottom>
            Classes
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            Assign one or more character classes at specified levels. Stat values from all assigned classes combine additively.
          </Typography>
          {deletedAssignedClasses.length > 0 && (
            <Alert severity="warning" sx={{ mb: 2 }}>
              This NPC is assigned to soft-deleted {deletedAssignedClasses.length === 1 ? 'class' : 'classes'}:{' '}
              {deletedAssignedClasses.map((c) => c.displayName).join(', ')}. Their stat contributions are still included.
            </Alert>
          )}
          <ClassAssignmentPanel
            assignments={assignments}
            classes={classes}
            maxLevel={maxLevel}
            onChange={(next) => void handleAssignmentsChange(next)}
            disabled={isSaving}
          />
        </Box>

        <Divider />

        <Box>
          <Typography variant="subtitle1" gutterBottom>
            Stat Block
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            Inherited values are summed from assigned classes at their levels. Enter an override to replace the inherited value for any stat.
          </Typography>
          <NpcStatBlockPanel
            stats={stats}
            assignments={assignments}
            growthByClass={growthByClass}
            overrides={overrides}
            onOverrideChange={handleOverrideChange}
            disabled={isSaving}
          />
        </Box>

        <Divider />

        <Box>
          <Typography variant="subtitle1" gutterBottom>
            Type Fields
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            {typeById.get(npcTypeId)?.displayName ?? 'Selected NPC type'}
          </Typography>
          <CustomFieldsPanel
            key={npcTypeId}
            domain="npcs"
            recordId={record.id}
            scopeType="npc_type"
            scopeId={npcTypeId}
          />
        </Box>
      </Stack>
    </Box>
  )
}

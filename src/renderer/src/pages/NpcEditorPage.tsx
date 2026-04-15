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
import { metaApi } from '../../api/meta.api'
import { npcsApi } from '../../api/npcs.api'
import CustomFieldsPanel from '../components/CustomFieldsPanel'
import type { MetaNpcType, NpcRecord } from '../../../shared/domain-types'

export default function NpcEditorPage(): React.JSX.Element {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()

  const [record, setRecord] = useState<NpcRecord | null>(null)
  const [npcTypes, setNpcTypes] = useState<MetaNpcType[]>([])
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

  const load = useCallback(async () => {
    if (!id) return
    setLoading(true)
    setError(null)
    try {
      const [data, typeList] = await Promise.all([
        npcsApi.get(id),
        metaApi.listNpcTypes(),
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
      setDirty(false)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to load NPC.')
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
      })
      if (updated) {
        setRecord(updated)
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

      <Stack spacing={3} sx={{ maxWidth: 760 }}>
        <FormControl fullWidth required>
          <InputLabel id="npc-type-label">NPC Type</InputLabel>
          <Select labelId="npc-type-label" label="NPC Type" value={npcTypeId} onChange={(e) => handleTypeChange(e.target.value)}>
            {npcTypes.map((type) => <MenuItem key={type.id} value={type.id}>{type.displayName}</MenuItem>)}
          </Select>
        </FormControl>

        <TextField label="Description" value={description} onChange={(e) => { setDescription(e.target.value); markDirty() }} multiline minRows={4} fullWidth />

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

import { ArrowBack as BackIcon } from '@mui/icons-material'
import {
  Alert,
  Box,
  Button,
  Chip,
  CircularProgress,
  Divider,
  IconButton,
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
  Tooltip,
  Typography,
} from '@mui/material'
import { useCallback, useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { abilitiesApi } from '../../api/abilities.api'
import { metaApi } from '../../api/meta.api'
import type { AbilityRecord, AbilityUsedBy, MetaStat } from '../../../shared/domain-types'

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

export default function AbilityEditorPage(): React.JSX.Element {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()

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
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to load ability.')
    } finally {
      setLoading(false)
    }
  }, [id])

  useEffect(() => {
    void load()
  }, [load])

  // Lazy-load "Used By" when that tab is first opened
  useEffect(() => {
    if (activeTab !== 2 || !id || usedBy !== null) return
    setUsedByLoading(true)
    abilitiesApi
      .getUsedBy(id)
      .then((result) => setUsedBy(result))
      .catch((cause) =>
        setError(cause instanceof Error ? cause.message : 'Failed to load Used By data.'),
      )
      .finally(() => setUsedByLoading(false))
  }, [activeTab, id, usedBy])

  const markDirty = (): void => {
    setDirty(true)
    setSavedAt(null)
  }

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
        <Button sx={{ mt: 2 }} onClick={() => void navigate('/abilities')}>
          Back to Abilities
        </Button>
      </Box>
    )
  }

  return (
    <Box>
      {/* Breadcrumb */}
      <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1 }}>
        <Tooltip title="Back to Abilities">
          <IconButton size="small" onClick={() => void navigate('/abilities')}>
            <BackIcon fontSize="small" />
          </IconButton>
        </Tooltip>
        <Typography variant="caption" color="text.secondary">
          Abilities
        </Typography>
      </Stack>

      {/* Title row */}
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
            placeholder="Ability Name"
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
      <Tabs value={activeTab} onChange={(_, v: number) => setActiveTab(v)}>
        <Tab label="Details" />
        <Tab label="Stat Modifiers" />
        <Tab label="Used By" />
      </Tabs>

      {/* Details tab */}
      <TabPanel index={0} value={activeTab}>
        <Stack spacing={2} sx={{ maxWidth: 600 }}>
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
            label="Ability Type"
            value={abilityType}
            onChange={(e) => {
              setAbilityType(e.target.value)
              markDirty()
            }}
            fullWidth
            helperText="e.g. active, passive, ultimate"
          />
          <TextField
            label="Resource Type"
            value={resourceType}
            onChange={(e) => {
              setResourceType(e.target.value)
              markDirty()
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
                markDirty()
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
                markDirty()
              }}
              inputProps={{ min: 0 }}
              helperText="In turns or seconds"
              sx={{ flex: 1 }}
            />
          </Stack>
        </Stack>
      </TabPanel>

      {/* Stat Modifiers tab */}
      <TabPanel index={1} value={activeTab}>
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
                          setStatModifiers((prev) => ({ ...prev, [stat.id]: e.target.value }))
                          markDirty()
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

      {/* Used By tab */}
      <TabPanel index={2} value={activeTab}>
        {usedByLoading ? (
          <CircularProgress size={24} />
        ) : (
          usedBy && (
            <Stack spacing={3}>
              <Box>
                <Typography variant="subtitle2" sx={{ mb: 1 }}>
                  Character Classes ({usedBy.classes.length})
                </Typography>
                {usedBy.classes.length === 0 ? (
                  <Typography variant="body2" color="text.secondary">
                    Not assigned to any class.
                  </Typography>
                ) : (
                  <Stack direction="row" flexWrap="wrap" gap={1}>
                    {usedBy.classes.map((c) => (
                      <Chip
                        key={c.id}
                        label={c.displayName}
                        size="small"
                        clickable
                        onClick={() => void navigate(`/classes/${c.id}`)}
                      />
                    ))}
                  </Stack>
                )}
              </Box>
              <Box>
                <Typography variant="subtitle2" sx={{ mb: 1 }}>
                  NPCs ({usedBy.npcs.length})
                </Typography>
                {usedBy.npcs.length === 0 ? (
                  <Typography variant="body2" color="text.secondary">
                    Not assigned to any NPC.
                  </Typography>
                ) : (
                  <Stack direction="row" flexWrap="wrap" gap={1}>
                    {usedBy.npcs.map((n) => (
                      <Chip key={n.id} label={n.displayName} size="small" />
                    ))}
                  </Stack>
                )}
              </Box>
            </Stack>
          )
        )}
      </TabPanel>
    </Box>
  )
}

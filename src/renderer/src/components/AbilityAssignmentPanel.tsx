import {
  ArrowDownward as ArrowDownIcon,
  ArrowUpward as ArrowUpIcon,
  Delete as RemoveIcon,
  Warning as WarningIcon,
} from '@mui/icons-material'
import {
  Alert,
  Autocomplete,
  Box,
  Button,
  Chip,
  CircularProgress,
  IconButton,
  List,
  ListItem,
  ListItemText,
  Paper,
  Stack,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material'
import { useCallback, useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { abilitiesApi } from '../../api/abilities.api'
import { classesApi } from '../../api/classes.api'
import type { AbilityRecord, ClassAbilityAssignment } from '../../../shared/domain-types'

interface Props {
  classId: string
}

interface AssignedRow {
  abilityId: string
  sortOrder: number
  displayName: string
  isDeleted: boolean
}

export default function AbilityAssignmentPanel({ classId }: Props): React.JSX.Element {
  const navigate = useNavigate()

  const [rows, setRows] = useState<AssignedRow[]>([])
  const [allAbilities, setAllAbilities] = useState<AbilityRecord[]>([])
  const [isLoading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [pickerValue, setPickerValue] = useState<AbilityRecord | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [assignments, abilities] = await Promise.all([
        classesApi.getAbilityAssignments(classId),
        abilitiesApi.list(true), // include deleted so we can show warning state
      ])

      const abilityMap = new Map(abilities.map((a) => [a.id, a]))
      setAllAbilities(abilities)

      const resolved: AssignedRow[] = assignments.map((a) => {
        const ability = abilityMap.get(a.abilityId)
        return {
          abilityId: a.abilityId,
          sortOrder: a.sortOrder,
          displayName: ability?.displayName ?? `[Unknown: ${a.abilityId}]`,
          isDeleted: ability?.deletedAt != null,
        }
      })
      setRows(resolved)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to load ability assignments.')
    } finally {
      setLoading(false)
    }
  }, [classId])

  useEffect(() => {
    void load()
  }, [load])

  const save = async (updated: AssignedRow[]): Promise<void> => {
    try {
      const assignments: ClassAbilityAssignment[] = updated.map((r, i) => ({
        abilityId: r.abilityId,
        sortOrder: i,
      }))
      await classesApi.setAbilityAssignments(classId, assignments)
      // Update local sortOrder to match persisted state
      setRows(updated.map((r, i) => ({ ...r, sortOrder: i })))
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to save ability assignments.')
    }
  }

  const handleAdd = async (): Promise<void> => {
    if (!pickerValue) return
    const ability = pickerValue
    setPickerValue(null)
    const next: AssignedRow[] = [
      ...rows,
      {
        abilityId: ability.id,
        sortOrder: rows.length,
        displayName: ability.displayName,
        isDeleted: ability.deletedAt != null,
      },
    ]
    await save(next)
  }

  const handleRemove = async (abilityId: string): Promise<void> => {
    await save(rows.filter((r) => r.abilityId !== abilityId))
  }

  const handleMoveUp = async (index: number): Promise<void> => {
    if (index === 0) return
    const next = [...rows]
    ;[next[index - 1], next[index]] = [next[index], next[index - 1]]
    await save(next)
  }

  const handleMoveDown = async (index: number): Promise<void> => {
    if (index === rows.length - 1) return
    const next = [...rows]
    ;[next[index], next[index + 1]] = [next[index + 1], next[index]]
    await save(next)
  }

  const assignedIds = new Set(rows.map((r) => r.abilityId))
  const pickerOptions = allAbilities.filter((a) => a.deletedAt == null && !assignedIds.has(a.id))

  if (isLoading) {
    return (
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, py: 2 }}>
        <CircularProgress size={16} />
        <Typography variant="body2" color="text.secondary">
          Loading…
        </Typography>
      </Box>
    )
  }

  return (
    <Box>
      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      {/* Assigned list */}
      {rows.length === 0 ? (
        <Paper variant="outlined" sx={{ p: 3, mb: 2, textAlign: 'center' }}>
          <Typography variant="body2" color="text.secondary">
            No abilities assigned. Use the picker below to add one.
          </Typography>
        </Paper>
      ) : (
        <Paper variant="outlined" sx={{ mb: 2 }}>
          <List disablePadding>
            {rows.map((row, index) => (
              <ListItem
                key={row.abilityId}
                divider={index < rows.length - 1}
                sx={{ gap: 1 }}
                secondaryAction={
                  <Stack direction="row" spacing={0.5}>
                    <Tooltip title="Move up">
                      <span>
                        <IconButton
                          size="small"
                          onClick={() => void handleMoveUp(index)}
                          disabled={index === 0}
                        >
                          <ArrowUpIcon fontSize="small" />
                        </IconButton>
                      </span>
                    </Tooltip>
                    <Tooltip title="Move down">
                      <span>
                        <IconButton
                          size="small"
                          onClick={() => void handleMoveDown(index)}
                          disabled={index === rows.length - 1}
                        >
                          <ArrowDownIcon fontSize="small" />
                        </IconButton>
                      </span>
                    </Tooltip>
                    <Tooltip title="Remove assignment">
                      <IconButton
                        size="small"
                        onClick={() => void handleRemove(row.abilityId)}
                        color="error"
                      >
                        <RemoveIcon fontSize="small" />
                      </IconButton>
                    </Tooltip>
                  </Stack>
                }
              >
                <ListItemText
                  primary={
                    <Stack direction="row" alignItems="center" spacing={1}>
                      <Typography
                        variant="body2"
                        component="span"
                        sx={{
                          cursor: 'pointer',
                          '&:hover': { textDecoration: 'underline' },
                          color: row.isDeleted ? 'text.secondary' : 'text.primary',
                        }}
                        onClick={() => void navigate(`/abilities/${row.abilityId}`)}
                      >
                        {row.displayName}
                      </Typography>
                      {row.isDeleted && (
                        <Tooltip title="This ability has been soft-deleted">
                          <Chip
                            icon={<WarningIcon />}
                            label="Deleted"
                            size="small"
                            color="warning"
                            variant="outlined"
                          />
                        </Tooltip>
                      )}
                    </Stack>
                  }
                />
              </ListItem>
            ))}
          </List>
        </Paper>
      )}

      {/* Add picker */}
      <Stack direction="row" spacing={1} alignItems="center">
        <Autocomplete
          options={pickerOptions}
          getOptionLabel={(option) => option.displayName}
          value={pickerValue}
          onChange={(_e, value) => setPickerValue(value)}
          renderInput={(params) => (
            <TextField {...params} label="Add ability" size="small" placeholder="Search…" />
          )}
          sx={{ flex: 1, maxWidth: 400 }}
          size="small"
          noOptionsText={
            pickerOptions.length === 0 && allAbilities.filter((a) => a.deletedAt == null).length === 0
              ? 'No abilities exist yet'
              : 'No matching abilities'
          }
        />
        <Button
          variant="outlined"
          onClick={() => void handleAdd()}
          disabled={!pickerValue}
          size="small"
        >
          Add
        </Button>
      </Stack>
    </Box>
  )
}

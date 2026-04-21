import {
  ArrowDownward as ArrowDownIcon,
  ArrowUpward as ArrowUpIcon,
  Delete as RemoveIcon,
  Warning as WarningIcon,
} from '@mui/icons-material'
import {
  Autocomplete,
  Box,
  Button,
  Chip,
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
import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import type { AbilityRecord } from '../../../shared/domain-types'

export interface AbilityAssignmentRef {
  abilityId: string
  sortOrder: number
}

interface Props {
  assignments: AbilityAssignmentRef[]
  abilities: AbilityRecord[]
  onChange: (next: AbilityAssignmentRef[]) => void
  disabled?: boolean
}

export default function AbilityAssignmentPanel({
  assignments,
  abilities,
  onChange,
  disabled = false,
}: Props): React.JSX.Element {
  const navigate = useNavigate()
  const [pickerValue, setPickerValue] = useState<AbilityRecord | null>(null)

  const abilityMap = new Map(abilities.map((a) => [a.id, a]))
  const assignedIds = new Set(assignments.map((a) => a.abilityId))
  const pickerOptions = abilities.filter((a) => a.deletedAt == null && !assignedIds.has(a.id))

  const emit = (next: AbilityAssignmentRef[]): void => {
    onChange(next.map((a, i) => ({ abilityId: a.abilityId, sortOrder: i })))
  }

  const handleAdd = (): void => {
    if (!pickerValue) return
    emit([...assignments, { abilityId: pickerValue.id, sortOrder: assignments.length }])
    setPickerValue(null)
  }

  const handleRemove = (abilityId: string): void => {
    emit(assignments.filter((a) => a.abilityId !== abilityId))
  }

  const handleMoveUp = (index: number): void => {
    if (index === 0) return
    const next = [...assignments]
    ;[next[index - 1], next[index]] = [next[index], next[index - 1]]
    emit(next)
  }

  const handleMoveDown = (index: number): void => {
    if (index === assignments.length - 1) return
    const next = [...assignments]
    ;[next[index], next[index + 1]] = [next[index + 1], next[index]]
    emit(next)
  }

  return (
    <Box>
      {assignments.length === 0 ? (
        <Paper variant="outlined" sx={{ p: 3, mb: 2, textAlign: 'center' }}>
          <Typography variant="body2" color="text.secondary">
            No abilities assigned. Use the picker below to add one.
          </Typography>
        </Paper>
      ) : (
        <Paper variant="outlined" sx={{ mb: 2 }}>
          <List disablePadding>
            {assignments.map((assignment, index) => {
              const ability = abilityMap.get(assignment.abilityId)
              const displayName = ability?.displayName ?? `[Unknown: ${assignment.abilityId}]`
              const isDeleted = ability?.deletedAt != null
              return (
                <ListItem
                  key={assignment.abilityId}
                  divider={index < assignments.length - 1}
                  sx={{ gap: 1 }}
                  secondaryAction={
                    <Stack direction="row" spacing={0.5}>
                      <Tooltip title="Move up">
                        <span>
                          <IconButton
                            size="small"
                            onClick={() => handleMoveUp(index)}
                            disabled={index === 0 || disabled}
                          >
                            <ArrowUpIcon fontSize="small" />
                          </IconButton>
                        </span>
                      </Tooltip>
                      <Tooltip title="Move down">
                        <span>
                          <IconButton
                            size="small"
                            onClick={() => handleMoveDown(index)}
                            disabled={index === assignments.length - 1 || disabled}
                          >
                            <ArrowDownIcon fontSize="small" />
                          </IconButton>
                        </span>
                      </Tooltip>
                      <Tooltip title="Remove assignment">
                        <span>
                          <IconButton
                            size="small"
                            onClick={() => handleRemove(assignment.abilityId)}
                            color="error"
                            disabled={disabled}
                          >
                            <RemoveIcon fontSize="small" />
                          </IconButton>
                        </span>
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
                            cursor: ability ? 'pointer' : 'default',
                            '&:hover': ability ? { textDecoration: 'underline' } : undefined,
                            color: isDeleted ? 'text.secondary' : 'text.primary',
                          }}
                          onClick={() => ability && navigate(`/abilities/${assignment.abilityId}`)}
                        >
                          {displayName}
                        </Typography>
                        {isDeleted && (
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
              )
            })}
          </List>
        </Paper>
      )}

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
          disabled={disabled}
          noOptionsText={
            pickerOptions.length === 0 && abilities.filter((a) => a.deletedAt == null).length === 0
              ? 'No abilities exist yet'
              : 'No matching abilities'
          }
        />
        <Button
          variant="outlined"
          onClick={handleAdd}
          disabled={!pickerValue || disabled}
          size="small"
        >
          Add
        </Button>
      </Stack>
    </Box>
  )
}

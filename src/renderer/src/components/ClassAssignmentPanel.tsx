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
  Paper,
  Stack,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material'
import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import type { ClassRecord, NpcClassAssignment } from '../../../shared/domain-types'

interface Props {
  assignments: NpcClassAssignment[]
  classes: ClassRecord[]
  maxLevel: number
  onChange: (next: NpcClassAssignment[]) => void
  disabled?: boolean
}

export default function ClassAssignmentPanel({
  assignments,
  classes,
  maxLevel,
  onChange,
  disabled = false,
}: Props): React.JSX.Element {
  const navigate = useNavigate()
  const [pickerValue, setPickerValue] = useState<ClassRecord | null>(null)

  const classesById = new Map(classes.map((c) => [c.id, c]))
  const assignedIds = new Set(assignments.map((a) => a.classId))
  const pickerOptions = classes.filter((c) => c.deletedAt == null && !assignedIds.has(c.id))

  const emit = (next: NpcClassAssignment[]): void => {
    onChange(next.map((a, i) => ({ ...a, sortOrder: i })))
  }

  const handleAdd = (): void => {
    if (!pickerValue) return
    emit([...assignments, { classId: pickerValue.id, level: 1, sortOrder: assignments.length }])
    setPickerValue(null)
  }

  const handleRemove = (classId: string): void => {
    emit(assignments.filter((a) => a.classId !== classId))
  }

  const handleLevelChange = (classId: string, level: number): void => {
    const clamped = Math.max(1, Math.min(maxLevel, Math.floor(level)))
    emit(assignments.map((a) => (a.classId === classId ? { ...a, level: clamped } : a)))
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
            No classes assigned. Use the picker below to add one.
          </Typography>
        </Paper>
      ) : (
        <Paper variant="outlined" sx={{ mb: 2 }}>
          <List disablePadding>
            {assignments.map((assignment, index) => {
              const cls = classesById.get(assignment.classId)
              const displayName = cls?.displayName ?? `[Unknown: ${assignment.classId}]`
              const isDeleted = cls?.deletedAt != null
              return (
                <ListItem
                  key={assignment.classId}
                  divider={index < assignments.length - 1}
                  sx={{ gap: 2 }}
                >
                  <Stack direction="row" alignItems="center" spacing={1} sx={{ flex: 1, minWidth: 0 }}>
                    <Typography
                      variant="body2"
                      component="span"
                      sx={{
                        cursor: cls ? 'pointer' : 'default',
                        '&:hover': cls ? { textDecoration: 'underline' } : undefined,
                        color: isDeleted ? 'text.secondary' : 'text.primary',
                      }}
                      onClick={() => cls && navigate(`/classes/${assignment.classId}`)}
                    >
                      {displayName}
                    </Typography>
                    {isDeleted && (
                      <Tooltip title="This class has been soft-deleted — it still contributes to stats but may be permanently removed later">
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

                  <TextField
                    label="Level"
                    type="number"
                    size="small"
                    value={assignment.level}
                    onChange={(e) => handleLevelChange(assignment.classId, Number(e.target.value))}
                    inputProps={{ min: 1, max: maxLevel, style: { width: 60 } }}
                    disabled={disabled}
                  />

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
                          onClick={() => handleRemove(assignment.classId)}
                          color="error"
                          disabled={disabled}
                        >
                          <RemoveIcon fontSize="small" />
                        </IconButton>
                      </span>
                    </Tooltip>
                  </Stack>
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
            <TextField {...params} label="Add class" size="small" placeholder="Search…" />
          )}
          sx={{ flex: 1, maxWidth: 400 }}
          size="small"
          disabled={disabled}
          noOptionsText={
            pickerOptions.length === 0 && classes.filter((c) => c.deletedAt == null).length === 0
              ? 'No classes exist yet'
              : 'No matching classes'
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

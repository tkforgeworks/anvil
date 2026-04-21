import { RestartAlt as RevertIcon } from '@mui/icons-material'
import {
  Box,
  IconButton,
  Paper,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material'
import type {
  MetaStat,
  NpcClassAssignment,
  StatGrowthEntry,
} from '../../../shared/domain-types'

interface Props {
  stats: MetaStat[]
  assignments: NpcClassAssignment[]
  growthByClass: Map<string, StatGrowthEntry[]>
  overrides: Record<string, number | null>
  onOverrideChange: (statId: string, value: number | null) => void
  disabled?: boolean
}

function computeInherited(
  statId: string,
  assignments: NpcClassAssignment[],
  growthByClass: Map<string, StatGrowthEntry[]>,
): number {
  let sum = 0
  for (const a of assignments) {
    const entries = growthByClass.get(a.classId)
    if (!entries) continue
    const match = entries.find((e) => e.statId === statId && e.level === a.level)
    if (match) sum += match.value
  }
  return sum
}

export default function NpcStatBlockPanel({
  stats,
  assignments,
  growthByClass,
  overrides,
  onOverrideChange,
  disabled = false,
}: Props): React.JSX.Element {
  if (stats.length === 0) {
    return (
      <Paper variant="outlined" sx={{ p: 3, textAlign: 'center' }}>
        <Typography variant="body2" color="text.secondary">
          No stats defined in project settings.
        </Typography>
      </Paper>
    )
  }

  const sorted = [...stats].sort((a, b) => a.sortOrder - b.sortOrder)

  return (
    <TableContainer component={Paper} variant="outlined">
      <Table size="small">
        <TableHead>
          <TableRow>
            <TableCell>Stat</TableCell>
            <TableCell align="right">Inherited</TableCell>
            <TableCell align="right">Override</TableCell>
            <TableCell align="right">Final</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {sorted.map((stat) => {
            const inherited = computeInherited(stat.id, assignments, growthByClass)
            const rawOverride = overrides[stat.id]
            const hasOverride = rawOverride != null
            const overrideValue = hasOverride ? rawOverride : null
            const finalValue = hasOverride ? (overrideValue as number) : inherited

            return (
              <TableRow key={stat.id} hover>
                <TableCell>
                  <Typography variant="body2">{stat.displayName}</Typography>
                </TableCell>
                <TableCell align="right">
                  <Typography
                    variant="body2"
                    sx={{ fontFamily: 'monospace', color: hasOverride ? 'text.disabled' : 'text.secondary' }}
                  >
                    {inherited}
                  </Typography>
                </TableCell>
                <TableCell align="right">
                  <Stack direction="row" spacing={0.5} alignItems="center" justifyContent="flex-end">
                    <TextField
                      type="number"
                      size="small"
                      value={overrideValue ?? ''}
                      placeholder="—"
                      onChange={(e) => {
                        const raw = e.target.value
                        if (raw === '') {
                          onOverrideChange(stat.id, null)
                        } else {
                          const parsed = Number(raw)
                          if (!Number.isNaN(parsed)) onOverrideChange(stat.id, parsed)
                        }
                      }}
                      inputProps={{
                        style: {
                          width: 70,
                          textAlign: 'right',
                          fontFamily: 'monospace',
                          fontWeight: hasOverride ? 700 : 400,
                        },
                      }}
                      sx={
                        hasOverride
                          ? { '& .MuiOutlinedInput-notchedOutline': { borderWidth: 2, borderColor: 'warning.main' } }
                          : undefined
                      }
                      disabled={disabled}
                    />
                    <Tooltip title={hasOverride ? 'Revert to inherited' : 'No override'}>
                      <span>
                        <IconButton
                          size="small"
                          onClick={() => onOverrideChange(stat.id, null)}
                          disabled={!hasOverride || disabled}
                        >
                          <RevertIcon fontSize="small" />
                        </IconButton>
                      </span>
                    </Tooltip>
                  </Stack>
                </TableCell>
                <TableCell align="right">
                  <Box
                    sx={{
                      fontFamily: 'monospace',
                      fontWeight: hasOverride ? 700 : 500,
                      color: hasOverride ? 'warning.main' : 'text.primary',
                    }}
                  >
                    {finalValue}
                  </Box>
                </TableCell>
              </TableRow>
            )
          })}
        </TableBody>
      </Table>
    </TableContainer>
  )
}

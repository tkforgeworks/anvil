import {
  Alert,
  Box,
  Button,
  Divider,
  FormControl,
  InputLabel,
  MenuItem,
  Paper,
  Select,
  Stack,
  TextField,
  Typography,
} from '@mui/material'
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import {
  CartesianGrid,
  Legend,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import { classesApi } from '../../api/classes.api'
import { metaApi } from '../../api/meta.api'
import type { MetaStat, StatGrowthEntry } from '../../../shared/domain-types'

// One color per stat slot — Nord-ish palette
const STAT_COLORS = [
  '#5E81AC',
  '#A3BE8C',
  '#EBCB8B',
  '#D08770',
  '#BF616A',
  '#B48EAD',
  '#88C0D0',
]

type GridValues = Record<string, Record<number, string>> // statId → level → display string

interface ChartPoint {
  level: number
  [exportKey: string]: number
}

function buildChartData(
  gridValues: GridValues,
  stats: MetaStat[],
  maxLevel: number,
): ChartPoint[] {
  return Array.from({ length: maxLevel }, (_, i) => {
    const level = i + 1
    const point: ChartPoint = { level }
    for (const stat of stats) {
      const raw = gridValues[stat.id]?.[level]
      point[stat.exportKey] = raw !== undefined && raw !== '' ? parseFloat(raw) : 0
    }
    return point
  })
}

function buildInitialGrid(stats: MetaStat[], maxLevel: number, entries: StatGrowthEntry[]): GridValues {
  const grid: GridValues = {}
  for (const stat of stats) {
    grid[stat.id] = {}
    for (let level = 1; level <= maxLevel; level++) {
      grid[stat.id][level] = ''
    }
  }
  for (const entry of entries) {
    if (grid[entry.statId]) {
      grid[entry.statId][entry.level] = String(entry.value)
    }
  }
  return grid
}

function gridToEntries(gridValues: GridValues): StatGrowthEntry[] {
  const entries: StatGrowthEntry[] = []
  for (const [statId, levels] of Object.entries(gridValues)) {
    for (const [levelStr, valueStr] of Object.entries(levels)) {
      if (valueStr !== '') {
        const value = parseFloat(valueStr)
        if (!isNaN(value)) {
          entries.push({ statId, level: parseInt(levelStr, 10), value })
        }
      }
    }
  }
  return entries
}

// ─── Entry helpers ─────────────────────────────────────────────────────────────

interface FillColumnHelperProps {
  stats: MetaStat[]
  onApply: (statId: string, value: number) => void
}

function FillColumnHelper({ stats, onApply }: FillColumnHelperProps): React.JSX.Element {
  const [statId, setStatId] = useState(stats[0]?.id ?? '')
  const [value, setValue] = useState('')

  return (
    <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap">
      <Typography variant="caption" color="text.secondary" sx={{ minWidth: 80 }}>
        Fill column:
      </Typography>
      <FormControl size="small" sx={{ minWidth: 140 }}>
        <InputLabel id="fill-stat-label">Stat</InputLabel>
        <Select
          labelId="fill-stat-label"
          label="Stat"
          value={statId}
          onChange={(e) => setStatId(e.target.value)}
        >
          {stats.map((s) => (
            <MenuItem key={s.id} value={s.id}>
              {s.displayName}
            </MenuItem>
          ))}
        </Select>
      </FormControl>
      <TextField
        size="small"
        label="Value"
        type="number"
        value={value}
        onChange={(e) => setValue(e.target.value)}
        sx={{ width: 100 }}
      />
      <Button
        size="small"
        variant="outlined"
        disabled={value === '' || isNaN(parseFloat(value))}
        onClick={() => {
          onApply(statId, parseFloat(value))
          setValue('')
        }}
      >
        Apply
      </Button>
    </Stack>
  )
}

interface InterpolateHelperProps {
  stats: MetaStat[]
  maxLevel: number
  onApply: (statId: string, fromLevel: number, fromValue: number, toLevel: number, toValue: number) => void
}

function InterpolateHelper({ stats, maxLevel, onApply }: InterpolateHelperProps): React.JSX.Element {
  const [statId, setStatId] = useState(stats[0]?.id ?? '')
  const [fromLevel, setFromLevel] = useState('1')
  const [fromValue, setFromValue] = useState('')
  const [toLevel, setToLevel] = useState(String(maxLevel))
  const [toValue, setToValue] = useState('')

  const canApply =
    fromValue !== '' &&
    toValue !== '' &&
    !isNaN(parseFloat(fromValue)) &&
    !isNaN(parseFloat(toValue)) &&
    parseInt(fromLevel) < parseInt(toLevel)

  return (
    <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap">
      <Typography variant="caption" color="text.secondary" sx={{ minWidth: 80 }}>
        Interpolate:
      </Typography>
      <FormControl size="small" sx={{ minWidth: 140 }}>
        <InputLabel id="interp-stat-label">Stat</InputLabel>
        <Select
          labelId="interp-stat-label"
          label="Stat"
          value={statId}
          onChange={(e) => setStatId(e.target.value)}
        >
          {stats.map((s) => (
            <MenuItem key={s.id} value={s.id}>
              {s.displayName}
            </MenuItem>
          ))}
        </Select>
      </FormControl>
      <TextField size="small" label="From lvl" type="number" value={fromLevel} onChange={(e) => setFromLevel(e.target.value)} sx={{ width: 80 }} />
      <TextField size="small" label="From val" type="number" value={fromValue} onChange={(e) => setFromValue(e.target.value)} sx={{ width: 90 }} />
      <Typography variant="body2" color="text.secondary">→</Typography>
      <TextField size="small" label="To lvl" type="number" value={toLevel} onChange={(e) => setToLevel(e.target.value)} sx={{ width: 80 }} />
      <TextField size="small" label="To val" type="number" value={toValue} onChange={(e) => setToValue(e.target.value)} sx={{ width: 90 }} />
      <Button
        size="small"
        variant="outlined"
        disabled={!canApply}
        onClick={() => {
          onApply(
            statId,
            parseInt(fromLevel),
            parseFloat(fromValue),
            parseInt(toLevel),
            parseFloat(toValue),
          )
        }}
      >
        Apply
      </Button>
    </Stack>
  )
}

// ─── Main component ────────────────────────────────────────────────────────────

interface StatGrowthEditorProps {
  classId: string
}

export default function StatGrowthEditor({ classId }: StatGrowthEditorProps): React.JSX.Element {
  const [stats, setStats] = useState<MetaStat[]>([])
  const [maxLevel, setMaxLevel] = useState(50)
  const [gridValues, setGridValues] = useState<GridValues>({})
  const [chartData, setChartData] = useState<ChartPoint[]>([])
  const [hiddenStats, setHiddenStats] = useState<Set<string>>(new Set())
  const [isDirty, setDirty] = useState(false)
  const [isLoading, setLoading] = useState(true)
  const [isSaving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [savedAt, setSavedAt] = useState<Date | null>(null)

  // Debounce chart updates so the chart doesn't re-render on every keystroke
  const chartDebounceRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [loadedStats, settings, entries] = await Promise.all([
        metaApi.listStats(),
        metaApi.getProjectSettings(),
        classesApi.getStatGrowth(classId),
      ])
      setStats(loadedStats)
      setMaxLevel(settings.maxLevel)
      const grid = buildInitialGrid(loadedStats, settings.maxLevel, entries)
      setGridValues(grid)
      setChartData(buildChartData(grid, loadedStats, settings.maxLevel))
      setDirty(false)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to load stat growth data.')
    } finally {
      setLoading(false)
    }
  }, [classId])

  useEffect(() => {
    void load()
  }, [load])

  const handleCellChange = useCallback(
    (statId: string, level: number, value: string) => {
      setGridValues((prev) => {
        const next = { ...prev, [statId]: { ...prev[statId], [level]: value } }
        // Debounce chart update
        if (chartDebounceRef.current) clearTimeout(chartDebounceRef.current)
        chartDebounceRef.current = setTimeout(() => {
          setChartData(buildChartData(next, stats, maxLevel))
        }, 300)
        return next
      })
      setDirty(true)
      setSavedAt(null)
    },
    [stats, maxLevel],
  )

  const handleFillColumn = useCallback(
    (statId: string, value: number) => {
      setGridValues((prev) => {
        const levels: Record<number, string> = {}
        for (let level = 1; level <= maxLevel; level++) {
          levels[level] = String(value)
        }
        const next = { ...prev, [statId]: levels }
        setChartData(buildChartData(next, stats, maxLevel))
        return next
      })
      setDirty(true)
      setSavedAt(null)
    },
    [stats, maxLevel],
  )

  const handleInterpolate = useCallback(
    (statId: string, fromLevel: number, fromValue: number, toLevel: number, toValue: number) => {
      setGridValues((prev) => {
        const updated = { ...prev[statId] }
        const range = toLevel - fromLevel
        for (let level = fromLevel; level <= toLevel; level++) {
          const t = range === 0 ? 0 : (level - fromLevel) / range
          updated[level] = String(Math.round((fromValue + t * (toValue - fromValue)) * 1000) / 1000)
        }
        const next = { ...prev, [statId]: updated }
        setChartData(buildChartData(next, stats, maxLevel))
        return next
      })
      setDirty(true)
      setSavedAt(null)
    },
    [stats, maxLevel],
  )

  const handleSave = async (): Promise<void> => {
    setSaving(true)
    setError(null)
    try {
      await classesApi.setStatGrowth(classId, gridToEntries(gridValues))
      setDirty(false)
      setSavedAt(new Date())
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to save stat growth.')
    } finally {
      setSaving(false)
    }
  }

  const handleLegendClick = useCallback((payload: unknown) => {
    const dataKey = (payload as { dataKey?: unknown }).dataKey
    if (typeof dataKey !== 'string') return
    setHiddenStats((prev) => {
      const next = new Set(prev)
      if (next.has(dataKey)) next.delete(dataKey)
      else next.add(dataKey)
      return next
    })
  }, [])

  // Memoize the lines so Recharts doesn't recreate them on chart data changes
  const lines = useMemo(
    () =>
      stats.map((stat, i) => (
        <Line
          key={stat.id}
          type="monotone"
          dataKey={stat.exportKey}
          name={stat.displayName}
          stroke={STAT_COLORS[i % STAT_COLORS.length]}
          dot={false}
          hide={hiddenStats.has(stat.exportKey)}
          strokeWidth={2}
          isAnimationActive={false}
        />
      )),
    [stats, hiddenStats],
  )

  if (isLoading) {
    return <Typography color="text.secondary">Loading stat growth…</Typography>
  }

  if (stats.length === 0) {
    return <Typography color="text.secondary">No stats configured in this project.</Typography>
  }

  return (
    <Box>
      {/* Header */}
      <Stack direction="row" alignItems="center" justifyContent="space-between" sx={{ mb: 2 }}>
        <Typography variant="subtitle1" fontWeight={500}>
          Primary Stat Growth — levels 1–{maxLevel}
        </Typography>
        <Stack direction="row" alignItems="center" spacing={2}>
          {savedAt && (
            <Typography variant="caption" color="success.main">
              Saved at {savedAt.toLocaleTimeString()}
            </Typography>
          )}
          <Button
            variant="contained"
            size="small"
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

      {/* Chart */}
      <Paper variant="outlined" sx={{ p: 2, mb: 2 }}>
        <ResponsiveContainer width="100%" height={280}>
          <LineChart data={chartData} margin={{ top: 4, right: 16, bottom: 4, left: 0 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.08)" />
            <XAxis
              dataKey="level"
              label={{ value: 'Level', position: 'insideBottomRight', offset: -8, fontSize: 11 }}
              tick={{ fontSize: 11 }}
            />
            <YAxis tick={{ fontSize: 11 }} width={40} />
            <Tooltip
              contentStyle={{ fontSize: 12 }}
              labelFormatter={(label) => `Level ${label}`}
            />
            <Legend
              onClick={handleLegendClick}
              wrapperStyle={{ cursor: 'pointer', fontSize: 12 }}
              formatter={(value, entry) => (
                <span style={{ opacity: hiddenStats.has(entry.dataKey as string) ? 0.4 : 1 }}>
                  {value}
                </span>
              )}
            />
            {lines}
          </LineChart>
        </ResponsiveContainer>
      </Paper>

      {/* Entry helpers */}
      <Paper variant="outlined" sx={{ p: 1.5, mb: 2 }}>
        <Stack spacing={1}>
          <FillColumnHelper stats={stats} onApply={handleFillColumn} />
          <Divider />
          <InterpolateHelper stats={stats} maxLevel={maxLevel} onApply={handleInterpolate} />
        </Stack>
      </Paper>

      {/* Stat growth grid */}
      <Box
        sx={{
          overflow: 'auto',
          maxHeight: 420,
          border: 1,
          borderColor: 'divider',
          borderRadius: 1,
        }}
      >
        <table
          style={{
            borderCollapse: 'collapse',
            width: '100%',
            tableLayout: 'fixed',
          }}
        >
          <colgroup>
            <col style={{ width: 56 }} />
            {stats.map((s) => (
              <col key={s.id} style={{ width: 88 }} />
            ))}
          </colgroup>
          <thead>
            <tr>
              <th
                style={{
                  position: 'sticky',
                  top: 0,
                  left: 0,
                  zIndex: 3,
                  background: 'var(--table-header-bg, #2e3440)',
                  padding: '6px 8px',
                  textAlign: 'center',
                  fontSize: 11,
                  fontWeight: 600,
                  color: '#aaa',
                  borderBottom: '1px solid rgba(255,255,255,0.12)',
                  borderRight: '1px solid rgba(255,255,255,0.12)',
                }}
              >
                Lvl
              </th>
              {stats.map((stat, i) => (
                <th
                  key={stat.id}
                  title={stat.displayName}
                  style={{
                    position: 'sticky',
                    top: 0,
                    zIndex: 2,
                    background: 'var(--table-header-bg, #2e3440)',
                    padding: '6px 8px',
                    textAlign: 'center',
                    fontSize: 11,
                    fontWeight: 600,
                    color: STAT_COLORS[i % STAT_COLORS.length],
                    borderBottom: '1px solid rgba(255,255,255,0.12)',
                    borderRight: '1px solid rgba(255,255,255,0.06)',
                    cursor: 'default',
                  }}
                >
                  {stat.exportKey.toUpperCase()}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {Array.from({ length: maxLevel }, (_, i) => {
              const level = i + 1
              return (
                <GridRow
                  key={level}
                  level={level}
                  stats={stats}
                  gridValues={gridValues}
                  onCellChange={handleCellChange}
                />
              )
            })}
          </tbody>
        </table>
      </Box>
    </Box>
  )
}

// ─── Memoized row to prevent full-grid re-renders on single-cell edits ─────────

interface GridRowProps {
  level: number
  stats: MetaStat[]
  gridValues: GridValues
  onCellChange: (statId: string, level: number, value: string) => void
}

const GridRow = ({
  level,
  stats,
  gridValues,
  onCellChange,
}: GridRowProps): React.JSX.Element => {
  const isEven = level % 2 === 0
  const rowBg = isEven ? 'rgba(255,255,255,0.02)' : 'transparent'

  return (
    <tr style={{ background: rowBg }}>
      <td
        style={{
          position: 'sticky',
          left: 0,
          zIndex: 1,
          background: isEven ? '#2a2f3a' : '#272c36',
          padding: '2px 8px',
          textAlign: 'center',
          fontSize: 11,
          color: '#888',
          borderRight: '1px solid rgba(255,255,255,0.12)',
          fontVariantNumeric: 'tabular-nums',
        }}
      >
        {level}
      </td>
      {stats.map((stat) => (
        <td
          key={stat.id}
          style={{
            padding: '2px 4px',
            borderRight: '1px solid rgba(255,255,255,0.04)',
          }}
        >
          <input
            type="number"
            value={gridValues[stat.id]?.[level] ?? ''}
            onChange={(e) => onCellChange(stat.id, level, e.target.value)}
            style={{
              width: '100%',
              background: 'transparent',
              border: 'none',
              outline: 'none',
              color: 'inherit',
              fontSize: 12,
              fontFamily: 'monospace',
              textAlign: 'right',
              padding: '3px 4px',
              cursor: 'text',
            }}
            onFocus={(e) => {
              e.currentTarget.style.background = 'rgba(94, 129, 172, 0.15)'
              e.currentTarget.style.borderRadius = '3px'
            }}
            onBlur={(e) => {
              e.currentTarget.style.background = 'transparent'
            }}
          />
        </td>
      ))}
    </tr>
  )
}

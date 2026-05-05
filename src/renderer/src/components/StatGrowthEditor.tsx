import {
  Alert,
  Box,
  Button,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
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
import { forwardRef, memo, useCallback, useEffect, useImperativeHandle, useMemo, useRef, useState } from 'react'
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
import { formulasApi } from '../../api/formulas.api'
import { metaApi } from '../../api/meta.api'
import type { MetaStat, StatGrowthEntry, StatGrowthFormula } from '../../../shared/domain-types'

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

function gridToEntries(gridValues: GridValues, excludeStatIds?: Set<string>): StatGrowthEntry[] {
  const entries: StatGrowthEntry[] = []
  for (const [statId, levels] of Object.entries(gridValues)) {
    if (excludeStatIds?.has(statId)) continue
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
  formulaStatIds: Set<string>
  onApply: (statId: string, value: number) => void
}

function FillColumnHelper({ stats, formulaStatIds, onApply }: FillColumnHelperProps): React.JSX.Element {
  const manualStats = stats.filter((s) => !formulaStatIds.has(s.id))
  const [statId, setStatId] = useState(manualStats[0]?.id ?? '')
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
          {manualStats.map((s) => (
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
        disabled={value === '' || isNaN(parseFloat(value)) || manualStats.length === 0}
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
  formulaStatIds: Set<string>
  maxLevel: number
  onApply: (statId: string, fromLevel: number, fromValue: number, toLevel: number, toValue: number) => void
}

function InterpolateHelper({ stats, formulaStatIds, maxLevel, onApply }: InterpolateHelperProps): React.JSX.Element {
  const manualStats = stats.filter((s) => !formulaStatIds.has(s.id))
  const [statId, setStatId] = useState(manualStats[0]?.id ?? '')
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
          {manualStats.map((s) => (
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

export interface StatGrowthEditorRef {
  save: () => Promise<void>
  reload: () => void
}

interface StatGrowthEditorProps {
  classId: string
  onDirtyChange?: (dirty: boolean) => void
}

const StatGrowthEditor = forwardRef<StatGrowthEditorRef, StatGrowthEditorProps>(function StatGrowthEditor({ classId, onDirtyChange }, ref) {
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

  // Formula mode state
  const [formulaMap, setFormulaMap] = useState<Record<string, string>>({})
  const [formulaErrors, setFormulaErrors] = useState<Record<string, string | null>>({})
  const [switchToManualStatId, setSwitchToManualStatId] = useState<string | null>(null)

  const formulaStatIds = useMemo(
    () => new Set(Object.keys(formulaMap)),
    [formulaMap],
  )

  // Debounce chart updates so the chart doesn't re-render on every keystroke
  const chartDebounceRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const formulaDebounceRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [loadedStats, settings, statGrowthData] = await Promise.all([
        metaApi.listStats(),
        metaApi.getProjectSettings(),
        classesApi.getStatGrowth(classId),
      ])
      setStats(loadedStats)
      setMaxLevel(settings.maxLevel)
      const grid = buildInitialGrid(loadedStats, settings.maxLevel, statGrowthData.entries)
      setGridValues(grid)
      setChartData(buildChartData(grid, loadedStats, settings.maxLevel))

      const fMap: Record<string, string> = {}
      for (const f of statGrowthData.formulas) {
        fMap[f.statId] = f.formula
      }
      setFormulaMap(fMap)
      setFormulaErrors({})
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

  useEffect(() => {
    return () => {
      if (chartDebounceRef.current) clearTimeout(chartDebounceRef.current)
      if (formulaDebounceRef.current) clearTimeout(formulaDebounceRef.current)
    }
  }, [])

  useEffect(() => {
    onDirtyChange?.(isDirty)
  }, [isDirty, onDirtyChange])

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

  const handleFormulaChange = useCallback(
    (statId: string, formula: string) => {
      setFormulaMap((prev) => ({ ...prev, [statId]: formula }))
      setDirty(true)
      setSavedAt(null)

      if (formulaDebounceRef.current) clearTimeout(formulaDebounceRef.current)
      formulaDebounceRef.current = setTimeout(async () => {
        if (!formula.trim()) {
          setFormulaErrors((prev) => ({ ...prev, [statId]: 'Formula is empty' }))
          return
        }
        const result = await formulasApi.evaluate(formula, { level: 1, max_level: maxLevel })
        if (result.error) {
          setFormulaErrors((prev) => ({ ...prev, [statId]: result.error }))
          return
        }
        setFormulaErrors((prev) => ({ ...prev, [statId]: null }))

        const requests = Array.from({ length: maxLevel }, (_, i) => ({
          formula,
          bindings: { level: i + 1, max_level: maxLevel },
        }))
        const results = await formulasApi.evaluateBatch(requests)
        setGridValues((prev) => {
          const levels: Record<number, string> = {}
          for (let i = 0; i < results.length; i++) {
            levels[i + 1] = String(results[i].value ?? 0)
          }
          const next = { ...prev, [statId]: levels }
          setChartData(buildChartData(next, stats, maxLevel))
          return next
        })
      }, 300)
    },
    [maxLevel, stats],
  )

  const handleSwitchToFormula = useCallback(
    (statId: string) => {
      setFormulaMap((prev) => ({ ...prev, [statId]: '' }))
      setDirty(true)
      setSavedAt(null)
    },
    [],
  )

  const handleSwitchToManual = useCallback(
    (statId: string, bakeValues: boolean) => {
      setFormulaMap((prev) => {
        const next = { ...prev }
        delete next[statId]
        return next
      })
      setFormulaErrors((prev) => {
        const next = { ...prev }
        delete next[statId]
        return next
      })
      if (!bakeValues) {
        setGridValues((prev) => {
          const levels: Record<number, string> = {}
          for (let level = 1; level <= maxLevel; level++) {
            levels[level] = ''
          }
          const next = { ...prev, [statId]: levels }
          setChartData(buildChartData(next, stats, maxLevel))
          return next
        })
      }
      setDirty(true)
      setSavedAt(null)
      setSwitchToManualStatId(null)
    },
    [maxLevel, stats],
  )

  const handleSave = async (): Promise<void> => {
    setSaving(true)
    setError(null)
    try {
      const formulas: StatGrowthFormula[] = Object.entries(formulaMap).map(
        ([statId, formula]) => ({ statId, formula }),
      )
      const fIds = new Set(formulas.map((f) => f.statId))
      await Promise.all([
        classesApi.setStatGrowth(classId, gridToEntries(gridValues, fIds)),
        classesApi.setStatGrowthFormulas(classId, formulas),
      ])
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

  useImperativeHandle(ref, () => ({
    save: handleSave,
    reload: () => void load(),
  }))

  if (isLoading) {
    return <Typography color="text.secondary">Loading stat growth…</Typography>
  }

  if (stats.length === 0) {
    return <Typography color="text.secondary">No stats configured in this project.</Typography>
  }

  return (
    <Box>
      {/* Header */}
      <Typography variant="subtitle1" fontWeight={500} sx={{ mb: 2 }}>
        Primary Stat Growth — levels 1–{maxLevel}
      </Typography>

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

      {/* Formula inputs for formula-mode stats */}
      {formulaStatIds.size > 0 && (
        <Paper variant="outlined" sx={{ p: 1.5, mb: 2 }}>
          <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 1 }}>
            Formula-driven stats — use <code>level</code> and <code>max_level</code> as variables.
            Functions: <code>min()</code>, <code>max()</code>, <code>floor()</code>, <code>ceil()</code>
          </Typography>
          <Stack spacing={1.5}>
            {stats.filter((s) => formulaStatIds.has(s.id)).map((stat) => (
              <Stack key={stat.id} direction="row" spacing={1} alignItems="flex-start">
                <Typography
                  variant="body2"
                  sx={{ fontWeight: 600, minWidth: 100, pt: 1 }}
                >
                  {stat.displayName}
                </Typography>
                <TextField
                  size="small"
                  fullWidth
                  placeholder="e.g. min(level, 30) + max(level - 30, 0) * 2"
                  value={formulaMap[stat.id] ?? ''}
                  onChange={(e) => handleFormulaChange(stat.id, e.target.value)}
                  error={!!formulaErrors[stat.id]}
                  helperText={formulaErrors[stat.id] ?? undefined}
                  slotProps={{
                    input: {
                      sx: { fontFamily: 'monospace', fontSize: '0.85rem' },
                    },
                  }}
                />
                <Button
                  size="small"
                  color="secondary"
                  onClick={() => setSwitchToManualStatId(stat.id)}
                  sx={{ whiteSpace: 'nowrap', mt: 0.25 }}
                >
                  Manual
                </Button>
              </Stack>
            ))}
          </Stack>
        </Paper>
      )}

      {/* Entry helpers */}
      <Paper variant="outlined" sx={{ p: 1.5, mb: 2 }}>
        <Stack spacing={1}>
          <FillColumnHelper stats={stats} formulaStatIds={formulaStatIds} onApply={handleFillColumn} />
          <Divider />
          <InterpolateHelper stats={stats} formulaStatIds={formulaStatIds} maxLevel={maxLevel} onApply={handleInterpolate} />
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
              {stats.map((stat, i) => {
                const isFormula = formulaStatIds.has(stat.id)
                return (
                  <th
                    key={stat.id}
                    title={stat.displayName}
                    style={{
                      position: 'sticky',
                      top: 0,
                      zIndex: 2,
                      background: 'var(--table-header-bg, #2e3440)',
                      padding: '4px 4px',
                      textAlign: 'center',
                      fontSize: 11,
                      fontWeight: 600,
                      color: STAT_COLORS[i % STAT_COLORS.length],
                      borderBottom: '1px solid rgba(255,255,255,0.12)',
                      borderRight: '1px solid rgba(255,255,255,0.06)',
                      cursor: 'default',
                    }}
                  >
                    <div>{stat.exportKey.toUpperCase()}</div>
                    <Chip
                      label={isFormula ? 'F' : 'M'}
                      size="small"
                      variant={isFormula ? 'filled' : 'outlined'}
                      color={isFormula ? 'info' : 'default'}
                      onClick={() => {
                        if (isFormula) {
                          setSwitchToManualStatId(stat.id)
                        } else {
                          handleSwitchToFormula(stat.id)
                        }
                      }}
                      sx={{ height: 18, fontSize: 9, mt: 0.25, cursor: 'pointer' }}
                    />
                  </th>
                )
              })}
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
                  formulaStatIds={formulaStatIds}
                  onCellChange={handleCellChange}
                />
              )
            })}
          </tbody>
        </table>
      </Box>

      {/* Switch-to-manual confirmation dialog */}
      <Dialog
        open={switchToManualStatId !== null}
        onClose={() => setSwitchToManualStatId(null)}
        maxWidth="xs"
        fullWidth
      >
        <DialogTitle>Switch to Manual Mode</DialogTitle>
        <DialogContent>
          <Typography variant="body2">
            How would you like to handle the computed values for this stat?
          </Typography>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setSwitchToManualStatId(null)}>Cancel</Button>
          <Button
            onClick={() => handleSwitchToManual(switchToManualStatId!, false)}
          >
            Clear Values
          </Button>
          <Button
            variant="contained"
            onClick={() => handleSwitchToManual(switchToManualStatId!, true)}
          >
            Keep Values
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  )
})

export default StatGrowthEditor

// ─── Memoized row to prevent full-grid re-renders on single-cell edits ─────────
// Custom comparator: only the values for this specific level matter.
// gridValues is a new object reference on every cell edit, so the default
// shallow comparison would always re-render all rows.

interface GridRowProps {
  level: number
  stats: MetaStat[]
  gridValues: GridValues
  formulaStatIds: Set<string>
  onCellChange: (statId: string, level: number, value: string) => void
}

const GridRow = memo(({
  level,
  stats,
  gridValues,
  formulaStatIds,
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
      {stats.map((stat) => {
        const isFormula = formulaStatIds.has(stat.id)
        const cellValue = gridValues[stat.id]?.[level] ?? ''
        return (
          <td
            key={stat.id}
            style={{
              padding: '2px 4px',
              borderRight: '1px solid rgba(255,255,255,0.04)',
              background: isFormula ? 'rgba(94, 129, 172, 0.06)' : undefined,
            }}
          >
            {isFormula ? (
              <div
                style={{
                  width: '100%',
                  fontSize: 12,
                  fontFamily: 'monospace',
                  textAlign: 'right',
                  padding: '3px 4px',
                  color: 'rgba(255,255,255,0.5)',
                }}
              >
                {cellValue}
              </div>
            ) : (
              <input
                type="number"
                value={cellValue}
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
            )}
          </td>
        )
      })}
    </tr>
  )
}, (prev, next) => {
  if (prev.level !== next.level || prev.stats !== next.stats
      || prev.onCellChange !== next.onCellChange || prev.formulaStatIds !== next.formulaStatIds) {
    return false
  }
  for (const stat of prev.stats) {
    if (prev.gridValues[stat.id]?.[prev.level] !== next.gridValues[stat.id]?.[next.level]) {
      return false
    }
  }
  return true
})

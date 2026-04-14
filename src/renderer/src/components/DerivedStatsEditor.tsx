import {
  Add as AddIcon,
  Close as CloseIcon,
  Delete as DeleteIcon,
} from '@mui/icons-material'
import {
  Alert,
  Box,
  Button,
  Chip,
  Divider,
  IconButton,
  Paper,
  Stack,
  Switch,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material'
import { useCallback, useEffect, useRef, useState } from 'react'
import { classesApi } from '../../api/classes.api'
import { formulasApi } from '../../api/formulas.api'
import { metaApi } from '../../api/meta.api'
import type {
  ClassDerivedStatOverride,
  ClassMetadataField,
  DerivedStatDefinition,
  FormulaEvalResult,
  MetaStat,
  StatGrowthEntry,
} from '../../../shared/domain-types'

// ─── Cycle detection ──────────────────────────────────────────────────────────

const BUILTIN_FN_NAMES = new Set(['min', 'max', 'floor', 'ceil'])

/**
 * Renderer-side variable extractor used for cycle detection and dependency
 * ordering. This is a regex approximation rather than the AST-based
 * extractVariableNames in engine.ts.
 *
 * Known limitation: it cannot distinguish function-call identifiers from
 * variable names beyond the hard-coded BUILTIN_FN_NAMES set. If the builtin
 * set is ever extended (e.g. "abs", "round"), that name must be added here too,
 * or cycle detection may treat it as a variable dependency.
 *
 * This is acceptable because: (a) the formula grammar is tightly constrained,
 * (b) false-positive cycle edges are conservative (they block evaluation rather
 * than silently computing wrong results), and (c) adding an IPC round-trip to
 * use the AST extractor inside the synchronous detectCycles / evaluateAllAtLevel
 * dependency-sort logic would require a more invasive async refactor.
 */
function extractVarNames(formula: string): string[] {
  const tokens = formula.match(/\b[a-zA-Z_][a-zA-Z0-9_]*\b/g) ?? []
  return tokens.filter((t) => !BUILTIN_FN_NAMES.has(t))
}

function detectCycles(
  derivedStats: DerivedStatDefinition[],
  activeFormulas: Record<string, string>,
): Set<string> {
  const exportKeyToId = new Map(derivedStats.map((d) => [d.exportKey, d.id]))
  const derivedKeys = new Set(derivedStats.map((d) => d.exportKey))

  const deps = new Map<string, Set<string>>()
  for (const d of derivedStats) {
    const formula = activeFormulas[d.id] ?? d.formula
    const varNames = extractVarNames(formula)
    const dependsOn = new Set<string>()
    for (const v of varNames) {
      if (derivedKeys.has(v)) {
        const depId = exportKeyToId.get(v)
        if (depId && depId !== d.id) dependsOn.add(depId)
      }
    }
    deps.set(d.id, dependsOn)
  }

  const visited = new Set<string>()
  const visiting = new Set<string>()
  const cyclic = new Set<string>()

  function dfs(id: string): boolean {
    if (visiting.has(id)) return true
    if (visited.has(id)) return false
    visiting.add(id)
    let isCyclic = false
    for (const dep of deps.get(id) ?? []) {
      if (dfs(dep)) { cyclic.add(dep); isCyclic = true }
    }
    visiting.delete(id)
    visited.add(id)
    if (isCyclic) cyclic.add(id)
    return isCyclic
  }

  for (const d of derivedStats) dfs(d.id)
  return cyclic
}

// ─── Evaluation helpers ───────────────────────────────────────────────────────

function applyOutputConfig(
  value: number,
  outputType: 'integer' | 'float',
  roundingMode: 'floor' | 'round' | 'none',
): number {
  if (outputType === 'float') return value
  switch (roundingMode) {
    case 'floor': return Math.floor(value)
    case 'round': return Math.round(value)
    case 'none': return value
  }
}

function formatResult(value: number, outputType: 'integer' | 'float'): string {
  if (outputType === 'integer') return String(Math.round(value))
  return value.toFixed(3).replace(/\.?0+$/, '')
}

function defaultBreakpointLevels(maxLevel: number): number[] {
  if (maxLevel <= 5) return Array.from({ length: maxLevel }, (_, i) => i + 1)
  // Six evenly-spread points: 0%, 20%, 40%, 60%, 80%, 100% of maxLevel
  const points = [0, 0.2, 0.4, 0.6, 0.8, 1.0]
  return points
    .map((p) => Math.max(1, Math.round(p * maxLevel)))
    .filter((v, i, arr) => arr.indexOf(v) === i)
    .sort((a, b) => a - b)
}

// Multi-pass dependency-order evaluation at a single level.
// cyclicIds is read-only — already computed before this is called.
// Each pass issues a single batch IPC call for all stats whose dependencies
// are resolved, rather than one call per stat.
async function evaluateAllAtLevel(
  defs: DerivedStatDefinition[],
  activeFormulas: Record<string, string>,
  cyclicIds: Set<string>,
  baseBindings: Record<string, number>,
): Promise<Record<string, FormulaEvalResult>> {
  const results: Record<string, FormulaEvalResult> = {}
  const evaluated: Record<string, number> = { ...baseBindings }
  const remaining = defs.filter((d) => !cyclicIds.has(d.id))
  const derivedKeys = new Set(defs.map((x) => x.exportKey))

  let passes = 0
  while (remaining.length > 0 && passes < defs.length + 1) {
    passes++
    const toEval = remaining.filter((d) => {
      const vars = extractVarNames(activeFormulas[d.id])
      return vars.every((v) => !derivedKeys.has(v) || v in evaluated)
    })
    if (toEval.length === 0) break
    const batchResults = await formulasApi.evaluateBatch(
      toEval.map((def) => ({ formula: activeFormulas[def.id], bindings: { ...evaluated } })),
    )
    for (let i = 0; i < toEval.length; i++) {
      const def = toEval[i]
      const result = batchResults[i]
      results[def.id] = result
      if (result.value !== null) {
        evaluated[def.exportKey] = applyOutputConfig(result.value, def.outputType, def.roundingMode)
      }
      remaining.splice(remaining.indexOf(def), 1)
    }
  }
  return results
}

// ─── Metadata fields panel ────────────────────────────────────────────────────

interface MetadataFieldsPanelProps {
  fields: Array<{ fieldKey: string; value: string }>
  onChange: (fields: Array<{ fieldKey: string; value: string }>) => void
}

function MetadataFieldsPanel({ fields, onChange }: MetadataFieldsPanelProps): React.JSX.Element {
  const addField = (): void => {
    onChange([...fields, { fieldKey: '', value: '0' }])
  }

  const updateKey = (i: number, key: string): void => {
    const next = [...fields]
    next[i] = { ...next[i], fieldKey: key }
    onChange(next)
  }

  const updateValue = (i: number, value: string): void => {
    const next = [...fields]
    next[i] = { ...next[i], value }
    onChange(next)
  }

  const removeField = (i: number): void => {
    onChange(fields.filter((_, idx) => idx !== i))
  }

  return (
    <Box>
      <Typography variant="subtitle2" gutterBottom>
        Class Metadata Fields
      </Typography>
      <Typography variant="caption" color="text.secondary" display="block" sx={{ mb: 1.5 }}>
        Numeric key-value pairs usable as variables in derived stat formulas.
      </Typography>
      {fields.length === 0 ? (
        <Typography variant="body2" color="text.secondary" sx={{ mb: 1.5 }}>
          No metadata fields. Add one below.
        </Typography>
      ) : (
        <Stack spacing={1} sx={{ mb: 1.5 }}>
          {fields.map((f, i) => (
            <Stack key={i} direction="row" spacing={1} alignItems="center">
              <TextField
                size="small"
                label="Key"
                value={f.fieldKey}
                onChange={(e) => updateKey(i, e.target.value)}
                inputProps={{ style: { fontFamily: 'monospace' } }}
                sx={{ flex: 1 }}
                error={!/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(f.fieldKey) && f.fieldKey !== ''}
                helperText={
                  !/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(f.fieldKey) && f.fieldKey !== ''
                    ? 'Letters, digits, underscores only. Must start with a letter.'
                    : undefined
                }
              />
              <TextField
                size="small"
                label="Value"
                type="number"
                value={f.value}
                onChange={(e) => updateValue(i, e.target.value)}
                sx={{ width: 120 }}
              />
              <Tooltip title="Remove field">
                <IconButton size="small" color="error" onClick={() => removeField(i)}>
                  <DeleteIcon fontSize="small" />
                </IconButton>
              </Tooltip>
            </Stack>
          ))}
        </Stack>
      )}
      <Button size="small" startIcon={<AddIcon />} onClick={addField} variant="outlined">
        Add Field
      </Button>
    </Box>
  )
}

// ─── Breakpoint table ─────────────────────────────────────────────────────────

interface BreakpointTableProps {
  derivedStats: DerivedStatDefinition[]
  breakpointLevels: number[]
  breakpointResults: Record<number, Record<string, FormulaEvalResult>>
  cyclicIds: Set<string>
  maxLevel: number
  onLevelsChange: (levels: number[]) => void
}

function BreakpointTable({
  derivedStats,
  breakpointLevels,
  breakpointResults,
  cyclicIds,
  maxLevel,
  onLevelsChange,
}: BreakpointTableProps): React.JSX.Element {
  const [levelInput, setLevelInput] = useState('')

  const addLevel = (): void => {
    const v = parseInt(levelInput, 10)
    if (isNaN(v) || v < 1 || v > maxLevel || breakpointLevels.includes(v)) return
    onLevelsChange([...breakpointLevels, v].sort((a, b) => a - b))
    setLevelInput('')
  }

  const removeLevel = (level: number): void => {
    onLevelsChange(breakpointLevels.filter((l) => l !== level))
  }

  return (
    <Box>
      <Stack direction="row" alignItems="center" justifyContent="space-between" sx={{ mb: 2 }}>
        <Typography variant="subtitle1" fontWeight={500}>
          Breakpoint Table
        </Typography>
        <Stack direction="row" spacing={1} alignItems="center">
          <TextField
            size="small"
            type="number"
            label="Add level"
            value={levelInput}
            onChange={(e) => setLevelInput(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter') { e.preventDefault(); addLevel() }
            }}
            inputProps={{ min: 1, max: maxLevel, style: { width: 56, textAlign: 'center' } }}
            sx={{ width: 110 }}
          />
          <Button size="small" variant="outlined" onClick={addLevel} disabled={!levelInput.trim()}>
            Add
          </Button>
        </Stack>
      </Stack>

      {breakpointLevels.length === 0 ? (
        <Typography variant="body2" color="text.secondary">
          No breakpoint levels configured.
        </Typography>
      ) : (
        <Paper variant="outlined" sx={{ overflow: 'auto' }}>
          <Table size="small" stickyHeader>
            <TableHead>
              <TableRow>
                <TableCell
                  sx={{ minWidth: 140, position: 'sticky', left: 0, zIndex: 3, bgcolor: 'background.paper' }}
                >
                  Stat
                </TableCell>
                {breakpointLevels.map((level) => (
                  <TableCell key={level} align="right" sx={{ minWidth: 90, whiteSpace: 'nowrap' }}>
                    <Stack direction="row" alignItems="center" justifyContent="flex-end" spacing={0.25}>
                      <Typography variant="caption" fontWeight={500}>
                        Lvl {level}
                      </Typography>
                      <Tooltip title="Remove level">
                        <IconButton size="small" onClick={() => removeLevel(level)} sx={{ p: 0.25, ml: 0.5 }}>
                          <CloseIcon sx={{ fontSize: 12 }} />
                        </IconButton>
                      </Tooltip>
                    </Stack>
                  </TableCell>
                ))}
              </TableRow>
            </TableHead>
            <TableBody>
              {derivedStats.map((def) => {
                const isCyclic = cyclicIds.has(def.id)
                return (
                  <TableRow key={def.id}>
                    <TableCell
                      sx={{ position: 'sticky', left: 0, bgcolor: 'background.paper', zIndex: 1 }}
                    >
                      <Typography variant="body2" fontWeight={500}>
                        {def.displayName}
                      </Typography>
                      <Typography variant="caption" color="text.secondary" fontFamily="monospace">
                        {def.exportKey}
                      </Typography>
                    </TableCell>
                    {breakpointLevels.map((level) => {
                      const result = breakpointResults[level]?.[def.id]
                      return (
                        <TableCell key={level} align="right">
                          {isCyclic ? (
                            <Chip label="cycle" size="small" color="error" variant="outlined" />
                          ) : result?.error ? (
                            <Tooltip title={result.error}>
                              <Chip label="err" size="small" color="warning" variant="outlined" />
                            </Tooltip>
                          ) : result?.value !== null && result?.value !== undefined ? (
                            <Typography variant="body2" fontFamily="monospace">
                              {formatResult(
                                applyOutputConfig(result.value, def.outputType, def.roundingMode),
                                def.outputType,
                              )}
                            </Typography>
                          ) : (
                            <Typography variant="caption" color="text.disabled">
                              —
                            </Typography>
                          )}
                        </TableCell>
                      )
                    })}
                  </TableRow>
                )
              })}
            </TableBody>
          </Table>
        </Paper>
      )}
    </Box>
  )
}

// ─── Main component ────────────────────────────────────────────────────────────

interface DerivedStatsEditorProps {
  classId: string
  resourceMultiplier: number
}

interface EvalState {
  results: Record<string, FormulaEvalResult>
  cyclicIds: Set<string>
}

export default function DerivedStatsEditor({
  classId,
  resourceMultiplier,
}: DerivedStatsEditorProps): React.JSX.Element {
  const [derivedStats, setDerivedStats] = useState<DerivedStatDefinition[]>([])
  const [stats, setStats] = useState<MetaStat[]>([])
  const [maxLevel, setMaxLevel] = useState(50)
  const [statGrowthEntries, setStatGrowthEntries] = useState<StatGrowthEntry[]>([])

  const [overrideEnabled, setOverrideEnabled] = useState<Record<string, boolean>>({})
  const [overrideFormulas, setOverrideFormulas] = useState<Record<string, string>>({})

  const [metadataFields, setMetadataFields] = useState<Array<{ fieldKey: string; value: string }>>([])

  const [previewLevel, setPreviewLevel] = useState(1)
  const [breakpointLevels, setBreakpointLevels] = useState<number[]>([])
  const [evalState, setEvalState] = useState<EvalState>({ results: {}, cyclicIds: new Set() })
  const [breakpointResults, setBreakpointResults] = useState<
    Record<number, Record<string, FormulaEvalResult>>
  >({})

  const [isLoading, setLoading] = useState(true)
  const [isSaving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [savedAt, setSavedAt] = useState<Date | null>(null)
  const [isDirty, setDirty] = useState(false)

  const evalDebounceRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  // ─── Load ─────────────────────────────────────────────────────────────────

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [defs, st, settings, entries, savedOverrides, savedMeta] = await Promise.all([
        metaApi.listDerivedStats(),
        metaApi.listStats(),
        metaApi.getProjectSettings(),
        classesApi.getStatGrowth(classId),
        classesApi.getDerivedStatOverrides(classId),
        classesApi.getMetadataFields(classId),
      ])

      setDerivedStats(defs)
      setStats(st)
      setMaxLevel(settings.maxLevel)
      setStatGrowthEntries(entries)
      setBreakpointLevels(defaultBreakpointLevels(settings.maxLevel))

      const enabledMap: Record<string, boolean> = {}
      const formulaMap: Record<string, string> = {}
      for (const def of defs) {
        const override = savedOverrides.find((o) => o.derivedStatId === def.id)
        enabledMap[def.id] = Boolean(override)
        formulaMap[def.id] = override?.formula ?? def.formula
      }
      setOverrideEnabled(enabledMap)
      setOverrideFormulas(formulaMap)
      setMetadataFields(savedMeta.map((f) => ({ fieldKey: f.fieldKey, value: String(f.value) })))
      setDirty(false)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to load derived stats.')
    } finally {
      setLoading(false)
    }
  }, [classId])

  useEffect(() => {
    void load()
  }, [load])

  useEffect(() => {
    return () => {
      if (evalDebounceRef.current) clearTimeout(evalDebounceRef.current)
    }
  }, [])

  // ─── Live evaluation ───────────────────────────────────────────────────────

  const runEvaluation = useCallback(
    async (
      defs: DerivedStatDefinition[],
      enabled: Record<string, boolean>,
      formulas: Record<string, string>,
      meta: Array<{ fieldKey: string; value: string }>,
      previewLvl: number,
      bpLevels: number[],
      statList: MetaStat[],
      growth: StatGrowthEntry[],
    ) => {
      // Build metadata bindings — same across all levels
      const metaBindings: Record<string, number> = { resource_multiplier: resourceMultiplier }
      for (const f of meta) {
        const v = parseFloat(f.value)
        if (f.fieldKey && !isNaN(v)) metaBindings[f.fieldKey] = v
      }

      // Determine active formula per derived stat
      const activeFormulas: Record<string, string> = {}
      for (const def of defs) {
        activeFormulas[def.id] = enabled[def.id] ? (formulas[def.id] ?? def.formula) : def.formula
      }

      // Cycle detection is formula-only — run once for all levels
      const cyclicIds = detectCycles(defs, activeFormulas)

      // Build primary stat bindings for a given level
      const buildStatBindings = (level: number): Record<string, number> => {
        const b: Record<string, number> = {}
        for (const stat of statList) {
          const entry = growth.find((e) => e.statId === stat.id && e.level === level)
          b[stat.exportKey] = entry?.value ?? 0
        }
        return b
      }

      // Evaluate at the preview level and all breakpoint levels in parallel
      const allLevels = [...new Set([previewLvl, ...bpLevels])]
      const levelResultPairs = await Promise.all(
        allLevels.map(async (level) => {
          const baseBindings = { ...buildStatBindings(level), ...metaBindings }
          const results = await evaluateAllAtLevel(defs, activeFormulas, cyclicIds, baseBindings)
          return { level, results }
        }),
      )

      const resultsByLevel: Record<number, Record<string, FormulaEvalResult>> = {}
      for (const { level, results } of levelResultPairs) {
        resultsByLevel[level] = results
      }

      setEvalState({ results: resultsByLevel[previewLvl] ?? {}, cyclicIds })
      setBreakpointResults(resultsByLevel)
    },
    [resourceMultiplier],
  )

  const scheduleEval = useCallback(
    (
      defs: DerivedStatDefinition[],
      enabled: Record<string, boolean>,
      formulas: Record<string, string>,
      meta: Array<{ fieldKey: string; value: string }>,
      previewLvl: number,
      bpLevels: number[],
    ) => {
      if (evalDebounceRef.current) clearTimeout(evalDebounceRef.current)
      evalDebounceRef.current = setTimeout(() => {
        void runEvaluation(defs, enabled, formulas, meta, previewLvl, bpLevels, stats, statGrowthEntries)
      }, 300)
    },
    [runEvaluation, stats, statGrowthEntries],
  )

  useEffect(() => {
    if (derivedStats.length === 0) return
    scheduleEval(derivedStats, overrideEnabled, overrideFormulas, metadataFields, previewLevel, breakpointLevels)
  }, [derivedStats, overrideEnabled, overrideFormulas, metadataFields, previewLevel, breakpointLevels, scheduleEval])

  // ─── Handlers ─────────────────────────────────────────────────────────────

  const toggleOverride = (defId: string, def: DerivedStatDefinition): void => {
    const nowEnabled = !overrideEnabled[defId]
    setOverrideEnabled((prev) => ({ ...prev, [defId]: nowEnabled }))
    if (nowEnabled && !overrideFormulas[defId]) {
      setOverrideFormulas((prev) => ({ ...prev, [defId]: def.formula }))
    }
    setDirty(true)
    setSavedAt(null)
  }

  const handleFormulaChange = (defId: string, formula: string): void => {
    setOverrideFormulas((prev) => ({ ...prev, [defId]: formula }))
    setDirty(true)
    setSavedAt(null)
  }

  const handleMetadataChange = (fields: Array<{ fieldKey: string; value: string }>): void => {
    setMetadataFields(fields)
    setDirty(true)
    setSavedAt(null)
  }

  const hasSyntaxErrors = derivedStats
    .filter((d) => overrideEnabled[d.id])
    .some((d) => evalState.results[d.id]?.isSyntaxError)
  const hasInvalidMetadataKeys = metadataFields.some(
    (f) => f.fieldKey && !/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(f.fieldKey),
  )

  const handleSave = async (): Promise<void> => {
    setSaving(true)
    setError(null)
    try {
      const overrides: ClassDerivedStatOverride[] = derivedStats
        .filter((d) => overrideEnabled[d.id])
        .map((d) => ({ derivedStatId: d.id, formula: overrideFormulas[d.id] ?? d.formula }))

      const metaFields: ClassMetadataField[] = metadataFields
        .filter((f) => f.fieldKey && /^[a-zA-Z_][a-zA-Z0-9_]*$/.test(f.fieldKey))
        .map((f) => ({ fieldKey: f.fieldKey, value: parseFloat(f.value) || 0 }))

      await Promise.all([
        classesApi.setDerivedStatOverrides(classId, overrides),
        classesApi.setMetadataFields(classId, metaFields),
      ])
      setDirty(false)
      setSavedAt(new Date())
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to save derived stats.')
    } finally {
      setSaving(false)
    }
  }

  // ─── Render ───────────────────────────────────────────────────────────────

  if (isLoading) {
    return <Typography color="text.secondary">Loading derived stats…</Typography>
  }

  if (derivedStats.length === 0) {
    return (
      <Typography color="text.secondary">No derived stats configured in this project.</Typography>
    )
  }

  return (
    <Box>
      {/* Header */}
      <Stack direction="row" alignItems="center" justifyContent="space-between" sx={{ mb: 2 }}>
        <Stack direction="row" alignItems="center" spacing={2}>
          <Typography variant="subtitle1" fontWeight={500}>
            Derived Stats
          </Typography>
          <Stack direction="row" alignItems="center" spacing={1}>
            <Typography variant="caption" color="text.secondary">
              Preview at level
            </Typography>
            <TextField
              size="small"
              type="number"
              value={previewLevel}
              onChange={(e) => {
                const v = Math.max(1, Math.min(maxLevel, parseInt(e.target.value) || 1))
                setPreviewLevel(v)
              }}
              inputProps={{ min: 1, max: maxLevel, style: { width: 56, textAlign: 'center' } }}
              sx={{ width: 80 }}
            />
          </Stack>
        </Stack>
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
            disabled={!isDirty || isSaving || hasSyntaxErrors || hasInvalidMetadataKeys}
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

      {/* Derived stats formula table */}
      <Paper variant="outlined" sx={{ mb: 3, overflow: 'hidden' }}>
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Stat</TableCell>
              <TableCell sx={{ minWidth: 240 }}>Formula</TableCell>
              <TableCell align="center" sx={{ width: 90 }}>Override</TableCell>
              <TableCell align="center" sx={{ width: 80 }}>Type</TableCell>
              <TableCell align="center" sx={{ width: 80 }}>Round</TableCell>
              <TableCell align="right" sx={{ width: 120 }}>
                Result (lvl {previewLevel})
              </TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {derivedStats.map((def) => {
              const isOverridden = overrideEnabled[def.id] ?? false
              const activeFormula = isOverridden ? (overrideFormulas[def.id] ?? def.formula) : def.formula
              const evalResult = evalState.results[def.id]
              const isCyclic = evalState.cyclicIds.has(def.id)
              const syntaxError =
                isOverridden && evalResult?.isSyntaxError ? (evalResult.error ?? 'Syntax error') : null

              return (
                <TableRow key={def.id}>
                  <TableCell>
                    <Typography variant="body2" fontWeight={500}>
                      {def.displayName}
                    </Typography>
                    <Typography variant="caption" color="text.secondary" fontFamily="monospace">
                      {def.exportKey}
                    </Typography>
                  </TableCell>

                  <TableCell>
                    {isOverridden ? (
                      <TextField
                        size="small"
                        fullWidth
                        value={overrideFormulas[def.id] ?? def.formula}
                        onChange={(e) => handleFormulaChange(def.id, e.target.value)}
                        error={Boolean(syntaxError)}
                        helperText={syntaxError ?? undefined}
                        inputProps={{ style: { fontFamily: 'monospace', fontSize: 12 } }}
                        placeholder="e.g. con * 10"
                      />
                    ) : (
                      <Typography variant="body2" fontFamily="monospace" color="text.secondary">
                        {activeFormula}
                      </Typography>
                    )}
                  </TableCell>

                  <TableCell align="center">
                    <Tooltip title={isOverridden ? 'Using class override' : 'Using project default'}>
                      <Switch
                        size="small"
                        checked={isOverridden}
                        onChange={() => toggleOverride(def.id, def)}
                      />
                    </Tooltip>
                  </TableCell>

                  <TableCell align="center">
                    <Chip label={def.outputType} size="small" variant="outlined" />
                  </TableCell>

                  <TableCell align="center">
                    <Typography variant="caption" color="text.secondary">
                      {def.roundingMode}
                    </Typography>
                  </TableCell>

                  <TableCell align="right">
                    {isCyclic ? (
                      <Tooltip title="Cyclic dependency detected — this formula depends on itself">
                        <Chip label="cycle" size="small" color="error" variant="outlined" />
                      </Tooltip>
                    ) : evalResult?.error ? (
                      <Tooltip title={evalResult.error}>
                        <Chip label="error" size="small" color="warning" variant="outlined" />
                      </Tooltip>
                    ) : evalResult?.value !== null && evalResult?.value !== undefined ? (
                      <Typography variant="body2" fontFamily="monospace">
                        {formatResult(
                          applyOutputConfig(evalResult.value, def.outputType, def.roundingMode),
                          def.outputType,
                        )}
                      </Typography>
                    ) : (
                      <Typography variant="caption" color="text.disabled">
                        —
                      </Typography>
                    )}
                  </TableCell>
                </TableRow>
              )
            })}
          </TableBody>
        </Table>
      </Paper>

      <Divider sx={{ mb: 3 }} />

      {/* Breakpoint table */}
      <Box sx={{ mb: 3 }}>
        <BreakpointTable
          derivedStats={derivedStats}
          breakpointLevels={breakpointLevels}
          breakpointResults={breakpointResults}
          cyclicIds={evalState.cyclicIds}
          maxLevel={maxLevel}
          onLevelsChange={setBreakpointLevels}
        />
      </Box>

      <Divider sx={{ mb: 3 }} />

      {/* Metadata fields */}
      <MetadataFieldsPanel fields={metadataFields} onChange={handleMetadataChange} />

      <Typography variant="caption" color="text.secondary" sx={{ mt: 1, display: 'block' }}>
        <code>resource_multiplier</code> ({resourceMultiplier}) is always available as a formula variable.
      </Typography>
    </Box>
  )
}

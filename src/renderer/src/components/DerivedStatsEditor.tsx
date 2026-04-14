import {
  Add as AddIcon,
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

  // Build dependency graph: id → set of derived-stat ids it depends on
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

  // DFS cycle detection
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

function formatResult(
  value: number,
  outputType: 'integer' | 'float',
): string {
  if (outputType === 'integer') return String(Math.round(value))
  return value.toFixed(3).replace(/\.?0+$/, '')
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

  // Overrides: which derived stats have a class-level formula override
  const [overrideEnabled, setOverrideEnabled] = useState<Record<string, boolean>>({})
  const [overrideFormulas, setOverrideFormulas] = useState<Record<string, string>>({})
  const [formulaSyntaxErrors, setFormulaSyntaxErrors] = useState<Record<string, string | null>>({})

  // Metadata fields as editable string pairs (before parsing)
  const [metadataFields, setMetadataFields] = useState<Array<{ fieldKey: string; value: string }>>([])

  const [previewLevel, setPreviewLevel] = useState(1)
  const [evalState, setEvalState] = useState<EvalState>({ results: {}, cyclicIds: new Set() })

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

      const enabledMap: Record<string, boolean> = {}
      const formulaMap: Record<string, string> = {}
      for (const def of defs) {
        const override = savedOverrides.find((o) => o.derivedStatId === def.id)
        enabledMap[def.id] = Boolean(override)
        formulaMap[def.id] = override?.formula ?? def.formula
      }
      setOverrideEnabled(enabledMap)
      setOverrideFormulas(formulaMap)
      setFormulaSyntaxErrors({})
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

  // ─── Live evaluation ───────────────────────────────────────────────────────

  const runEvaluation = useCallback(
    async (
      defs: DerivedStatDefinition[],
      enabled: Record<string, boolean>,
      formulas: Record<string, string>,
      meta: Array<{ fieldKey: string; value: string }>,
      level: number,
      statList: MetaStat[],
      growth: StatGrowthEntry[],
    ) => {
      // Build primary stat bindings at the selected level
      const statBindings: Record<string, number> = {}
      for (const stat of statList) {
        const entry = growth.find((e) => e.statId === stat.id && e.level === level)
        statBindings[stat.exportKey] = entry?.value ?? 0
      }

      // Build metadata bindings
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

      // Detect cycles
      const cyclicIds = detectCycles(defs, activeFormulas)

      // Evaluate in dependency order (multi-pass until stable)
      const results: Record<string, FormulaEvalResult> = {}
      const evaluated: Record<string, number> = { ...statBindings, ...metaBindings }

      const remaining = defs.filter((d) => !cyclicIds.has(d.id))
      let passes = 0
      while (remaining.length > 0 && passes < defs.length + 1) {
        passes++
        const toEval = remaining.filter((d) => {
          // Check if all variable deps are already in evaluated
          const formula = activeFormulas[d.id]
          const vars = extractVarNames(formula)
          const derivedKeys = new Set(defs.map((x) => x.exportKey))
          return vars.every((v) => !derivedKeys.has(v) || evaluated[v] !== undefined)
        })
        if (toEval.length === 0) break
        const evalResults = await Promise.all(
          toEval.map(async (def) => {
            const formula = activeFormulas[def.id]
            const result = await formulasApi.evaluate(formula, evaluated)
            return { def, result }
          }),
        )
        for (const { def, result } of evalResults) {
          results[def.id] = result
          if (result.value !== null) {
            evaluated[def.exportKey] = applyOutputConfig(
              result.value,
              def.outputType,
              def.roundingMode,
            )
          }
          remaining.splice(remaining.indexOf(def), 1)
        }
      }

      // Mark remaining as cyclic if still unresolved
      for (const def of remaining) cyclicIds.add(def.id)

      setEvalState({ results, cyclicIds })
    },
    [resourceMultiplier],
  )

  // Debounced evaluation trigger
  const scheduleEval = useCallback(
    (
      defs: DerivedStatDefinition[],
      enabled: Record<string, boolean>,
      formulas: Record<string, string>,
      meta: Array<{ fieldKey: string; value: string }>,
      level: number,
    ) => {
      if (evalDebounceRef.current) clearTimeout(evalDebounceRef.current)
      evalDebounceRef.current = setTimeout(() => {
        void runEvaluation(defs, enabled, formulas, meta, level, stats, statGrowthEntries)
      }, 300)
    },
    [runEvaluation, stats, statGrowthEntries],
  )

  // Re-evaluate when inputs change
  useEffect(() => {
    if (derivedStats.length === 0) return
    scheduleEval(derivedStats, overrideEnabled, overrideFormulas, metadataFields, previewLevel)
  }, [derivedStats, overrideEnabled, overrideFormulas, metadataFields, previewLevel, scheduleEval])

  // ─── Handlers ─────────────────────────────────────────────────────────────

  const toggleOverride = (defId: string, def: DerivedStatDefinition): void => {
    const nowEnabled = !overrideEnabled[defId]
    setOverrideEnabled((prev) => ({ ...prev, [defId]: nowEnabled }))
    // If enabling, pre-fill with project default
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

  const hasSyntaxErrors = Object.values(formulaSyntaxErrors).some(Boolean)
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

      {/* Derived stats table */}
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
              const syntaxError = isOverridden ? formulaSyntaxErrors[def.id] : null

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

      {/* Metadata fields */}
      <MetadataFieldsPanel fields={metadataFields} onChange={handleMetadataChange} />

      {metadataFields.length > 0 && (
        <Typography variant="caption" color="text.secondary" sx={{ mt: 1, display: 'block' }}>
          <code>resource_multiplier</code> ({resourceMultiplier}) is always available as a formula variable.
        </Typography>
      )}
      {metadataFields.length === 0 && (
        <Typography variant="caption" color="text.secondary" sx={{ mt: 1, display: 'block' }}>
          <code>resource_multiplier</code> ({resourceMultiplier}) is always available as a formula variable.
        </Typography>
      )}
    </Box>
  )
}

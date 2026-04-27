import {
  Add as AddIcon,
  AutoAwesome as AbilitiesIcon,
  Casino as LootIcon,
  Construction as RecipesIcon,
  Download as BackupIcon,
  History as HistoryIcon,
  Inventory as ItemsIcon,
  People as ClassesIcon,
  Schedule as ScheduleIcon,
  SmartToy as NpcsIcon,
  Warning as WarningIcon,
} from '@mui/icons-material'
import {
  Box,
  Button,
  ButtonBase,
  Chip,
  Menu,
  MenuItem,
  Paper,
  Stack,
  Typography,
} from '@mui/material'
import { useCallback, useEffect, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { projectApi } from '../../api/project.api'
import { validationApi } from '../../api/validation.api'
import type { ValidationIssue } from '../../../shared/domain-types'
import type { RecordCounts, SaveHistoryEntry } from '../../../shared/project-types'
import { useProjectStore } from '../stores/project.store'
import { useValidationStore } from '../stores/validation.store'
import { ProjectInitialsMark } from '../components/ProjectInitialsMark'
import { RelativeTimestamp } from '../components/RelativeTimestamp'
import { FileSizeDisplay } from '../components/FileSizeDisplay'
import { StatusTag } from '../components/StatusTag'

const DOMAIN_TILES = [
  { label: 'Classes', key: 'classes' as keyof RecordCounts, path: '/classes', Icon: ClassesIcon },
  { label: 'Abilities', key: 'abilities' as keyof RecordCounts, path: '/abilities', Icon: AbilitiesIcon },
  { label: 'Items', key: 'items' as keyof RecordCounts, path: '/items', Icon: ItemsIcon },
  { label: 'Recipes', key: 'recipes' as keyof RecordCounts, path: '/recipes', Icon: RecipesIcon },
  { label: 'NPCs', key: 'npcs' as keyof RecordCounts, path: '/npcs', Icon: NpcsIcon },
  { label: 'Loot Tables', key: 'lootTables' as keyof RecordCounts, path: '/loot-tables', Icon: LootIcon },
] as const

const QUICK_ADD_DOMAINS = [
  { label: 'Class', path: '/classes?action=create' },
  { label: 'Ability', path: '/abilities?action=create' },
  { label: 'Item', path: '/items?action=create' },
  { label: 'Recipe', path: '/recipes?action=create' },
  { label: 'NPC', path: '/npcs?action=create' },
  { label: 'Loot Table', path: '/loot-tables?action=create' },
]

export default function DashboardPage(): React.JSX.Element {
  const navigate = useNavigate()
  const activeProject = useProjectStore((state) => state.activeProject)
  const saveStatus = useProjectStore((state) => state.saveStatus)
  const hydrate = useProjectStore((state) => state.hydrate)
  const setGlobalIssues = useValidationStore((s) => s.setIssues)
  const [refreshError, setRefreshError] = useState<string | null>(null)
  const [validationIssues, setValidationIssues] = useState<ValidationIssue[]>([])
  const [weeklyDeltas, setWeeklyDeltas] = useState<RecordCounts | null>(null)
  const [saveHistory, setSaveHistory] = useState<SaveHistoryEntry[]>([])
  const [autoSaveInfo, setAutoSaveInfo] = useState<{ intervalMs: number; nextSaveAt: string | null } | null>(null)
  const [countdown, setCountdown] = useState<string | null>(null)
  const [quickAddAnchor, setQuickAddAnchor] = useState<null | HTMLElement>(null)

  const countdownRef = useRef<ReturnType<typeof setInterval> | null>(null)

  const refreshProjectState = useCallback(async () => {
    try {
      const [snapshot, issues, deltas, history, asInfo] = await Promise.all([
        projectApi.getState(),
        validationApi.run(),
        projectApi.getWeeklyDeltas(),
        projectApi.getSaveHistory(5),
        projectApi.getAutoSaveInfo(),
      ])
      hydrate(snapshot)
      setGlobalIssues(issues)
      setValidationIssues(issues)
      setWeeklyDeltas(deltas)
      setSaveHistory(history)
      setAutoSaveInfo(asInfo)
      setRefreshError(null)
    } catch (cause) {
      setRefreshError(cause instanceof Error ? cause.message : 'Unable to refresh dashboard.')
    }
  }, [hydrate, setGlobalIssues])

  useEffect(() => {
    void refreshProjectState()

    const refreshOnFocus = (): void => { void refreshProjectState() }
    window.addEventListener('focus', refreshOnFocus)
    const intervalId = window.setInterval(() => {
      if (document.visibilityState === 'visible') void refreshProjectState()
    }, 5000)

    return () => {
      window.removeEventListener('focus', refreshOnFocus)
      window.clearInterval(intervalId)
    }
  }, [refreshProjectState])

  useEffect(() => {
    if (countdownRef.current) clearInterval(countdownRef.current)
    if (!autoSaveInfo?.nextSaveAt) {
      setCountdown(null)
      return
    }

    const tick = () => {
      const remaining = new Date(autoSaveInfo.nextSaveAt!).getTime() - Date.now()
      if (remaining <= 0) {
        setCountdown('saving...')
      } else {
        const mins = Math.floor(remaining / 60000)
        const secs = Math.floor((remaining % 60000) / 1000)
        setCountdown(`${mins}:${secs.toString().padStart(2, '0')}`)
      }
    }
    tick()
    countdownRef.current = setInterval(tick, 1000)
    return () => { if (countdownRef.current) clearInterval(countdownRef.current) }
  }, [autoSaveInfo])

  const handleBackup = async () => {
    await projectApi.backup()
  }

  if (!activeProject) {
    return <Typography variant="h5">No Project Open</Typography>
  }

  const errorCount = validationIssues.filter((i) => i.severity === 'error').length
  const warningCount = validationIssues.filter((i) => i.severity === 'warning').length
  const totalIssues = errorCount + warningCount

  return (
    <Stack spacing={2}>
      {refreshError && (
        <Typography color="error" variant="body2">{refreshError}</Typography>
      )}

      {/* Hero Banner */}
      <Paper
        sx={{
          p: 2,
          display: 'flex',
          alignItems: 'center',
          gap: 2,
          bgcolor: 'primary.main',
          color: '#fff',
        }}
      >
        <ProjectInitialsMark name={activeProject.projectName} size={56} />
        <Box sx={{ flex: 1, minWidth: 0 }}>
          <Stack direction="row" spacing={1} alignItems="center">
            <Typography variant="h6" sx={{ fontWeight: 700, color: '#fff' }} noWrap>
              {activeProject.projectName}
            </Typography>
            <StatusTag status={saveStatus} />
          </Stack>
          <Typography variant="body2" sx={{ color: 'rgba(255,255,255,0.8)', mt: 0.25 }}>
            Last saved <RelativeTimestamp timestamp={activeProject.lastModifiedAt} variant="caption" inline />
          </Typography>
          <Typography
            variant="caption"
            sx={{ color: 'rgba(255,255,255,0.6)', fontFamily: (t) => (t.typography as any).fontFamilyMono }}
          >
            {activeProject.filePath} · <FileSizeDisplay bytes={activeProject.fileSize} />
          </Typography>
        </Box>
        <Stack direction="row" spacing={1}>
          <Button
            variant="outlined"
            size="small"
            startIcon={<BackupIcon />}
            onClick={() => void handleBackup()}
            sx={{ color: '#fff', borderColor: 'rgba(255,255,255,0.5)', textTransform: 'none' }}
          >
            Backup
          </Button>
          <Button
            variant="contained"
            size="small"
            startIcon={<AddIcon />}
            onClick={(e) => setQuickAddAnchor(e.currentTarget)}
            sx={{ bgcolor: 'rgba(255,255,255,0.2)', textTransform: 'none', '&:hover': { bgcolor: 'rgba(255,255,255,0.3)' } }}
          >
            Quick add
          </Button>
          <Menu
            anchorEl={quickAddAnchor}
            open={Boolean(quickAddAnchor)}
            onClose={() => setQuickAddAnchor(null)}
          >
            {QUICK_ADD_DOMAINS.map((d) => (
              <MenuItem
                key={d.label}
                onClick={() => { setQuickAddAnchor(null); navigate(d.path) }}
              >
                {d.label}
              </MenuItem>
            ))}
          </Menu>
        </Stack>
      </Paper>

      {/* Count Tiles */}
      <Box sx={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: 1.25 }}>
        {DOMAIN_TILES.map(({ label, key, path, Icon }) => {
          const count = activeProject.recordCounts[key]
          const delta = weeklyDeltas?.[key] ?? 0
          return (
            <ButtonBase
              key={key}
              onClick={() => navigate(path)}
              sx={{ display: 'block', textAlign: 'left', width: '100%' }}
            >
              <Paper variant="outlined" sx={{ p: 1.25 }}>
                <Stack direction="row" spacing={0.75} alignItems="center" sx={{ mb: 0.5 }}>
                  <Icon sx={{ fontSize: 16, color: 'primary.main' }} />
                  <Typography variant="caption" sx={{ textTransform: 'uppercase', fontWeight: 500, letterSpacing: 0.5 }}>
                    {label}
                  </Typography>
                </Stack>
                <Typography variant="h5" sx={{ fontWeight: 700, color: 'primary.main' }}>
                  {count}
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  {delta > 0 ? `+${delta} this wk` : delta < 0 ? `${delta} this wk` : 'stable'}
                </Typography>
              </Paper>
            </ButtonBase>
          )
        })}
      </Box>

      {/* Two-column row: Save history + sidebar tiles */}
      <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', md: '2fr 1fr' }, gap: 1.25 }}>
        {/* Save History */}
        <Paper variant="outlined" sx={{ p: 1.5 }}>
          <Stack direction="row" spacing={0.75} alignItems="center" sx={{ mb: 1 }}>
            <HistoryIcon sx={{ fontSize: 16, color: 'text.secondary' }} />
            <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>Save history</Typography>
            <Typography variant="caption" color="text.secondary" sx={{ ml: 'auto' }}>
              last {saveHistory.length} saves
            </Typography>
          </Stack>
          {saveHistory.length === 0 ? (
            <Typography variant="body2" color="text.secondary">No saves recorded yet.</Typography>
          ) : (
            <Stack spacing={0.75}>
              {saveHistory.map((entry) => (
                <Stack key={entry.id} direction="row" spacing={1} alignItems="center">
                  <Box
                    sx={{
                      width: 28,
                      height: 28,
                      borderRadius: 0.5,
                      bgcolor: 'action.hover',
                      border: 1,
                      borderColor: 'primary.main',
                      display: 'grid',
                      placeItems: 'center',
                    }}
                  >
                    <HistoryIcon sx={{ fontSize: 14, color: 'primary.main' }} />
                  </Box>
                  <Box sx={{ flex: 1, minWidth: 0 }}>
                    <Typography variant="body2" noWrap>
                      {entry.isAutoSave ? 'Auto-save' : 'Manual save'}
                    </Typography>
                  </Box>
                  <RelativeTimestamp timestamp={entry.savedAt} variant="caption" />
                </Stack>
              ))}
            </Stack>
          )}
        </Paper>

        {/* Right column */}
        <Stack spacing={1.25}>
          {/* Validation Warnings */}
          <Paper
            variant="outlined"
            sx={{
              p: 1.5,
              cursor: 'pointer',
              borderColor: totalIssues > 0 ? (errorCount > 0 ? 'error.main' : 'warning.main') : 'divider',
            }}
            onClick={() => navigate('/validation')}
          >
            <Stack direction="row" spacing={0.75} alignItems="center">
              <WarningIcon sx={{ fontSize: 16, color: totalIssues > 0 ? 'warning.main' : 'text.secondary' }} />
              <Typography
                variant="subtitle2"
                sx={{ fontWeight: 600, color: totalIssues > 0 ? 'warning.main' : 'text.primary' }}
              >
                {totalIssues === 0 ? 'No issues' : `${totalIssues} ${totalIssues === 1 ? 'issue' : 'issues'}`}
              </Typography>
            </Stack>
            {totalIssues > 0 && (
              <Typography variant="caption" color="text.secondary" sx={{ mt: 0.25, display: 'block' }}>
                {[
                  errorCount > 0 && `${errorCount} ${errorCount === 1 ? 'error' : 'errors'}`,
                  warningCount > 0 && `${warningCount} ${warningCount === 1 ? 'warning' : 'warnings'}`,
                ].filter(Boolean).join(', ')}
              </Typography>
            )}
          </Paper>

          {/* Quick Add */}
          <Paper variant="outlined" sx={{ p: 1.5 }}>
            <Stack direction="row" spacing={0.75} alignItems="center" sx={{ mb: 1 }}>
              <AddIcon sx={{ fontSize: 16, color: 'text.secondary' }} />
              <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>Quick add</Typography>
            </Stack>
            <Stack direction="row" flexWrap="wrap" gap={0.75}>
              {QUICK_ADD_DOMAINS.map((d) => (
                <Chip
                  key={d.label}
                  label={d.label}
                  size="small"
                  onClick={() => navigate(d.path)}
                  clickable
                />
              ))}
            </Stack>
          </Paper>

          {/* Auto-save */}
          <Paper variant="outlined" sx={{ p: 1.5, bgcolor: 'action.hover' }}>
            <Stack direction="row" spacing={0.75} alignItems="center">
              <ScheduleIcon sx={{ fontSize: 16, color: 'text.secondary' }} />
              <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>Auto-save</Typography>
            </Stack>
            <Typography variant="caption" color="text.secondary" sx={{ mt: 0.25, display: 'block' }}>
              Every {autoSaveInfo ? Math.round(autoSaveInfo.intervalMs / 60000) : '?'} min
              {countdown && ` · next save in ${countdown}`}
            </Typography>
          </Paper>
        </Stack>
      </Box>
    </Stack>
  )
}

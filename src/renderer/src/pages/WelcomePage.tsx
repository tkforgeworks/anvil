import {
  Add as AddIcon,
  FolderOpen as FolderOpenIcon,
  Settings as SettingsIcon,
} from '@mui/icons-material'
import {
  Box,
  Button,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControl,
  InputLabel,
  MenuItem,
  Paper,
  Select,
  Stack,
  TextField,
  Typography,
} from '@mui/material'
import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { projectApi } from '../../api/project.api'
import type { ProjectTemplateId, RecentProject } from '../../../shared/project-types'
import { useProjectStore } from '../stores/project.store'
import AppSettingsDialog from '../components/AppSettingsDialog'
import { ProjectInitialsMark } from '../components/ProjectInitialsMark'
import { RelativeTimestamp } from '../components/RelativeTimestamp'
import { FileSizeDisplay } from '../components/FileSizeDisplay'

const TEMPLATE_OPTIONS: { value: ProjectTemplateId; label: string }[] = [
  { value: 'blank', label: 'Blank' },
  { value: 'fantasy-rpg', label: 'Fantasy RPG' },
  { value: 'sci-fi-rpg', label: 'Sci-Fi RPG' },
]

function countSummary(project: RecentProject): string {
  const c = project.recordCounts
  const parts: string[] = []
  if (c.items) parts.push(`${c.items} items`)
  if (c.abilities) parts.push(`${c.abilities} abilities`)
  if (c.classes) parts.push(`${c.classes} classes`)
  if (c.npcs) parts.push(`${c.npcs} NPCs`)
  if (c.recipes) parts.push(`${c.recipes} recipes`)
  if (c.lootTables) parts.push(`${c.lootTables} loot tables`)
  return parts.join(' · ')
}

export default function WelcomePage(): React.JSX.Element {
  const navigate = useNavigate()
  const hydrate = useProjectStore((state) => state.hydrate)
  const recentProjects = useProjectStore((state) => state.recentProjects)
  const [isCreateOpen, setCreateOpen] = useState(false)
  const [projectName, setProjectName] = useState('')
  const [gameTitle, setGameTitle] = useState('')
  const [templateId, setTemplateId] = useState<ProjectTemplateId>('blank')
  const [error, setError] = useState<string | null>(null)
  const [isBusy, setBusy] = useState(false)
  const [settingsOpen, setSettingsOpen] = useState(false)

  const openProject = async (filePath?: string): Promise<void> => {
    setBusy(true)
    setError(null)
    try {
      const snapshot = await projectApi.open(filePath)
      hydrate(snapshot)
      if (snapshot.activeProject) navigate('/')
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Unable to open project.')
    } finally {
      setBusy(false)
    }
  }

  const createProject = async (): Promise<void> => {
    setBusy(true)
    setError(null)
    try {
      const snapshot = await projectApi.create({ projectName, gameTitle, templateId })
      hydrate(snapshot)
      if (snapshot.activeProject) {
        setCreateOpen(false)
        navigate('/')
      }
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Unable to create project.')
    } finally {
      setBusy(false)
    }
  }

  const removeRecentProject = async (filePath: string): Promise<void> => {
    const snapshot = await projectApi.removeRecent(filePath)
    hydrate(snapshot)
  }

  const closeCreateDialog = (): void => {
    setCreateOpen(false)
    setProjectName('')
    setGameTitle('')
    setTemplateId('blank')
    setError(null)
  }

  const canCreate = projectName.trim().length > 0 && gameTitle.trim().length > 0 && !isBusy

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', height: '100%', bgcolor: 'background.default' }}>
      <Box sx={{ flex: 1, overflow: 'auto', px: 6, py: 4 }}>
        <Box sx={{ maxWidth: 920, mx: 'auto' }}>
          {/* Hero */}
          <Typography variant="h4" component="h1" sx={{ fontWeight: 700, mb: 0.5 }}>
            Welcome to{' '}
            <Box component="span" sx={{ color: 'primary.main' }}>
              Anvil
            </Box>
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
            Pick a project, or start a new world.
          </Typography>

          {error && (
            <Typography color="error" role="alert" sx={{ mb: 2 }}>
              {error}
            </Typography>
          )}

          {/* Quick-action tiles */}
          <Stack direction="row" spacing={1.5} sx={{ mb: 3.5 }}>
            <ActionTile
              icon={<AddIcon sx={{ color: '#fff', fontSize: 22 }} />}
              iconBg="primary.main"
              title="New project"
              subtitle="Blank or from template"
              variant="brand"
              onClick={() => setCreateOpen(true)}
              disabled={isBusy}
            />
            <ActionTile
              icon={<FolderOpenIcon sx={{ fontSize: 18 }} />}
              iconBg="action.hover"
              title="Open file..."
              subtitle=".anvil project file"
              onClick={() => void openProject()}
              disabled={isBusy}
            />
            <ActionTile
              icon={<SettingsIcon sx={{ fontSize: 18 }} />}
              iconBg="action.hover"
              title="Settings"
              subtitle="Theme, shortcuts, paths"
              onClick={() => setSettingsOpen(true)}
              disabled={isBusy}
            />
          </Stack>

          {/* Recent projects header */}
          <Stack direction="row" alignItems="baseline" justifyContent="space-between" sx={{ mb: 1 }}>
            <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>
              Recent projects
            </Typography>
            <Typography variant="caption" color="text.secondary">
              Sorted by last save · stored locally
            </Typography>
          </Stack>

          {/* Recents list */}
          {recentProjects.length === 0 ? (
            <Typography color="text.secondary" sx={{ py: 3 }}>
              No recent projects yet. Create a new project or open an existing .anvil file.
            </Typography>
          ) : (
            <Paper variant="outlined" sx={{ overflow: 'hidden' }}>
              {recentProjects.map((project, idx) => (
                <Box
                  key={project.filePath}
                  onClick={() => !isBusy && project.exists && void openProject(project.filePath)}
                  sx={{
                    display: 'flex',
                    alignItems: 'flex-start',
                    gap: 1.5,
                    px: 1.5,
                    py: 1.25,
                    cursor: project.exists && !isBusy ? 'pointer' : 'default',
                    opacity: !project.exists ? 0.5 : project.isArchived ? 0.7 : 1,
                    borderBottom: idx < recentProjects.length - 1 ? 1 : 0,
                    borderColor: 'divider',
                    '&:hover': project.exists ? { bgcolor: 'action.hover' } : undefined,
                  }}
                >
                  <ProjectInitialsMark name={project.projectName} size={34} />
                  <Box sx={{ flex: 1, minWidth: 0 }}>
                    <Stack direction="row" spacing={1} alignItems="baseline">
                      <Typography variant="body2" sx={{ fontWeight: 600 }} noWrap>
                        {project.projectName}
                      </Typography>
                      {project.isArchived && (
                        <Chip label="archived" size="small" variant="outlined" sx={{ height: 18, fontSize: '0.65rem' }} />
                      )}
                      <Typography variant="caption" color="text.secondary" noWrap>
                        · {countSummary(project) || 'empty project'}
                      </Typography>
                    </Stack>
                    <Stack direction="row" spacing={0.75} alignItems="center" sx={{ mt: 0.25 }}>
                      <Box
                        sx={{
                          width: 6,
                          height: 6,
                          borderRadius: '50%',
                          bgcolor: 'primary.main',
                          flexShrink: 0,
                        }}
                      />
                      <Typography variant="caption" color="text.secondary">
                        Last saved{' '}
                        <RelativeTimestamp timestamp={project.lastModifiedAt} variant="caption" inline />
                      </Typography>
                      {!project.exists && (
                        <Typography variant="caption" color="error.main" sx={{ ml: 1 }}>
                          · File missing
                        </Typography>
                      )}
                    </Stack>
                  </Box>
                  <Stack alignItems="flex-end" spacing={0.25} sx={{ flexShrink: 0 }}>
                    <FileSizeDisplay bytes={project.fileSize} />
                    <Button
                      size="small"
                      color="inherit"
                      onClick={(e) => {
                        e.stopPropagation()
                        void removeRecentProject(project.filePath)
                      }}
                      disabled={isBusy}
                      sx={{ fontSize: 10, minWidth: 0, px: 0.5, py: 0, textTransform: 'none' }}
                    >
                      Remove
                    </Button>
                  </Stack>
                </Box>
              ))}
            </Paper>
          )}

          {/* Footer */}
          <Typography
            variant="caption"
            color="text.secondary"
            sx={{ display: 'block', textAlign: 'center', mt: 3 }}
          >
            <strong>Local-first:</strong> all projects live on disk. No accounts, no sync.
          </Typography>
        </Box>
      </Box>

      {/* Create Project Dialog */}
      <Dialog open={isCreateOpen} onClose={closeCreateDialog} fullWidth maxWidth="sm">
        <DialogTitle>Create New Project</DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ pt: 1 }}>
            <TextField
              label="Project Name"
              value={projectName}
              onChange={(event) => setProjectName(event.target.value)}
              autoFocus
              required
            />
            <TextField
              label="Game Title"
              value={gameTitle}
              onChange={(event) => setGameTitle(event.target.value)}
              required
            />
            <FormControl>
              <InputLabel id="project-template-label">Template</InputLabel>
              <Select
                labelId="project-template-label"
                label="Template"
                value={templateId}
                onChange={(event) => setTemplateId(event.target.value as ProjectTemplateId)}
              >
                {TEMPLATE_OPTIONS.map((option) => (
                  <MenuItem key={option.value} value={option.value}>
                    {option.label}
                  </MenuItem>
                ))}
              </Select>
            </FormControl>
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={closeCreateDialog} disabled={isBusy}>
            Cancel
          </Button>
          <Button onClick={() => void createProject()} disabled={!canCreate} variant="contained">
            Create
          </Button>
        </DialogActions>
      </Dialog>

      <AppSettingsDialog open={settingsOpen} onClose={() => setSettingsOpen(false)} />
    </Box>
  )
}

interface ActionTileProps {
  icon: React.ReactNode
  iconBg: string
  title: string
  subtitle: string
  variant?: 'brand' | 'default'
  onClick: () => void
  disabled?: boolean
}

function ActionTile({ icon, iconBg, title, subtitle, variant, onClick, disabled }: ActionTileProps) {
  const isBrand = variant === 'brand'
  return (
    <Paper
      variant="outlined"
      onClick={disabled ? undefined : onClick}
      sx={{
        flex: 1,
        p: 1.5,
        cursor: disabled ? 'default' : 'pointer',
        display: 'flex',
        alignItems: 'center',
        gap: 1.25,
        borderColor: isBrand ? 'primary.main' : 'divider',
        bgcolor: isBrand ? 'primary.main' : 'background.paper',
        '&:hover': disabled
          ? undefined
          : { bgcolor: isBrand ? 'primary.dark' : 'action.hover' },
      }}
    >
      <Box
        sx={{
          width: 44,
          height: 44,
          borderRadius: 1,
          bgcolor: isBrand ? 'primary.dark' : iconBg,
          border: isBrand ? 'none' : 1,
          borderColor: 'divider',
          display: 'grid',
          placeItems: 'center',
        }}
      >
        {icon}
      </Box>
      <Box>
        <Typography
          variant="body2"
          sx={{ fontWeight: 600, color: isBrand ? '#fff' : 'text.primary' }}
        >
          {title}
        </Typography>
        <Typography
          variant="caption"
          sx={{ color: isBrand ? 'rgba(255,255,255,0.7)' : 'text.secondary' }}
        >
          {subtitle}
        </Typography>
      </Box>
    </Paper>
  )
}

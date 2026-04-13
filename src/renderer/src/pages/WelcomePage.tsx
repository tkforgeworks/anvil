import {
  Box,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControl,
  InputLabel,
  List,
  ListItem,
  ListItemText,
  MenuItem,
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

const TEMPLATE_OPTIONS: { value: ProjectTemplateId; label: string }[] = [
  { value: 'blank', label: 'Blank' },
  { value: 'fantasy-rpg', label: 'Fantasy RPG' },
  { value: 'sci-fi-rpg', label: 'Sci-Fi RPG' },
]

function formatDate(value: string): string {
  return new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value))
}

function countSummary(project: RecentProject): string {
  const counts = project.recordCounts
  return [
    `${counts.classes} classes`,
    `${counts.abilities} abilities`,
    `${counts.items} items`,
    `${counts.recipes} recipes`,
    `${counts.npcs} NPCs`,
    `${counts.lootTables} loot tables`,
  ].join(' | ')
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
    <Box sx={{ minHeight: '100vh', bgcolor: 'background.default', p: 4 }}>
      <Stack spacing={4} sx={{ maxWidth: 920, mx: 'auto' }}>
        <Box>
          <Typography variant="h3" component="h1" sx={{ fontWeight: 700 }}>
            Anvil
          </Typography>
          <Typography color="text.secondary" sx={{ mt: 1 }}>
            Open a project or create a new RPG data workspace.
          </Typography>
        </Box>

        {error && (
          <Typography color="error" role="alert">
            {error}
          </Typography>
        )}

        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2}>
          <Button variant="contained" onClick={() => setCreateOpen(true)} disabled={isBusy}>
            Create New Project
          </Button>
          <Button variant="outlined" onClick={() => void openProject()} disabled={isBusy}>
            Open Project
          </Button>
        </Stack>

        <Box>
          <Typography variant="h5" sx={{ mb: 1 }}>
            Recent Projects
          </Typography>
          {recentProjects.length === 0 ? (
            <Typography color="text.secondary">No recent projects yet.</Typography>
          ) : (
            <List sx={{ border: 1, borderColor: 'divider', borderRadius: 1 }}>
              {recentProjects.map((project) => (
                <ListItem
                  key={project.filePath}
                  divider
                  secondaryAction={
                    <Stack direction="row" spacing={1}>
                      <Button
                        size="small"
                        onClick={() => void openProject(project.filePath)}
                        disabled={isBusy || !project.exists}
                      >
                        Open
                      </Button>
                      <Button
                        size="small"
                        color="inherit"
                        onClick={() => void removeRecentProject(project.filePath)}
                        disabled={isBusy}
                      >
                        Remove
                      </Button>
                    </Stack>
                  }
                >
                  <ListItemText
                    primary={`${project.projectName} - ${project.gameTitle}`}
                    secondary={`${formatDate(project.lastModifiedAt)} - ${countSummary(project)}${
                      project.exists ? '' : ' - Missing file'
                    }`}
                  />
                </ListItem>
              ))}
            </List>
          )}
        </Box>
      </Stack>

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
    </Box>
  )
}

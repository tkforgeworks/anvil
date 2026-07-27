import {
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControl,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  TextField,
  Typography,
} from '@mui/material'
import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { projectApi } from '../../api/project.api'
import type { ProjectTemplateId } from '../../../shared/project-types'
import { MODAL_IDS } from '../menu/constants'
import { useProjectStore } from '../stores/project.store'
import { useUiStore } from '../stores/ui.store'

const TEMPLATE_OPTIONS: { value: ProjectTemplateId; label: string }[] = [
  { value: 'blank', label: 'Blank' },
  { value: 'fantasy-rpg', label: 'Fantasy RPG' },
  { value: 'sci-fi-rpg', label: 'Sci-Fi RPG' },
]

export default function CreateProjectModal(): React.JSX.Element | null {
  const activeModalId = useUiStore((s) => s.activeModalId)

  if (activeModalId !== MODAL_IDS.NEW_PROJECT) return null

  return <CreateProjectDialog />
}

function CreateProjectDialog(): React.JSX.Element {
  const navigate = useNavigate()
  const closeModal = useUiStore((s) => s.closeModal)
  const hydrate = useProjectStore((state) => state.hydrate)
  const [projectName, setProjectName] = useState('')
  const [gameTitle, setGameTitle] = useState('')
  const [templateId, setTemplateId] = useState<ProjectTemplateId>('blank')
  const [error, setError] = useState<string | null>(null)
  const [isBusy, setBusy] = useState(false)

  const createProject = async (): Promise<void> => {
    setBusy(true)
    setError(null)
    try {
      const snapshot = await projectApi.create({ projectName, gameTitle, templateId })
      hydrate(snapshot)
      if (snapshot.activeProject) {
        closeModal()
        navigate('/')
      }
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Unable to create project.')
    } finally {
      setBusy(false)
    }
  }

  const canCreate = projectName.trim().length > 0 && gameTitle.trim().length > 0 && !isBusy

  return (
    <Dialog open onClose={isBusy ? undefined : closeModal} fullWidth maxWidth="sm">
      <DialogTitle>Create New Project</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ pt: 1 }}>
          {error && (
            <Typography color="error" role="alert">
              {error}
            </Typography>
          )}
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
        <Button onClick={closeModal} disabled={isBusy} data-tid="dialog-create-project-cancel">
          Cancel
        </Button>
        <Button
          onClick={() => void createProject()}
          disabled={!canCreate}
          variant="contained"
          data-tid="dialog-create-project-confirm"
        >
          Create
        </Button>
      </DialogActions>
    </Dialog>
  )
}

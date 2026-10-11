import {
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Stack,
  TextField,
  Typography,
} from '@mui/material'
import { useState } from 'react'
import { useNavigate } from 'react-router'
import { projectApi } from '../../api/project.api'
import { MODAL_IDS } from '../menu/constants'
import { useProjectStore } from '../stores/project.store'
import { useUiStore } from '../stores/ui.store'

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
  const [error, setError] = useState<string | null>(null)
  const [isBusy, setBusy] = useState(false)

  const createProject = async (): Promise<void> => {
    setBusy(true)
    setError(null)
    try {
      // Templates are not implemented in the main process yet (ANVL-156), so the
      // selector is hidden and every project is created blank. `templateId`
      // stays in the IPC contract so the wire shape does not churn.
      const snapshot = await projectApi.create({ projectName, gameTitle, templateId: 'blank' })
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

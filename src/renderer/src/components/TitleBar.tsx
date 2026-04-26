import { AppBar, Toolbar, Typography, Chip, Stack, Button, IconButton, Divider } from '@mui/material'
import MinimizeIcon from '@mui/icons-material/RemoveRounded'
import MaximizeIcon from '@mui/icons-material/CropSquareRounded'
import CloseIcon from '@mui/icons-material/CloseRounded'
import { IPC_CHANNELS } from '../../../shared/ipc-channels'
import { projectApi } from '../../api/project.api'
import { useProjectStore, type SaveStatus } from '../stores/project.store'

const noDrag = { WebkitAppRegion: 'no-drag' } as const

function saveStatusLabel(isDirty: boolean, saveStatus: SaveStatus): string {
  if (saveStatus === 'saving') return 'Saving...'
  if (saveStatus === 'unsaved') return 'Unsaved Changes'
  if (isDirty) return 'Unsaved Changes'
  if (saveStatus === 'error') return 'Save Error'
  return 'Saved'
}

function saveStatusColor(isDirty: boolean, saveStatus: SaveStatus): 'default' | 'error' | 'warning' {
  if (saveStatus === 'error') return 'error'
  if (isDirty || saveStatus === 'unsaved') return 'warning'
  return 'default'
}

export default function TitleBar(): React.JSX.Element {
  const activeProject = useProjectStore((state) => state.activeProject)
  const hydrate = useProjectStore((state) => state.hydrate)
  const isDirty = useProjectStore((state) => state.isDirty)
  const isRecoveryMode = useProjectStore((state) => state.isRecoveryMode)
  const saveStatus = useProjectStore((state) => state.saveStatus)
  const setSaveStatus = useProjectStore((state) => state.setSaveStatus)
  const setSaveError = useProjectStore((state) => state.setSaveError)

  const saveProject = async (): Promise<void> => {
    if (isRecoveryMode) return
    setSaveStatus('saving')
    setSaveError(null)
    try {
      const snapshot = await projectApi.save()
      hydrate(snapshot)
    } catch (cause) {
      setSaveError(cause instanceof Error ? cause.message : 'Unable to save project.')
    }
  }

  const saveProjectAs = async (): Promise<void> => {
    if (isRecoveryMode) return
    setSaveStatus('saving')
    setSaveError(null)
    try {
      const snapshot = await projectApi.saveAs()
      hydrate(snapshot)
    } catch (cause) {
      setSaveError(cause instanceof Error ? cause.message : 'Unable to save project copy.')
    }
  }

  const closeProject = async (): Promise<void> => {
    const snapshot = await projectApi.close()
    hydrate(snapshot)
  }

  return (
    <AppBar
      position="static"
      elevation={0}
      sx={{ zIndex: (theme) => theme.zIndex.drawer + 1, WebkitAppRegion: 'drag' }}
    >
      <Toolbar variant="dense">
        <Typography variant="h6" component="div" sx={{ fontWeight: 700, letterSpacing: 0 }}>
          ANVIL
        </Typography>
        <Chip
          label={activeProject ? activeProject.projectName : 'No Project Open'}
          size="small"
          variant="outlined"
          sx={{ ml: 2, fontSize: '0.7rem', opacity: 0.7, ...noDrag }}
        />
        <Stack direction="row" spacing={1} sx={{ ml: 'auto', alignItems: 'center', ...noDrag }}>
          <Chip
            label={saveStatusLabel(isDirty, saveStatus)}
            size="small"
            color={saveStatusColor(isDirty, saveStatus)}
            variant="outlined"
            sx={{ fontSize: '0.7rem' }}
          />
          <Button
            color="inherit"
            size="small"
            onClick={() => void saveProject()}
            disabled={!activeProject || isRecoveryMode}
          >
            Save
          </Button>
          <Button
            color="inherit"
            size="small"
            onClick={() => void saveProjectAs()}
            disabled={!activeProject || isRecoveryMode}
          >
            Save As
          </Button>
          <Button color="inherit" size="small" onClick={() => void closeProject()}>
            Close
          </Button>
          <Divider orientation="vertical" flexItem sx={{ mx: 0.5, borderColor: 'rgba(255,255,255,0.2)' }} />
          <IconButton
            color="inherit"
            size="small"
            onClick={() => void window.anvil.invoke(IPC_CHANNELS.WINDOW_MINIMIZE)}
          >
            <MinimizeIcon fontSize="small" />
          </IconButton>
          <IconButton
            color="inherit"
            size="small"
            onClick={() => void window.anvil.invoke(IPC_CHANNELS.WINDOW_MAXIMIZE)}
          >
            <MaximizeIcon fontSize="small" />
          </IconButton>
          <IconButton
            color="inherit"
            size="small"
            onClick={() => void window.anvil.invoke(IPC_CHANNELS.WINDOW_CLOSE)}
            sx={{ '&:hover': { bgcolor: 'error.dark' } }}
          >
            <CloseIcon fontSize="small" />
          </IconButton>
        </Stack>
      </Toolbar>
    </AppBar>
  )
}

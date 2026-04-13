import { AppBar, Toolbar, Typography, Chip, Stack, Button } from '@mui/material'
import { projectApi } from '../../api/project.api'
import { useProjectStore } from '../stores/project.store'

function saveStatusLabel(isDirty: boolean, saveStatus: string): string {
  if (saveStatus === 'saving') return 'Saving...'
  if (isDirty) return 'Unsaved Changes'
  if (saveStatus === 'error') return 'Save Error'
  return 'Saved'
}

export default function TitleBar(): React.JSX.Element {
  const activeProject = useProjectStore((state) => state.activeProject)
  const hydrate = useProjectStore((state) => state.hydrate)
  const isDirty = useProjectStore((state) => state.isDirty)
  const saveStatus = useProjectStore((state) => state.saveStatus)

  const closeProject = async (): Promise<void> => {
    const snapshot = await projectApi.close()
    hydrate(snapshot)
  }

  return (
    <AppBar position="static" elevation={0} sx={{ zIndex: (theme) => theme.zIndex.drawer + 1 }}>
      <Toolbar variant="dense">
        <Typography variant="h6" component="div" sx={{ fontWeight: 700, letterSpacing: 0 }}>
          ANVIL
        </Typography>
        <Chip
          label={activeProject ? activeProject.projectName : 'No Project Open'}
          size="small"
          variant="outlined"
          sx={{ ml: 2, fontSize: '0.7rem', opacity: 0.7 }}
        />
        <Stack direction="row" spacing={1} sx={{ ml: 'auto', alignItems: 'center' }}>
          <Chip
            label={saveStatusLabel(isDirty, saveStatus)}
            size="small"
            color={isDirty ? 'warning' : saveStatus === 'error' ? 'error' : 'default'}
            variant="outlined"
            sx={{ fontSize: '0.7rem' }}
          />
          <Button color="inherit" size="small" onClick={() => void closeProject()}>
            Close
          </Button>
        </Stack>
      </Toolbar>
    </AppBar>
  )
}

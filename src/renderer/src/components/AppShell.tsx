import { Alert, Box, Snackbar } from '@mui/material'
import { useCallback, useEffect } from 'react'
import { Outlet } from 'react-router-dom'
import { projectApi } from '../../api/project.api'
import { useLifecycleStore } from '../stores/lifecycle.store'
import { useProjectStore } from '../stores/project.store'
import TitleBar from './TitleBar'
import Sidebar from './Sidebar'

export default function AppShell(): React.JSX.Element {
  const refreshTrashCount = useLifecycleStore((state) => state.refreshTrashCount)
  const activeProject = useProjectStore((state) => state.activeProject)
  const hydrate = useProjectStore((state) => state.hydrate)
  const isRecoveryMode = useProjectStore((state) => state.isRecoveryMode)
  const recoveryMessage = useProjectStore((state) => state.recoveryMessage)
  const saveError = useProjectStore((state) => state.saveError)
  const setSaveStatus = useProjectStore((state) => state.setSaveStatus)
  const setSaveError = useProjectStore((state) => state.setSaveError)

  const saveProject = useCallback(async (): Promise<void> => {
    if (!activeProject || isRecoveryMode) return

    setSaveStatus('saving')
    setSaveError(null)
    try {
      const snapshot = await projectApi.save()
      hydrate(snapshot)
    } catch (cause) {
      setSaveError(cause instanceof Error ? cause.message : 'Unable to save project.')
    }
  }, [activeProject, hydrate, isRecoveryMode, setSaveError, setSaveStatus])

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent): void => {
      if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 's') {
        event.preventDefault()
        void saveProject()
      }
    }

    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [saveProject])

  useEffect(() => {
    if (!activeProject) return undefined

    void refreshTrashCount()

    const intervalId = window.setInterval(() => {
      void projectApi
        .getState()
        .then(hydrate)
        .catch((cause) => {
          setSaveError(cause instanceof Error ? cause.message : 'Unable to refresh project state.')
        })
      void refreshTrashCount()
    }, 2000)

    return () => window.clearInterval(intervalId)
  }, [activeProject, hydrate, refreshTrashCount, setSaveError])

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', height: '100vh', overflow: 'hidden' }}>
      <TitleBar />
      <Box sx={{ display: 'flex', flex: 1, overflow: 'hidden' }}>
        <Sidebar />
        <Box
          component="main"
          sx={{
            flex: 1,
            overflow: 'auto',
            px: 3,
            pb: 3,
            bgcolor: 'background.default',
          }}
        >
          <Box sx={{ pt: 3 }}>
            {isRecoveryMode && (
              <Alert severity="warning" sx={{ mb: 2 }}>
                Recovery mode is active. This project is read-only and cannot be saved.
                {recoveryMessage ? ` ${recoveryMessage}` : ''}
              </Alert>
            )}
            <Outlet />
          </Box>
        </Box>
      </Box>
      <Snackbar
        open={Boolean(saveError)}
        autoHideDuration={6000}
        onClose={() => setSaveError(null)}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
      >
        <Alert severity="error" variant="filled" onClose={() => setSaveError(null)}>
          {saveError}
        </Alert>
      </Snackbar>
    </Box>
  )
}

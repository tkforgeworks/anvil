import { Alert, Box, ButtonBase, Stack, Typography } from '@mui/material'
import { useCallback, useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { projectApi } from '../../api/project.api'
import { useProjectStore } from '../stores/project.store'

const COUNT_LINKS = [
  { label: 'Classes', key: 'classes', path: '/classes' },
  { label: 'Abilities', key: 'abilities', path: '/abilities' },
  { label: 'Items', key: 'items', path: '/items' },
  { label: 'Recipes', key: 'recipes', path: '/recipes' },
  { label: 'NPCs', key: 'npcs', path: '/npcs' },
  { label: 'Loot Tables', key: 'lootTables', path: '/loot-tables' },
] as const

function formatDate(value: string): string {
  return new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value))
}

export default function DashboardPage(): React.JSX.Element {
  const navigate = useNavigate()
  const activeProject = useProjectStore((state) => state.activeProject)
  const hydrate = useProjectStore((state) => state.hydrate)
  const [refreshError, setRefreshError] = useState<string | null>(null)

  const refreshProjectState = useCallback(async () => {
    try {
      const snapshot = await projectApi.getState()
      hydrate(snapshot)
      setRefreshError(null)
    } catch (cause) {
      setRefreshError(cause instanceof Error ? cause.message : 'Unable to refresh dashboard.')
    }
  }, [hydrate])

  useEffect(() => {
    void refreshProjectState()

    const refreshOnFocus = (): void => {
      void refreshProjectState()
    }
    window.addEventListener('focus', refreshOnFocus)
    const intervalId = window.setInterval(() => {
      if (document.visibilityState === 'visible') {
        void refreshProjectState()
      }
    }, 5000)

    return () => {
      window.removeEventListener('focus', refreshOnFocus)
      window.clearInterval(intervalId)
    }
  }, [refreshProjectState])

  if (!activeProject) {
    return <Typography variant="h5">No Project Open</Typography>
  }

  return (
    <Stack spacing={3}>
      {refreshError && <Alert severity="error">{refreshError}</Alert>}

      <Box>
        <Typography variant="h4" component="h1" sx={{ fontWeight: 700 }}>
          {activeProject.projectName}
        </Typography>
        <Typography color="text.secondary">{activeProject.gameTitle}</Typography>
      </Box>

      <Stack direction={{ xs: 'column', sm: 'row' }} spacing={3}>
        <Box>
          <Typography variant="overline" color="text.secondary">
            Last Modified
          </Typography>
          <Typography>{formatDate(activeProject.lastModifiedAt)}</Typography>
        </Box>
        <Box>
          <Typography variant="overline" color="text.secondary">
            Schema Version
          </Typography>
          <Typography>{activeProject.schemaVersion}</Typography>
        </Box>
      </Stack>

      <Box
        sx={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
          gap: 2,
        }}
      >
        {COUNT_LINKS.map((item) => (
          <ButtonBase
            key={item.key}
            onClick={() => navigate(item.path)}
            sx={{
              display: 'block',
              textAlign: 'left',
              border: 1,
              borderColor: 'divider',
              borderRadius: 1,
              p: 2,
            }}
          >
            <Typography variant="h4">{activeProject.recordCounts[item.key]}</Typography>
            <Typography color="text.secondary">{item.label}</Typography>
          </ButtonBase>
        ))}
      </Box>
    </Stack>
  )
}

import { Box, Typography } from '@mui/material'
import { projectApi } from '../../../api/project.api'
import { useProjectStore } from '../../stores/project.store'
import { useUiStore } from '../../stores/ui.store'
import { RelativeTimestamp } from '../RelativeTimestamp'
import MenuIcon from './MenuIcon'

export default function RecentSubmenu(): React.JSX.Element {
  const recentProjects = useProjectStore((s) => s.recentProjects)
  const hydrate = useProjectStore((s) => s.hydrate)
  const setMenuOpen = useUiStore((s) => s.setMenuOpen)

  const handleOpen = (filePath: string): void => {
    setMenuOpen(false)
    void projectApi
      .open(filePath)
      .then((s) => {
        if (s.activeProject) hydrate(s)
      })
      .catch(() => {})
  }

  const handleClear = (): void => {
    void projectApi.clearRecents().then((s) => hydrate(s))
  }

  return (
    <Box
      sx={{
        position: 'absolute',
        top: 0,
        left: 320,
        bgcolor: '#14203a',
        border: '1px solid #2a3553',
        borderRadius: '8px',
        boxShadow: '0 18px 40px rgba(0,0,0,0.55)',
        width: 320,
        pt: '4px',
        pb: '6px',
        zIndex: 1302,
      }}
      role="menu"
    >
      <Typography
        sx={{
          fontFamily: '"Poppins", sans-serif',
          fontSize: '10px',
          letterSpacing: '0.08em',
          textTransform: 'uppercase',
          color: '#5d6a85',
          px: '14px',
          pt: '10px',
          pb: '6px',
        }}
      >
        Recent Projects
      </Typography>

      {recentProjects.length === 0 && (
        <Box sx={{ px: '14px', py: '8px', fontSize: '13px', color: '#5d6a85' }}>
          No recent projects
        </Box>
      )}

      {recentProjects.map((project) => (
        <Box
          key={project.filePath}
          onClick={() => project.exists && handleOpen(project.filePath)}
          sx={{
            display: 'flex',
            alignItems: 'center',
            gap: '10px',
            px: '10px',
            py: '8px',
            mx: '4px',
            borderRadius: '5px',
            cursor: project.exists ? 'pointer' : 'not-allowed',
            opacity: project.exists ? 1 : 0.5,
            '&:hover': project.exists
              ? { bgcolor: 'rgba(59,130,246,0.14)', '& .recent-name': { color: '#fff' } }
              : {},
          }}
        >
          <Box
            sx={{
              width: 18,
              display: 'inline-flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: '#5d6a85',
              flexShrink: 0,
            }}
          >
            <MenuIcon name="folder" size={15} />
          </Box>
          <Box sx={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column' }}>
            <Box
              className="recent-name"
              sx={{
                fontSize: '13px',
                color: 'text.primary',
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
              }}
            >
              {project.projectName}
            </Box>
            <Box
              sx={{
                fontFamily: '"JetBrains Mono", monospace',
                fontSize: '10px',
                color: '#5d6a85',
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
              }}
            >
              {project.filePath}
            </Box>
          </Box>
          <Box sx={{ flexShrink: 0, fontSize: '10px', color: '#5d6a85' }}>
            <RelativeTimestamp timestamp={project.lastModifiedAt} inline variant="caption" />
          </Box>
        </Box>
      ))}

      {recentProjects.length > 0 && (
        <>
          <Box sx={{ height: '1px', bgcolor: '#233048', mx: '8px', my: '4px' }} />
          <Box
            onClick={handleClear}
            sx={{
              display: 'flex',
              alignItems: 'center',
              gap: '10px',
              px: '10px',
              py: '8px',
              mx: '4px',
              borderRadius: '5px',
              fontSize: '13px',
              color: '#fb7185',
              cursor: 'pointer',
              '&:hover': { bgcolor: 'rgba(239,68,68,0.16)', color: '#fda4af' },
            }}
          >
            Clear Recents
          </Box>
        </>
      )}
    </Box>
  )
}

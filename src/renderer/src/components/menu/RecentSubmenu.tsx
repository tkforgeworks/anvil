import { Box, Typography } from '@mui/material'
import type { Theme } from '@mui/material/styles'
import { projectApi } from '../../../api/project.api'
import { useProjectStore } from '../../stores/project.store'
import { useUiStore } from '../../stores/ui.store'
import { RelativeTimestamp } from '../RelativeTimestamp'
import MenuDivider from './MenuDivider'
import MenuIcon from './MenuIcon'
import { menuHighlight, menuMutedColor, menuRowColor, menuSurfaceSx } from './menu-theme'

interface RecentSubmenuProps {
  focusedIndex?: number | null
  rowRef?: (index: number) => (el: HTMLElement | null) => void
}

export default function RecentSubmenu({ focusedIndex, rowRef }: RecentSubmenuProps): React.JSX.Element {
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
        ...menuSurfaceSx,
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
          color: menuMutedColor,
          px: '14px',
          pt: '10px',
          pb: '6px',
        }}
      >
        Recent Projects
      </Typography>

      {recentProjects.length === 0 && (
        <Box sx={{ px: '14px', py: '8px', fontSize: '13px', color: menuMutedColor }}>
          No recent projects
        </Box>
      )}

      {recentProjects.map((project, i) => (
        <Box
          key={project.filePath}
          ref={rowRef?.(i)}
          role="menuitem"
          tabIndex={focusedIndex === i ? 0 : -1}
          aria-disabled={!project.exists || undefined}
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
            outline: 'none',
            bgcolor: (theme) => (focusedIndex === i ? menuHighlight(theme) : 'transparent'),
            '&:hover': project.exists
              ? { bgcolor: (theme: Theme) => menuHighlight(theme) }
              : {},
          }}
        >
          <Box
            sx={{
              width: 18,
              display: 'inline-flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: menuMutedColor,
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
                color: menuMutedColor,
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
              }}
            >
              {project.filePath}
            </Box>
          </Box>
          <Box sx={{ flexShrink: 0, fontSize: '10px', color: menuMutedColor }}>
            <RelativeTimestamp timestamp={project.lastModifiedAt} inline variant="caption" />
          </Box>
        </Box>
      ))}

      {recentProjects.length > 0 && (
        <>
          <MenuDivider />
          <Box
            ref={rowRef?.(recentProjects.length)}
            role="menuitem"
            tabIndex={focusedIndex === recentProjects.length ? 0 : -1}
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
              color: (theme) => menuRowColor(theme, true),
              cursor: 'pointer',
              outline: 'none',
              bgcolor: (theme) =>
                focusedIndex === recentProjects.length ? menuHighlight(theme, true) : 'transparent',
              '&:hover': { bgcolor: (theme: Theme) => menuHighlight(theme, true) },
            }}
          >
            Clear Recents
          </Box>
        </>
      )}
    </Box>
  )
}

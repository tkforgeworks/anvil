import { Box } from '@mui/material'
import { alpha } from '@mui/material/styles'
import { menuMutedColor } from './menu-theme'

interface KbdPillProps {
  shortcut: string
}

export default function KbdPill({ shortcut }: KbdPillProps): React.JSX.Element {
  return (
    <Box
      component="span"
      sx={{
        fontFamily: 'var(--font-mono, "JetBrains Mono", monospace)',
        fontSize: '10px',
        color: menuMutedColor,
        bgcolor: (theme) => alpha(theme.palette.text.primary, 0.04),
        border: '1px solid',
        borderColor: 'divider',
        px: '6px',
        py: '1px',
        borderRadius: '3px',
        whiteSpace: 'nowrap',
        lineHeight: 1.4,
      }}
    >
      {shortcut}
    </Box>
  )
}

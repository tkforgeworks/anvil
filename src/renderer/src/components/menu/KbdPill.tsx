import { Box } from '@mui/material'

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
        color: '#5d6a85',
        bgcolor: 'rgba(255,255,255,0.04)',
        border: '1px solid #233048',
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

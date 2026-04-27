import { Box, useTheme } from '@mui/material'

interface ProjectInitialsMarkProps {
  name: string
  size?: number
}

function getInitials(name: string): string {
  const words = name.trim().split(/\s+/)
  if (words.length >= 2) {
    return (words[0][0] + words[1][0]).toUpperCase()
  }
  return (words[0]?.[0] ?? '?').toUpperCase()
}

export function ProjectInitialsMark({ name, size = 34 }: ProjectInitialsMarkProps) {
  const theme = useTheme()
  const fontSize = Math.round(size * 0.38)

  return (
    <Box
      sx={{
        width: size,
        height: size,
        minWidth: size,
        borderRadius: 1,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        backgroundColor: theme.palette.primary.main,
        color: '#ffffff',
        fontFamily: "'Poppins', sans-serif",
        fontWeight: 700,
        fontSize,
        lineHeight: 1,
        userSelect: 'none',
      }}
    >
      {getInitials(name)}
    </Box>
  )
}

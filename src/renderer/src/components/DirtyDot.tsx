import { Box } from '@mui/material'

interface DirtyDotProps {
  visible: boolean
}

export default function DirtyDot({ visible }: DirtyDotProps): React.JSX.Element | null {
  if (!visible) return null
  return (
    <Box
      component="span"
      sx={{
        display: 'inline-block',
        width: 7,
        height: 7,
        borderRadius: '50%',
        bgcolor: 'warning.main',
        ml: 0.75,
        verticalAlign: 'middle',
      }}
    />
  )
}

import { Box } from '@mui/material'

export default function MenuDivider(): React.JSX.Element {
  return (
    <Box
      sx={{
        height: '1px',
        bgcolor: '#233048',
        mx: '8px',
        my: '4px',
      }}
    />
  )
}

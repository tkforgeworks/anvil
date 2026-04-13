import { AppBar, Toolbar, Typography, Chip } from '@mui/material'

export default function TitleBar(): React.JSX.Element {
  return (
    <AppBar position="static" elevation={0} sx={{ zIndex: (theme) => theme.zIndex.drawer + 1 }}>
      <Toolbar variant="dense">
        <Typography variant="h6" component="div" sx={{ fontWeight: 700, letterSpacing: 2 }}>
          ANVIL
        </Typography>
        <Chip
          label="No Project Open"
          size="small"
          variant="outlined"
          sx={{ ml: 2, fontSize: '0.7rem', opacity: 0.7 }}
        />
      </Toolbar>
    </AppBar>
  )
}

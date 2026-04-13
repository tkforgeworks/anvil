import { createTheme } from '@mui/material/styles'

export const darkTheme = createTheme({
  palette: {
    mode: 'dark',
    primary: {
      main: '#7c8cff',
    },
    background: {
      default: '#1a1a2e',
      paper: '#16213e',
    },
  },
  components: {
    MuiCssBaseline: {
      styleOverrides: {
        body: {
          scrollbarColor: '#6b6b6b #1a1a2e',
        },
      },
    },
  },
})

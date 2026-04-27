import { createTheme } from '@mui/material/styles'

export const darkTheme = createTheme({
  palette: {
    mode: 'dark',
    primary: {
      main: '#3b82f6',
      dark: '#2563eb',
    },
    secondary: {
      main: '#60a5fa',
    },
    background: {
      default: '#0f172a',
      paper: '#1e293b',
    },
  },
  typography: {
    fontFamily: "'Poppins', sans-serif",
    fontFamilyMono: "'JetBrains Mono', monospace",
  },
  components: {
    MuiCssBaseline: {
      styleOverrides: {
        body: {
          scrollbarColor: '#6b6b6b #0f172a',
        },
      },
    },
  },
})

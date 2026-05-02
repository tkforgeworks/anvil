import { createTheme } from '@mui/material/styles'

export const lightTheme = createTheme({
  palette: {
    mode: 'light',
    primary: {
      main: '#2563eb',
      dark: '#1d4ed8',
    },
    secondary: {
      main: '#3b82f6',
    },
    background: {
      default: '#f8fafc',
      paper: '#ffffff',
    },
  },
  typography: {
    fontFamily: "'Poppins', sans-serif",
    fontFamilyMono: "'JetBrains Mono', monospace",
  },
  components: {
    MuiTableCell: {
      styleOverrides: {
        root: {
          'tbody tr:last-of-type &': {
            borderBottom: 0,
          },
        },
      },
    },
  },
})

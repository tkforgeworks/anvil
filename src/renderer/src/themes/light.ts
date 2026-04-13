import { createTheme } from '@mui/material/styles'

export const lightTheme = createTheme({
  palette: {
    mode: 'light',
    primary: {
      main: '#5c6bc0',
    },
    background: {
      default: '#f5f5f5',
      paper: '#ffffff',
    },
  },
})

import { createTheme } from '@mui/material/styles'
import type { CustomThemeColors } from '../../../shared/settings-types'

export function buildCustomTheme(colors: CustomThemeColors): ReturnType<typeof createTheme> {
  const mode = colors.mode ?? 'dark'
  return createTheme({
    palette: {
      mode,
      ...(colors.primary ? { primary: { main: colors.primary } } : {}),
      ...(colors.secondary ? { secondary: { main: colors.secondary } } : {}),
      ...(colors.backgroundDefault || colors.backgroundPaper
        ? {
            background: {
              ...(colors.backgroundDefault ? { default: colors.backgroundDefault } : {}),
              ...(colors.backgroundPaper ? { paper: colors.backgroundPaper } : {}),
            },
          }
        : {}),
      ...(colors.textPrimary || colors.textSecondary
        ? {
            text: {
              ...(colors.textPrimary ? { primary: colors.textPrimary } : {}),
              ...(colors.textSecondary ? { secondary: colors.textSecondary } : {}),
            },
          }
        : {}),
      ...(colors.error ? { error: { main: colors.error } } : {}),
      ...(colors.warning ? { warning: { main: colors.warning } } : {}),
      ...(colors.info ? { info: { main: colors.info } } : {}),
      ...(colors.success ? { success: { main: colors.success } } : {}),
      ...(colors.divider ? { divider: colors.divider } : {}),
    },
    typography: {
      fontFamily: "'Poppins', sans-serif",
      fontFamilyMono: "'JetBrains Mono', monospace",
    },
    components:
      mode === 'dark'
        ? {
            MuiCssBaseline: {
              styleOverrides: {
                body: {
                  scrollbarColor: `#6b6b6b ${colors.backgroundDefault ?? '#0f172a'}`,
                },
              },
            },
          }
        : {},
  })
}

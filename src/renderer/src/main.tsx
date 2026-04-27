import './assets/fonts/fonts.css'
import React, { useEffect, useMemo, useState } from 'react'
import ReactDOM from 'react-dom/client'
import { HashRouter } from 'react-router-dom'
import { ThemeProvider, CssBaseline } from '@mui/material'
import { darkTheme } from './themes/dark'
import { lightTheme } from './themes/light'
import { buildCustomTheme } from './themes/custom'
import { useUiStore } from './stores/ui.store'
import { useSettingsStore } from './stores/settings.store'
import type { CustomThemeColors } from '../../shared/settings-types'
import App from './App'

function Root(): React.JSX.Element {
  const themeSetting = useUiStore((s) => s.theme)
  const appSettings = useSettingsStore((s) => s.appSettings)
  const hydrate = useSettingsStore((s) => s.hydrate)
  const [booted, setBooted] = useState(false)

  useEffect(() => {
    void hydrate().finally(() => setBooted(true))
  }, [hydrate])

  const resolvedTheme = useMemo(() => {
    if (themeSetting === 'custom' && appSettings?.customThemeColors) {
      return buildCustomTheme(appSettings.customThemeColors as CustomThemeColors)
    }
    return themeSetting === 'light' ? lightTheme : darkTheme
  }, [themeSetting, appSettings?.customThemeColors])

  if (!booted) return <></>

  return (
    <ThemeProvider theme={resolvedTheme}>
      <CssBaseline />
      <HashRouter>
        <App />
      </HashRouter>
    </ThemeProvider>
  )
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <Root />
  </React.StrictMode>,
)

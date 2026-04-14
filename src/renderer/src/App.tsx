import { Routes, Route } from 'react-router-dom'
import { Box, CircularProgress } from '@mui/material'
import { useEffect, useState } from 'react'
import AppShell from './components/AppShell'
import DashboardPage from './pages/DashboardPage'
import ClassesPage from './pages/ClassesPage'
import ClassEditorPage from './pages/ClassEditorPage'
import AbilitiesPage from './pages/AbilitiesPage'
import AbilityEditorPage from './pages/AbilityEditorPage'
import ItemsPage from './pages/ItemsPage'
import RecipesPage from './pages/RecipesPage'
import NpcsPage from './pages/NpcsPage'
import LootTablesPage from './pages/LootTablesPage'
import ValidationPage from './pages/ValidationPage'
import RecycleBinPage from './pages/RecycleBinPage'
import ExportPage from './pages/ExportPage'
import SettingsPage from './pages/SettingsPage'
import WelcomePage from './pages/WelcomePage'
import { projectApi } from '../api/project.api'
import { useProjectStore } from './stores/project.store'

export default function App(): React.JSX.Element {
  const activeProject = useProjectStore((state) => state.activeProject)
  const hydrate = useProjectStore((state) => state.hydrate)
  const [isLoading, setLoading] = useState(true)

  useEffect(() => {
    let isMounted = true

    projectApi
      .getState()
      .then((snapshot) => {
        if (isMounted) hydrate(snapshot)
      })
      .finally(() => {
        if (isMounted) setLoading(false)
      })

    return () => {
      isMounted = false
    }
  }, [hydrate])

  if (isLoading) {
    return (
      <Box sx={{ minHeight: '100vh', display: 'grid', placeItems: 'center' }}>
        <CircularProgress aria-label="Loading project state" />
      </Box>
    )
  }

  if (!activeProject) {
    return <WelcomePage />
  }

  return (
    <Routes>
      <Route path="/" element={<AppShell />}>
        <Route index element={<DashboardPage />} />
        <Route path="classes" element={<ClassesPage />} />
        <Route path="classes/:id" element={<ClassEditorPage />} />
        <Route path="abilities" element={<AbilitiesPage />} />
        <Route path="abilities/:id" element={<AbilityEditorPage />} />
        <Route path="items" element={<ItemsPage />} />
        <Route path="recipes" element={<RecipesPage />} />
        <Route path="npcs" element={<NpcsPage />} />
        <Route path="loot-tables" element={<LootTablesPage />} />
        <Route path="validation" element={<ValidationPage />} />
        <Route path="recycle-bin" element={<RecycleBinPage />} />
        <Route path="export" element={<ExportPage />} />
        <Route path="settings" element={<SettingsPage />} />
      </Route>
    </Routes>
  )
}

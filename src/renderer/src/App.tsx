import { Routes, Route } from 'react-router-dom'
import AppShell from './components/AppShell'
import DashboardPage from './pages/DashboardPage'
import ClassesPage from './pages/ClassesPage'
import AbilitiesPage from './pages/AbilitiesPage'
import ItemsPage from './pages/ItemsPage'
import RecipesPage from './pages/RecipesPage'
import NpcsPage from './pages/NpcsPage'
import LootTablesPage from './pages/LootTablesPage'
import ValidationPage from './pages/ValidationPage'
import RecycleBinPage from './pages/RecycleBinPage'
import ExportPage from './pages/ExportPage'
import SettingsPage from './pages/SettingsPage'

export default function App(): React.JSX.Element {
  return (
    <Routes>
      <Route path="/" element={<AppShell />}>
        <Route index element={<DashboardPage />} />
        <Route path="classes" element={<ClassesPage />} />
        <Route path="abilities" element={<AbilitiesPage />} />
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

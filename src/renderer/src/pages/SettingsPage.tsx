import { Box, Divider, Tab, Tabs, Typography } from '@mui/material'
import { useState } from 'react'
import ApplicationSettingsPanel from '../components/ApplicationSettingsPanel'
import ProjectSettingsTab from '../components/ProjectSettingsTab'
import { useProjectStore } from '../stores/project.store'

// ─── Tab panel ────────────────────────────────────────────────────────────────

interface TabPanelProps {
  index: number
  value: number
  children: React.ReactNode
}

function TabPanel({ index, value, children }: TabPanelProps): React.JSX.Element {
  return (
    <Box role="tabpanel" hidden={value !== index} sx={{ pt: 3 }}>
      {value === index && children}
    </Box>
  )
}

// ─── Settings page ────────────────────────────────────────────────────────────

export default function SettingsPage(): React.JSX.Element {
  const activeProject = useProjectStore((state) => state.activeProject)
  const [activeTab, setActiveTab] = useState(0)

  if (!activeProject) {
    return (
      <Box sx={{ p: 4 }}>
        <Typography color="text.secondary">Open a project to manage settings.</Typography>
      </Box>
    )
  }

  return (
    <Box sx={{ maxWidth: 1100, mx: 'auto' }}>
      <Typography variant="h4" sx={{ mb: 0.5 }}>
        Settings
      </Typography>

      <Tabs value={activeTab} onChange={(_, v: number) => setActiveTab(v)} sx={{ mb: 0 }}>
        <Tab label="Application" />
        <Tab label="Project" />
      </Tabs>
      <Divider />

      <TabPanel index={0} value={activeTab}>
        <ApplicationSettingsPanel />
      </TabPanel>

      <TabPanel index={1} value={activeTab}>
        <ProjectSettingsTab />
      </TabPanel>
    </Box>
  )
}

import { SaveAs as SaveAsIcon } from '@mui/icons-material'
import CloseIcon from '@mui/icons-material/CloseRounded'
import {
  Box,
  Button,
  Dialog,
  DialogContent,
  DialogTitle,
  Divider,
  FormControl,
  FormControlLabel,
  IconButton,
  Radio,
  RadioGroup,
  Stack,
  Tab,
  Tabs,
  TextField,
  Typography,
} from '@mui/material'
import { useEffect, useState } from 'react'
import { metaApi } from '../../../api/meta.api'
import { projectApi } from '../../../api/project.api'
import type {
  DerivedStatDefinition,
  MetaCraftingSpecialization,
  MetaCraftingStation,
  MetaItemCategory,
  MetaNpcType,
  MetaRarity,
  MetaStat,
  ProjectSettings,
} from '../../../../shared/domain-types'
import { MODAL_IDS } from '../../menu/constants'
import { useProjectStore } from '../../stores/project.store'
import { useUiStore } from '../../stores/ui.store'
import MetaListSection from '../MetaListSection'
import { CustomFieldsSection, DerivedStatSection, RaritySection } from '../ProjectSettingsTab'

const TAB_INDEX: Record<string, number> = { 'custom-fields': 3 }

export default function ProjectSettingsModal(): React.JSX.Element | null {
  const activeModalId = useUiStore((s) => s.activeModalId)
  const modalOptions = useUiStore((s) => s.modalOptions)
  const closeModal = useUiStore((s) => s.closeModal)

  const activeProject = useProjectStore((s) => s.activeProject)
  const isRecoveryMode = useProjectStore((s) => s.isRecoveryMode)
  const hydrate = useProjectStore((s) => s.hydrate)
  const setSaveStatus = useProjectStore((s) => s.setSaveStatus)
  const setSaveError = useProjectStore((s) => s.setSaveError)

  const [tab, setTab] = useState(0)
  const [projectSettings, setProjectSettings] = useState<ProjectSettings | null>(null)
  const [gameTitleStr, setGameTitleStr] = useState('')
  const [maxLevelStr, setMaxLevelStr] = useState('100')
  const [stats, setStats] = useState<MetaStat[]>([])
  const [rarities, setRarities] = useState<MetaRarity[]>([])
  const [craftingStations, setCraftingStations] = useState<MetaCraftingStation[]>([])
  const [craftingSpecializations, setCraftingSpecializations] = useState<MetaCraftingSpecialization[]>([])
  const [derivedStats, setDerivedStats] = useState<DerivedStatDefinition[]>([])
  const [itemCategories, setItemCategories] = useState<MetaItemCategory[]>([])
  const [npcTypes, setNpcTypes] = useState<MetaNpcType[]>([])

  const open = activeModalId === MODAL_IDS.PROJECT_SETTINGS

  useEffect(() => {
    if (!open || !activeProject) return
    const initialTab = modalOptions?.initialTab
    if (initialTab && initialTab in TAB_INDEX) setTab(TAB_INDEX[initialTab])
    else setTab(0)

    void Promise.all([
      metaApi.getProjectSettings(),
      metaApi.listStats(),
      metaApi.listRarities(),
      metaApi.listCraftingStations(),
      metaApi.listCraftingSpecializations(),
      metaApi.listDerivedStats(),
      metaApi.listItemCategories(),
      metaApi.listNpcTypes(),
    ]).then(([settings, s, r, cs, csp, ds, cats, types]) => {
      setProjectSettings(settings)
      setGameTitleStr(settings.gameTitle)
      setMaxLevelStr(String(settings.maxLevel))
      setStats(s)
      setRarities(r)
      setCraftingStations(cs)
      setCraftingSpecializations(csp)
      setDerivedStats(ds)
      setItemCategories(cats)
      setNpcTypes(types)
    })
  }, [open, activeProject, modalOptions])

  if (!open || !activeProject) return null

  const refreshStats = (): void => { void metaApi.listStats().then(setStats) }
  const refreshRarities = (): void => { void metaApi.listRarities().then(setRarities) }
  const refreshCraftingStations = (): void => { void metaApi.listCraftingStations().then(setCraftingStations) }
  const refreshCraftingSpecializations = (): void => { void metaApi.listCraftingSpecializations().then(setCraftingSpecializations) }
  const refreshNpcTypes = (): void => { void metaApi.listNpcTypes().then(setNpcTypes) }
  const refreshDerivedStats = (): void => { void metaApi.listDerivedStats().then(setDerivedStats) }

  const saveProjectAs = async (): Promise<void> => {
    if (isRecoveryMode) return
    setSaveStatus('saving')
    setSaveError(null)
    try {
      const snapshot = await projectApi.saveAs()
      hydrate(snapshot)
    } catch (cause) {
      setSaveError(cause instanceof Error ? cause.message : 'Unable to save project copy.')
    }
  }

  const handleGameTitleBlur = (): void => {
    const trimmed = gameTitleStr.trim()
    if (!trimmed) { setGameTitleStr(projectSettings!.gameTitle); return }
    if (trimmed === projectSettings!.gameTitle) return
    void metaApi.setProjectSettings({ gameTitle: trimmed }).then((updated) => {
      setProjectSettings(updated)
      setGameTitleStr(updated.gameTitle)
      void projectApi.getState().then(hydrate)
    })
  }

  const handleMaxLevelBlur = (): void => {
    const value = Math.max(1, parseInt(maxLevelStr, 10) || 100)
    setMaxLevelStr(String(value))
    void metaApi.setProjectSettings({ maxLevel: value }).then(setProjectSettings)
  }

  const handleSeverityChange = (value: string): void => {
    void metaApi
      .setProjectSettings({ softDeleteReferenceSeverity: value as 'Warning' | 'Error' })
      .then(setProjectSettings)
  }

  return (
    <Dialog open onClose={closeModal} maxWidth="lg" fullWidth>
      <DialogTitle sx={{ display: 'flex', alignItems: 'center', pb: 0 }}>
        <Typography variant="h6" sx={{ flex: 1, fontWeight: 600 }}>
          Project Settings
        </Typography>
        <IconButton size="small" onClick={closeModal}>
          <CloseIcon fontSize="small" />
        </IconButton>
      </DialogTitle>

      <Tabs value={tab} onChange={(_, v) => setTab(v)} sx={{ px: 3, borderBottom: 1, borderColor: 'divider' }}>
        <Tab label="General" />
        <Tab label="Stats & Formulas" />
        <Tab label="Crafting" />
        <Tab label="Custom Fields" />
      </Tabs>

      <DialogContent sx={{ pt: 3, minHeight: 400 }}>
        {!projectSettings ? (
          <Typography color="text.secondary">Loading project settings...</Typography>
        ) : tab === 0 ? (
          <Stack spacing={3} sx={{ maxWidth: 700 }}>
            <Box>
              <Typography variant="subtitle2" gutterBottom>Project File</Typography>
              <Typography
                variant="body2"
                color="text.secondary"
                sx={{ fontFamily: '"JetBrains Mono", monospace', fontSize: '0.8rem', mb: 1 }}
              >
                {activeProject?.projectFolder?.root ?? activeProject?.filePath ?? '—'}
              </Typography>
              <Button
                variant="outlined"
                size="small"
                startIcon={<SaveAsIcon />}
                onClick={() => void saveProjectAs()}
                disabled={isRecoveryMode}
              >
                Save As
              </Button>
            </Box>

            <Divider />

            <Box>
              <Typography variant="subtitle2" gutterBottom>Game Title</Typography>
              <TextField
                size="small"
                value={gameTitleStr}
                onChange={(e) => setGameTitleStr(e.target.value)}
                onBlur={handleGameTitleBlur}
                onKeyDown={(e) => { if (e.key === 'Enter') (e.target as HTMLInputElement).blur() }}
                sx={{ width: 360 }}
              />
            </Box>

            <Box>
              <Typography variant="subtitle2" gutterBottom>Max Level</Typography>
              <TextField
                type="number"
                size="small"
                value={maxLevelStr}
                onChange={(e) => setMaxLevelStr(e.target.value)}
                onBlur={handleMaxLevelBlur}
                onKeyDown={(e) => { if (e.key === 'Enter') (e.target as HTMLInputElement).blur() }}
                inputProps={{ min: 1, step: 1 }}
                sx={{ width: 100 }}
              />
            </Box>

            <Box>
              <Typography variant="subtitle2" gutterBottom>Soft-Delete Reference Severity</Typography>
              <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 1.5 }}>
                Controls how the validation engine treats references to soft-deleted (archived) records.
              </Typography>
              <FormControl>
                <RadioGroup
                  value={projectSettings.softDeleteReferenceSeverity}
                  onChange={(e) => handleSeverityChange(e.target.value)}
                >
                  <FormControlLabel value="Warning" control={<Radio size="small" />} label="Warning" />
                  <Typography variant="caption" color="text.secondary" sx={{ pl: 3.75, mt: -0.5, mb: 0.5 }}>
                    Flag references to archived records, but allow export.
                  </Typography>
                  <FormControlLabel value="Error" control={<Radio size="small" />} label="Error" />
                  <Typography variant="caption" color="text.secondary" sx={{ pl: 3.75, mt: -0.5 }}>
                    Block export when references to archived records exist.
                  </Typography>
                </RadioGroup>
              </FormControl>
            </Box>

            <Divider />

            <MetaListSection
              title="NPC Types"
              singularName="NPC Type"
              description="Types used to categorize NPCs. Each NPC type can have its own custom fields."
              items={npcTypes}
              onAdd={metaApi.addNpcType}
              onUpdate={metaApi.updateNpcType}
              onDelete={metaApi.deleteNpcType}
              onReorder={metaApi.reorderNpcTypes}
              onRefresh={refreshNpcTypes}
            />

            <Divider />

            <RaritySection rarities={rarities} onRefresh={refreshRarities} />
          </Stack>
        ) : tab === 1 ? (
          <Stack spacing={4} sx={{ maxWidth: 700 }}>
            <MetaListSection
              title="Primary Stats"
              singularName="Stat"
              description="Stats used in class growth curves and derived stat formulas."
              items={stats}
              onAdd={metaApi.addStat}
              onUpdate={metaApi.updateStat}
              onDelete={metaApi.deleteStat}
              onReorder={metaApi.reorderStats}
              onRefresh={refreshStats}
            />

            <Divider />

            <DerivedStatSection derivedStats={derivedStats} onRefresh={refreshDerivedStats} />
          </Stack>
        ) : tab === 2 ? (
          <Stack spacing={4} sx={{ maxWidth: 700 }}>
            <MetaListSection
              title="Crafting Stations"
              singularName="Crafting Station"
              description="Stations that recipes can require."
              items={craftingStations}
              onAdd={metaApi.addCraftingStation}
              onUpdate={metaApi.updateCraftingStation}
              onDelete={metaApi.deleteCraftingStation}
              onReorder={metaApi.reorderCraftingStations}
              onRefresh={refreshCraftingStations}
            />

            <Divider />

            <MetaListSection
              title="Crafting Specializations"
              singularName="Crafting Specialization"
              description="Specializations that recipes can require."
              items={craftingSpecializations}
              onAdd={metaApi.addCraftingSpecialization}
              onUpdate={metaApi.updateCraftingSpecialization}
              onDelete={metaApi.deleteCraftingSpecialization}
              onReorder={metaApi.reorderCraftingSpecializations}
              onRefresh={refreshCraftingSpecializations}
            />
          </Stack>
        ) : (
          <CustomFieldsSection itemCategories={itemCategories} npcTypes={npcTypes} />
        )}
      </DialogContent>
    </Dialog>
  )
}

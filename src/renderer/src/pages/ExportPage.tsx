import {
  Add as AddIcon,
  Delete as DeleteIcon,
  Edit as EditIcon,
  ExpandMore as ExpandMoreIcon,
  FileDownload as ExportIcon,
  Preview as PreviewIcon,
} from '@mui/icons-material'
import {
  Accordion,
  AccordionDetails,
  AccordionSummary,
  Alert,
  Box,
  Button,
  Checkbox,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControl,
  IconButton,
  InputLabel,
  List,
  ListItem,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  MenuItem,
  Paper,
  Select,
  Stack,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material'
import { useCallback, useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { classesApi } from '../../api/classes.api'
import { abilitiesApi } from '../../api/abilities.api'
import { itemsApi } from '../../api/items.api'
import { recipesApi } from '../../api/recipes.api'
import { npcsApi } from '../../api/npcs.api'
import { lootTablesApi } from '../../api/loot-tables.api'
import {
  exportApi,
  type ExportPresetInfo,
  type ExportScope,
  type CustomTemplate,
} from '../../api/export.api'
import PageHeader from '../components/PageHeader'

const DOMAIN_OPTIONS = [
  { value: 'classes', label: 'Classes' },
  { value: 'abilities', label: 'Abilities' },
  { value: 'items', label: 'Items' },
  { value: 'recipes', label: 'Recipes' },
  { value: 'npcs', label: 'NPCs' },
  { value: 'loot-tables', label: 'Loot Tables' },
]

interface DomainRecord {
  id: string
  displayName: string
}

const DOMAIN_LIST_FETCHERS: Record<string, () => Promise<DomainRecord[]>> = {
  classes: () => classesApi.list(),
  abilities: () => abilitiesApi.list(),
  items: () => itemsApi.list(),
  recipes: () => recipesApi.list(),
  npcs: () => npcsApi.list(),
  'loot-tables': () => lootTablesApi.list(),
}

type ScopeMode = 'full' | 'domain' | 'selection'

export default function ExportPage(): React.JSX.Element {
  const navigate = useNavigate()
  const [presets, setPresets] = useState<ExportPresetInfo[]>([])
  const [selectedPreset, setSelectedPreset] = useState('')
  const [scopeMode, setScopeMode] = useState<ScopeMode>('full')
  const [scopeDomain, setScopeDomain] = useState('')
  const [domainRecords, setDomainRecords] = useState<DomainRecord[]>([])
  const [selectedRecordIds, setSelectedRecordIds] = useState<Set<string>>(new Set())
  const [preview, setPreview] = useState<string | null>(null)
  const [isLoading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState<string | null>(null)
  const [validationBlocked, setValidationBlocked] = useState(false)

  const [templateDialogOpen, setTemplateDialogOpen] = useState(false)
  const [editingTemplate, setEditingTemplate] = useState<CustomTemplate | null>(null)
  const [templateName, setTemplateName] = useState('')
  const [templateDescription, setTemplateDescription] = useState('')
  const [templateSource, setTemplateSource] = useState('')
  const [templateFormat, setTemplateFormat] = useState('text')

  const loadPresets = useCallback(async () => {
    const list = await exportApi.getPresets()
    setPresets(list)
    if (list.length > 0 && !list.find((p) => p.id === selectedPreset)) {
      setSelectedPreset(list[0].id)
    }
  }, [selectedPreset])

  useEffect(() => {
    void loadPresets()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(() => {
    if ((scopeMode === 'domain' || scopeMode === 'selection') && scopeDomain) {
      const fetcher = DOMAIN_LIST_FETCHERS[scopeDomain]
      if (fetcher) {
        void fetcher().then((records) => {
          setDomainRecords(records)
          setSelectedRecordIds(new Set())
        })
      }
    } else {
      setDomainRecords([])
      setSelectedRecordIds(new Set())
    }
  }, [scopeMode, scopeDomain])

  const buildScope = useCallback((): ExportScope => {
    if (scopeMode === 'selection' && scopeDomain && selectedRecordIds.size > 0) {
      return { mode: 'selection', domain: scopeDomain, recordIds: [...selectedRecordIds] }
    }
    if ((scopeMode === 'domain' || scopeMode === 'selection') && scopeDomain) {
      return { mode: 'domain', domain: scopeDomain }
    }
    return { mode: 'full' }
  }, [scopeMode, scopeDomain, selectedRecordIds])

  const handlePreview = async (): Promise<void> => {
    if (!selectedPreset) return
    setLoading(true)
    setError(null)
    setSuccess(null)
    setPreview(null)
    setValidationBlocked(false)
    try {
      const result = await exportApi.preview(selectedPreset, buildScope())
      if (result.error) {
        if (result.error.startsWith('Export blocked:')) setValidationBlocked(true)
        setError(result.error)
      } else {
        setPreview(result.output)
      }
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Preview failed.')
    } finally {
      setLoading(false)
    }
  }

  const handleExport = async (): Promise<void> => {
    if (!selectedPreset) return
    setLoading(true)
    setError(null)
    setSuccess(null)
    setValidationBlocked(false)
    try {
      const result = await exportApi.execute(selectedPreset, buildScope())
      if (result.error) {
        if (result.error.startsWith('Export blocked:')) setValidationBlocked(true)
        setError(result.error)
      } else if (result.success) {
        setSuccess(`Exported to ${result.path}`)
      }
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Export failed.')
    } finally {
      setLoading(false)
    }
  }

  const openNewTemplate = (): void => {
    setEditingTemplate(null)
    setTemplateName('')
    setTemplateDescription('')
    setTemplateSource('')
    setTemplateFormat('text')
    setTemplateDialogOpen(true)
  }

  const openEditTemplate = async (presetId: string): Promise<void> => {
    const templates = await exportApi.listCustomTemplates()
    const t = templates.find((tpl) => tpl.id === presetId)
    if (!t) return
    setEditingTemplate(t)
    setTemplateName(t.name)
    setTemplateDescription(t.description)
    setTemplateSource(t.template_source)
    setTemplateFormat(t.format)
    setTemplateDialogOpen(true)
  }

  const handleSaveTemplate = async (): Promise<void> => {
    if (!templateName.trim()) return
    if (editingTemplate) {
      await exportApi.updateTemplate(editingTemplate.id, {
        name: templateName.trim(),
        description: templateDescription.trim(),
        template_source: templateSource,
        format: templateFormat,
      })
    } else {
      const created = await exportApi.createTemplate({
        name: templateName.trim(),
        description: templateDescription.trim(),
        template_source: templateSource,
        format: templateFormat,
      })
      setSelectedPreset(created.id)
    }
    setTemplateDialogOpen(false)
    await loadPresets()
  }

  const handleDeleteTemplate = async (presetId: string): Promise<void> => {
    await exportApi.deleteTemplate(presetId)
    if (selectedPreset === presetId) {
      setSelectedPreset(presets[0]?.id ?? '')
    }
    await loadPresets()
  }

  const toggleRecord = (id: string): void => {
    setSelectedRecordIds((prev) => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
    setPreview(null)
  }

  const toggleAll = (): void => {
    if (selectedRecordIds.size === domainRecords.length) {
      setSelectedRecordIds(new Set())
    } else {
      setSelectedRecordIds(new Set(domainRecords.map((r) => r.id)))
    }
    setPreview(null)
  }

  const currentPreset = presets.find((p) => p.id === selectedPreset)
  const canPreview = selectedPreset && (scopeMode === 'full' || scopeDomain)

  return (
    <Box>
      <PageHeader
        title="Export"
        action={
          <Button
            variant="outlined"
            startIcon={<AddIcon />}
            onClick={openNewTemplate}
            size="small"
            data-tid="export-new-template"
          >
            New Template
          </Button>
        }
      />

      {error && (
        <Alert
          severity="error"
          sx={{ mb: 2 }}
          onClose={() => { setError(null); setValidationBlocked(false) }}
        >
          {error}
          {validationBlocked && (
            <Button
              size="small"
              sx={{ ml: 2 }}
              onClick={() => navigate('/validation')}
            >
              Open Validation Panel
            </Button>
          )}
        </Alert>
      )}

      {success && (
        <Alert severity="success" sx={{ mb: 2 }} onClose={() => setSuccess(null)}>
          {success}
        </Alert>
      )}

      <Paper variant="outlined" sx={{ borderRadius: 2.5, p: 3 }}>
        <Stack spacing={3} sx={{ maxWidth: 600 }}>
          <FormControl fullWidth>
            <InputLabel id="export-preset-label">Template / Preset</InputLabel>
            <Select
              labelId="export-preset-label"
              label="Template / Preset"
              value={selectedPreset}
              onChange={(e) => { setSelectedPreset(e.target.value); setPreview(null) }}
              data-tid="export-template-select"
            >
              {presets.map((preset) => (
                <MenuItem key={preset.id} value={preset.id}>
                  <Stack direction="row" alignItems="center" spacing={1} sx={{ width: '100%' }}>
                    <span>{preset.name}</span>
                    {preset.builtIn && (
                      <Chip label="Built-in" size="small" variant="outlined" sx={{ ml: 'auto' }} />
                    )}
                  </Stack>
                </MenuItem>
              ))}
            </Select>
          </FormControl>

          {currentPreset && (
            <Stack direction="row" alignItems="center" spacing={1}>
              <Typography variant="body2" color="text.secondary" sx={{ flex: 1 }}>
                {currentPreset.description}
              </Typography>
              {!currentPreset.builtIn && (
                <>
                  <Tooltip title="Edit template">
                    <IconButton size="small" onClick={() => void openEditTemplate(currentPreset.id)}>
                      <EditIcon fontSize="small" />
                    </IconButton>
                  </Tooltip>
                  <Tooltip title="Delete template">
                    <IconButton size="small" onClick={() => void handleDeleteTemplate(currentPreset.id)}>
                      <DeleteIcon fontSize="small" />
                    </IconButton>
                  </Tooltip>
                </>
              )}
            </Stack>
          )}

          <FormControl fullWidth>
            <InputLabel id="export-scope-label">Scope</InputLabel>
            <Select
              labelId="export-scope-label"
              label="Scope"
              value={scopeMode}
              onChange={(e) => { setScopeMode(e.target.value as ScopeMode); setPreview(null) }}
              data-tid="export-scope-select"
            >
              <MenuItem value="full">Full Project</MenuItem>
              <MenuItem value="domain">Single Domain</MenuItem>
              <MenuItem value="selection">Record Selection</MenuItem>
            </Select>
          </FormControl>

          {(scopeMode === 'domain' || scopeMode === 'selection') && (
            <FormControl fullWidth>
              <InputLabel id="export-domain-label">Domain</InputLabel>
              <Select
                labelId="export-domain-label"
                label="Domain"
                value={scopeDomain}
                onChange={(e) => { setScopeDomain(e.target.value); setPreview(null) }}
              >
                {DOMAIN_OPTIONS.map((opt) => (
                  <MenuItem key={opt.value} value={opt.value}>
                    {opt.label}
                  </MenuItem>
                ))}
              </Select>
            </FormControl>
          )}

          {scopeMode === 'selection' && scopeDomain && domainRecords.length > 0 && (
            <Box sx={{ border: 1, borderColor: 'divider', borderRadius: 1, maxHeight: 300, overflow: 'auto' }}>
              <List dense disablePadding>
                <ListItem disablePadding>
                  <ListItemButton onClick={toggleAll} dense>
                    <ListItemIcon sx={{ minWidth: 36 }}>
                      <Checkbox
                        edge="start"
                        checked={selectedRecordIds.size === domainRecords.length}
                        indeterminate={selectedRecordIds.size > 0 && selectedRecordIds.size < domainRecords.length}
                        tabIndex={-1}
                        disableRipple
                      />
                    </ListItemIcon>
                    <ListItemText
                      primary={`Select All (${selectedRecordIds.size}/${domainRecords.length})`}
                      primaryTypographyProps={{ fontWeight: 600, variant: 'body2' }}
                    />
                  </ListItemButton>
                </ListItem>
                {domainRecords.map((record) => (
                  <ListItem key={record.id} disablePadding>
                    <ListItemButton onClick={() => toggleRecord(record.id)} dense>
                      <ListItemIcon sx={{ minWidth: 36 }}>
                        <Checkbox
                          edge="start"
                          checked={selectedRecordIds.has(record.id)}
                          tabIndex={-1}
                          disableRipple
                        />
                      </ListItemIcon>
                      <ListItemText primary={record.displayName} />
                    </ListItemButton>
                  </ListItem>
                ))}
              </List>
            </Box>
          )}

          {scopeMode === 'selection' && scopeDomain && domainRecords.length === 0 && (
            <Typography variant="body2" color="text.secondary">
              No records found in this domain.
            </Typography>
          )}

          <Stack direction="row" spacing={2}>
            <Button
              variant="outlined"
              startIcon={<PreviewIcon />}
              onClick={() => void handlePreview()}
              disabled={isLoading || !canPreview}
              data-tid="export-preview"
            >
              {isLoading ? 'Loading...' : 'Preview'}
            </Button>
            <Button
              variant="contained"
              startIcon={<ExportIcon />}
              onClick={() => void handleExport()}
              disabled={isLoading || !canPreview}
              data-tid="export-execute"
            >
              Export to File
            </Button>
          </Stack>
        </Stack>
      </Paper>

      {preview != null && (
        <Box sx={{ mt: 3 }}>
          <Typography variant="subtitle1" sx={{ mb: 1, fontWeight: 600 }}>
            Preview
          </Typography>
          <Paper variant="outlined" sx={{ borderRadius: 2.5, overflow: 'hidden' }}>
            <Box
              sx={{
                bgcolor: 'grey.900',
                color: 'grey.100',
                p: 2,
                fontFamily: 'monospace',
                fontSize: '0.8rem',
                whiteSpace: 'pre',
                overflow: 'auto',
                maxHeight: 600,
              }}
            >
              {preview}
            </Box>
          </Paper>
        </Box>
      )}

      <Dialog
        open={templateDialogOpen}
        onClose={() => setTemplateDialogOpen(false)}
        maxWidth="md"
        fullWidth
      >
        <DialogTitle>
          {editingTemplate ? 'Edit Template' : 'New Custom Template'}
        </DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ mt: 1 }}>
            <TextField
              label="Name"
              value={templateName}
              onChange={(e) => setTemplateName(e.target.value)}
              fullWidth
              autoFocus
            />
            <TextField
              label="Description"
              value={templateDescription}
              onChange={(e) => setTemplateDescription(e.target.value)}
              fullWidth
            />
            <FormControl fullWidth>
              <InputLabel id="template-format-label">Format</InputLabel>
              <Select
                labelId="template-format-label"
                label="Format"
                value={templateFormat}
                onChange={(e) => setTemplateFormat(e.target.value)}
              >
                <MenuItem value="text">Text</MenuItem>
                <MenuItem value="json">JSON</MenuItem>
                <MenuItem value="csv">CSV</MenuItem>
              </Select>
            </FormControl>
            <Box>
              <Typography variant="body2" sx={{ mb: 1, fontWeight: 600 }}>
                Template Source (Nunjucks)
              </Typography>

              <Accordion
                disableGutters
                sx={{ mb: 1.5, bgcolor: 'transparent', boxShadow: 'none', '&:before': { display: 'none' } }}
              >
                <AccordionSummary
                  expandIcon={<ExpandMoreIcon />}
                  sx={{ px: 0, minHeight: 'unset', '& .MuiAccordionSummary-content': { my: 0.5 } }}
                >
                  <Typography variant="caption" color="primary">
                    Template writing guide
                  </Typography>
                </AccordionSummary>
                <AccordionDetails sx={{ px: 0, pt: 0 }}>
                  <Stack spacing={1.5}>
                    <Box>
                      <Typography variant="caption" sx={{ fontWeight: 600, display: 'block', mb: 0.5 }}>
                        Context Variables
                      </Typography>
                      <Typography variant="caption" color="text.secondary" component="div">
                        Your template receives these top-level variables:
                      </Typography>
                      <Box component="ul" sx={{ m: 0, pl: 2.5, '& li': { fontSize: '0.75rem', color: 'text.secondary' } }}>
                        <li><code>project</code> — name, game_title, schema_version, max_level</li>
                        <li><code>meta</code> — stats, rarities, item_categories, npc_types, crafting_stations, crafting_specializations, derived_stats</li>
                        <li><code>classes</code> — array of class records (with stat_growth, abilities, derived_stat_overrides, metadata)</li>
                        <li><code>abilities</code> — array of ability records (with stat_modifiers)</li>
                        <li><code>items</code> — array of item records (with custom_fields)</li>
                        <li><code>recipes</code> — array of recipe records (with ingredients)</li>
                        <li><code>npcs</code> — array of NPC records (with class_assignments, ability_assignments, combat_stats, custom_fields)</li>
                        <li><code>loot_tables</code> — array of loot table records (with entries)</li>
                      </Box>
                    </Box>

                    <Box>
                      <Typography variant="caption" sx={{ fontWeight: 600, display: 'block', mb: 0.5 }}>
                        Each record has
                      </Typography>
                      <Box component="ul" sx={{ m: 0, pl: 2.5, '& li': { fontSize: '0.75rem', color: 'text.secondary' } }}>
                        <li><code>id</code> — internal UUID (for FK references)</li>
                        <li><code>export_key</code> — user-defined key for external use</li>
                        <li><code>display_name</code> — human-readable name</li>
                        <li><code>description</code></li>
                      </Box>
                    </Box>

                    <Box>
                      <Typography variant="caption" sx={{ fontWeight: 600, display: 'block', mb: 0.5 }}>
                        Filters
                      </Typography>
                      <Box component="ul" sx={{ m: 0, pl: 2.5, '& li': { fontSize: '0.75rem', color: 'text.secondary' } }}>
                        <li><code>{'{{ value | json }}'}</code> — output as formatted JSON (optional indent: <code>{'{{ value | json(4) }}'}</code>)</li>
                        <li><code>{'{{ some_id | export_key }}'}</code> — resolve an internal ID to its export key</li>
                      </Box>
                    </Box>

                    <Box>
                      <Typography variant="caption" sx={{ fontWeight: 600, display: 'block', mb: 0.5 }}>
                        Syntax Basics
                      </Typography>
                      <Box component="ul" sx={{ m: 0, pl: 2.5, '& li': { fontSize: '0.75rem', color: 'text.secondary' } }}>
                        <li><code>{'{{ variable }}'}</code> — output a value</li>
                        <li><code>{'{% for item in items %}...{% endfor %}'}</code> — loop over an array</li>
                        <li><code>{'{% if condition %}...{% endif %}'}</code> — conditional</li>
                        <li><code>{'{% set x = value %}'}</code> — assign a variable</li>
                      </Box>
                    </Box>

                    <Box>
                      <Typography variant="caption" sx={{ fontWeight: 600, display: 'block', mb: 0.5 }}>
                        Example
                      </Typography>
                      <Box
                        sx={{
                          bgcolor: 'grey.900',
                          color: 'grey.300',
                          p: 1.5,
                          borderRadius: 1,
                          fontFamily: 'monospace',
                          fontSize: '0.75rem',
                          whiteSpace: 'pre',
                          overflow: 'auto',
                        }}
                      >
{`# {{ project.game_title }} - Items

{% for item in items %}
## {{ item.display_name }} ({{ item.export_key }})
Category: {{ item.item_category_id | export_key }}
Rarity: {{ item.rarity_id | export_key }}
{{ item.description }}

{% endfor %}`}
                      </Box>
                    </Box>
                  </Stack>
                </AccordionDetails>
              </Accordion>

              <Box
                component="textarea"
                value={templateSource}
                onChange={(e: React.ChangeEvent<HTMLTextAreaElement>) => setTemplateSource(e.target.value)}
                spellCheck={false}
                sx={{
                  width: '100%',
                  minHeight: 300,
                  fontFamily: 'monospace',
                  fontSize: '0.85rem',
                  p: 1.5,
                  bgcolor: 'grey.900',
                  color: 'grey.100',
                  border: 1,
                  borderColor: 'divider',
                  borderRadius: 1,
                  resize: 'vertical',
                  outline: 'none',
                  '&:focus': {
                    borderColor: 'primary.main',
                  },
                }}
              />
            </Box>
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setTemplateDialogOpen(false)} data-tid="dialog-template-cancel">Cancel</Button>
          <Button
            variant="contained"
            onClick={() => void handleSaveTemplate()}
            disabled={!templateName.trim()}
            data-tid="dialog-template-confirm"
          >
            {editingTemplate ? 'Save Changes' : 'Create Template'}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  )
}

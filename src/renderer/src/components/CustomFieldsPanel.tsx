import {
  Alert,
  Box,
  Button,
  Checkbox,
  FormControl,
  FormControlLabel,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  TextField,
  Typography,
} from '@mui/material'
import { useCallback, useEffect, useState } from 'react'
import { customFieldsApi } from '../../api/custom-fields.api'
import type {
  CustomFieldDefinition,
  CustomFieldScope,
  CustomFieldValue,
} from '../../../shared/domain-types'

interface CustomFieldsPanelProps {
  domain: 'items' | 'npcs'
  recordId: string
  scopeType: CustomFieldScope
  scopeId: string
}

/**
 * Renders the custom field value editor for a single record.
 *
 * Loads field definitions for the given scope and current values for the record,
 * then renders appropriate inputs per field type. Persists values on Save.
 *
 * This component is domain-agnostic: pass the correct domain/scope and it works
 * for items or NPCs. Full integration into domain editors is handled in ANV-10 / ANV-13.
 */
export default function CustomFieldsPanel({
  domain,
  recordId,
  scopeType,
  scopeId,
}: CustomFieldsPanelProps): React.JSX.Element {
  const [definitions, setDefinitions] = useState<CustomFieldDefinition[]>([])
  const [values, setValues] = useState<Record<string, string>>({})
  const [isLoading, setLoading] = useState(true)
  const [isSaving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [savedAt, setSavedAt] = useState<Date | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [defs, vals] = await Promise.all([
        customFieldsApi.listDefinitions(scopeType, scopeId),
        customFieldsApi.getValues(domain, recordId),
      ])
      setDefinitions(defs)
      // Build a fieldDefinitionId → value map; seed with defaults for any missing field
      const valueMap: Record<string, string> = {}
      for (const def of defs) {
        valueMap[def.id] = def.defaultValue ?? ''
      }
      for (const v of vals) {
        valueMap[v.fieldDefinitionId] = v.value ?? ''
      }
      setValues(valueMap)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to load custom fields.')
    } finally {
      setLoading(false)
    }
  }, [domain, recordId, scopeType, scopeId])

  useEffect(() => {
    void load()
  }, [load])

  const setValue = (fieldId: string, value: string): void => {
    setValues((prev) => ({ ...prev, [fieldId]: value }))
    setSavedAt(null)
  }

  const handleSave = async (): Promise<void> => {
    setSaving(true)
    setError(null)
    try {
      const fieldValues: CustomFieldValue[] = Object.entries(values).map(
        ([fieldDefinitionId, value]) => ({
          fieldDefinitionId,
          value: value || null,
        }),
      )
      await customFieldsApi.setValues(domain, recordId, fieldValues)
      setSavedAt(new Date())
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to save custom fields.')
    } finally {
      setSaving(false)
    }
  }

  if (isLoading) {
    return (
      <Typography variant="body2" color="text.secondary">
        Loading custom fields…
      </Typography>
    )
  }

  if (definitions.length === 0) {
    return (
      <Typography variant="body2" color="text.secondary">
        No custom fields defined for this{' '}
        {scopeType === 'item_category' ? 'item category' : 'NPC type'}.
      </Typography>
    )
  }

  return (
    <Box>
      <Typography variant="subtitle2" gutterBottom>
        Custom Fields
      </Typography>

      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      <Stack spacing={2} sx={{ mb: 2 }}>
        {definitions.map((def) => {
          const currentValue = values[def.id] ?? ''
          const isRequiredAndEmpty = def.isRequired && !currentValue

          switch (def.fieldType) {
            case 'boolean':
              return (
                <FormControlLabel
                  key={def.id}
                  control={
                    <Checkbox
                      checked={currentValue === 'true'}
                      onChange={(e) => setValue(def.id, e.target.checked ? 'true' : 'false')}
                    />
                  }
                  label={
                    <Stack direction="row" spacing={0.5} alignItems="center">
                      <span>{def.fieldName}</span>
                      {def.isRequired && (
                        <Typography component="span" color="error" variant="caption">
                          *
                        </Typography>
                      )}
                    </Stack>
                  }
                />
              )

            case 'enum':
              return (
                <FormControl key={def.id} fullWidth error={isRequiredAndEmpty}>
                  <InputLabel id={`cf-${def.id}-label`}>
                    {def.fieldName}
                    {def.isRequired ? ' *' : ''}
                  </InputLabel>
                  <Select
                    labelId={`cf-${def.id}-label`}
                    label={`${def.fieldName}${def.isRequired ? ' *' : ''}`}
                    value={currentValue}
                    onChange={(e) => setValue(def.id, e.target.value)}
                  >
                    <MenuItem value="">
                      <em>None</em>
                    </MenuItem>
                    {def.enumOptions.map((opt) => (
                      <MenuItem key={opt} value={opt}>
                        {opt}
                      </MenuItem>
                    ))}
                  </Select>
                  {isRequiredAndEmpty && (
                    <Typography variant="caption" color="error" sx={{ mt: 0.5 }}>
                      This field is required.
                    </Typography>
                  )}
                </FormControl>
              )

            case 'integer':
            case 'decimal':
              return (
                <TextField
                  key={def.id}
                  label={def.fieldName}
                  value={currentValue}
                  onChange={(e) => setValue(def.id, e.target.value)}
                  type="number"
                  inputProps={def.fieldType === 'integer' ? { step: 1 } : { step: 'any' }}
                  required={def.isRequired}
                  error={isRequiredAndEmpty}
                  helperText={isRequiredAndEmpty ? 'This field is required.' : undefined}
                  fullWidth
                />
              )

            case 'text':
            default:
              return (
                <TextField
                  key={def.id}
                  label={def.fieldName}
                  value={currentValue}
                  onChange={(e) => setValue(def.id, e.target.value)}
                  required={def.isRequired}
                  error={isRequiredAndEmpty}
                  helperText={isRequiredAndEmpty ? 'This field is required.' : undefined}
                  fullWidth
                />
              )
          }
        })}
      </Stack>

      <Stack direction="row" spacing={2} alignItems="center">
        <Button
          variant="contained"
          size="small"
          onClick={() => void handleSave()}
          disabled={isSaving}
        >
          Save Custom Fields
        </Button>
        {savedAt && (
          <Typography variant="caption" color="success.main">
            Saved at {savedAt.toLocaleTimeString()}
          </Typography>
        )}
      </Stack>
    </Box>
  )
}

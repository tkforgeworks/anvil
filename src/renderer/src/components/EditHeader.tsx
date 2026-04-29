import {
  ArrowBack as ArrowBackIcon,
  Redo as RedoIcon,
  Save as SaveIcon,
  Undo as UndoIcon,
} from '@mui/icons-material'
import { Box, Button, IconButton, Paper, Stack, TextField, Tooltip, Typography } from '@mui/material'
import { RelativeTimestamp } from './RelativeTimestamp'

export interface EditHeaderProps {
  backLabel: string
  onBack: () => void
  displayName: string
  onDisplayNameChange: (value: string) => void
  exportKey: string
  isDirty: boolean
  isSaving: boolean
  onSave: () => void
  savedAt: Date | null
  canUndo: boolean
  canRedo: boolean
  onUndo: () => void
  onRedo: () => void
}

export default function EditHeader({
  backLabel,
  onBack,
  displayName,
  onDisplayNameChange,
  exportKey,
  isDirty,
  isSaving,
  onSave,
  savedAt,
  canUndo,
  canRedo,
  onUndo,
  onRedo,
}: EditHeaderProps): React.JSX.Element {
  return (
    <Paper
      variant="outlined"
      sx={{
        position: 'sticky',
        top: 0,
        zIndex: 10,
        p: 2,
        mb: 2,
        borderColor: isDirty ? 'warning.main' : 'divider',
      }}
    >
      {/* Row 1: Back navigation */}
      <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1 }}>
        <Tooltip title={`Back to ${backLabel}`}>
          <IconButton size="small" onClick={onBack}>
            <ArrowBackIcon fontSize="small" />
          </IconButton>
        </Tooltip>
        <Typography variant="caption" color="text.secondary">
          {backLabel}
        </Typography>
      </Stack>

      {/* Row 2: Display name + undo/redo + save */}
      <Stack direction="row" alignItems="center" spacing={2}>
        <TextField
          variant="standard"
          value={displayName}
          onChange={(e) => onDisplayNameChange(e.target.value)}
          inputProps={{ style: { fontSize: '1.5rem', fontWeight: 600 } }}
          placeholder="Name"
          sx={{ flex: 1 }}
        />
        <Tooltip title="Undo (Ctrl+Z)">
          <span>
            <IconButton size="small" onClick={onUndo} disabled={!canUndo}>
              <UndoIcon fontSize="small" />
            </IconButton>
          </span>
        </Tooltip>
        <Tooltip title="Redo (Ctrl+Y)">
          <span>
            <IconButton size="small" onClick={onRedo} disabled={!canRedo}>
              <RedoIcon fontSize="small" />
            </IconButton>
          </span>
        </Tooltip>
        {savedAt && (
          <RelativeTimestamp
            timestamp={savedAt.toISOString()}
            variant="caption"
          />
        )}
        <Button
          variant="contained"
          startIcon={<SaveIcon />}
          onClick={onSave}
          disabled={!isDirty || isSaving}
        >
          Save
        </Button>
      </Stack>

      {/* Row 3: Export key (read-only) */}
      <Typography
        variant="caption"
        color="text.secondary"
        sx={{ mt: 1, display: 'block', fontFamily: '"JetBrains Mono", monospace', fontSize: '0.75rem' }}
      >
        key: {exportKey}
      </Typography>
    </Paper>
  )
}

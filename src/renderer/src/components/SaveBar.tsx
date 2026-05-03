import { WarningAmber as WarningAmberIcon } from '@mui/icons-material'
import { Box, Button, Paper, Stack, Typography } from '@mui/material'

export interface SaveBarProps {
  isDirty: boolean
  isSaving: boolean
  onSave: () => void
  onDiscard: () => void
}

export default function SaveBar({
  isDirty,
  isSaving,
  onSave,
  onDiscard,
}: SaveBarProps): React.JSX.Element | null {
  if (!isDirty) return null

  return (
    <Paper
      variant="outlined"
      sx={{
        position: 'sticky',
        bottom: 0,
        zIndex: 10,
        px: 3,
        py: 1.5,
        borderTop: 2,
        borderTopColor: 'warning.main',
      }}
    >
      <Stack direction="row" alignItems="center" spacing={2}>
        <WarningAmberIcon color="warning" />
        <Typography variant="body2">You have unsaved changes</Typography>
        <Box sx={{ flex: 1 }} />
        <Button variant="outlined" color="inherit" onClick={onDiscard} disabled={isSaving} data-tid="savebar-discard">
          Discard
        </Button>
        <Button variant="contained" onClick={onSave} disabled={isSaving} data-tid="savebar-save">
          Save
        </Button>
      </Stack>
    </Paper>
  )
}

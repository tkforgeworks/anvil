import { Chip, CircularProgress } from '@mui/material'
import type { ProjectSaveStatus } from '../../../shared/project-types'

interface StatusTagProps {
  status: ProjectSaveStatus
}

const STATUS_CONFIG: Record<ProjectSaveStatus, { label: string; color: 'success' | 'info' | 'warning' | 'error' }> = {
  saved: { label: 'saved', color: 'success' },
  saving: { label: 'saving…', color: 'info' },
  unsaved: { label: 'unsaved', color: 'warning' },
  error: { label: 'error', color: 'error' },
}

export function StatusTag({ status }: StatusTagProps) {
  const config = STATUS_CONFIG[status]

  return (
    <Chip
      label={config.label}
      color={config.color}
      size="small"
      variant="outlined"
      icon={status === 'saving' ? <CircularProgress size={12} color="inherit" /> : undefined}
      sx={{ transition: 'all 200ms ease' }}
    />
  )
}

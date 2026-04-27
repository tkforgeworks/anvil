import { Typography } from '@mui/material'

interface FileSizeDisplayProps {
  bytes: number
}

function formatFileSize(bytes: number): string {
  if (bytes === 0) return '0 B'
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(1)} GB`
}

export function FileSizeDisplay({ bytes }: FileSizeDisplayProps) {
  return (
    <Typography
      variant="caption"
      component="span"
      sx={{ fontFamily: (theme) => theme.typography.fontFamilyMono ?? 'monospace' }}
      color="text.secondary"
    >
      {formatFileSize(bytes)}
    </Typography>
  )
}

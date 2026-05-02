import { Box, Button, Typography } from '@mui/material'

export interface EmptyStateProps {
  icon?: React.ReactNode
  title: string
  body?: string
  ctaLabel?: string
  onCtaClick?: () => void
}

export default function EmptyState({
  icon,
  title,
  body,
  ctaLabel,
  onCtaClick,
}: EmptyStateProps): React.JSX.Element {
  return (
    <Box sx={{ textAlign: 'center', py: 8 }}>
      {icon && (
        <Box sx={{
          width: 96,
          height: 96,
          borderRadius: '18px',
          border: '1px dashed',
          borderColor: 'divider',
          bgcolor: 'background.paper',
          display: 'grid',
          placeItems: 'center',
          color: 'text.disabled',
          fontSize: 36,
          mx: 'auto',
          mb: 1,
        }}>
          {icon}
        </Box>
      )}
      <Typography variant="h6" color="text.secondary">
        {title}
      </Typography>
      {body && (
        <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
          {body}
        </Typography>
      )}
      {ctaLabel && onCtaClick && (
        <Button variant="contained" sx={{ mt: 3 }} onClick={onCtaClick}>
          {ctaLabel}
        </Button>
      )}
    </Box>
  )
}

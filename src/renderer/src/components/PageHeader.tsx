import { Stack, Typography } from '@mui/material'

interface PageHeaderProps {
  title: string
  subtitle?: string
  action?: React.ReactNode
}

export default function PageHeader({ title, subtitle, action }: PageHeaderProps): React.JSX.Element {
  return (
    <Stack direction="row" alignItems="center" justifyContent="space-between" sx={{ mb: 2.5 }}>
      <div>
        <Typography variant="h5" component="h1" sx={{ fontWeight: 600 }}>
          {title}
        </Typography>
        {subtitle && (
          <Typography variant="caption" color="text.secondary">
            {subtitle}
          </Typography>
        )}
      </div>
      {action}
    </Stack>
  )
}

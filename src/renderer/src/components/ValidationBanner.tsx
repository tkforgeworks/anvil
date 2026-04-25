import { Alert, AlertTitle, Stack, Typography } from '@mui/material'
import type { ValidationIssue } from '../../../shared/domain-types'

interface Props {
  issues: ValidationIssue[]
}

export default function ValidationBanner({ issues }: Props): React.JSX.Element | null {
  if (issues.length === 0) return null

  const errors = issues.filter((i) => i.severity === 'error')
  const warnings = issues.filter((i) => i.severity === 'warning')

  const parts: string[] = []
  if (errors.length > 0) parts.push(`${errors.length} ${errors.length === 1 ? 'error' : 'errors'}`)
  if (warnings.length > 0) parts.push(`${warnings.length} ${warnings.length === 1 ? 'warning' : 'warnings'}`)

  const severity = errors.length > 0 ? 'error' : 'warning'

  return (
    <Alert severity={severity} sx={{ mb: 2 }}>
      <AlertTitle>Validation: {parts.join(', ')}</AlertTitle>
      <Stack spacing={0.25}>
        {issues.map((issue) => (
          <Typography
            key={issue.id}
            variant="body2"
            color={issue.severity === 'error' ? 'error.main' : 'warning.main'}
          >
            {issue.field ? `${issue.field}: ` : ''}{issue.message}
          </Typography>
        ))}
      </Stack>
    </Alert>
  )
}

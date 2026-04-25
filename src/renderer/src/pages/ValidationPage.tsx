import {
  Error as ErrorIcon,
  CheckCircleOutline as CheckIcon,
  Refresh as RefreshIcon,
  Warning as WarningIcon,
} from '@mui/icons-material'
import {
  Box,
  Button,
  Chip,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Typography,
} from '@mui/material'
import { useCallback, useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { validationApi } from '../../api/validation.api'
import { useValidationStore } from '../stores/validation.store'
import type { ValidationDomain, ValidationIssue, ValidationSeverity } from '../../../shared/domain-types'

const SEVERITY_ORDER: Record<ValidationSeverity, number> = { error: 0, warning: 1, info: 2 }

const DOMAIN_ORDER: ValidationDomain[] = [
  'classes',
  'abilities',
  'items',
  'recipes',
  'npcs',
  'loot-tables',
  'derived-stats',
]

const DOMAIN_LABELS: Record<ValidationDomain, string> = {
  classes: 'Classes',
  abilities: 'Abilities',
  items: 'Items',
  recipes: 'Recipes',
  npcs: 'NPCs',
  'loot-tables': 'Loot Tables',
  'derived-stats': 'Derived Stats',
}

function domainRoute(issue: ValidationIssue): string | null {
  switch (issue.domain) {
    case 'classes':
      return `/classes/${issue.recordId}`
    case 'abilities':
      return `/abilities/${issue.recordId}`
    case 'items':
      return `/items/${issue.recordId}`
    case 'recipes':
      return `/recipes/${issue.recordId}`
    case 'npcs':
      return `/npcs/${issue.recordId}`
    case 'loot-tables':
      return `/loot-tables/${issue.recordId}`
    case 'derived-stats':
      return `/classes/${issue.recordId}`
    default:
      return null
  }
}

function severityIcon(severity: ValidationSeverity): React.JSX.Element {
  switch (severity) {
    case 'error':
      return <ErrorIcon fontSize="small" color="error" />
    case 'warning':
      return <WarningIcon fontSize="small" color="warning" />
    default:
      return <WarningIcon fontSize="small" color="info" />
  }
}

function groupByDomain(issues: ValidationIssue[]): Map<ValidationDomain, ValidationIssue[]> {
  const groups = new Map<ValidationDomain, ValidationIssue[]>()
  for (const domain of DOMAIN_ORDER) {
    const domainIssues = issues
      .filter((i) => i.domain === domain)
      .sort((a, b) => SEVERITY_ORDER[a.severity] - SEVERITY_ORDER[b.severity])
    if (domainIssues.length > 0) groups.set(domain, domainIssues)
  }
  return groups
}

function formatTimestamp(iso: string): string {
  return new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: 'medium',
  }).format(new Date(iso))
}

export default function ValidationPage(): React.JSX.Element {
  const navigate = useNavigate()
  const issues = useValidationStore((s) => s.issues)
  const lastValidatedAt = useValidationStore((s) => s.lastValidatedAt)
  const setGlobalIssues = useValidationStore((s) => s.setIssues)
  const [isRunning, setRunning] = useState(false)

  const runValidation = useCallback(async () => {
    setRunning(true)
    try {
      const result = await validationApi.run()
      setGlobalIssues(result)
    } finally {
      setRunning(false)
    }
  }, [setGlobalIssues])

  useEffect(() => {
    if (!lastValidatedAt) {
      void runValidation()
    }
  }, [lastValidatedAt, runValidation])

  const errorCount = issues.filter((i) => i.severity === 'error').length
  const warningCount = issues.filter((i) => i.severity === 'warning').length
  const grouped = groupByDomain(issues)

  return (
    <Stack spacing={3}>
      <Stack direction="row" alignItems="center" justifyContent="space-between">
        <Box>
          <Typography variant="h5" component="h1" sx={{ fontWeight: 700 }}>
            Validation
          </Typography>
          {lastValidatedAt && (
            <Typography variant="caption" color="text.secondary">
              Last checked: {formatTimestamp(lastValidatedAt)}
            </Typography>
          )}
        </Box>
        <Button
          variant="outlined"
          startIcon={<RefreshIcon />}
          onClick={() => void runValidation()}
          disabled={isRunning}
        >
          {isRunning ? 'Running...' : 'Re-run'}
        </Button>
      </Stack>

      {issues.length > 0 && (
        <Stack direction="row" spacing={2}>
          {errorCount > 0 && (
            <Chip
              icon={<ErrorIcon />}
              label={`${errorCount} ${errorCount === 1 ? 'error' : 'errors'}`}
              color="error"
              variant="outlined"
            />
          )}
          {warningCount > 0 && (
            <Chip
              icon={<WarningIcon />}
              label={`${warningCount} ${warningCount === 1 ? 'warning' : 'warnings'}`}
              color="warning"
              variant="outlined"
            />
          )}
        </Stack>
      )}

      {issues.length === 0 && lastValidatedAt && !isRunning && (
        <Box sx={{ textAlign: 'center', py: 6 }}>
          <CheckIcon sx={{ fontSize: 48, color: 'success.main', mb: 1 }} />
          <Typography variant="h6" color="text.secondary">
            No issues found
          </Typography>
          <Typography variant="body2" color="text.secondary">
            All records passed validation checks.
          </Typography>
        </Box>
      )}

      {[...grouped.entries()].map(([domain, domainIssues]) => (
        <Box key={domain}>
          <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 1 }}>
            {DOMAIN_LABELS[domain]}
          </Typography>
          <TableContainer>
            <Table size="small">
              <TableHead>
                <TableRow>
                  <TableCell width={40} />
                  <TableCell width={220}>Record</TableCell>
                  <TableCell width={160}>Field</TableCell>
                  <TableCell>Message</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {domainIssues.map((issue) => {
                  const route = domainRoute(issue)
                  return (
                    <TableRow
                      key={issue.id}
                      hover={route != null}
                      onClick={route ? () => navigate(route) : undefined}
                      sx={route ? { cursor: 'pointer' } : undefined}
                    >
                      <TableCell>{severityIcon(issue.severity)}</TableCell>
                      <TableCell>
                        <Typography variant="body2" sx={{ fontWeight: 500 }}>
                          {issue.recordDisplayName}
                        </Typography>
                      </TableCell>
                      <TableCell>
                        {issue.field && (
                          <Typography variant="body2" color="text.secondary" sx={{ fontFamily: 'monospace', fontSize: '0.8rem' }}>
                            {issue.field}
                          </Typography>
                        )}
                      </TableCell>
                      <TableCell>
                        <Typography variant="body2">{issue.message}</Typography>
                      </TableCell>
                    </TableRow>
                  )
                })}
              </TableBody>
            </Table>
          </TableContainer>
        </Box>
      ))}
    </Stack>
  )
}

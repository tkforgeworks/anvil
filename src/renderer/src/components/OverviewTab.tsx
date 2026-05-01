import { Box, CircularProgress, Stack, Typography } from '@mui/material'
import { useNavigate } from 'react-router-dom'
import type { UsedBySection } from './InspectorRail'

export interface OverviewTabProps {
  displayName: string
  description: string
  usedBySections?: UsedBySection[]
  usedByLoading?: boolean
}

export default function OverviewTab({
  displayName,
  description,
  usedBySections = [],
  usedByLoading = false,
}: OverviewTabProps): React.JSX.Element {
  const navigate = useNavigate()

  return (
    <Box sx={{ maxWidth: 680 }}>
      <Box sx={{ mb: 3 }}>
        <Typography
          variant="caption"
          sx={{ textTransform: 'uppercase', letterSpacing: '0.06em', color: 'text.disabled', fontWeight: 600 }}
        >
          Name
        </Typography>
        <Typography variant="h6">{displayName || '—'}</Typography>
      </Box>

      <Box sx={{ mb: 3 }}>
        <Typography
          variant="caption"
          sx={{ textTransform: 'uppercase', letterSpacing: '0.06em', color: 'text.disabled', fontWeight: 600 }}
        >
          Description
        </Typography>
        <Typography variant="body1" color="text.secondary" sx={{ mt: 0.5, whiteSpace: 'pre-wrap' }}>
          {description || 'No description provided.'}
        </Typography>
      </Box>

      {usedBySections.length > 0 && (
        <Box>
          <Typography
            variant="subtitle2"
            sx={{
              fontWeight: 700,
              textTransform: 'uppercase',
              letterSpacing: '0.08em',
              fontSize: '0.6875rem',
              mb: 1.5,
            }}
          >
            Used By
          </Typography>

          {usedByLoading ? (
            <Box sx={{ display: 'flex', justifyContent: 'center', py: 2 }}>
              <CircularProgress size={24} />
            </Box>
          ) : (
            <Stack spacing={2}>
              {usedBySections.map((section) => (
                <Box key={section.label}>
                  <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 0.5 }}>
                    <Typography variant="body2" sx={{ fontWeight: 600 }}>
                      {section.label}
                    </Typography>
                    <Typography
                      variant="body2"
                      sx={{
                        fontFamily: '"JetBrains Mono", monospace',
                        fontSize: '0.6875rem',
                        color: 'text.disabled',
                      }}
                    >
                      {section.items.length}
                    </Typography>
                  </Box>

                  {section.items.length === 0 ? (
                    <Typography
                      variant="body2"
                      color="text.disabled"
                      sx={{ fontStyle: 'italic', fontSize: '0.6875rem' }}
                    >
                      Not assigned to any {section.label.toLowerCase().replace(/s$/, '')}.
                    </Typography>
                  ) : (
                    <Stack spacing={0.5}>
                      {section.items.map((item) => (
                        <Box
                          key={item.id}
                          onClick={() => void navigate(item.route)}
                          sx={{
                            display: 'flex',
                            alignItems: 'center',
                            gap: 1,
                            px: 1,
                            py: 0.75,
                            borderRadius: 1,
                            cursor: 'pointer',
                            fontSize: '0.75rem',
                            color: 'text.primary',
                            '&:hover': { bgcolor: 'action.hover', color: 'primary.main' },
                          }}
                        >
                          <Typography color="text.disabled" sx={{ fontSize: 'inherit' }}>
                            &#x203A;
                          </Typography>
                          <Typography sx={{ flex: 1, fontSize: 'inherit' }}>
                            {item.displayName}
                          </Typography>
                          <Typography color="text.disabled" sx={{ fontSize: 'inherit' }}>
                            &rarr;
                          </Typography>
                        </Box>
                      ))}
                    </Stack>
                  )}
                </Box>
              ))}
            </Stack>
          )}
        </Box>
      )}
    </Box>
  )
}

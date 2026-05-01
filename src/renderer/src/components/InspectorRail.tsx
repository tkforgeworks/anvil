import {
  Box,
  CircularProgress,
  Paper,
  Stack,
  Typography,
} from '@mui/material'
import { useNavigate } from 'react-router-dom'

interface UsedByItem {
  id: string
  displayName: string
  route: string
}

export interface UsedBySection {
  label: string
  items: UsedByItem[]
}

export interface InspectorRailProps {
  sections: UsedBySection[]
  isLoading: boolean
  emptyMessage?: string
}

export default function InspectorRail({
  sections,
  isLoading,
  emptyMessage = 'Not referenced by any records',
}: InspectorRailProps): React.JSX.Element {
  const navigate = useNavigate()

  const isEmpty = !isLoading && sections.length === 0

  return (
    <Box sx={{ width: 260, flexShrink: 0, pl: 2 }}>
      <Paper variant="outlined" sx={{ position: 'sticky', top: 0, p: 2 }}>
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

        {isLoading && (
          <Box sx={{ display: 'flex', justifyContent: 'center', py: 2 }}>
            <CircularProgress size={24} />
          </Box>
        )}

        {isEmpty && (
          <Typography variant="body2" color="text.secondary">
            {emptyMessage}
          </Typography>
        )}

        {!isLoading && !isEmpty && (
          <Box>
            {sections.map((section, i) => (
              <Box
                key={section.label}
                sx={{
                  pb: 1.5,
                  mb: i < sections.length - 1 ? 1.5 : 0,
                  borderBottom: i < sections.length - 1 ? '1px dashed' : 'none',
                  borderColor: 'divider',
                }}
              >
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 1 }}>
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
          </Box>
        )}
      </Paper>
    </Box>
  )
}

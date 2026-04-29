import {
  Box,
  Chip,
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

  const totalItems = sections.reduce((sum, section) => sum + section.items.length, 0)
  const isEmpty = !isLoading && (sections.length === 0 || totalItems === 0)

  return (
    <Box sx={{ width: 260, flexShrink: 0, pl: 2 }}>
      <Paper variant="outlined" sx={{ position: 'sticky', top: 0, p: 2 }}>
        <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1.5 }}>
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
          <Stack spacing={1.5}>
            {sections.map((section) => (
              <Box key={section.label}>
                <Typography variant="caption" color="text.secondary">
                  {section.label} ({section.items.length})
                </Typography>
                <Stack direction="row" flexWrap="wrap" gap={0.5} sx={{ mt: 0.5 }}>
                  {section.items.map((item) => (
                    <Chip
                      key={item.id}
                      label={item.displayName}
                      variant="outlined"
                      size="small"
                      clickable
                      onClick={() => void navigate(item.route)}
                    />
                  ))}
                </Stack>
              </Box>
            ))}
          </Stack>
        )}
      </Paper>
    </Box>
  )
}

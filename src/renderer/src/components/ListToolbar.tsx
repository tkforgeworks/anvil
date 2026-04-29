import { Search as SearchIcon } from '@mui/icons-material'
import {
  Box,
  Button,
  InputAdornment,
  MenuItem,
  Stack,
  TextField,
  ToggleButton,
  ToggleButtonGroup,
} from '@mui/material'

export interface ListToolbarProps {
  search: string
  onSearchChange: (value: string) => void
  sortKey: string
  onSortChange: (value: string) => void
  sortOptions: Array<{ value: string; label: string }>
  viewMode: 'active' | 'archived'
  onViewModeChange: (mode: 'active' | 'archived') => void
  onNew: () => void
  newLabel: string
  filterSlot?: React.ReactNode
  hideNew?: boolean
}

export default function ListToolbar({
  search,
  onSearchChange,
  sortKey,
  onSortChange,
  sortOptions,
  viewMode,
  onViewModeChange,
  onNew,
  newLabel,
  filterSlot,
  hideNew,
}: ListToolbarProps): React.JSX.Element {
  return (
    <Stack direction="row" alignItems="center" spacing={1.5} flexWrap="wrap" mb={2}>
      <TextField
        size="small"
        placeholder="Search..."
        value={search}
        onChange={(e) => onSearchChange(e.target.value)}
        InputProps={{
          startAdornment: (
            <InputAdornment position="start">
              <SearchIcon fontSize="small" />
            </InputAdornment>
          ),
        }}
        sx={{ width: 220 }}
      />

      {filterSlot}

      <TextField
        select
        size="small"
        label="Sort by"
        value={sortKey}
        onChange={(e) => onSortChange(e.target.value)}
        sx={{ width: 160 }}
      >
        {sortOptions.map((opt) => (
          <MenuItem key={opt.value} value={opt.value}>
            {opt.label}
          </MenuItem>
        ))}
      </TextField>

      <Box sx={{ flex: 1 }} />

      <ToggleButtonGroup
        value={viewMode}
        exclusive
        onChange={(_e, v) => { if (v) onViewModeChange(v as 'active' | 'archived') }}
        size="small"
      >
        <ToggleButton value="active">Active</ToggleButton>
        <ToggleButton value="archived">Archived</ToggleButton>
      </ToggleButtonGroup>

      {viewMode !== 'archived' && !hideNew && (
        <Button variant="contained" size="small" onClick={onNew}>
          {newLabel}
        </Button>
      )}
    </Stack>
  )
}

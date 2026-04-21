import { Warning as WarningIcon } from '@mui/icons-material'
import {
  Alert,
  Autocomplete,
  Box,
  Chip,
  Paper,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material'
import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { lootTablesApi } from '../../api/loot-tables.api'
import type {
  ItemRecord,
  LootTableEntry,
  LootTableRecord,
} from '../../../shared/domain-types'

interface Props {
  value: string | null
  lootTables: LootTableRecord[]
  items: ItemRecord[]
  onChange: (next: string | null) => void
  disabled?: boolean
}

export default function LootTableAssignmentPanel({
  value,
  lootTables,
  items,
  onChange,
  disabled = false,
}: Props): React.JSX.Element {
  const navigate = useNavigate()
  const [entries, setEntries] = useState<LootTableEntry[]>([])
  const [loadingEntries, setLoadingEntries] = useState(false)
  const [entriesError, setEntriesError] = useState<string | null>(null)

  const lootTablesById = new Map(lootTables.map((lt) => [lt.id, lt]))
  const selected = value ? lootTablesById.get(value) ?? null : null
  const isSelectedDeleted = selected?.deletedAt != null

  // Picker only offers active loot tables, plus the currently-selected one (even if deleted)
  // so the user can still see/clear it.
  const pickerOptions = lootTables.filter(
    (lt) => lt.deletedAt == null || lt.id === value,
  )

  const itemsById = new Map(items.map((i) => [i.id, i]))

  useEffect(() => {
    if (!value) {
      setEntries([])
      setEntriesError(null)
      return
    }
    let cancelled = false
    setLoadingEntries(true)
    setEntriesError(null)
    lootTablesApi
      .getEntries(value)
      .then((result) => {
        if (!cancelled) setEntries(result)
      })
      .catch((cause) => {
        if (!cancelled) {
          setEntriesError(cause instanceof Error ? cause.message : 'Failed to load loot entries.')
        }
      })
      .finally(() => {
        if (!cancelled) setLoadingEntries(false)
      })
    return () => {
      cancelled = true
    }
  }, [value])

  const totalWeight = entries.reduce((sum, e) => sum + e.weight, 0)

  return (
    <Box>
      <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 2 }}>
        <Autocomplete
          options={pickerOptions}
          getOptionLabel={(option) => option.displayName}
          value={selected}
          onChange={(_e, next) => onChange(next?.id ?? null)}
          renderInput={(params) => (
            <TextField {...params} label="Loot Table" size="small" placeholder="None" />
          )}
          sx={{ flex: 1, maxWidth: 400 }}
          size="small"
          disabled={disabled}
          isOptionEqualToValue={(option, val) => option.id === val.id}
          noOptionsText={
            pickerOptions.length === 0 ? 'No loot tables exist yet' : 'No matching loot tables'
          }
        />
        {isSelectedDeleted && (
          <Tooltip title="This loot table has been soft-deleted">
            <Chip
              icon={<WarningIcon />}
              label="Deleted"
              size="small"
              color="warning"
              variant="outlined"
            />
          </Tooltip>
        )}
      </Stack>

      {isSelectedDeleted && (
        <Alert severity="warning" sx={{ mb: 2 }}>
          The assigned loot table has been soft-deleted. It is still referenced here but may be
          permanently removed later.
        </Alert>
      )}

      {selected && (
        <Box>
          <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1 }}>
            <Typography
              variant="body2"
              sx={{ cursor: 'pointer', '&:hover': { textDecoration: 'underline' } }}
              onClick={() => navigate(`/loot-tables/${selected.id}`)}
            >
              {selected.displayName}
            </Typography>
            <Typography variant="caption" color="text.secondary">
              ({entries.length} {entries.length === 1 ? 'entry' : 'entries'})
            </Typography>
          </Stack>

          {entriesError && (
            <Alert severity="error" sx={{ mb: 1 }} onClose={() => setEntriesError(null)}>
              {entriesError}
            </Alert>
          )}

          {loadingEntries ? (
            <Typography variant="body2" color="text.secondary">
              Loading entries…
            </Typography>
          ) : entries.length === 0 ? (
            <Paper variant="outlined" sx={{ p: 2, textAlign: 'center' }}>
              <Typography variant="body2" color="text.secondary">
                This loot table has no entries.
              </Typography>
            </Paper>
          ) : (
            <TableContainer component={Paper} variant="outlined">
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>Item</TableCell>
                    <TableCell align="right">Weight</TableCell>
                    <TableCell align="right">Chance</TableCell>
                    <TableCell align="right">Quantity</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {entries.map((entry) => {
                    const item = itemsById.get(entry.itemId)
                    const itemName = item?.displayName ?? `[Unknown: ${entry.itemId}]`
                    const itemDeleted = item?.deletedAt != null
                    const chance =
                      totalWeight > 0
                        ? `${((entry.weight / totalWeight) * 100).toFixed(1)}%`
                        : '—'
                    const qty =
                      entry.quantityMin === entry.quantityMax
                        ? String(entry.quantityMin)
                        : `${entry.quantityMin}–${entry.quantityMax}`
                    return (
                      <TableRow key={entry.id}>
                        <TableCell>
                          <Stack direction="row" spacing={1} alignItems="center">
                            <Typography
                              variant="body2"
                              sx={{ color: itemDeleted ? 'text.secondary' : 'text.primary' }}
                            >
                              {itemName}
                            </Typography>
                            {itemDeleted && (
                              <Chip label="Deleted" size="small" color="warning" variant="outlined" />
                            )}
                          </Stack>
                        </TableCell>
                        <TableCell align="right" sx={{ fontFamily: 'monospace' }}>
                          {entry.weight}
                        </TableCell>
                        <TableCell align="right" sx={{ fontFamily: 'monospace' }}>
                          {chance}
                        </TableCell>
                        <TableCell align="right" sx={{ fontFamily: 'monospace' }}>
                          {qty}
                        </TableCell>
                      </TableRow>
                    )
                  })}
                </TableBody>
              </Table>
            </TableContainer>
          )}
        </Box>
      )}
    </Box>
  )
}

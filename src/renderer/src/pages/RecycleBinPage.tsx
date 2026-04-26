import {
  DeleteForever as PermanentDeleteIcon,
  DeleteSweep as EmptyTrashIcon,
  RestoreFromTrash as RestoreIcon,
} from '@mui/icons-material'
import {
  Alert,
  Box,
  Button,
  Checkbox,
  IconButton,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  Tooltip,
  Typography,
} from '@mui/material'
import { useCallback, useEffect, useState } from 'react'
import type { BaseRecord, LifecycleDomain } from '../../../shared/domain-types'
import { classesApi } from '../../api/classes.api'
import { abilitiesApi } from '../../api/abilities.api'
import { itemsApi } from '../../api/items.api'
import { recipesApi } from '../../api/recipes.api'
import { npcsApi } from '../../api/npcs.api'
import { lootTablesApi } from '../../api/loot-tables.api'
import { lifecycleApi } from '../../api/lifecycle.api'
import { PermanentDeleteDialog } from '../components/ArchiveView'
import {
  BulkActionToolbar,
  BulkHardDeleteDialog,
  EmptyTrashDialog,
} from '../components/BulkActions'
import { useMultiSelect } from '../hooks/useMultiSelect'

interface DomainGroup {
  domain: LifecycleDomain
  label: string
  records: BaseRecord[]
}

const DOMAIN_FETCHERS: Array<{
  domain: LifecycleDomain
  label: string
  fetch: () => Promise<BaseRecord[]>
}> = [
  { domain: 'classes', label: 'Character Classes', fetch: () => classesApi.list(false, true) },
  { domain: 'abilities', label: 'Abilities', fetch: () => abilitiesApi.list(false, true) },
  { domain: 'items', label: 'Items', fetch: () => itemsApi.list(false, true) },
  { domain: 'recipes', label: 'Crafting Recipes', fetch: () => recipesApi.list(false, true) },
  { domain: 'npcs', label: 'NPCs', fetch: () => npcsApi.list(false, true) },
  { domain: 'loot-tables', label: 'Loot Tables', fetch: () => lootTablesApi.list(false, true) },
]

function formatDeletedAt(iso: string | null): string {
  if (!iso) return '—'
  try {
    return new Date(iso + 'Z').toLocaleString()
  } catch {
    return iso
  }
}

export default function RecycleBinPage(): React.JSX.Element {
  const [groups, setGroups] = useState<DomainGroup[]>([])
  const [error, setError] = useState<string | null>(null)
  const [deleteTarget, setDeleteTarget] = useState<BaseRecord | null>(null)
  const [deleteTargetDomain, setDeleteTargetDomain] = useState<LifecycleDomain>('classes')
  const [emptyTrashOpen, setEmptyTrashOpen] = useState(false)
  const [bulkHardDeleteOpen, setBulkHardDeleteOpen] = useState(false)
  const multiSelect = useMultiSelect()

  const totalCount = groups.reduce((sum, g) => sum + g.records.length, 0)
  const allRecordIds = groups.flatMap((g) => g.records.map((r) => r.id))

  const load = useCallback(async () => {
    setError(null)
    try {
      const results = await Promise.all(
        DOMAIN_FETCHERS.map(async (df) => ({
          domain: df.domain,
          label: df.label,
          records: await df.fetch(),
        })),
      )
      setGroups(results.filter((g) => g.records.length > 0))
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to load archived records.')
    }
  }, [])

  useEffect(() => { void load() }, [load])

  const findRecordDomain = (id: string): LifecycleDomain | null => {
    for (const g of groups) {
      if (g.records.some((r) => r.id === id)) return g.domain
    }
    return null
  }

  const handleRestore = async (domain: LifecycleDomain, id: string): Promise<void> => {
    setError(null)
    try {
      await lifecycleApi.bulkRestore(domain, [id])
      multiSelect.clear()
      await load()
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Restore failed.')
    }
  }

  const handleHardDelete = async (domain: LifecycleDomain, id: string): Promise<void> => {
    setError(null)
    try {
      await lifecycleApi.bulkHardDelete(domain, [id])
      setDeleteTarget(null)
      multiSelect.clear()
      await load()
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Delete failed.')
    }
  }

  const handleBulkRestore = async (): Promise<void> => {
    setError(null)
    try {
      const byDomain = groupSelectedByDomain()
      for (const [domain, ids] of byDomain) {
        await lifecycleApi.bulkRestore(domain, ids)
      }
      multiSelect.clear()
      await load()
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Bulk restore failed.')
    }
  }

  const handleBulkHardDelete = async (): Promise<void> => {
    setError(null)
    try {
      const byDomain = groupSelectedByDomain()
      for (const [domain, ids] of byDomain) {
        await lifecycleApi.bulkHardDelete(domain, ids)
      }
      setBulkHardDeleteOpen(false)
      multiSelect.clear()
      await load()
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Bulk delete failed.')
    }
  }

  const handleEmptyTrash = async (): Promise<void> => {
    setError(null)
    try {
      await lifecycleApi.emptyTrash()
      setEmptyTrashOpen(false)
      multiSelect.clear()
      await load()
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to empty trash.')
    }
  }

  const groupSelectedByDomain = (): Map<LifecycleDomain, string[]> => {
    const map = new Map<LifecycleDomain, string[]>()
    for (const id of multiSelect.selected) {
      const domain = findRecordDomain(id)
      if (!domain) continue
      const ids = map.get(domain) ?? []
      ids.push(id)
      map.set(domain, ids)
    }
    return map
  }

  return (
    <Box>
      <Stack direction="row" alignItems="center" justifyContent="space-between" sx={{ mb: 3 }}>
        <Typography variant="h5">Recycle Bin</Typography>
        {totalCount > 0 && (
          <Button
            color="error"
            variant="outlined"
            startIcon={<EmptyTrashIcon />}
            onClick={() => setEmptyTrashOpen(true)}
          >
            Empty Trash
          </Button>
        )}
      </Stack>

      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      <BulkActionToolbar
        count={multiSelect.count}
        mode="recycle-bin"
        onBulkRestore={() => void handleBulkRestore()}
        onBulkHardDelete={() => setBulkHardDeleteOpen(true)}
      />

      {totalCount === 0 ? (
        <Typography variant="body2" color="text.secondary">
          Trash is empty.
        </Typography>
      ) : (
        groups.map((group) => (
          <Box key={group.domain} sx={{ mb: 3 }}>
            <Typography variant="subtitle1" fontWeight={600} sx={{ mb: 1 }}>
              {group.label}
              <Typography component="span" variant="body2" color="text.secondary" sx={{ ml: 1 }}>
                ({group.records.length})
              </Typography>
            </Typography>
            <Table size="small">
              <TableHead>
                <TableRow>
                  <TableCell padding="checkbox">
                    <Checkbox
                      size="small"
                      checked={group.records.every((r) => multiSelect.isSelected(r.id))}
                      indeterminate={
                        group.records.some((r) => multiSelect.isSelected(r.id)) &&
                        !group.records.every((r) => multiSelect.isSelected(r.id))
                      }
                      onChange={() => multiSelect.toggleAll(group.records.map((r) => r.id))}
                    />
                  </TableCell>
                  <TableCell>Name</TableCell>
                  <TableCell>Export Key</TableCell>
                  <TableCell>Deleted At</TableCell>
                  <TableCell align="right">Actions</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {group.records.map((record) => (
                  <TableRow key={record.id}>
                    <TableCell padding="checkbox">
                      <Checkbox
                        size="small"
                        checked={multiSelect.isSelected(record.id)}
                        onChange={() => multiSelect.toggle(record.id)}
                      />
                    </TableCell>
                    <TableCell>
                      <Typography variant="body2" fontWeight={500} color="text.secondary">
                        {record.displayName}
                      </Typography>
                    </TableCell>
                    <TableCell>
                      <Typography variant="body2" color="text.secondary" fontFamily="monospace">
                        {record.exportKey}
                      </Typography>
                    </TableCell>
                    <TableCell>
                      <Typography variant="body2" color="text.secondary">
                        {formatDeletedAt(record.deletedAt)}
                      </Typography>
                    </TableCell>
                    <TableCell align="right">
                      <Stack direction="row" spacing={0.5} justifyContent="flex-end">
                        <Tooltip title="Restore">
                          <IconButton
                            size="small"
                            color="primary"
                            onClick={() => void handleRestore(group.domain, record.id)}
                          >
                            <RestoreIcon fontSize="small" />
                          </IconButton>
                        </Tooltip>
                        <Tooltip title="Permanently Delete">
                          <IconButton
                            size="small"
                            color="error"
                            onClick={() => { setDeleteTarget(record); setDeleteTargetDomain(group.domain) }}
                          >
                            <PermanentDeleteIcon fontSize="small" />
                          </IconButton>
                        </Tooltip>
                      </Stack>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </Box>
        ))
      )}

      <PermanentDeleteDialog
        record={deleteTarget}
        domainLabel="Record"
        onClose={() => setDeleteTarget(null)}
        onConfirm={(id) => void handleHardDelete(deleteTargetDomain, id)}
      />

      <BulkHardDeleteDialog
        open={bulkHardDeleteOpen}
        count={multiSelect.count}
        onClose={() => setBulkHardDeleteOpen(false)}
        onConfirm={() => void handleBulkHardDelete()}
      />

      <EmptyTrashDialog
        open={emptyTrashOpen}
        totalCount={totalCount}
        onClose={() => setEmptyTrashOpen(false)}
        onConfirm={() => void handleEmptyTrash()}
      />
    </Box>
  )
}

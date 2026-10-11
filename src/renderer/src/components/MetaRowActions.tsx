import {
  ArrowDownward as DownIcon,
  ArrowUpward as UpIcon,
  Delete as DeleteIcon,
  Edit as EditIcon,
} from '@mui/icons-material'
import { IconButton, TableCell, Tooltip } from '@mui/material'

// `width: 1%` with `nowrap` shrinks the column to its content, so it is always
// exactly as wide as the buttons it holds and a narrow dialog squeezes the
// other columns instead of wrapping the actions onto a second line.
const actionsCellSx = { width: '1%', whiteSpace: 'nowrap' } as const

export function MetaRowActionsHeader(): React.JSX.Element {
  return (
    <TableCell align="right" sx={actionsCellSx}>
      Actions
    </TableCell>
  )
}

interface MetaRowActionsProps {
  isFirst: boolean
  isLast: boolean
  onMoveUp: () => void
  onMoveDown: () => void
  onEdit: () => void
  onDelete: () => void
}

/**
 * Actions cell shared by the Project Settings meta tables: move up, move down,
 * edit, delete. Clicks never reach the row, so it is safe in selectable rows.
 */
export default function MetaRowActions({
  isFirst,
  isLast,
  onMoveUp,
  onMoveDown,
  onEdit,
  onDelete,
}: MetaRowActionsProps): React.JSX.Element {
  return (
    <TableCell align="right" sx={actionsCellSx} onClick={(e) => e.stopPropagation()}>
      <Tooltip title="Move up">
        <span>
          <IconButton size="small" disabled={isFirst} onClick={onMoveUp}>
            <UpIcon fontSize="small" />
          </IconButton>
        </span>
      </Tooltip>
      <Tooltip title="Move down">
        <span>
          <IconButton size="small" disabled={isLast} onClick={onMoveDown}>
            <DownIcon fontSize="small" />
          </IconButton>
        </span>
      </Tooltip>
      <Tooltip title="Edit">
        <IconButton size="small" onClick={onEdit}>
          <EditIcon fontSize="small" />
        </IconButton>
      </Tooltip>
      <Tooltip title="Delete">
        <IconButton size="small" color="error" onClick={onDelete}>
          <DeleteIcon fontSize="small" />
        </IconButton>
      </Tooltip>
    </TableCell>
  )
}

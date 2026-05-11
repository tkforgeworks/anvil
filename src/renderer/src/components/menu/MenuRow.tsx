import { Box } from '@mui/material'
import { forwardRef } from 'react'
import KbdPill from './KbdPill'
import MenuDivider from './MenuDivider'
import MenuIcon, { MENU_ICONS } from './MenuIcon'

export interface MenuRowItem {
  kind: 'item' | 'submenu' | 'divider'
  icon?: string
  label?: string
  shortcut?: string
  meta?: string
  sub?: string
  disabled?: boolean
  checked?: boolean
  danger?: boolean
  tooltip?: string
}

interface MenuRowProps {
  item: MenuRowItem
  hovered?: boolean
  onClick?: () => void
  onMouseEnter?: () => void
  onMouseLeave?: () => void
  role?: string
  tabIndex?: number
  'aria-checked'?: boolean
}

const MenuRow = forwardRef<HTMLDivElement, MenuRowProps>(function MenuRow(
  { item, hovered, onClick, onMouseEnter, onMouseLeave, role, tabIndex, 'aria-checked': ariaChecked },
  ref,
): React.JSX.Element {
  if (item.kind === 'divider') {
    return <MenuDivider />
  }

  const isSubmenu = item.kind === 'submenu'

  return (
    <Box
      ref={ref}
      role={role}
      tabIndex={tabIndex}
      aria-checked={ariaChecked}
      aria-disabled={item.disabled || undefined}
      onClick={item.disabled ? undefined : onClick}
      onMouseEnter={onMouseEnter}
      onMouseLeave={onMouseLeave}
      title={item.tooltip}
      sx={{
        display: 'flex',
        alignItems: 'center',
        gap: '10px',
        px: '10px',
        py: '8px',
        borderRadius: '5px',
        fontSize: '13px',
        color: item.danger ? '#fb7185' : '#e6edf7',
        cursor: item.disabled ? 'not-allowed' : 'pointer',
        userSelect: 'none',
        minHeight: '32px',
        opacity: item.disabled ? 0.4 : 1,
        bgcolor: hovered && !item.disabled
          ? (item.danger ? 'rgba(239,68,68,0.16)' : 'rgba(59,130,246,0.14)')
          : 'transparent',
        '&:hover': item.disabled
          ? {}
          : {
              bgcolor: item.danger ? 'rgba(239,68,68,0.16)' : 'rgba(59,130,246,0.14)',
              color: item.danger ? '#fda4af' : '#fff',
              '& .menu-row-ico': { color: 'inherit' },
            },
        '&:focus-visible': {
          bgcolor: item.danger ? 'rgba(239,68,68,0.16)' : 'rgba(59,130,246,0.14)',
          color: item.danger ? '#fda4af' : '#fff',
          outline: 'none',
        },
      }}
    >
      {/* Icon slot */}
      <Box
        className="menu-row-ico"
        sx={{
          width: 18,
          display: 'inline-flex',
          alignItems: 'center',
          justifyContent: 'center',
          color: '#9ba8c2',
          flexShrink: 0,
        }}
      >
        {item.checked ? (
          <MenuIcon name="check_mark" size={14} />
        ) : item.icon ? (
          <MenuIcon name={item.icon} />
        ) : null}
      </Box>

      {/* Label */}
      <Box
        component="span"
        sx={{
          flex: 1,
          whiteSpace: 'nowrap',
          overflow: 'hidden',
          textOverflow: 'ellipsis',
        }}
      >
        {item.label}
        {item.sub && (
          <Box component="span" sx={{ color: '#5d6a85', fontSize: '11px', ml: '4px' }}>
            {' · '}
            {item.sub}
          </Box>
        )}
      </Box>

      {/* Meta text (right-aligned, e.g. record counts) */}
      {item.meta && (
        <Box
          component="span"
          sx={{
            fontFamily: 'var(--font-mono, "JetBrains Mono", monospace)',
            fontSize: '10px',
            color: '#5d6a85',
          }}
        >
          {item.meta}
        </Box>
      )}

      {/* Keyboard shortcut pill */}
      {item.shortcut && <KbdPill shortcut={item.shortcut} />}

      {/* Submenu chevron */}
      {isSubmenu && (
        <Box component="span" sx={{ color: '#5d6a85', ml: '-2px' }}>
          <MenuIcon name="chevron" size={12} />
        </Box>
      )}
    </Box>
  )
})

export default MenuRow

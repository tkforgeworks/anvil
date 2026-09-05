import { Box } from '@mui/material'
import type { Theme } from '@mui/material/styles'
import { forwardRef } from 'react'
import KbdPill from './KbdPill'
import MenuDivider from './MenuDivider'
import MenuIcon, { MENU_ICONS } from './MenuIcon'
import { menuHighlight, menuMutedColor, menuRowColor } from './menu-theme'

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
  'aria-haspopup'?: 'menu'
  'aria-expanded'?: boolean
}

const MenuRow = forwardRef<HTMLDivElement, MenuRowProps>(function MenuRow(
  {
    item,
    hovered,
    onClick,
    onMouseEnter,
    onMouseLeave,
    role,
    tabIndex,
    'aria-checked': ariaChecked,
    'aria-haspopup': ariaHasPopup,
    'aria-expanded': ariaExpanded,
  },
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
      aria-haspopup={ariaHasPopup}
      aria-expanded={ariaExpanded}
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
        color: (theme) => menuRowColor(theme, item.danger),
        cursor: item.disabled ? 'not-allowed' : 'pointer',
        userSelect: 'none',
        minHeight: '32px',
        opacity: item.disabled ? 0.4 : 1,
        bgcolor: (theme) => (hovered && !item.disabled ? menuHighlight(theme, item.danger) : 'transparent'),
        '&:hover': item.disabled
          ? {}
          : {
              bgcolor: (theme: Theme) => menuHighlight(theme, item.danger),
              color: (theme: Theme) => menuRowColor(theme, item.danger),
              '& .menu-row-ico': { color: 'inherit' },
            },
        '&:focus': { outline: 'none' },
        '&:focus-visible': {
          bgcolor: (theme: Theme) => menuHighlight(theme, item.danger),
          color: (theme: Theme) => menuRowColor(theme, item.danger),
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
          color: menuMutedColor,
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
          <Box component="span" sx={{ color: menuMutedColor, fontSize: '11px', ml: '4px' }}>
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
            color: menuMutedColor,
          }}
        >
          {item.meta}
        </Box>
      )}

      {/* Keyboard shortcut pill */}
      {item.shortcut && <KbdPill shortcut={item.shortcut} />}

      {/* Submenu chevron */}
      {isSubmenu && (
        <Box component="span" sx={{ color: menuMutedColor, ml: '-2px' }}>
          <MenuIcon name="chevron" size={12} />
        </Box>
      )}
    </Box>
  )
})

export default MenuRow

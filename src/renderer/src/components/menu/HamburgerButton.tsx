import { IconButton } from '@mui/material'
import { useUiStore } from '../../stores/ui.store'
import MenuIcon from './MenuIcon'

export default function HamburgerButton(): React.JSX.Element {
  const menuOpen = useUiStore((s) => s.menuOpen)
  const setMenuOpen = useUiStore((s) => s.setMenuOpen)

  return (
    <IconButton
      onClick={() => setMenuOpen(!menuOpen)}
      aria-haspopup="menu"
      aria-expanded={menuOpen}
      data-tid="menu-hamburger"
      size="small"
      sx={{
        WebkitAppRegion: 'no-drag',
        width: 32,
        height: 28,
        mr: 0.5,
        ml: -0.5,
        borderRadius: '4px',
        // Inherit the AppBar's contrast text like the other title-bar controls so the
        // button stays visible whether the bar is dark paper or light-mode primary.
        // The highlight is mixed from currentColor for the same reason.
        color: 'inherit',
        opacity: menuOpen ? 1 : 0.75,
        bgcolor: menuOpen ? 'color-mix(in srgb, currentColor 18%, transparent)' : 'transparent',
        '&:hover': {
          opacity: 1,
          bgcolor: menuOpen
            ? 'color-mix(in srgb, currentColor 18%, transparent)'
            : 'color-mix(in srgb, currentColor 10%, transparent)',
        },
      }}
    >
      <MenuIcon name="menu" size={18} />
    </IconButton>
  )
}

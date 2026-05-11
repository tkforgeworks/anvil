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
        color: menuOpen ? 'primary.main' : 'text.secondary',
        bgcolor: menuOpen ? 'rgba(59,130,246,0.16)' : 'transparent',
        '&:hover': {
          bgcolor: menuOpen ? 'rgba(59,130,246,0.16)' : 'rgba(255,255,255,0.08)',
          color: menuOpen ? 'primary.main' : 'text.primary',
        },
      }}
    >
      <MenuIcon name="menu" size={18} />
    </IconButton>
  )
}

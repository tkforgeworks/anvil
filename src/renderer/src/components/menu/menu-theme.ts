import { alpha } from '@mui/material/styles'
import type { SxProps, Theme } from '@mui/material/styles'

/**
 * Theme-derived style helpers shared by the hamburger menu primitives.
 *
 * Every colour in the menu flyouts must come from the active MUI theme so the
 * panel follows dark/light/custom mode changes at runtime (ANVL-93). Keep the
 * palette lookups here rather than sprinkling hex literals through the
 * components.
 */

/** Translucent highlight used for hovered/focused rows and the active hamburger. */
export function menuHighlight(theme: Theme, danger = false): string {
  return danger ? alpha(theme.palette.error.main, 0.16) : alpha(theme.palette.primary.main, 0.14)
}

/** Foreground colour for a row, before and during hover. */
export function menuRowColor(theme: Theme, danger = false): string {
  return danger ? theme.palette.error.main : theme.palette.text.primary
}

/** Floating surface shared by the dropdown panel and the recent-projects flyout. */
export const menuSurfaceSx: SxProps<Theme> = {
  bgcolor: 'background.paper',
  border: '1px solid',
  borderColor: 'divider',
  borderRadius: '8px',
  boxShadow: (theme) =>
    theme.palette.mode === 'dark'
      ? '0 18px 40px rgba(0,0,0,0.55), 0 2px 6px rgba(0,0,0,0.4)'
      : '0 18px 40px rgba(15,23,42,0.18), 0 2px 6px rgba(15,23,42,0.10)',
}

/** Muted secondary text: shortcuts, meta counts, sub-labels, section captions. */
export const menuMutedColor = 'text.secondary'

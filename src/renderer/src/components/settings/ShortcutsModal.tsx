import CloseIcon from '@mui/icons-material/CloseRounded'
import { Box, Dialog, DialogContent, DialogTitle, IconButton, Stack, Typography } from '@mui/material'
import { MODAL_IDS } from '../../menu/constants'
import { SHORTCUTS } from '../../menu/shortcuts'
import { useUiStore } from '../../stores/ui.store'
import { KbdPill } from '../menu'

const GROUP_ORDER = ['File', 'Navigation', 'Editing', 'View', 'Project', 'Help'] as const

export default function ShortcutsModal(): React.JSX.Element | null {
  const activeModalId = useUiStore((s) => s.activeModalId)
  const closeModal = useUiStore((s) => s.closeModal)

  if (activeModalId !== MODAL_IDS.SHORTCUTS) return null

  const grouped = new Map<string, typeof SHORTCUTS>()
  for (const s of SHORTCUTS) {
    const list = grouped.get(s.group) ?? []
    list.push(s)
    grouped.set(s.group, list)
  }

  return (
    <Dialog open onClose={closeModal} maxWidth="md" fullWidth>
      <DialogTitle sx={{ display: 'flex', alignItems: 'center' }}>
        <Typography variant="h6" sx={{ flex: 1, fontWeight: 600 }}>
          Keyboard Shortcuts
        </Typography>
        <IconButton size="small" onClick={closeModal}>
          <CloseIcon fontSize="small" />
        </IconButton>
      </DialogTitle>

      <DialogContent>
        <Box
          sx={{
            display: 'grid',
            gridTemplateColumns: '1fr 1fr',
            gap: '8px 24px',
          }}
        >
          {GROUP_ORDER.map((group) => {
            const entries = grouped.get(group)
            if (!entries?.length) return null
            return (
              <Box key={group}>
                <Typography
                  variant="overline"
                  sx={{ fontWeight: 700, letterSpacing: '0.08em', color: 'text.secondary', mb: 0.5, display: 'block' }}
                >
                  {group}
                </Typography>
                {entries.map((s) => (
                  <Stack
                    key={s.id}
                    direction="row"
                    justifyContent="space-between"
                    alignItems="center"
                    sx={{ py: 0.5, borderBottom: '1px dashed', borderColor: 'divider' }}
                  >
                    <Typography variant="body2">{s.label}</Typography>
                    <KbdPill shortcut={s.keys} />
                  </Stack>
                ))}
              </Box>
            )
          })}
        </Box>

        <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 2 }}>
          macOS: substitute Cmd for Ctrl. Press Esc to close.
        </Typography>
      </DialogContent>
    </Dialog>
  )
}

import CloseIcon from '@mui/icons-material/CloseRounded'
import { Box, Dialog, DialogContent, DialogTitle, IconButton, Stack, Typography } from '@mui/material'
import { MODAL_IDS } from '../../menu/constants'
import { SHORTCUTS } from '../../menu/shortcuts'
import { useUiStore } from '../../stores/ui.store'

const GROUP_ORDER = ['File', 'Navigation', 'Editing', 'View', 'Project', 'Help'] as const

const PANEL_BG = '#1a2438'
const RULE = '#2a3553'
const RULE_SOFT = '#233048'
const TEXT = '#e6edf7'
const TEXT_STRONG = '#f4f7fc'
const TEXT_SOFT = '#9ba8c2'
const TEXT_FAINT = '#5d6a85'
const BG_INPUT = '#1d273c'

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
    <Dialog
      open
      onClose={closeModal}
      maxWidth="md"
      fullWidth
      PaperProps={{
        sx: {
          bgcolor: PANEL_BG,
          border: `1px solid ${RULE}`,
          backgroundImage: 'none',
        },
      }}
    >
      <DialogTitle sx={{ display: 'flex', alignItems: 'center', borderBottom: `1px solid ${RULE_SOFT}` }}>
        <Typography variant="h6" sx={{ flex: 1, fontWeight: 600, color: TEXT_STRONG }}>
          Keyboard Shortcuts
        </Typography>
        <IconButton size="small" onClick={closeModal} sx={{ color: TEXT_SOFT }}>
          <CloseIcon fontSize="small" />
        </IconButton>
      </DialogTitle>

      <DialogContent sx={{ pt: 2, pb: 2 }}>
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
                  sx={{
                    fontWeight: 700,
                    letterSpacing: '0.08em',
                    color: TEXT_SOFT,
                    mb: 0.5,
                    display: 'block',
                  }}
                >
                  {group}
                </Typography>
                {entries.map((s) => (
                  <Stack
                    key={s.id}
                    direction="row"
                    justifyContent="space-between"
                    alignItems="center"
                    sx={{ py: 0.5, borderBottom: `1px dashed ${RULE_SOFT}` }}
                  >
                    <Typography variant="body2" sx={{ color: TEXT }}>{s.label}</Typography>
                    <Box
                      component="span"
                      sx={{
                        fontFamily: '"JetBrains Mono", monospace',
                        fontSize: '11px',
                        color: TEXT_SOFT,
                        bgcolor: BG_INPUT,
                        border: `1px solid ${RULE}`,
                        px: '8px',
                        py: '2px',
                        borderRadius: '4px',
                        whiteSpace: 'nowrap',
                        lineHeight: 1.4,
                      }}
                    >
                      {s.keys}
                    </Box>
                  </Stack>
                ))}
              </Box>
            )
          })}
        </Box>

        <Typography
          variant="caption"
          sx={{ display: 'block', mt: 2, color: TEXT_FAINT, borderTop: `1px solid ${RULE_SOFT}`, pt: 1.5 }}
        >
          macOS: substitute Cmd for Ctrl. Press Esc to close.
        </Typography>
      </DialogContent>
    </Dialog>
  )
}

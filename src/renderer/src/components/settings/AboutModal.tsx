import CloseIcon from '@mui/icons-material/CloseRounded'
import FolderOpenIcon from '@mui/icons-material/FolderOpen'
import LaunchIcon from '@mui/icons-material/Launch'
import { Box, Button, Dialog, DialogContent, DialogTitle, IconButton, Stack, Typography } from '@mui/material'
import { IPC_CHANNELS } from '../../../../shared/ipc-channels'
import { MODAL_IDS } from '../../menu/constants'
import { useUiStore } from '../../stores/ui.store'

const PANEL_BG = '#1a2438'
const RULE = '#2a3553'
const RULE_SOFT = '#233048'
const TEXT = '#e6edf7'
const TEXT_STRONG = '#f4f7fc'
const TEXT_SOFT = '#9ba8c2'
const TEXT_FAINT = '#5d6a85'

function InfoRow({ label, value }: { label: string; value: string }): React.JSX.Element {
  return (
    <Stack direction="row" spacing={2} sx={{ py: 0.5 }}>
      <Typography sx={{ fontSize: '13px', color: TEXT_SOFT, width: 72, flexShrink: 0 }}>
        {label}
      </Typography>
      <Typography
        sx={{ fontSize: '13px', color: TEXT, fontFamily: '"JetBrains Mono", monospace' }}
      >
        {value}
      </Typography>
    </Stack>
  )
}

export default function AboutModal(): React.JSX.Element | null {
  const activeModalId = useUiStore((s) => s.activeModalId)
  const closeModal = useUiStore((s) => s.closeModal)

  if (activeModalId !== MODAL_IDS.ABOUT) return null

  const handleOpenWebsite = (): void => {
    void window.anvil.invoke(IPC_CHANNELS.SHELL_OPEN_EXTERNAL, 'https://tkforgeworks.com')
  }

  const handleOpenLogFolder = async (): Promise<void> => {
    const logPath = await window.anvil.invoke<string>(IPC_CHANNELS.APP_GET_LOG_PATH)
    if (logPath) void window.anvil.invoke(IPC_CHANNELS.SHELL_OPEN_PATH, logPath)
  }

  return (
    <Dialog
      open
      onClose={closeModal}
      maxWidth="xs"
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
          About Anvil
        </Typography>
        <IconButton size="small" onClick={closeModal} sx={{ color: TEXT_SOFT }}>
          <CloseIcon fontSize="small" />
        </IconButton>
      </DialogTitle>

      <DialogContent sx={{ pt: 3, pb: 3 }}>
        <Box sx={{ textAlign: 'center', mb: 2.5 }}>
          <Typography
            sx={{
              fontFamily: '"Poppins", sans-serif',
              fontWeight: 700,
              fontSize: '28px',
              letterSpacing: '0.04em',
              color: TEXT_STRONG,
            }}
          >
            ANVIL
          </Typography>
          <Typography sx={{ fontSize: '13px', color: TEXT_SOFT }}>
            RPG Data Management Tool
          </Typography>
        </Box>

        <InfoRow label="Version" value={__APP_VERSION__} />
        <InfoRow label="Build" value={__GIT_SHA__} />
        <InfoRow label="Built" value={__BUILD_DATE__} />

        <Box sx={{ height: '1px', bgcolor: RULE_SOFT, my: 2 }} />

        <Stack direction="row" spacing={2} sx={{ py: 0.5 }}>
          <Typography sx={{ fontSize: '13px', color: TEXT_SOFT, width: 72, flexShrink: 0 }}>
            Author
          </Typography>
          <Typography sx={{ fontSize: '13px', color: TEXT }}>
            Tim Klimpel
          </Typography>
        </Stack>

        <Stack direction="row" spacing={2} sx={{ py: 0.5 }}>
          <Typography sx={{ fontSize: '13px', color: TEXT_SOFT, width: 72, flexShrink: 0 }}>
            Website
          </Typography>
          <Typography
            onClick={handleOpenWebsite}
            sx={{
              fontSize: '13px',
              color: '#3b82f6',
              cursor: 'pointer',
              '&:hover': { textDecoration: 'underline' },
              display: 'flex',
              alignItems: 'center',
              gap: 0.5,
            }}
          >
            tkforgeworks.com
            <LaunchIcon sx={{ fontSize: 12 }} />
          </Typography>
        </Stack>

        <Box sx={{ height: '1px', bgcolor: RULE_SOFT, my: 2 }} />

        <Stack direction="row" spacing={2} alignItems="center" sx={{ py: 0.5 }}>
          <Typography sx={{ fontSize: '13px', color: TEXT_SOFT, width: 72, flexShrink: 0 }}>
            Logs
          </Typography>
          <Button
            size="small"
            variant="outlined"
            startIcon={<FolderOpenIcon />}
            onClick={() => void handleOpenLogFolder()}
            sx={{
              fontSize: '12px',
              color: TEXT,
              borderColor: RULE,
              '&:hover': { borderColor: TEXT_SOFT, bgcolor: 'rgba(255,255,255,0.04)' },
            }}
          >
            Open Log Folder
          </Button>
        </Stack>

        <Typography
          sx={{ display: 'block', mt: 3, textAlign: 'center', fontSize: '11px', color: TEXT_FAINT }}
        >
          Local-first: all projects live on disk. No accounts, no sync.
        </Typography>
      </DialogContent>
    </Dialog>
  )
}

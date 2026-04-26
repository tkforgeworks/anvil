import { Close as CloseIcon } from '@mui/icons-material'
import { Dialog, DialogContent, DialogTitle, IconButton } from '@mui/material'
import ApplicationSettingsPanel from './ApplicationSettingsPanel'

interface AppSettingsDialogProps {
  open: boolean
  onClose: () => void
}

export default function AppSettingsDialog({ open, onClose }: AppSettingsDialogProps): React.JSX.Element {
  return (
    <Dialog open={open} onClose={onClose} fullWidth maxWidth="sm">
      <DialogTitle sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        Application Settings
        <IconButton size="small" onClick={onClose}>
          <CloseIcon fontSize="small" />
        </IconButton>
      </DialogTitle>
      <DialogContent>
        <ApplicationSettingsPanel />
      </DialogContent>
    </Dialog>
  )
}

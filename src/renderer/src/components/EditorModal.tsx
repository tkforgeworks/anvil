import { Close as CloseIcon } from '@mui/icons-material'
import { Dialog, DialogContent, DialogTitle, IconButton } from '@mui/material'

interface EditorModalProps {
  open: boolean
  title: string
  onClose: () => void
  children: React.ReactNode
}

export default function EditorModal({ open, title, onClose, children }: EditorModalProps): React.JSX.Element {
  return (
    <Dialog
      open={open}
      onClose={onClose}
      fullWidth
      maxWidth="lg"
      PaperProps={{ sx: { height: '85vh', display: 'flex', flexDirection: 'column' } }}
    >
      <DialogTitle sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', py: 1 }}>
        {title}
        <IconButton size="small" onClick={onClose} data-tid="dialog-editor-modal-close">
          <CloseIcon fontSize="small" />
        </IconButton>
      </DialogTitle>
      <DialogContent sx={{ flex: 1, overflow: 'auto' }}>
        {children}
      </DialogContent>
    </Dialog>
  )
}

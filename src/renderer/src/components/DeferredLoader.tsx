import { Box, CircularProgress } from '@mui/material'
import { useEffect, useState } from 'react'

interface DeferredLoaderProps {
  delayMs?: number
}

export default function DeferredLoader({ delayMs = 500 }: DeferredLoaderProps): React.JSX.Element | null {
  const [showSpinner, setShowSpinner] = useState(false)

  useEffect(() => {
    const timer = setTimeout(() => setShowSpinner(true), delayMs)
    return () => clearTimeout(timer)
  }, [delayMs])

  if (!showSpinner) return null

  return (
    <Box sx={{ display: 'flex', justifyContent: 'center', py: 4 }}>
      <CircularProgress size={28} />
    </Box>
  )
}

import { useEffect, useState } from 'react'
import { Tooltip, Typography } from '@mui/material'

interface RelativeTimestampProps {
  timestamp: string
  variant?: 'body2' | 'caption'
  inline?: boolean
}

function formatRelative(iso: string): string {
  const date = new Date(iso)
  const now = Date.now()
  const diffMs = now - date.getTime()

  if (diffMs < 0) return 'just now'

  const seconds = Math.floor(diffMs / 1000)
  const minutes = Math.floor(seconds / 60)
  const hours = Math.floor(minutes / 60)
  const days = Math.floor(hours / 24)

  if (seconds < 60) return 'just now'
  if (minutes === 1) return '1 minute ago'
  if (minutes < 60) return `${minutes} minutes ago`
  if (hours === 1) return '1 hour ago'
  if (hours < 24) return `${hours} hours ago`
  if (days === 1) return 'yesterday'
  if (days < 7) return `${days} days ago`
  if (days < 14) return 'last week'

  return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' })
}

export function RelativeTimestamp({ timestamp, variant = 'body2', inline }: RelativeTimestampProps) {
  const [display, setDisplay] = useState(() => formatRelative(timestamp))

  useEffect(() => {
    setDisplay(formatRelative(timestamp))
    const interval = setInterval(() => {
      setDisplay(formatRelative(timestamp))
    }, 60_000)
    return () => clearInterval(interval)
  }, [timestamp])

  const fullDate = new Date(timestamp).toLocaleString()

  if (inline) {
    return (
      <Tooltip title={fullDate} arrow>
        <span style={{ fontWeight: 500 }}>{display}</span>
      </Tooltip>
    )
  }

  return (
    <Tooltip title={fullDate} arrow>
      <Typography variant={variant} component="span" color="text.secondary">
        {display}
      </Typography>
    </Tooltip>
  )
}

import { useEffect, useRef } from 'react'
import { useLocation } from 'react-router-dom'
import { recordEvent } from './telemetry-collector'

export default function TelemetryRouteTracker(): null {
  const location = useLocation()
  const prevPath = useRef<string | null>(null)
  const enteredAt = useRef<number>(performance.now())

  useEffect(() => {
    if (!__TELEMETRY_ENABLED__) return

    const now = performance.now()
    const dwellMs = prevPath.current !== null ? Math.round(now - enteredAt.current) : null

    recordEvent({
      ts: new Date().toISOString(),
      type: 'navigation',
      data: {
        from: prevPath.current,
        to: location.pathname,
        dwellMs,
      },
    })

    prevPath.current = location.pathname
    enteredAt.current = now
  }, [location.pathname])

  return null
}

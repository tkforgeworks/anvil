import { IPC_CHANNELS } from '@shared/ipc-channels'
import type { TelemetryEvent } from '@shared/telemetry-types'

const buffer: TelemetryEvent[] = []
let flushTimer: number | null = null
const FLUSH_INTERVAL = 3000
const MAX_BUFFER_SIZE = 50

export function recordEvent(event: TelemetryEvent): void {
  if (!__TELEMETRY_ENABLED__) return
  buffer.push(event)
  if (buffer.length >= MAX_BUFFER_SIZE) flush()
}

export function startFlushing(): void {
  if (!__TELEMETRY_ENABLED__) return
  flushTimer = window.setInterval(flush, FLUSH_INTERVAL)
}

export function stopFlushing(): void {
  if (flushTimer != null) window.clearInterval(flushTimer)
}

export function flushSync(): void {
  if (buffer.length === 0) return
  const batch = buffer.splice(0)
  window.anvil.invoke(IPC_CHANNELS.TELEMETRY_FLUSH, batch).catch(() => {})
}

function flush(): void {
  if (buffer.length === 0) return
  const batch = buffer.splice(0)
  window.anvil.invoke(IPC_CHANNELS.TELEMETRY_FLUSH, batch).catch(() => {})
}

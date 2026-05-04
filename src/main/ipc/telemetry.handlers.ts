import { IPC_CHANNELS } from '../../shared/ipc-channels'
import { safeHandle } from './safe-handle'
import type { TelemetryEvent } from '../../shared/telemetry-types'
import { writeTelemetryBatch } from '../logging/telemetry-writer'

export function registerTelemetryHandlers(): void {
  safeHandle(IPC_CHANNELS.TELEMETRY_FLUSH, (_event, events: TelemetryEvent[]) => {
    if (!__TELEMETRY_ENABLED__) return
    writeTelemetryBatch(events)
  })
}

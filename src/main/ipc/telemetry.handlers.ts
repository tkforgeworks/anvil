import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type { TelemetryEvent } from '../../shared/telemetry-types'
import { writeTelemetryBatch } from '../logging/telemetry-writer'

export function registerTelemetryHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.TELEMETRY_FLUSH, (_event, events: TelemetryEvent[]) => {
    if (!__TELEMETRY_ENABLED__) return
    writeTelemetryBatch(events)
  })
}

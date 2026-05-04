import type { IpcChannel } from './ipc-channels'
import type { TelemetryEvent } from './telemetry-types'

export interface AnvilBridge {
  invoke: <T = unknown>(channel: IpcChannel, ...args: unknown[]) => Promise<T>
  on: (channel: IpcChannel, listener: (...args: unknown[]) => void) => () => void
  drainIpcTelemetry: () => TelemetryEvent[]
}

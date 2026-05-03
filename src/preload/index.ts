import { contextBridge, ipcRenderer } from 'electron'
import type { AnvilBridge } from '../shared/ipc-types'
import { IPC_CHANNELS } from '../shared/ipc-channels'

// Allowlist of all valid IPC channels, plus the ping verification channel
const ALLOWED_CHANNELS = new Set<string>([
  ...Object.values(IPC_CHANNELS),
  'ping',
])

const TELEMETRY_EXCLUDED = new Set<string>([
  IPC_CHANNELS.TELEMETRY_FLUSH,
  IPC_CHANNELS.PROJECT_GET_STATE,
  IPC_CHANNELS.LIFECYCLE_COUNT_DELETED,
  IPC_CHANNELS.VALIDATION_RUN,
  IPC_CHANNELS.PROJECT_GET_WEEKLY_DELTAS,
  IPC_CHANNELS.PROJECT_GET_SAVE_HISTORY,
  IPC_CHANNELS.PROJECT_GET_AUTO_SAVE_INFO,
])

const bridge: AnvilBridge = {
  invoke: (channel, ...args) => {
    if (!ALLOWED_CHANNELS.has(channel)) {
      return Promise.reject(new Error(`Blocked IPC channel: ${channel}`))
    }
    if (__TELEMETRY_ENABLED__ && !TELEMETRY_EXCLUDED.has(channel)) {
      const start = performance.now()
      return ipcRenderer.invoke(channel, ...args).finally(() => {
        ipcRenderer.invoke(IPC_CHANNELS.TELEMETRY_FLUSH, [{
          ts: new Date().toISOString(),
          type: 'ipc',
          data: { channel, durationMs: Math.round(performance.now() - start) },
        }]).catch(() => {})
      })
    }
    return ipcRenderer.invoke(channel, ...args)
  },

  on: (channel, listener) => {
    if (!ALLOWED_CHANNELS.has(channel)) {
      throw new Error(`Blocked IPC channel: ${channel}`)
    }
    const wrapped = (_event: Electron.IpcRendererEvent, ...args: unknown[]) =>
      listener(...args)
    ipcRenderer.on(channel, wrapped)
    return () => ipcRenderer.removeListener(channel, wrapped)
  },
}

contextBridge.exposeInMainWorld('anvil', bridge)

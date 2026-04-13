import { contextBridge, ipcRenderer } from 'electron'
import type { AnvilBridge } from '../shared/ipc-types'
import { IPC_CHANNELS } from '../shared/ipc-channels'

// Allowlist of all valid IPC channels, plus the ping verification channel
const ALLOWED_CHANNELS = new Set<string>([
  ...Object.values(IPC_CHANNELS),
  'ping',
])

const bridge: AnvilBridge = {
  invoke: (channel, ...args) => {
    if (!ALLOWED_CHANNELS.has(channel)) {
      return Promise.reject(new Error(`Blocked IPC channel: ${channel}`))
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

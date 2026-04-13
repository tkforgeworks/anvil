import type { AnvilBridge } from '../../shared/ipc-types'

declare global {
  interface Window {
    /** Typed IPC bridge exposed by the preload script via contextBridge. */
    anvil: AnvilBridge
  }
}

export {}

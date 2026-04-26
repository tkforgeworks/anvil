import type { AnvilBridge } from '../../shared/ipc-types'

declare global {
  interface Window {
    /** Typed IPC bridge exposed by the preload script via contextBridge. */
    anvil: AnvilBridge
  }
}

declare module '*.png' {
  const src: string
  export default src
}

export {}

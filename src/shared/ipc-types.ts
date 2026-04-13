import type { IpcChannel } from './ipc-channels'

/**
 * The typed IPC surface exposed to the renderer via contextBridge as window.anvil.
 * All renderer communication with the main process goes through this interface.
 */
export interface AnvilBridge {
  /**
   * Invoke a main-process handler and await its result.
   * @returns A promise resolving to the handler's return value.
   */
  invoke: <T = unknown>(channel: IpcChannel, ...args: unknown[]) => Promise<T>

  /**
   * Subscribe to main-process push events on the given channel.
   * @returns An unsubscribe function — call it to remove the listener.
   */
  on: (channel: IpcChannel, listener: (...args: unknown[]) => void) => () => void
}

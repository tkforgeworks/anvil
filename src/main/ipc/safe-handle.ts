import { ipcMain, type IpcMainInvokeEvent } from 'electron'
import { logError } from '../logging/app-logger'

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type IpcHandler = (event: IpcMainInvokeEvent, ...args: any[]) => any

export function safeHandle(channel: string, handler: IpcHandler): void {
  ipcMain.handle(channel, async (event, ...args) => {
    try {
      return await handler(event, ...args)
    } catch (error) {
      logError(`IPC handler error [${channel}]`, error instanceof Error ? error : new Error(String(error)))
      throw error
    }
  })
}

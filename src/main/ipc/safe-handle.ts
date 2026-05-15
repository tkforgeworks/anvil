import { ipcMain, type IpcMainInvokeEvent } from 'electron'
import { logError } from '../logging/app-logger'

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type IpcHandler = (event: IpcMainInvokeEvent, ...args: any[]) => any

const LOGGED_ERRORS = new WeakSet<Error>()

export function isAlreadyLoggedError(error: unknown): boolean {
  return error instanceof Error && LOGGED_ERRORS.has(error)
}

export function safeHandle(channel: string, handler: IpcHandler): void {
  ipcMain.handle(channel, async (event, ...args) => {
    try {
      return await handler(event, ...args)
    } catch (error) {
      const err = error instanceof Error ? error : new Error(String(error))
      logError(`IPC handler error [${channel}]`, err)
      LOGGED_ERRORS.add(err)
      throw error
    }
  })
}

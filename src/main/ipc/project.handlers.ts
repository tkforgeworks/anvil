import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'

// Full implementation in the Project File & Lifecycle Management epic
export function registerProjectHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.PROJECT_CREATE, () => null)
  ipcMain.handle(IPC_CHANNELS.PROJECT_OPEN, () => null)
  ipcMain.handle(IPC_CHANNELS.PROJECT_SAVE, () => undefined)
  ipcMain.handle(IPC_CHANNELS.PROJECT_SAVE_AS, () => undefined)
  ipcMain.handle(IPC_CHANNELS.PROJECT_CLOSE, () => undefined)
  ipcMain.handle(IPC_CHANNELS.PROJECT_GET_STATE, () => null)
}

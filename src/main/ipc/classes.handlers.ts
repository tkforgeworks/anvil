import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'

// Full implementation in the Character Classes epic
export function registerClassesHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.CLASSES_LIST, () => [])
  ipcMain.handle(IPC_CHANNELS.CLASSES_GET, () => null)
  ipcMain.handle(IPC_CHANNELS.CLASSES_CREATE, () => null)
  ipcMain.handle(IPC_CHANNELS.CLASSES_UPDATE, () => null)
  ipcMain.handle(IPC_CHANNELS.CLASSES_DELETE, () => undefined)
  ipcMain.handle(IPC_CHANNELS.CLASSES_RESTORE, () => undefined)
}

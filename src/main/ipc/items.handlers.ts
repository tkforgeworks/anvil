import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'

// Full implementation in the Items epic
export function registerItemsHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.ITEMS_LIST, () => [])
  ipcMain.handle(IPC_CHANNELS.ITEMS_GET, () => null)
  ipcMain.handle(IPC_CHANNELS.ITEMS_CREATE, () => null)
  ipcMain.handle(IPC_CHANNELS.ITEMS_UPDATE, () => null)
  ipcMain.handle(IPC_CHANNELS.ITEMS_DELETE, () => undefined)
  ipcMain.handle(IPC_CHANNELS.ITEMS_RESTORE, () => undefined)
}

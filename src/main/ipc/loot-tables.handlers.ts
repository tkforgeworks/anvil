import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'

// Full implementation in the Loot Tables epic
export function registerLootTablesHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.LOOT_TABLES_LIST, () => [])
  ipcMain.handle(IPC_CHANNELS.LOOT_TABLES_GET, () => null)
  ipcMain.handle(IPC_CHANNELS.LOOT_TABLES_CREATE, () => null)
  ipcMain.handle(IPC_CHANNELS.LOOT_TABLES_UPDATE, () => null)
  ipcMain.handle(IPC_CHANNELS.LOOT_TABLES_DELETE, () => undefined)
  ipcMain.handle(IPC_CHANNELS.LOOT_TABLES_RESTORE, () => undefined)
}

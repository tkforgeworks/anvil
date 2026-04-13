import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'

// Full implementation in the NPCs epic
export function registerNpcsHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.NPCS_LIST, () => [])
  ipcMain.handle(IPC_CHANNELS.NPCS_GET, () => null)
  ipcMain.handle(IPC_CHANNELS.NPCS_CREATE, () => null)
  ipcMain.handle(IPC_CHANNELS.NPCS_UPDATE, () => null)
  ipcMain.handle(IPC_CHANNELS.NPCS_DELETE, () => undefined)
  ipcMain.handle(IPC_CHANNELS.NPCS_RESTORE, () => undefined)
}

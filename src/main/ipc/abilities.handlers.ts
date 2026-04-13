import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'

// Full implementation in the Abilities epic
export function registerAbilitiesHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.ABILITIES_LIST, () => [])
  ipcMain.handle(IPC_CHANNELS.ABILITIES_GET, () => null)
  ipcMain.handle(IPC_CHANNELS.ABILITIES_CREATE, () => null)
  ipcMain.handle(IPC_CHANNELS.ABILITIES_UPDATE, () => null)
  ipcMain.handle(IPC_CHANNELS.ABILITIES_DELETE, () => undefined)
  ipcMain.handle(IPC_CHANNELS.ABILITIES_RESTORE, () => undefined)
}

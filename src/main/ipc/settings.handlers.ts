import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'

// Full implementation in the Settings epic
export function registerSettingsHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.SETTINGS_GET_APP, () => null)
  ipcMain.handle(IPC_CHANNELS.SETTINGS_SET_APP, () => undefined)
  ipcMain.handle(IPC_CHANNELS.SETTINGS_GET_PROJECT, () => null)
  ipcMain.handle(IPC_CHANNELS.SETTINGS_SET_PROJECT, () => undefined)
}

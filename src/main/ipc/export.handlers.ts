import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'

// Full implementation in the Export epic
export function registerExportHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.EXPORT_PREVIEW, () => '')
  ipcMain.handle(IPC_CHANNELS.EXPORT_EXECUTE, () => undefined)
  ipcMain.handle(IPC_CHANNELS.EXPORT_GET_TEMPLATES, () => [])
}

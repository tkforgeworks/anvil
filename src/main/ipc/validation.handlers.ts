import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'

// Full implementation in the Validation epic
export function registerValidationHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.VALIDATION_RUN, () => [])
  ipcMain.handle(IPC_CHANNELS.VALIDATION_GET_ISSUES, () => [])
}

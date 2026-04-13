import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'

// Full implementation in the Crafting Recipes epic
export function registerRecipesHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.RECIPES_LIST, () => [])
  ipcMain.handle(IPC_CHANNELS.RECIPES_GET, () => null)
  ipcMain.handle(IPC_CHANNELS.RECIPES_CREATE, () => null)
  ipcMain.handle(IPC_CHANNELS.RECIPES_UPDATE, () => null)
  ipcMain.handle(IPC_CHANNELS.RECIPES_DELETE, () => undefined)
  ipcMain.handle(IPC_CHANNELS.RECIPES_RESTORE, () => undefined)
}

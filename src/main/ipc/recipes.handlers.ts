import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import { recipeRepository } from '../repositories'

export function registerRecipesHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.RECIPES_LIST, (_event, options?: { includeDeleted?: boolean }) =>
    recipeRepository.list(options?.includeDeleted ?? false),
  )
  ipcMain.handle(IPC_CHANNELS.RECIPES_GET, (_event, id: string) => recipeRepository.get(id))
  ipcMain.handle(IPC_CHANNELS.RECIPES_CREATE, () => null)
  ipcMain.handle(IPC_CHANNELS.RECIPES_UPDATE, () => null)
  ipcMain.handle(IPC_CHANNELS.RECIPES_DELETE, (_event, id: string) => recipeRepository.softDelete(id))
  ipcMain.handle(IPC_CHANNELS.RECIPES_RESTORE, (_event, id: string) => recipeRepository.restore(id))
}

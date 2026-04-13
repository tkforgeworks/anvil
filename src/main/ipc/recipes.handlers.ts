import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import { markProjectDirty } from '../project/project-service'
import { recipeRepository } from '../repositories'

export function registerRecipesHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.RECIPES_LIST, (_event, options?: { includeDeleted?: boolean }) =>
    recipeRepository.list(options?.includeDeleted ?? false),
  )
  ipcMain.handle(IPC_CHANNELS.RECIPES_GET, (_event, id: string) => recipeRepository.get(id))
  ipcMain.handle(IPC_CHANNELS.RECIPES_CREATE, () => null)
  ipcMain.handle(IPC_CHANNELS.RECIPES_UPDATE, () => null)
  ipcMain.handle(IPC_CHANNELS.RECIPES_DELETE, (_event, id: string) => {
    recipeRepository.softDelete(id)
    return markProjectDirty()
  })
  ipcMain.handle(IPC_CHANNELS.RECIPES_RESTORE, (_event, id: string) => {
    recipeRepository.restore(id)
    return markProjectDirty()
  })
}

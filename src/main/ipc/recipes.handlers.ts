import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type { CreateRecipeInput, UpdateRecipeInput } from '../../shared/domain-types'
import { markProjectDirty } from '../project/project-service'
import { recipeRepository } from '../repositories'

export function registerRecipesHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.RECIPES_LIST, (_event, options?: { includeDeleted?: boolean }) =>
    recipeRepository.list(options?.includeDeleted ?? false),
  )

  ipcMain.handle(IPC_CHANNELS.RECIPES_GET, (_event, id: string) => recipeRepository.get(id))

  ipcMain.handle(IPC_CHANNELS.RECIPES_CREATE, (_event, data: CreateRecipeInput) => {
    const record = recipeRepository.create(data)
    markProjectDirty()
    return record
  })

  ipcMain.handle(IPC_CHANNELS.RECIPES_UPDATE, (_event, id: string, data: UpdateRecipeInput) => {
    const record = recipeRepository.update(id, data)
    if (record) markProjectDirty()
    return record
  })

  ipcMain.handle(IPC_CHANNELS.RECIPES_DELETE, (_event, id: string) => {
    recipeRepository.softDelete(id)
    return markProjectDirty()
  })

  ipcMain.handle(IPC_CHANNELS.RECIPES_RESTORE, (_event, id: string) => {
    recipeRepository.restore(id)
    return markProjectDirty()
  })
}

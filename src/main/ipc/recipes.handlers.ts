import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type { CreateRecipeInput, RecipeIngredient, UpdateRecipeInput } from '../../shared/domain-types'
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
    markProjectDirty()
  })

  ipcMain.handle(IPC_CHANNELS.RECIPES_RESTORE, (_event, id: string) => {
    recipeRepository.restore(id)
    markProjectDirty()
  })

  ipcMain.handle(IPC_CHANNELS.RECIPES_DUPLICATE, (_event, id: string) => {
    const record = recipeRepository.duplicate(id)
    if (record) markProjectDirty()
    return record
  })

  ipcMain.handle(IPC_CHANNELS.RECIPES_GET_INGREDIENTS, (_event, id: string) =>
    recipeRepository.getIngredients(id),
  )

  ipcMain.handle(
    IPC_CHANNELS.RECIPES_SET_INGREDIENTS,
    (_event, id: string, ingredients: RecipeIngredient[]) => {
      recipeRepository.setIngredients(id, ingredients)
      markProjectDirty()
    },
  )
}

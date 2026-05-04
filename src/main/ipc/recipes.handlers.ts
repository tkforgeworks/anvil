import { IPC_CHANNELS } from '../../shared/ipc-channels'
import { safeHandle } from './safe-handle'
import type { CreateRecipeInput, RecipeIngredient, UpdateRecipeInput } from '../../shared/domain-types'
import { markProjectDirty } from '../project/project-service'
import type { ChangeEntry } from '../project/change-accumulator'
import { recipeRepository } from '../repositories'

export function registerRecipesHandlers(): void {
  safeHandle(IPC_CHANNELS.RECIPES_LIST, (_event, options?: { includeDeleted?: boolean; deletedOnly?: boolean }) =>
    recipeRepository.list(options?.includeDeleted ?? false, options?.deletedOnly ?? false),
  )

  safeHandle(IPC_CHANNELS.RECIPES_GET, (_event, id: string) => recipeRepository.get(id))

  safeHandle(IPC_CHANNELS.RECIPES_CREATE, (_event, data: CreateRecipeInput) => {
    const record = recipeRepository.create(data)
    markProjectDirty({ domain: 'recipes', recordId: record.id, recordName: record.displayName, subArea: 'basic-info', action: 'create' })
    return record
  })

  safeHandle(IPC_CHANNELS.RECIPES_UPDATE, (_event, id: string, data: UpdateRecipeInput) => {
    const record = recipeRepository.update(id, data)
    if (record) markProjectDirty({ domain: 'recipes', recordId: record.id, recordName: record.displayName, subArea: 'basic-info', action: 'update' })
    return record
  })

  safeHandle(IPC_CHANNELS.RECIPES_DELETE, (_event, id: string) => {
    const record = recipeRepository.get(id)
    recipeRepository.softDelete(id)
    markProjectDirty({ domain: 'recipes', recordId: id, recordName: record?.displayName ?? id, subArea: 'basic-info', action: 'delete' })
  })

  safeHandle(IPC_CHANNELS.RECIPES_RESTORE, (_event, id: string) => {
    recipeRepository.restore(id)
    const record = recipeRepository.get(id)
    markProjectDirty({ domain: 'recipes', recordId: id, recordName: record?.displayName ?? id, subArea: 'basic-info', action: 'restore' })
  })

  safeHandle(IPC_CHANNELS.RECIPES_HARD_DELETE, (_event, id: string) => {
    recipeRepository.hardDelete(id)
    markProjectDirty({ domain: 'recipes', recordId: id, recordName: id, subArea: 'basic-info', action: 'hard-delete' })
  })

  safeHandle(IPC_CHANNELS.RECIPES_DUPLICATE, (_event, id: string) => {
    const record = recipeRepository.duplicate(id)
    if (record) markProjectDirty({ domain: 'recipes', recordId: record.id, recordName: record.displayName, subArea: 'basic-info', action: 'duplicate' })
    return record
  })

  safeHandle(IPC_CHANNELS.RECIPES_GET_INGREDIENTS, (_event, id: string) =>
    recipeRepository.getIngredients(id),
  )

  safeHandle(
    IPC_CHANNELS.RECIPES_SET_INGREDIENTS,
    (_event, id: string, ingredients: RecipeIngredient[]) => {
      recipeRepository.setIngredients(id, ingredients)
      const record = recipeRepository.get(id)
      markProjectDirty({ domain: 'recipes', recordId: id, recordName: record?.displayName ?? id, subArea: 'ingredients', action: 'update' })
    },
  )
}

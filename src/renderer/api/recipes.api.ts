import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type {
  CreateRecipeInput,
  RecipeRecord,
  UpdateRecipeInput,
} from '../../shared/domain-types'

export const recipesApi = {
  list: (includeDeleted = false) =>
    window.anvil.invoke<RecipeRecord[]>(IPC_CHANNELS.RECIPES_LIST, { includeDeleted }),

  get: (id: string) =>
    window.anvil.invoke<RecipeRecord | null>(IPC_CHANNELS.RECIPES_GET, id),

  create: (data: CreateRecipeInput) =>
    window.anvil.invoke<RecipeRecord>(IPC_CHANNELS.RECIPES_CREATE, data),

  update: (id: string, data: UpdateRecipeInput) =>
    window.anvil.invoke<RecipeRecord | null>(IPC_CHANNELS.RECIPES_UPDATE, id, data),

  delete: (id: string) =>
    window.anvil.invoke<void>(IPC_CHANNELS.RECIPES_DELETE, id),

  restore: (id: string) =>
    window.anvil.invoke<void>(IPC_CHANNELS.RECIPES_RESTORE, id),
}

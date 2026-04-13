import { IPC_CHANNELS } from '../../shared/ipc-channels'

// Full types defined in the Crafting Recipes epic
export const recipesApi = {
  list: (includeDeleted = false) =>
    window.anvil.invoke<unknown[]>(IPC_CHANNELS.RECIPES_LIST, { includeDeleted }),
  get: (id: string) =>
    window.anvil.invoke<unknown>(IPC_CHANNELS.RECIPES_GET, id),
  create: (data: unknown) =>
    window.anvil.invoke<unknown>(IPC_CHANNELS.RECIPES_CREATE, data),
  update: (id: string, data: unknown) =>
    window.anvil.invoke<unknown>(IPC_CHANNELS.RECIPES_UPDATE, id, data),
  delete: (id: string) =>
    window.anvil.invoke<void>(IPC_CHANNELS.RECIPES_DELETE, id),
  restore: (id: string) =>
    window.anvil.invoke<void>(IPC_CHANNELS.RECIPES_RESTORE, id),
}

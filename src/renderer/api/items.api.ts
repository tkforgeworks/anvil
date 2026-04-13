import { IPC_CHANNELS } from '../../shared/ipc-channels'

// Full types defined in the Items epic
export const itemsApi = {
  list: (includeDeleted = false) =>
    window.anvil.invoke<unknown[]>(IPC_CHANNELS.ITEMS_LIST, { includeDeleted }),
  get: (id: string) =>
    window.anvil.invoke<unknown>(IPC_CHANNELS.ITEMS_GET, id),
  create: (data: unknown) =>
    window.anvil.invoke<unknown>(IPC_CHANNELS.ITEMS_CREATE, data),
  update: (id: string, data: unknown) =>
    window.anvil.invoke<unknown>(IPC_CHANNELS.ITEMS_UPDATE, id, data),
  delete: (id: string) =>
    window.anvil.invoke<void>(IPC_CHANNELS.ITEMS_DELETE, id),
  restore: (id: string) =>
    window.anvil.invoke<void>(IPC_CHANNELS.ITEMS_RESTORE, id),
}

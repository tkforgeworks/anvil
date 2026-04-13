import { IPC_CHANNELS } from '../../shared/ipc-channels'

// Full types defined in the Loot Tables epic
export const lootTablesApi = {
  list: (includeDeleted = false) =>
    window.anvil.invoke<unknown[]>(IPC_CHANNELS.LOOT_TABLES_LIST, { includeDeleted }),
  get: (id: string) =>
    window.anvil.invoke<unknown>(IPC_CHANNELS.LOOT_TABLES_GET, id),
  create: (data: unknown) =>
    window.anvil.invoke<unknown>(IPC_CHANNELS.LOOT_TABLES_CREATE, data),
  update: (id: string, data: unknown) =>
    window.anvil.invoke<unknown>(IPC_CHANNELS.LOOT_TABLES_UPDATE, id, data),
  delete: (id: string) =>
    window.anvil.invoke<void>(IPC_CHANNELS.LOOT_TABLES_DELETE, id),
  restore: (id: string) =>
    window.anvil.invoke<void>(IPC_CHANNELS.LOOT_TABLES_RESTORE, id),
}

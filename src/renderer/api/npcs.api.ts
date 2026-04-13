import { IPC_CHANNELS } from '../../shared/ipc-channels'

// Full types defined in the NPCs epic
export const npcsApi = {
  list: (includeDeleted = false) =>
    window.anvil.invoke<unknown[]>(IPC_CHANNELS.NPCS_LIST, { includeDeleted }),
  get: (id: string) =>
    window.anvil.invoke<unknown>(IPC_CHANNELS.NPCS_GET, id),
  create: (data: unknown) =>
    window.anvil.invoke<unknown>(IPC_CHANNELS.NPCS_CREATE, data),
  update: (id: string, data: unknown) =>
    window.anvil.invoke<unknown>(IPC_CHANNELS.NPCS_UPDATE, id, data),
  delete: (id: string) =>
    window.anvil.invoke<void>(IPC_CHANNELS.NPCS_DELETE, id),
  restore: (id: string) =>
    window.anvil.invoke<void>(IPC_CHANNELS.NPCS_RESTORE, id),
}

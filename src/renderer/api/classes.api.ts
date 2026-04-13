import { IPC_CHANNELS } from '../../shared/ipc-channels'

// Full types defined in the Character Classes epic
export const classesApi = {
  list: (includeDeleted = false) =>
    window.anvil.invoke<unknown[]>(IPC_CHANNELS.CLASSES_LIST, { includeDeleted }),
  get: (id: string) =>
    window.anvil.invoke<unknown>(IPC_CHANNELS.CLASSES_GET, id),
  create: (data: unknown) =>
    window.anvil.invoke<unknown>(IPC_CHANNELS.CLASSES_CREATE, data),
  update: (id: string, data: unknown) =>
    window.anvil.invoke<unknown>(IPC_CHANNELS.CLASSES_UPDATE, id, data),
  delete: (id: string) =>
    window.anvil.invoke<void>(IPC_CHANNELS.CLASSES_DELETE, id),
  restore: (id: string) =>
    window.anvil.invoke<void>(IPC_CHANNELS.CLASSES_RESTORE, id),
}

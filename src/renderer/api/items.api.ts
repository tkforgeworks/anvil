import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type {
  CreateItemInput,
  ItemRecord,
  ItemUsedBy,
  UpdateItemInput,
} from '../../shared/domain-types'

export const itemsApi = {
  list: (includeDeleted = false, deletedOnly = false) =>
    window.anvil.invoke<ItemRecord[]>(IPC_CHANNELS.ITEMS_LIST, { includeDeleted, deletedOnly }),

  get: (id: string) =>
    window.anvil.invoke<ItemRecord | null>(IPC_CHANNELS.ITEMS_GET, id),

  create: (data: CreateItemInput) =>
    window.anvil.invoke<ItemRecord>(IPC_CHANNELS.ITEMS_CREATE, data),

  update: (id: string, data: UpdateItemInput) =>
    window.anvil.invoke<ItemRecord | null>(IPC_CHANNELS.ITEMS_UPDATE, id, data),

  delete: (id: string) =>
    window.anvil.invoke<void>(IPC_CHANNELS.ITEMS_DELETE, id),

  restore: (id: string) =>
    window.anvil.invoke<void>(IPC_CHANNELS.ITEMS_RESTORE, id),

  hardDelete: (id: string) =>
    window.anvil.invoke<void>(IPC_CHANNELS.ITEMS_HARD_DELETE, id),

  duplicate: (id: string) =>
    window.anvil.invoke<ItemRecord | null>(IPC_CHANNELS.ITEMS_DUPLICATE, id),

  getUsedBy: (id: string) =>
    window.anvil.invoke<ItemUsedBy>(IPC_CHANNELS.ITEMS_GET_USED_BY, id),
}

import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type {
  CreateLootTableInput,
  LootTableRecord,
  UpdateLootTableInput,
} from '../../shared/domain-types'

export const lootTablesApi = {
  list: (includeDeleted = false) =>
    window.anvil.invoke<LootTableRecord[]>(IPC_CHANNELS.LOOT_TABLES_LIST, { includeDeleted }),

  get: (id: string) =>
    window.anvil.invoke<LootTableRecord | null>(IPC_CHANNELS.LOOT_TABLES_GET, id),

  create: (data: CreateLootTableInput) =>
    window.anvil.invoke<LootTableRecord>(IPC_CHANNELS.LOOT_TABLES_CREATE, data),

  update: (id: string, data: UpdateLootTableInput) =>
    window.anvil.invoke<LootTableRecord | null>(IPC_CHANNELS.LOOT_TABLES_UPDATE, id, data),

  delete: (id: string) =>
    window.anvil.invoke<void>(IPC_CHANNELS.LOOT_TABLES_DELETE, id),

  restore: (id: string) =>
    window.anvil.invoke<void>(IPC_CHANNELS.LOOT_TABLES_RESTORE, id),
}

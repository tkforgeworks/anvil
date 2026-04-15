import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type {
  CreateLootTableEntryInput,
  CreateLootTableInput,
  UpdateLootTableInput,
} from '../../shared/domain-types'
import { markProjectDirty } from '../project/project-service'
import { lootTableRepository } from '../repositories'

export function registerLootTablesHandlers(): void {
  ipcMain.handle(
    IPC_CHANNELS.LOOT_TABLES_LIST,
    (_event, options?: { includeDeleted?: boolean }) =>
      lootTableRepository.list(options?.includeDeleted ?? false),
  )

  ipcMain.handle(IPC_CHANNELS.LOOT_TABLES_GET, (_event, id: string) =>
    lootTableRepository.get(id),
  )

  ipcMain.handle(IPC_CHANNELS.LOOT_TABLES_CREATE, (_event, data: CreateLootTableInput) => {
    const record = lootTableRepository.create(data)
    markProjectDirty()
    return record
  })

  ipcMain.handle(
    IPC_CHANNELS.LOOT_TABLES_UPDATE,
    (_event, id: string, data: UpdateLootTableInput) => {
      const record = lootTableRepository.update(id, data)
      if (record) markProjectDirty()
      return record
    },
  )

  ipcMain.handle(IPC_CHANNELS.LOOT_TABLES_DELETE, (_event, id: string) => {
    lootTableRepository.softDelete(id)
    markProjectDirty()
  })

  ipcMain.handle(IPC_CHANNELS.LOOT_TABLES_RESTORE, (_event, id: string) => {
    lootTableRepository.restore(id)
    markProjectDirty()
  })

  ipcMain.handle(IPC_CHANNELS.LOOT_TABLES_DUPLICATE, (_event, id: string) => {
    const record = lootTableRepository.duplicate(id)
    if (record) markProjectDirty()
    return record
  })

  ipcMain.handle(IPC_CHANNELS.LOOT_TABLES_GET_ENTRIES, (_event, id: string) =>
    lootTableRepository.getEntries(id),
  )

  ipcMain.handle(
    IPC_CHANNELS.LOOT_TABLES_SET_ENTRIES,
    (_event, id: string, entries: CreateLootTableEntryInput[]) => {
      const result = lootTableRepository.setEntries(id, entries)
      markProjectDirty()
      return result
    },
  )
}

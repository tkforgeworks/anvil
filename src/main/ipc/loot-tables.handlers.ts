import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type {
  CreateLootTableEntryInput,
  CreateLootTableInput,
  UpdateLootTableInput,
} from '../../shared/domain-types'
import { markProjectDirty } from '../project/project-service'
import type { ChangeEntry } from '../project/change-accumulator'
import { lootTableRepository } from '../repositories'

export function registerLootTablesHandlers(): void {
  ipcMain.handle(
    IPC_CHANNELS.LOOT_TABLES_LIST,
    (_event, options?: { includeDeleted?: boolean; deletedOnly?: boolean }) =>
      lootTableRepository.list(options?.includeDeleted ?? false, options?.deletedOnly ?? false),
  )

  ipcMain.handle(IPC_CHANNELS.LOOT_TABLES_GET, (_event, id: string) =>
    lootTableRepository.get(id),
  )

  ipcMain.handle(IPC_CHANNELS.LOOT_TABLES_CREATE, (_event, data: CreateLootTableInput) => {
    const record = lootTableRepository.create(data)
    markProjectDirty({ domain: 'loot-tables', recordId: record.id, recordName: record.displayName, subArea: 'basic-info', action: 'create' })
    return record
  })

  ipcMain.handle(
    IPC_CHANNELS.LOOT_TABLES_UPDATE,
    (_event, id: string, data: UpdateLootTableInput) => {
      const record = lootTableRepository.update(id, data)
      if (record) markProjectDirty({ domain: 'loot-tables', recordId: record.id, recordName: record.displayName, subArea: 'basic-info', action: 'update' })
      return record
    },
  )

  ipcMain.handle(IPC_CHANNELS.LOOT_TABLES_DELETE, (_event, id: string) => {
    const record = lootTableRepository.get(id)
    lootTableRepository.softDelete(id)
    markProjectDirty({ domain: 'loot-tables', recordId: id, recordName: record?.displayName ?? id, subArea: 'basic-info', action: 'delete' })
  })

  ipcMain.handle(IPC_CHANNELS.LOOT_TABLES_RESTORE, (_event, id: string) => {
    lootTableRepository.restore(id)
    const record = lootTableRepository.get(id)
    markProjectDirty({ domain: 'loot-tables', recordId: id, recordName: record?.displayName ?? id, subArea: 'basic-info', action: 'restore' })
  })

  ipcMain.handle(IPC_CHANNELS.LOOT_TABLES_HARD_DELETE, (_event, id: string) => {
    lootTableRepository.hardDelete(id)
    markProjectDirty({ domain: 'loot-tables', recordId: id, recordName: id, subArea: 'basic-info', action: 'hard-delete' })
  })

  ipcMain.handle(IPC_CHANNELS.LOOT_TABLES_DUPLICATE, (_event, id: string) => {
    const record = lootTableRepository.duplicate(id)
    if (record) markProjectDirty({ domain: 'loot-tables', recordId: record.id, recordName: record.displayName, subArea: 'basic-info', action: 'duplicate' })
    return record
  })

  ipcMain.handle(IPC_CHANNELS.LOOT_TABLES_GET_ENTRIES, (_event, id: string) =>
    lootTableRepository.getEntries(id),
  )

  ipcMain.handle(
    IPC_CHANNELS.LOOT_TABLES_SET_ENTRIES,
    (_event, id: string, entries: CreateLootTableEntryInput[]) => {
      const result = lootTableRepository.setEntries(id, entries)
      const record = lootTableRepository.get(id)
      markProjectDirty({ domain: 'loot-tables', recordId: id, recordName: record?.displayName ?? id, subArea: 'entries', action: 'update' })
      return result
    },
  )

  ipcMain.handle(IPC_CHANNELS.LOOT_TABLES_GET_USED_BY, (_event, id: string) =>
    lootTableRepository.getUsedBy(id),
  )
}

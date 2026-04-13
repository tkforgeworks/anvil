import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import { lootTableRepository } from '../repositories'

export function registerLootTablesHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.LOOT_TABLES_LIST, (_event, options?: { includeDeleted?: boolean }) =>
    lootTableRepository.list(options?.includeDeleted ?? false),
  )
  ipcMain.handle(IPC_CHANNELS.LOOT_TABLES_GET, (_event, id: string) => lootTableRepository.get(id))
  ipcMain.handle(IPC_CHANNELS.LOOT_TABLES_CREATE, () => null)
  ipcMain.handle(IPC_CHANNELS.LOOT_TABLES_UPDATE, () => null)
  ipcMain.handle(IPC_CHANNELS.LOOT_TABLES_DELETE, (_event, id: string) =>
    lootTableRepository.softDelete(id),
  )
  ipcMain.handle(IPC_CHANNELS.LOOT_TABLES_RESTORE, (_event, id: string) =>
    lootTableRepository.restore(id),
  )
}

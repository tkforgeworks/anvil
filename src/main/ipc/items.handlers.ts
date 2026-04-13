import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import { markProjectDirty } from '../project/project-service'
import { itemRepository } from '../repositories'

export function registerItemsHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.ITEMS_LIST, (_event, options?: { includeDeleted?: boolean }) =>
    itemRepository.list(options?.includeDeleted ?? false),
  )
  ipcMain.handle(IPC_CHANNELS.ITEMS_GET, (_event, id: string) => itemRepository.get(id))
  ipcMain.handle(IPC_CHANNELS.ITEMS_CREATE, () => null)
  ipcMain.handle(IPC_CHANNELS.ITEMS_UPDATE, () => null)
  ipcMain.handle(IPC_CHANNELS.ITEMS_DELETE, (_event, id: string) => {
    itemRepository.softDelete(id)
    return markProjectDirty()
  })
  ipcMain.handle(IPC_CHANNELS.ITEMS_RESTORE, (_event, id: string) => {
    itemRepository.restore(id)
    return markProjectDirty()
  })
}

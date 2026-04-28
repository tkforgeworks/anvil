import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type { CreateItemInput, UpdateItemInput } from '../../shared/domain-types'
import { markProjectDirty } from '../project/project-service'
import type { ChangeEntry } from '../project/change-accumulator'
import { itemRepository } from '../repositories'

export function registerItemsHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.ITEMS_LIST, (_event, options?: { includeDeleted?: boolean; deletedOnly?: boolean }) =>
    itemRepository.list(options?.includeDeleted ?? false, options?.deletedOnly ?? false),
  )

  ipcMain.handle(IPC_CHANNELS.ITEMS_GET, (_event, id: string) => itemRepository.get(id))

  ipcMain.handle(IPC_CHANNELS.ITEMS_CREATE, (_event, data: CreateItemInput) => {
    const record = itemRepository.create(data)
    markProjectDirty({ domain: 'items', recordId: record.id, recordName: record.displayName, subArea: 'basic-info', action: 'create' })
    return record
  })

  ipcMain.handle(IPC_CHANNELS.ITEMS_UPDATE, (_event, id: string, data: UpdateItemInput) => {
    const record = itemRepository.update(id, data)
    if (record) markProjectDirty({ domain: 'items', recordId: record.id, recordName: record.displayName, subArea: 'basic-info', action: 'update' })
    return record
  })

  ipcMain.handle(IPC_CHANNELS.ITEMS_DELETE, (_event, id: string) => {
    const record = itemRepository.get(id)
    itemRepository.softDelete(id)
    markProjectDirty({ domain: 'items', recordId: id, recordName: record?.displayName ?? id, subArea: 'basic-info', action: 'delete' })
  })

  ipcMain.handle(IPC_CHANNELS.ITEMS_RESTORE, (_event, id: string) => {
    itemRepository.restore(id)
    const record = itemRepository.get(id)
    markProjectDirty({ domain: 'items', recordId: id, recordName: record?.displayName ?? id, subArea: 'basic-info', action: 'restore' })
  })

  ipcMain.handle(IPC_CHANNELS.ITEMS_HARD_DELETE, (_event, id: string) => {
    itemRepository.hardDelete(id)
    markProjectDirty({ domain: 'items', recordId: id, recordName: id, subArea: 'basic-info', action: 'hard-delete' })
  })

  ipcMain.handle(IPC_CHANNELS.ITEMS_DUPLICATE, (_event, id: string) => {
    const record = itemRepository.duplicate(id)
    if (record) markProjectDirty({ domain: 'items', recordId: record.id, recordName: record.displayName, subArea: 'basic-info', action: 'duplicate' })
    return record
  })
}

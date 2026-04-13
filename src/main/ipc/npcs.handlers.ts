import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type { CreateNpcInput, UpdateNpcInput } from '../../shared/domain-types'
import { markProjectDirty } from '../project/project-service'
import { npcRepository } from '../repositories'

export function registerNpcsHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.NPCS_LIST, (_event, options?: { includeDeleted?: boolean }) =>
    npcRepository.list(options?.includeDeleted ?? false),
  )

  ipcMain.handle(IPC_CHANNELS.NPCS_GET, (_event, id: string) => npcRepository.get(id))

  ipcMain.handle(IPC_CHANNELS.NPCS_CREATE, (_event, data: CreateNpcInput) => {
    const record = npcRepository.create(data)
    markProjectDirty()
    return record
  })

  ipcMain.handle(IPC_CHANNELS.NPCS_UPDATE, (_event, id: string, data: UpdateNpcInput) => {
    const record = npcRepository.update(id, data)
    if (record) markProjectDirty()
    return record
  })

  ipcMain.handle(IPC_CHANNELS.NPCS_DELETE, (_event, id: string) => {
    npcRepository.softDelete(id)
    return markProjectDirty()
  })

  ipcMain.handle(IPC_CHANNELS.NPCS_RESTORE, (_event, id: string) => {
    npcRepository.restore(id)
    return markProjectDirty()
  })
}

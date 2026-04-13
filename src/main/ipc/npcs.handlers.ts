import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import { npcRepository } from '../repositories'

export function registerNpcsHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.NPCS_LIST, (_event, options?: { includeDeleted?: boolean }) =>
    npcRepository.list(options?.includeDeleted ?? false),
  )
  ipcMain.handle(IPC_CHANNELS.NPCS_GET, (_event, id: string) => npcRepository.get(id))
  ipcMain.handle(IPC_CHANNELS.NPCS_CREATE, () => null)
  ipcMain.handle(IPC_CHANNELS.NPCS_UPDATE, () => null)
  ipcMain.handle(IPC_CHANNELS.NPCS_DELETE, (_event, id: string) => npcRepository.softDelete(id))
  ipcMain.handle(IPC_CHANNELS.NPCS_RESTORE, (_event, id: string) => npcRepository.restore(id))
}

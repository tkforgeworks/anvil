import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import { markProjectDirty } from '../project/project-service'
import { abilityRepository } from '../repositories'

export function registerAbilitiesHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.ABILITIES_LIST, (_event, options?: { includeDeleted?: boolean }) =>
    abilityRepository.list(options?.includeDeleted ?? false),
  )
  ipcMain.handle(IPC_CHANNELS.ABILITIES_GET, (_event, id: string) => abilityRepository.get(id))
  ipcMain.handle(IPC_CHANNELS.ABILITIES_CREATE, () => null)
  ipcMain.handle(IPC_CHANNELS.ABILITIES_UPDATE, () => null)
  ipcMain.handle(IPC_CHANNELS.ABILITIES_DELETE, (_event, id: string) => {
    abilityRepository.softDelete(id)
    return markProjectDirty()
  })
  ipcMain.handle(IPC_CHANNELS.ABILITIES_RESTORE, (_event, id: string) => {
    abilityRepository.restore(id)
    return markProjectDirty()
  })
}

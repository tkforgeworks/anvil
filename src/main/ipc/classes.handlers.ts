import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import { classRepository } from '../repositories'

export function registerClassesHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.CLASSES_LIST, (_event, options?: { includeDeleted?: boolean }) =>
    classRepository.list(options?.includeDeleted ?? false),
  )
  ipcMain.handle(IPC_CHANNELS.CLASSES_GET, (_event, id: string) => classRepository.get(id))
  ipcMain.handle(IPC_CHANNELS.CLASSES_CREATE, () => null)
  ipcMain.handle(IPC_CHANNELS.CLASSES_UPDATE, () => null)
  ipcMain.handle(IPC_CHANNELS.CLASSES_DELETE, (_event, id: string) => classRepository.softDelete(id))
  ipcMain.handle(IPC_CHANNELS.CLASSES_RESTORE, (_event, id: string) => classRepository.restore(id))
}

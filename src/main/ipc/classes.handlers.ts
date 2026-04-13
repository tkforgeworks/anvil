import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type { CreateClassInput, StatGrowthEntry, UpdateClassInput } from '../../shared/domain-types'
import { markProjectDirty } from '../project/project-service'
import { classRepository } from '../repositories'

export function registerClassesHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.CLASSES_LIST, (_event, options?: { includeDeleted?: boolean }) =>
    classRepository.list(options?.includeDeleted ?? false),
  )

  ipcMain.handle(IPC_CHANNELS.CLASSES_GET, (_event, id: string) => classRepository.get(id))

  ipcMain.handle(IPC_CHANNELS.CLASSES_CREATE, (_event, data: CreateClassInput) => {
    const record = classRepository.create(data)
    markProjectDirty()
    return record
  })

  ipcMain.handle(IPC_CHANNELS.CLASSES_UPDATE, (_event, id: string, data: UpdateClassInput) => {
    const record = classRepository.update(id, data)
    if (record) markProjectDirty()
    return record
  })

  ipcMain.handle(IPC_CHANNELS.CLASSES_DELETE, (_event, id: string) => {
    classRepository.softDelete(id)
    return markProjectDirty()
  })

  ipcMain.handle(IPC_CHANNELS.CLASSES_RESTORE, (_event, id: string) => {
    classRepository.restore(id)
    return markProjectDirty()
  })

  ipcMain.handle(IPC_CHANNELS.CLASSES_DUPLICATE, (_event, id: string) => {
    const record = classRepository.duplicate(id)
    if (record) markProjectDirty()
    return record
  })

  ipcMain.handle(IPC_CHANNELS.CLASSES_GET_STAT_GROWTH, (_event, classId: string) =>
    classRepository.getStatGrowth(classId),
  )

  ipcMain.handle(
    IPC_CHANNELS.CLASSES_SET_STAT_GROWTH,
    (_event, classId: string, entries: StatGrowthEntry[]) => {
      classRepository.setStatGrowth(classId, entries)
      markProjectDirty()
    },
  )
}

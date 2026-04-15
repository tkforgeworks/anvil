import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type {
  ClassAbilityAssignment,
  ClassDerivedStatOverride,
  ClassMetadataField,
  CreateClassInput,
  StatGrowthEntry,
  UpdateClassInput,
} from '../../shared/domain-types'
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
    markProjectDirty()
  })

  ipcMain.handle(IPC_CHANNELS.CLASSES_RESTORE, (_event, id: string) => {
    classRepository.restore(id)
    markProjectDirty()
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

  ipcMain.handle(IPC_CHANNELS.CLASSES_GET_DERIVED_STAT_OVERRIDES, (_event, classId: string) =>
    classRepository.getDerivedStatOverrides(classId),
  )

  ipcMain.handle(
    IPC_CHANNELS.CLASSES_SET_DERIVED_STAT_OVERRIDES,
    (_event, classId: string, overrides: ClassDerivedStatOverride[]) => {
      classRepository.setDerivedStatOverrides(classId, overrides)
      markProjectDirty()
    },
  )

  ipcMain.handle(IPC_CHANNELS.CLASSES_GET_METADATA_FIELDS, (_event, classId: string) =>
    classRepository.getMetadataFields(classId),
  )

  ipcMain.handle(
    IPC_CHANNELS.CLASSES_SET_METADATA_FIELDS,
    (_event, classId: string, fields: ClassMetadataField[]) => {
      classRepository.setMetadataFields(classId, fields)
      markProjectDirty()
    },
  )

  ipcMain.handle(IPC_CHANNELS.CLASSES_GET_ABILITY_ASSIGNMENTS, (_event, classId: string) =>
    classRepository.getAbilityAssignments(classId),
  )

  ipcMain.handle(
    IPC_CHANNELS.CLASSES_SET_ABILITY_ASSIGNMENTS,
    (_event, classId: string, assignments: ClassAbilityAssignment[]) => {
      classRepository.setAbilityAssignments(classId, assignments)
      markProjectDirty()
    },
  )
}

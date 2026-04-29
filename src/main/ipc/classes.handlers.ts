import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type {
  ClassAbilityAssignment,
  ClassDerivedStatOverride,
  ClassMetadataField,
  CreateClassInput,
  StatGrowthEntry,
  StatGrowthFormula,
  UpdateClassInput,
} from '../../shared/domain-types'
import { markProjectDirty } from '../project/project-service'
import type { ChangeEntry } from '../project/change-accumulator'
import { classRepository } from '../repositories'
import { getDb } from '../db/connection'

export function registerClassesHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.CLASSES_LIST, (_event, options?: { includeDeleted?: boolean; deletedOnly?: boolean }) =>
    classRepository.list(options?.includeDeleted ?? false, options?.deletedOnly ?? false),
  )

  ipcMain.handle(IPC_CHANNELS.CLASSES_GET, (_event, id: string) => classRepository.get(id))

  ipcMain.handle(IPC_CHANNELS.CLASSES_CREATE, (_event, data: CreateClassInput) => {
    const record = classRepository.create(data)
    markProjectDirty({ domain: 'classes', recordId: record.id, recordName: record.displayName, subArea: 'basic-info', action: 'create' })
    return record
  })

  ipcMain.handle(IPC_CHANNELS.CLASSES_UPDATE, (_event, id: string, data: UpdateClassInput) => {
    const record = classRepository.update(id, data)
    if (record) markProjectDirty({ domain: 'classes', recordId: record.id, recordName: record.displayName, subArea: 'basic-info', action: 'update' })
    return record
  })

  ipcMain.handle(IPC_CHANNELS.CLASSES_DELETE, (_event, id: string) => {
    const record = classRepository.get(id)
    classRepository.softDelete(id)
    markProjectDirty({ domain: 'classes', recordId: id, recordName: record?.displayName ?? id, subArea: 'basic-info', action: 'delete' })
  })

  ipcMain.handle(IPC_CHANNELS.CLASSES_RESTORE, (_event, id: string) => {
    classRepository.restore(id)
    const record = classRepository.get(id)
    markProjectDirty({ domain: 'classes', recordId: id, recordName: record?.displayName ?? id, subArea: 'basic-info', action: 'restore' })
  })

  ipcMain.handle(IPC_CHANNELS.CLASSES_HARD_DELETE, (_event, id: string) => {
    classRepository.hardDelete(id)
    markProjectDirty({ domain: 'classes', recordId: id, recordName: id, subArea: 'basic-info', action: 'hard-delete' })
  })

  ipcMain.handle(IPC_CHANNELS.CLASSES_DUPLICATE, (_event, id: string) => {
    const record = classRepository.duplicate(id)
    if (record) markProjectDirty({ domain: 'classes', recordId: record.id, recordName: record.displayName, subArea: 'basic-info', action: 'duplicate' })
    return record
  })

  ipcMain.handle(IPC_CHANNELS.CLASSES_GET_STAT_GROWTH, (_event, classId: string) => {
    const { max_level } = getDb()
      .prepare('SELECT max_level FROM project_info LIMIT 1')
      .get() as { max_level: number }
    return classRepository.getStatGrowthWithFormulas(classId, max_level)
  })

  ipcMain.handle(
    IPC_CHANNELS.CLASSES_SET_STAT_GROWTH,
    (_event, classId: string, entries: StatGrowthEntry[]) => {
      classRepository.setStatGrowth(classId, entries)
      const record = classRepository.get(classId)
      markProjectDirty({ domain: 'classes', recordId: classId, recordName: record?.displayName ?? classId, subArea: 'stat-growth', action: 'update' })
    },
  )

  ipcMain.handle(IPC_CHANNELS.CLASSES_GET_STAT_GROWTH_FORMULAS, (_event, classId: string) =>
    classRepository.getStatGrowthFormulas(classId),
  )

  ipcMain.handle(
    IPC_CHANNELS.CLASSES_SET_STAT_GROWTH_FORMULAS,
    (_event, classId: string, formulas: StatGrowthFormula[]) => {
      classRepository.setStatGrowthFormulas(classId, formulas)
      const record = classRepository.get(classId)
      markProjectDirty({ domain: 'classes', recordId: classId, recordName: record?.displayName ?? classId, subArea: 'stat-growth-formulas', action: 'update' })
    },
  )

  ipcMain.handle(IPC_CHANNELS.CLASSES_GET_DERIVED_STAT_OVERRIDES, (_event, classId: string) =>
    classRepository.getDerivedStatOverrides(classId),
  )

  ipcMain.handle(
    IPC_CHANNELS.CLASSES_SET_DERIVED_STAT_OVERRIDES,
    (_event, classId: string, overrides: ClassDerivedStatOverride[]) => {
      classRepository.setDerivedStatOverrides(classId, overrides)
      const record = classRepository.get(classId)
      markProjectDirty({ domain: 'classes', recordId: classId, recordName: record?.displayName ?? classId, subArea: 'derived-stat-overrides', action: 'update' })
    },
  )

  ipcMain.handle(IPC_CHANNELS.CLASSES_GET_METADATA_FIELDS, (_event, classId: string) =>
    classRepository.getMetadataFields(classId),
  )

  ipcMain.handle(
    IPC_CHANNELS.CLASSES_SET_METADATA_FIELDS,
    (_event, classId: string, fields: ClassMetadataField[]) => {
      classRepository.setMetadataFields(classId, fields)
      const record = classRepository.get(classId)
      markProjectDirty({ domain: 'classes', recordId: classId, recordName: record?.displayName ?? classId, subArea: 'metadata-fields', action: 'update' })
    },
  )

  ipcMain.handle(IPC_CHANNELS.CLASSES_GET_ABILITY_ASSIGNMENTS, (_event, classId: string) =>
    classRepository.getAbilityAssignments(classId),
  )

  ipcMain.handle(
    IPC_CHANNELS.CLASSES_SET_ABILITY_ASSIGNMENTS,
    (_event, classId: string, assignments: ClassAbilityAssignment[]) => {
      classRepository.setAbilityAssignments(classId, assignments)
      const record = classRepository.get(classId)
      markProjectDirty({ domain: 'classes', recordId: classId, recordName: record?.displayName ?? classId, subArea: 'ability-assignments', action: 'update' })
    },
  )

  ipcMain.handle(IPC_CHANNELS.CLASSES_GET_USED_BY, (_event, id: string) =>
    classRepository.getUsedBy(id),
  )
}

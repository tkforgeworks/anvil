import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type {
  ClassAbilityAssignment,
  ClassDerivedStatOverride,
  ClassMetadataField,
  ClassRecord,
  CreateClassInput,
  StatGrowthEntry,
  UpdateClassInput,
} from '../../shared/domain-types'

export const classesApi = {
  list: (includeDeleted = false) =>
    window.anvil.invoke<ClassRecord[]>(IPC_CHANNELS.CLASSES_LIST, { includeDeleted }),

  get: (id: string) =>
    window.anvil.invoke<ClassRecord | null>(IPC_CHANNELS.CLASSES_GET, id),

  create: (data: CreateClassInput) =>
    window.anvil.invoke<ClassRecord>(IPC_CHANNELS.CLASSES_CREATE, data),

  update: (id: string, data: UpdateClassInput) =>
    window.anvil.invoke<ClassRecord | null>(IPC_CHANNELS.CLASSES_UPDATE, id, data),

  delete: (id: string) =>
    window.anvil.invoke<void>(IPC_CHANNELS.CLASSES_DELETE, id),

  restore: (id: string) =>
    window.anvil.invoke<void>(IPC_CHANNELS.CLASSES_RESTORE, id),

  duplicate: (id: string) =>
    window.anvil.invoke<ClassRecord | null>(IPC_CHANNELS.CLASSES_DUPLICATE, id),

  getStatGrowth: (classId: string) =>
    window.anvil.invoke<StatGrowthEntry[]>(IPC_CHANNELS.CLASSES_GET_STAT_GROWTH, classId),

  setStatGrowth: (classId: string, entries: StatGrowthEntry[]) =>
    window.anvil.invoke<void>(IPC_CHANNELS.CLASSES_SET_STAT_GROWTH, classId, entries),

  getDerivedStatOverrides: (classId: string) =>
    window.anvil.invoke<ClassDerivedStatOverride[]>(
      IPC_CHANNELS.CLASSES_GET_DERIVED_STAT_OVERRIDES,
      classId,
    ),

  setDerivedStatOverrides: (classId: string, overrides: ClassDerivedStatOverride[]) =>
    window.anvil.invoke<void>(IPC_CHANNELS.CLASSES_SET_DERIVED_STAT_OVERRIDES, classId, overrides),

  getMetadataFields: (classId: string) =>
    window.anvil.invoke<ClassMetadataField[]>(IPC_CHANNELS.CLASSES_GET_METADATA_FIELDS, classId),

  setMetadataFields: (classId: string, fields: ClassMetadataField[]) =>
    window.anvil.invoke<void>(IPC_CHANNELS.CLASSES_SET_METADATA_FIELDS, classId, fields),

  getAbilityAssignments: (classId: string) =>
    window.anvil.invoke<ClassAbilityAssignment[]>(
      IPC_CHANNELS.CLASSES_GET_ABILITY_ASSIGNMENTS,
      classId,
    ),

  setAbilityAssignments: (classId: string, assignments: ClassAbilityAssignment[]) =>
    window.anvil.invoke<void>(IPC_CHANNELS.CLASSES_SET_ABILITY_ASSIGNMENTS, classId, assignments),
}

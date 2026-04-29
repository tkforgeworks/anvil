import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type {
  ClassAbilityAssignment,
  ClassDerivedStatOverride,
  ClassMetadataField,
  ClassRecord,
  ClassUsedBy,
  CreateClassInput,
  StatGrowthData,
  StatGrowthEntry,
  StatGrowthFormula,
  UpdateClassInput,
} from '../../shared/domain-types'

export const classesApi = {
  list: (includeDeleted = false, deletedOnly = false) =>
    window.anvil.invoke<ClassRecord[]>(IPC_CHANNELS.CLASSES_LIST, { includeDeleted, deletedOnly }),

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

  hardDelete: (id: string) =>
    window.anvil.invoke<void>(IPC_CHANNELS.CLASSES_HARD_DELETE, id),

  duplicate: (id: string) =>
    window.anvil.invoke<ClassRecord | null>(IPC_CHANNELS.CLASSES_DUPLICATE, id),

  getStatGrowth: (classId: string) =>
    window.anvil.invoke<StatGrowthData>(IPC_CHANNELS.CLASSES_GET_STAT_GROWTH, classId),

  setStatGrowth: (classId: string, entries: StatGrowthEntry[]) =>
    window.anvil.invoke<void>(IPC_CHANNELS.CLASSES_SET_STAT_GROWTH, classId, entries),

  getStatGrowthFormulas: (classId: string) =>
    window.anvil.invoke<StatGrowthFormula[]>(IPC_CHANNELS.CLASSES_GET_STAT_GROWTH_FORMULAS, classId),

  setStatGrowthFormulas: (classId: string, formulas: StatGrowthFormula[]) =>
    window.anvil.invoke<void>(IPC_CHANNELS.CLASSES_SET_STAT_GROWTH_FORMULAS, classId, formulas),

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

  getUsedBy: (id: string) =>
    window.anvil.invoke<ClassUsedBy>(IPC_CHANNELS.CLASSES_GET_USED_BY, id),
}

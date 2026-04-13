import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type {
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
}

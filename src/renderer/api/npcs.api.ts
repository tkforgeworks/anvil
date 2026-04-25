import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type {
  CreateNpcInput,
  NpcAbilityAssignment,
  NpcClassAssignment,
  NpcRecord,
  UpdateNpcInput,
} from '../../shared/domain-types'

export const npcsApi = {
  list: (includeDeleted = false, deletedOnly = false) =>
    window.anvil.invoke<NpcRecord[]>(IPC_CHANNELS.NPCS_LIST, { includeDeleted, deletedOnly }),

  get: (id: string) =>
    window.anvil.invoke<NpcRecord | null>(IPC_CHANNELS.NPCS_GET, id),

  create: (data: CreateNpcInput) =>
    window.anvil.invoke<NpcRecord>(IPC_CHANNELS.NPCS_CREATE, data),

  update: (id: string, data: UpdateNpcInput) =>
    window.anvil.invoke<NpcRecord | null>(IPC_CHANNELS.NPCS_UPDATE, id, data),

  delete: (id: string) =>
    window.anvil.invoke<void>(IPC_CHANNELS.NPCS_DELETE, id),

  restore: (id: string) =>
    window.anvil.invoke<void>(IPC_CHANNELS.NPCS_RESTORE, id),

  hardDelete: (id: string) =>
    window.anvil.invoke<void>(IPC_CHANNELS.NPCS_HARD_DELETE, id),

  duplicate: (id: string) =>
    window.anvil.invoke<NpcRecord | null>(IPC_CHANNELS.NPCS_DUPLICATE, id),

  getClassAssignments: (id: string) =>
    window.anvil.invoke<NpcClassAssignment[]>(IPC_CHANNELS.NPCS_GET_CLASS_ASSIGNMENTS, id),

  setClassAssignments: (id: string, assignments: NpcClassAssignment[]) =>
    window.anvil.invoke<void>(IPC_CHANNELS.NPCS_SET_CLASS_ASSIGNMENTS, id, assignments),

  getAbilityAssignments: (id: string) =>
    window.anvil.invoke<NpcAbilityAssignment[]>(IPC_CHANNELS.NPCS_GET_ABILITY_ASSIGNMENTS, id),

  setAbilityAssignments: (id: string, assignments: NpcAbilityAssignment[]) =>
    window.anvil.invoke<void>(IPC_CHANNELS.NPCS_SET_ABILITY_ASSIGNMENTS, id, assignments),
}

import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type {
  AbilityRecord,
  AbilityUsedBy,
  CreateAbilityInput,
  UpdateAbilityInput,
} from '../../shared/domain-types'

export const abilitiesApi = {
  list: (includeDeleted = false, deletedOnly = false) =>
    window.anvil.invoke<AbilityRecord[]>(IPC_CHANNELS.ABILITIES_LIST, { includeDeleted, deletedOnly }),

  get: (id: string) =>
    window.anvil.invoke<AbilityRecord | null>(IPC_CHANNELS.ABILITIES_GET, id),

  create: (data: CreateAbilityInput) =>
    window.anvil.invoke<AbilityRecord>(IPC_CHANNELS.ABILITIES_CREATE, data),

  update: (id: string, data: UpdateAbilityInput) =>
    window.anvil.invoke<AbilityRecord | null>(IPC_CHANNELS.ABILITIES_UPDATE, id, data),

  delete: (id: string) =>
    window.anvil.invoke<void>(IPC_CHANNELS.ABILITIES_DELETE, id),

  restore: (id: string) =>
    window.anvil.invoke<void>(IPC_CHANNELS.ABILITIES_RESTORE, id),

  hardDelete: (id: string) =>
    window.anvil.invoke<void>(IPC_CHANNELS.ABILITIES_HARD_DELETE, id),

  duplicate: (id: string) =>
    window.anvil.invoke<AbilityRecord | null>(IPC_CHANNELS.ABILITIES_DUPLICATE, id),

  getUsedBy: (id: string) =>
    window.anvil.invoke<AbilityUsedBy>(IPC_CHANNELS.ABILITIES_GET_USED_BY, id),
}

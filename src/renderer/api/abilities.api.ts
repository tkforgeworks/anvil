import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type {
  AbilityRecord,
  CreateAbilityInput,
  UpdateAbilityInput,
} from '../../shared/domain-types'

export const abilitiesApi = {
  list: (includeDeleted = false) =>
    window.anvil.invoke<AbilityRecord[]>(IPC_CHANNELS.ABILITIES_LIST, { includeDeleted }),

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
}

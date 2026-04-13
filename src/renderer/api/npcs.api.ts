import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type {
  CreateNpcInput,
  NpcRecord,
  UpdateNpcInput,
} from '../../shared/domain-types'

export const npcsApi = {
  list: (includeDeleted = false) =>
    window.anvil.invoke<NpcRecord[]>(IPC_CHANNELS.NPCS_LIST, { includeDeleted }),

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
}

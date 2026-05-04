import { IPC_CHANNELS } from '../../shared/ipc-channels'
import { safeHandle } from './safe-handle'
import type {
  CreateNpcInput,
  NpcAbilityAssignment,
  NpcClassAssignment,
  UpdateNpcInput,
} from '../../shared/domain-types'
import { markProjectDirty } from '../project/project-service'
import type { ChangeEntry } from '../project/change-accumulator'
import { npcRepository } from '../repositories'

export function registerNpcsHandlers(): void {
  safeHandle(IPC_CHANNELS.NPCS_LIST, (_event, options?: { includeDeleted?: boolean; deletedOnly?: boolean }) =>
    npcRepository.list(options?.includeDeleted ?? false, options?.deletedOnly ?? false),
  )

  safeHandle(IPC_CHANNELS.NPCS_GET, (_event, id: string) => npcRepository.get(id))

  safeHandle(IPC_CHANNELS.NPCS_CREATE, (_event, data: CreateNpcInput) => {
    const record = npcRepository.create(data)
    markProjectDirty({ domain: 'npcs', recordId: record.id, recordName: record.displayName, subArea: 'basic-info', action: 'create' })
    return record
  })

  safeHandle(IPC_CHANNELS.NPCS_UPDATE, (_event, id: string, data: UpdateNpcInput) => {
    const record = npcRepository.update(id, data)
    if (record) markProjectDirty({ domain: 'npcs', recordId: record.id, recordName: record.displayName, subArea: 'basic-info', action: 'update' })
    return record
  })

  safeHandle(IPC_CHANNELS.NPCS_DELETE, (_event, id: string) => {
    const record = npcRepository.get(id)
    npcRepository.softDelete(id)
    markProjectDirty({ domain: 'npcs', recordId: id, recordName: record?.displayName ?? id, subArea: 'basic-info', action: 'delete' })
  })

  safeHandle(IPC_CHANNELS.NPCS_RESTORE, (_event, id: string) => {
    npcRepository.restore(id)
    const record = npcRepository.get(id)
    markProjectDirty({ domain: 'npcs', recordId: id, recordName: record?.displayName ?? id, subArea: 'basic-info', action: 'restore' })
  })

  safeHandle(IPC_CHANNELS.NPCS_HARD_DELETE, (_event, id: string) => {
    npcRepository.hardDelete(id)
    markProjectDirty({ domain: 'npcs', recordId: id, recordName: id, subArea: 'basic-info', action: 'hard-delete' })
  })

  safeHandle(IPC_CHANNELS.NPCS_DUPLICATE, (_event, id: string) => {
    const record = npcRepository.duplicate(id)
    if (record) markProjectDirty({ domain: 'npcs', recordId: record.id, recordName: record.displayName, subArea: 'basic-info', action: 'duplicate' })
    return record
  })

  safeHandle(IPC_CHANNELS.NPCS_GET_CLASS_ASSIGNMENTS, (_event, id: string) =>
    npcRepository.getClassAssignments(id),
  )

  safeHandle(
    IPC_CHANNELS.NPCS_SET_CLASS_ASSIGNMENTS,
    (_event, id: string, assignments: NpcClassAssignment[]) => {
      npcRepository.setClassAssignments(id, assignments)
      const record = npcRepository.get(id)
      markProjectDirty({ domain: 'npcs', recordId: id, recordName: record?.displayName ?? id, subArea: 'class-assignments', action: 'update' })
    },
  )

  safeHandle(IPC_CHANNELS.NPCS_GET_ABILITY_ASSIGNMENTS, (_event, id: string) =>
    npcRepository.getAbilityAssignments(id),
  )

  safeHandle(
    IPC_CHANNELS.NPCS_SET_ABILITY_ASSIGNMENTS,
    (_event, id: string, assignments: NpcAbilityAssignment[]) => {
      npcRepository.setAbilityAssignments(id, assignments)
      const record = npcRepository.get(id)
      markProjectDirty({ domain: 'npcs', recordId: id, recordName: record?.displayName ?? id, subArea: 'ability-assignments', action: 'update' })
    },
  )
}

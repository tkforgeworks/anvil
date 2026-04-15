import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type {
  CreateNpcInput,
  NpcAbilityAssignment,
  NpcClassAssignment,
  UpdateNpcInput,
} from '../../shared/domain-types'
import { markProjectDirty } from '../project/project-service'
import { npcRepository } from '../repositories'

export function registerNpcsHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.NPCS_LIST, (_event, options?: { includeDeleted?: boolean }) =>
    npcRepository.list(options?.includeDeleted ?? false),
  )

  ipcMain.handle(IPC_CHANNELS.NPCS_GET, (_event, id: string) => npcRepository.get(id))

  ipcMain.handle(IPC_CHANNELS.NPCS_CREATE, (_event, data: CreateNpcInput) => {
    const record = npcRepository.create(data)
    markProjectDirty()
    return record
  })

  ipcMain.handle(IPC_CHANNELS.NPCS_UPDATE, (_event, id: string, data: UpdateNpcInput) => {
    const record = npcRepository.update(id, data)
    if (record) markProjectDirty()
    return record
  })

  ipcMain.handle(IPC_CHANNELS.NPCS_DELETE, (_event, id: string) => {
    npcRepository.softDelete(id)
    markProjectDirty()
  })

  ipcMain.handle(IPC_CHANNELS.NPCS_RESTORE, (_event, id: string) => {
    npcRepository.restore(id)
    markProjectDirty()
  })

  ipcMain.handle(IPC_CHANNELS.NPCS_DUPLICATE, (_event, id: string) => {
    const record = npcRepository.duplicate(id)
    if (record) markProjectDirty()
    return record
  })

  ipcMain.handle(IPC_CHANNELS.NPCS_GET_CLASS_ASSIGNMENTS, (_event, id: string) =>
    npcRepository.getClassAssignments(id),
  )

  ipcMain.handle(
    IPC_CHANNELS.NPCS_SET_CLASS_ASSIGNMENTS,
    (_event, id: string, assignments: NpcClassAssignment[]) => {
      npcRepository.setClassAssignments(id, assignments)
      markProjectDirty()
    },
  )

  ipcMain.handle(IPC_CHANNELS.NPCS_GET_ABILITY_ASSIGNMENTS, (_event, id: string) =>
    npcRepository.getAbilityAssignments(id),
  )

  ipcMain.handle(
    IPC_CHANNELS.NPCS_SET_ABILITY_ASSIGNMENTS,
    (_event, id: string, assignments: NpcAbilityAssignment[]) => {
      npcRepository.setAbilityAssignments(id, assignments)
      markProjectDirty()
    },
  )
}

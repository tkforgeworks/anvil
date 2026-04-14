import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type { CreateAbilityInput, UpdateAbilityInput } from '../../shared/domain-types'
import { markProjectDirty } from '../project/project-service'
import { abilityRepository } from '../repositories'

export function registerAbilitiesHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.ABILITIES_LIST, (_event, options?: { includeDeleted?: boolean }) =>
    abilityRepository.list(options?.includeDeleted ?? false),
  )

  ipcMain.handle(IPC_CHANNELS.ABILITIES_GET, (_event, id: string) => abilityRepository.get(id))

  ipcMain.handle(IPC_CHANNELS.ABILITIES_CREATE, (_event, data: CreateAbilityInput) => {
    const record = abilityRepository.create(data)
    markProjectDirty()
    return record
  })

  ipcMain.handle(IPC_CHANNELS.ABILITIES_UPDATE, (_event, id: string, data: UpdateAbilityInput) => {
    const record = abilityRepository.update(id, data)
    if (record) markProjectDirty()
    return record
  })

  ipcMain.handle(IPC_CHANNELS.ABILITIES_DELETE, (_event, id: string) => {
    abilityRepository.softDelete(id)
    return markProjectDirty()
  })

  ipcMain.handle(IPC_CHANNELS.ABILITIES_RESTORE, (_event, id: string) => {
    abilityRepository.restore(id)
    return markProjectDirty()
  })

  ipcMain.handle(IPC_CHANNELS.ABILITIES_DUPLICATE, (_event, id: string) => {
    const record = abilityRepository.duplicate(id)
    if (record) markProjectDirty()
    return record
  })

  ipcMain.handle(IPC_CHANNELS.ABILITIES_GET_USED_BY, (_event, id: string) =>
    abilityRepository.getUsedBy(id),
  )
}

import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type { CreateAbilityInput, UpdateAbilityInput } from '../../shared/domain-types'
import { markProjectDirty } from '../project/project-service'
import type { ChangeEntry } from '../project/change-accumulator'
import { abilityRepository } from '../repositories'

export function registerAbilitiesHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.ABILITIES_LIST, (_event, options?: { includeDeleted?: boolean; deletedOnly?: boolean }) =>
    abilityRepository.list(options?.includeDeleted ?? false, options?.deletedOnly ?? false),
  )

  ipcMain.handle(IPC_CHANNELS.ABILITIES_GET, (_event, id: string) => abilityRepository.get(id))

  ipcMain.handle(IPC_CHANNELS.ABILITIES_CREATE, (_event, data: CreateAbilityInput) => {
    const record = abilityRepository.create(data)
    markProjectDirty({ domain: 'abilities', recordId: record.id, recordName: record.displayName, subArea: 'basic-info', action: 'create' })
    return record
  })

  ipcMain.handle(IPC_CHANNELS.ABILITIES_UPDATE, (_event, id: string, data: UpdateAbilityInput) => {
    const record = abilityRepository.update(id, data)
    if (record) markProjectDirty({ domain: 'abilities', recordId: record.id, recordName: record.displayName, subArea: 'basic-info', action: 'update' })
    return record
  })

  ipcMain.handle(IPC_CHANNELS.ABILITIES_DELETE, (_event, id: string) => {
    const record = abilityRepository.get(id)
    abilityRepository.softDelete(id)
    markProjectDirty({ domain: 'abilities', recordId: id, recordName: record?.displayName ?? id, subArea: 'basic-info', action: 'delete' })
  })

  ipcMain.handle(IPC_CHANNELS.ABILITIES_RESTORE, (_event, id: string) => {
    abilityRepository.restore(id)
    const record = abilityRepository.get(id)
    markProjectDirty({ domain: 'abilities', recordId: id, recordName: record?.displayName ?? id, subArea: 'basic-info', action: 'restore' })
  })

  ipcMain.handle(IPC_CHANNELS.ABILITIES_HARD_DELETE, (_event, id: string) => {
    abilityRepository.hardDelete(id)
    markProjectDirty({ domain: 'abilities', recordId: id, recordName: id, subArea: 'basic-info', action: 'hard-delete' })
  })

  ipcMain.handle(IPC_CHANNELS.ABILITIES_DUPLICATE, (_event, id: string) => {
    const record = abilityRepository.duplicate(id)
    if (record) markProjectDirty({ domain: 'abilities', recordId: record.id, recordName: record.displayName, subArea: 'basic-info', action: 'duplicate' })
    return record
  })

  ipcMain.handle(IPC_CHANNELS.ABILITIES_GET_USED_BY, (_event, id: string) =>
    abilityRepository.getUsedBy(id),
  )
}

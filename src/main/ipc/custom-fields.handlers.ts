import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type {
  CreateCustomFieldDefinitionInput,
  CustomFieldValue,
  UpdateCustomFieldDefinitionInput,
} from '../../shared/domain-types'
import {
  customFieldDefinitionRepository,
  itemRepository,
  npcRepository,
} from '../repositories'
import { markProjectDirty } from '../project/project-service'

export function registerCustomFieldsHandlers(): void {
  ipcMain.handle(
    IPC_CHANNELS.CUSTOM_FIELDS_LIST_DEFINITIONS,
    (_event, { scopeType, scopeId }: { scopeType: string; scopeId: string }) => {
      return customFieldDefinitionRepository.listByScope(scopeType, scopeId)
    },
  )

  ipcMain.handle(
    IPC_CHANNELS.CUSTOM_FIELDS_CREATE_DEFINITION,
    (_event, input: CreateCustomFieldDefinitionInput) => {
      const record = customFieldDefinitionRepository.create(input)
      markProjectDirty()
      return record
    },
  )

  ipcMain.handle(
    IPC_CHANNELS.CUSTOM_FIELDS_UPDATE_DEFINITION,
    (_event, id: string, input: UpdateCustomFieldDefinitionInput) => {
      const record = customFieldDefinitionRepository.update(id, input)
      if (record) markProjectDirty()
      return record
    },
  )

  ipcMain.handle(IPC_CHANNELS.CUSTOM_FIELDS_DELETE_DEFINITION, (_event, id: string) => {
    const result = customFieldDefinitionRepository.delete(id)
    if (result.deleted) markProjectDirty()
    return result
  })

  ipcMain.handle(
    IPC_CHANNELS.CUSTOM_FIELDS_GET_VALUES,
    (_event, { domain, recordId }: { domain: 'items' | 'npcs'; recordId: string }) => {
      if (domain === 'items') return itemRepository.getCustomFieldValues(recordId)
      return npcRepository.getCustomFieldValues(recordId)
    },
  )

  ipcMain.handle(
    IPC_CHANNELS.CUSTOM_FIELDS_SET_VALUES,
    (
      _event,
      {
        domain,
        recordId,
        values,
      }: { domain: 'items' | 'npcs'; recordId: string; values: CustomFieldValue[] },
    ) => {
      if (domain === 'items') {
        itemRepository.setCustomFieldValues(recordId, values)
      } else {
        npcRepository.setCustomFieldValues(recordId, values)
      }
      markProjectDirty()
    },
  )
}

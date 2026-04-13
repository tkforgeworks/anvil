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
      return customFieldDefinitionRepository.create(input)
    },
  )

  ipcMain.handle(
    IPC_CHANNELS.CUSTOM_FIELDS_UPDATE_DEFINITION,
    (_event, id: string, input: UpdateCustomFieldDefinitionInput) => {
      return customFieldDefinitionRepository.update(id, input)
    },
  )

  ipcMain.handle(IPC_CHANNELS.CUSTOM_FIELDS_DELETE_DEFINITION, (_event, id: string) => {
    return customFieldDefinitionRepository.delete(id)
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
      if (domain === 'items') return itemRepository.setCustomFieldValues(recordId, values)
      return npcRepository.setCustomFieldValues(recordId, values)
    },
  )
}

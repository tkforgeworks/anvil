import { IPC_CHANNELS } from '../../shared/ipc-channels'
import { safeHandle } from './safe-handle'
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
import type { ChangeEntry } from '../project/change-accumulator'

export function registerCustomFieldsHandlers(): void {
  safeHandle(
    IPC_CHANNELS.CUSTOM_FIELDS_LIST_DEFINITIONS,
    (_event, { scopeType, scopeId }: { scopeType: string; scopeId: string }) => {
      return customFieldDefinitionRepository.listByScope(scopeType, scopeId)
    },
  )

  safeHandle(
    IPC_CHANNELS.CUSTOM_FIELDS_CREATE_DEFINITION,
    (_event, input: CreateCustomFieldDefinitionInput) => {
      const record = customFieldDefinitionRepository.create(input)
      markProjectDirty({ domain: 'custom-fields', recordId: record.id, recordName: record.fieldName, subArea: 'basic-info', action: 'create' })
      return record
    },
  )

  safeHandle(
    IPC_CHANNELS.CUSTOM_FIELDS_UPDATE_DEFINITION,
    (_event, id: string, input: UpdateCustomFieldDefinitionInput) => {
      const record = customFieldDefinitionRepository.update(id, input)
      if (record) markProjectDirty({ domain: 'custom-fields', recordId: record.id, recordName: record.fieldName, subArea: 'basic-info', action: 'update' })
      return record
    },
  )

  safeHandle(IPC_CHANNELS.CUSTOM_FIELDS_DELETE_DEFINITION, (_event, id: string) => {
    const result = customFieldDefinitionRepository.delete(id)
    if (result.deleted) markProjectDirty({ domain: 'custom-fields', recordId: id, recordName: '', subArea: 'basic-info', action: 'delete' })
    return result
  })

  safeHandle(
    IPC_CHANNELS.CUSTOM_FIELDS_GET_VALUES,
    (_event, { domain, recordId }: { domain: 'items' | 'npcs'; recordId: string }) => {
      if (domain === 'items') return itemRepository.getCustomFieldValues(recordId)
      return npcRepository.getCustomFieldValues(recordId)
    },
  )

  safeHandle(
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
      markProjectDirty({ domain: 'custom-fields', recordId, recordName: '', subArea: 'custom-fields', action: 'update' })
    },
  )
}

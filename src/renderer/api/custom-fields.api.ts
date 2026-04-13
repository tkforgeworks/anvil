import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type {
  CreateCustomFieldDefinitionInput,
  CustomFieldDefinition,
  CustomFieldScope,
  CustomFieldValue,
  DeleteDefinitionResult,
  UpdateCustomFieldDefinitionInput,
} from '../../shared/domain-types'

export const customFieldsApi = {
  listDefinitions: (scopeType: CustomFieldScope, scopeId: string) =>
    window.anvil.invoke<CustomFieldDefinition[]>(IPC_CHANNELS.CUSTOM_FIELDS_LIST_DEFINITIONS, {
      scopeType,
      scopeId,
    }),

  createDefinition: (input: CreateCustomFieldDefinitionInput) =>
    window.anvil.invoke<CustomFieldDefinition>(
      IPC_CHANNELS.CUSTOM_FIELDS_CREATE_DEFINITION,
      input,
    ),

  updateDefinition: (id: string, input: UpdateCustomFieldDefinitionInput) =>
    window.anvil.invoke<CustomFieldDefinition | null>(
      IPC_CHANNELS.CUSTOM_FIELDS_UPDATE_DEFINITION,
      id,
      input,
    ),

  deleteDefinition: (id: string) =>
    window.anvil.invoke<DeleteDefinitionResult>(
      IPC_CHANNELS.CUSTOM_FIELDS_DELETE_DEFINITION,
      id,
    ),

  getValues: (domain: 'items' | 'npcs', recordId: string) =>
    window.anvil.invoke<CustomFieldValue[]>(IPC_CHANNELS.CUSTOM_FIELDS_GET_VALUES, {
      domain,
      recordId,
    }),

  setValues: (domain: 'items' | 'npcs', recordId: string, values: CustomFieldValue[]) =>
    window.anvil.invoke<void>(IPC_CHANNELS.CUSTOM_FIELDS_SET_VALUES, {
      domain,
      recordId,
      values,
    }),
}

import { IPC_CHANNELS } from '../../shared/ipc-channels'

export interface ExportPresetInfo {
  id: string
  name: string
  description: string
  format: string
  builtIn: boolean
}

export interface ExportScope {
  mode: 'full' | 'domain' | 'selection'
  domain?: string
  recordIds?: string[]
}

export interface PreviewResult {
  output: string
  files?: { filename: string; content: string }[]
  error?: string
}

export interface ExecuteResult {
  success: boolean
  error?: string
  path?: string
}

export interface CustomTemplate {
  id: string
  name: string
  description: string
  template_source: string
  format: string
  created_at: string
  updated_at: string
}

export const exportApi = {
  getPresets: () =>
    window.anvil.invoke<ExportPresetInfo[]>(IPC_CHANNELS.EXPORT_GET_TEMPLATES),
  preview: (presetId: string, scope: ExportScope) =>
    window.anvil.invoke<PreviewResult>(IPC_CHANNELS.EXPORT_PREVIEW, presetId, scope),
  execute: (presetId: string, scope: ExportScope) =>
    window.anvil.invoke<ExecuteResult>(IPC_CHANNELS.EXPORT_EXECUTE, presetId, scope),

  listCustomTemplates: () =>
    window.anvil.invoke<CustomTemplate[]>(IPC_CHANNELS.EXPORT_LIST_CUSTOM_TEMPLATES),
  createTemplate: (data: { name: string; description?: string; template_source: string; format?: string }) =>
    window.anvil.invoke<CustomTemplate>(IPC_CHANNELS.EXPORT_CREATE_TEMPLATE, data),
  updateTemplate: (id: string, data: { name?: string; description?: string; template_source?: string; format?: string }) =>
    window.anvil.invoke<CustomTemplate>(IPC_CHANNELS.EXPORT_UPDATE_TEMPLATE, id, data),
  deleteTemplate: (id: string) =>
    window.anvil.invoke<{ success: boolean }>(IPC_CHANNELS.EXPORT_DELETE_TEMPLATE, id),
}

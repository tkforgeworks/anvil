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

export const exportApi = {
  getPresets: () =>
    window.anvil.invoke<ExportPresetInfo[]>(IPC_CHANNELS.EXPORT_GET_TEMPLATES),
  preview: (presetId: string, scope: ExportScope) =>
    window.anvil.invoke<PreviewResult>(IPC_CHANNELS.EXPORT_PREVIEW, presetId, scope),
  execute: (presetId: string, scope: ExportScope) =>
    window.anvil.invoke<ExecuteResult>(IPC_CHANNELS.EXPORT_EXECUTE, presetId, scope),
}

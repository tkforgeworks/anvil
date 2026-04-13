import { IPC_CHANNELS } from '../../shared/ipc-channels'

// Full types defined in the Export epic
export const exportApi = {
  preview: (templateId: string, scope: unknown) =>
    window.anvil.invoke<string>(IPC_CHANNELS.EXPORT_PREVIEW, templateId, scope),
  execute: (templateId: string, scope: unknown, outputPath: string) =>
    window.anvil.invoke<void>(IPC_CHANNELS.EXPORT_EXECUTE, templateId, scope, outputPath),
  getTemplates: () =>
    window.anvil.invoke<unknown[]>(IPC_CHANNELS.EXPORT_GET_TEMPLATES),
}

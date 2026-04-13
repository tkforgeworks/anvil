import { IPC_CHANNELS } from '../../shared/ipc-channels'

// Full types defined in the Project Lifecycle epic
export const projectApi = {
  create: (name: string, gameTitle: string, filePath: string) =>
    window.anvil.invoke<unknown>(IPC_CHANNELS.PROJECT_CREATE, { name, gameTitle, filePath }),
  open: (filePath: string) =>
    window.anvil.invoke<unknown>(IPC_CHANNELS.PROJECT_OPEN, filePath),
  save: () =>
    window.anvil.invoke<void>(IPC_CHANNELS.PROJECT_SAVE),
  saveAs: (filePath: string) =>
    window.anvil.invoke<void>(IPC_CHANNELS.PROJECT_SAVE_AS, filePath),
  close: () =>
    window.anvil.invoke<void>(IPC_CHANNELS.PROJECT_CLOSE),
  getState: () =>
    window.anvil.invoke<unknown>(IPC_CHANNELS.PROJECT_GET_STATE),
}

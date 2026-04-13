import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type { CreateProjectInput, ProjectStateSnapshot } from '../../shared/project-types'

export const projectApi = {
  create: (input: CreateProjectInput) =>
    window.anvil.invoke<ProjectStateSnapshot>(IPC_CHANNELS.PROJECT_CREATE, input),
  open: (filePath?: string) =>
    window.anvil.invoke<ProjectStateSnapshot>(IPC_CHANNELS.PROJECT_OPEN, filePath),
  save: () =>
    window.anvil.invoke<ProjectStateSnapshot>(IPC_CHANNELS.PROJECT_SAVE),
  saveAs: () =>
    window.anvil.invoke<ProjectStateSnapshot>(IPC_CHANNELS.PROJECT_SAVE_AS),
  close: () =>
    window.anvil.invoke<ProjectStateSnapshot>(IPC_CHANNELS.PROJECT_CLOSE),
  getState: () =>
    window.anvil.invoke<ProjectStateSnapshot>(IPC_CHANNELS.PROJECT_GET_STATE),
  removeRecent: (filePath: string) =>
    window.anvil.invoke<ProjectStateSnapshot>(IPC_CHANNELS.PROJECT_REMOVE_RECENT, filePath),
}

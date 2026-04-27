import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type { CreateProjectInput, ProjectStateSnapshot, RecordCounts, SaveHistoryEntry } from '../../shared/project-types'

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
  getSaveHistory: (limit?: number) =>
    window.anvil.invoke<SaveHistoryEntry[]>(IPC_CHANNELS.PROJECT_GET_SAVE_HISTORY, limit),
  getAutoSaveInfo: () =>
    window.anvil.invoke<{ intervalMs: number; nextSaveAt: string | null }>(IPC_CHANNELS.PROJECT_GET_AUTO_SAVE_INFO),
  backup: () =>
    window.anvil.invoke<{ success: boolean }>(IPC_CHANNELS.PROJECT_BACKUP),
  getWeeklyDeltas: () =>
    window.anvil.invoke<RecordCounts>(IPC_CHANNELS.PROJECT_GET_WEEKLY_DELTAS),
}

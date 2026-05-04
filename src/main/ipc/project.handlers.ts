import { BrowserWindow } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import { safeHandle } from './safe-handle'
import type { CreateProjectInput } from '../../shared/project-types'
import {
  backupProject,
  closeActiveProject,
  createProject,
  getAutoSaveInfo,
  getProjectState,
  getWeeklyDeltas,
  openProject,
  removeRecentProject,
  saveProject,
  saveProjectAs,
} from '../project/project-service'
import { getRecentSaves } from '../project/save-history-service'

export function registerProjectHandlers(): void {
  safeHandle(IPC_CHANNELS.PROJECT_CREATE, (event, input: CreateProjectInput) =>
    createProject(input, BrowserWindow.fromWebContents(event.sender)),
  )
  safeHandle(IPC_CHANNELS.PROJECT_OPEN, (event, filePath?: string) =>
    openProject(filePath, BrowserWindow.fromWebContents(event.sender)),
  )
  safeHandle(IPC_CHANNELS.PROJECT_SAVE, () => saveProject())
  safeHandle(IPC_CHANNELS.PROJECT_SAVE_AS, (event) =>
    saveProjectAs(BrowserWindow.fromWebContents(event.sender)),
  )
  safeHandle(IPC_CHANNELS.PROJECT_CLOSE, () => closeActiveProject())
  safeHandle(IPC_CHANNELS.PROJECT_GET_STATE, () => getProjectState())
  safeHandle(IPC_CHANNELS.PROJECT_REMOVE_RECENT, (_event, filePath: string) =>
    removeRecentProject(filePath),
  )
  safeHandle(IPC_CHANNELS.PROJECT_GET_SAVE_HISTORY, (_event, limit?: number) =>
    getRecentSaves(limit),
  )
  safeHandle(IPC_CHANNELS.PROJECT_GET_AUTO_SAVE_INFO, () => getAutoSaveInfo())
  safeHandle(IPC_CHANNELS.PROJECT_BACKUP, (event) =>
    backupProject(BrowserWindow.fromWebContents(event.sender)),
  )
  safeHandle(IPC_CHANNELS.PROJECT_GET_WEEKLY_DELTAS, () => getWeeklyDeltas())
}

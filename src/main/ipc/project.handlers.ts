import { BrowserWindow, ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type { CreateProjectInput } from '../../shared/project-types'
import {
  closeActiveProject,
  createProject,
  getProjectState,
  openProject,
  removeRecentProject,
  saveProject,
  saveProjectAs,
} from '../project/project-service'

export function registerProjectHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.PROJECT_CREATE, (event, input: CreateProjectInput) =>
    createProject(input, BrowserWindow.fromWebContents(event.sender)),
  )
  ipcMain.handle(IPC_CHANNELS.PROJECT_OPEN, (event, filePath?: string) =>
    openProject(filePath, BrowserWindow.fromWebContents(event.sender)),
  )
  ipcMain.handle(IPC_CHANNELS.PROJECT_SAVE, () => saveProject())
  ipcMain.handle(IPC_CHANNELS.PROJECT_SAVE_AS, (event) =>
    saveProjectAs(BrowserWindow.fromWebContents(event.sender)),
  )
  ipcMain.handle(IPC_CHANNELS.PROJECT_CLOSE, () => closeActiveProject())
  ipcMain.handle(IPC_CHANNELS.PROJECT_GET_STATE, () => getProjectState())
  ipcMain.handle(IPC_CHANNELS.PROJECT_REMOVE_RECENT, (_event, filePath: string) =>
    removeRecentProject(filePath),
  )
}

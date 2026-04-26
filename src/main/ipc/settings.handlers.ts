import { BrowserWindow, dialog, ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type { AppSettings } from '../../shared/settings-types'
import { restartAutoSaveTimer } from '../project/project-service'
import { getAppSettings, parseCustomThemeFile, setAppSettings } from '../settings/app-settings-service'

export function registerSettingsHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.SETTINGS_GET_APP, () => getAppSettings())

  ipcMain.handle(IPC_CHANNELS.SETTINGS_SET_APP, (_event, settings: Partial<AppSettings>) => {
    const updatedSettings = setAppSettings(settings)
    restartAutoSaveTimer()
    return updatedSettings
  })

  ipcMain.handle(IPC_CHANNELS.SETTINGS_GET_PROJECT, () => null)
  ipcMain.handle(IPC_CHANNELS.SETTINGS_SET_PROJECT, () => undefined)

  ipcMain.handle(IPC_CHANNELS.SETTINGS_SELECT_FOLDER, async (event) => {
    const win = BrowserWindow.fromWebContents(event.sender)
    const result = win
      ? await dialog.showOpenDialog(win, { title: 'Select Folder', properties: ['openDirectory', 'createDirectory'] })
      : await dialog.showOpenDialog({ title: 'Select Folder', properties: ['openDirectory', 'createDirectory'] })
    if (result.canceled || !result.filePaths[0]) return null
    return result.filePaths[0]
  })

  ipcMain.handle(IPC_CHANNELS.SETTINGS_SELECT_THEME_FILE, async (event) => {
    const win = BrowserWindow.fromWebContents(event.sender)
    const result = win
      ? await dialog.showOpenDialog(win, {
          title: 'Select Custom Theme JSON',
          filters: [{ name: 'JSON Files', extensions: ['json'] }],
          properties: ['openFile'],
        })
      : await dialog.showOpenDialog({
          title: 'Select Custom Theme JSON',
          filters: [{ name: 'JSON Files', extensions: ['json'] }],
          properties: ['openFile'],
        })
    if (result.canceled || !result.filePaths[0]) return null
    const filePath = result.filePaths[0]
    const parseResult = parseCustomThemeFile(filePath)
    return { filePath, ...parseResult }
  })
}

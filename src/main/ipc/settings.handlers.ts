import { BrowserWindow, dialog } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type { AppSettings } from '../../shared/settings-types'
import { logInfo } from '../logging/app-logger'
import { restartAutoSaveTimer } from '../project/project-service'
import { getAppSettings, parseCustomThemeFile, setAppSettings } from '../settings/app-settings-service'
import { safeHandle } from './safe-handle'

export function registerSettingsHandlers(): void {
  safeHandle(IPC_CHANNELS.SETTINGS_GET_APP, () => getAppSettings())

  safeHandle(IPC_CHANNELS.SETTINGS_SET_APP, (_event, settings: Partial<AppSettings>) => {
    const updatedSettings = setAppSettings(settings)
    restartAutoSaveTimer()
    logInfo('App settings updated')
    return updatedSettings
  })

  safeHandle(IPC_CHANNELS.SETTINGS_GET_PROJECT, () => null)
  safeHandle(IPC_CHANNELS.SETTINGS_SET_PROJECT, () => undefined)

  safeHandle(IPC_CHANNELS.SETTINGS_SELECT_FOLDER, async (event) => {
    const win = BrowserWindow.fromWebContents(event.sender)
    const result = win
      ? await dialog.showOpenDialog(win, { title: 'Select Folder', properties: ['openDirectory', 'createDirectory'] })
      : await dialog.showOpenDialog({ title: 'Select Folder', properties: ['openDirectory', 'createDirectory'] })
    if (result.canceled || !result.filePaths[0]) return null
    return result.filePaths[0]
  })

  safeHandle(IPC_CHANNELS.SETTINGS_SELECT_THEME_FILE, async (event) => {
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

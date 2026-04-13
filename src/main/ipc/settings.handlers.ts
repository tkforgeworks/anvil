import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type { AppSettings } from '../../shared/settings-types'
import { restartAutoSaveTimer } from '../project/project-service'
import { getAppSettings, setAppSettings } from '../settings/app-settings-service'

export function registerSettingsHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.SETTINGS_GET_APP, () => getAppSettings())
  ipcMain.handle(IPC_CHANNELS.SETTINGS_SET_APP, (_event, settings: Partial<AppSettings>) => {
    const updatedSettings = setAppSettings(settings)
    restartAutoSaveTimer()
    return updatedSettings
  })
  ipcMain.handle(IPC_CHANNELS.SETTINGS_GET_PROJECT, () => null)
  ipcMain.handle(IPC_CHANNELS.SETTINGS_SET_PROJECT, () => undefined)
}

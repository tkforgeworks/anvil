import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type { AppSettings } from '../../shared/settings-types'

export const settingsApi = {
  getApp: () =>
    window.anvil.invoke<AppSettings>(IPC_CHANNELS.SETTINGS_GET_APP),
  setApp: (settings: Partial<AppSettings>) =>
    window.anvil.invoke<AppSettings>(IPC_CHANNELS.SETTINGS_SET_APP, settings),
  getProject: () =>
    window.anvil.invoke<unknown>(IPC_CHANNELS.SETTINGS_GET_PROJECT),
  setProject: (settings: unknown) =>
    window.anvil.invoke<void>(IPC_CHANNELS.SETTINGS_SET_PROJECT, settings),
}

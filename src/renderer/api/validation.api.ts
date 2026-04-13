import { IPC_CHANNELS } from '../../shared/ipc-channels'

// Full types defined in the Validation epic
export const validationApi = {
  run: () =>
    window.anvil.invoke<unknown[]>(IPC_CHANNELS.VALIDATION_RUN),
  getIssues: () =>
    window.anvil.invoke<unknown[]>(IPC_CHANNELS.VALIDATION_GET_ISSUES),
}

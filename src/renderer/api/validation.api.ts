import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type { ValidationIssue } from '../../shared/domain-types'

export const validationApi = {
  run: () => window.anvil.invoke<ValidationIssue[]>(IPC_CHANNELS.VALIDATION_RUN),
  getIssues: () => window.anvil.invoke<ValidationIssue[]>(IPC_CHANNELS.VALIDATION_GET_ISSUES),
}

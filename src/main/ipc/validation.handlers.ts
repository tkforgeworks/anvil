import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type { ValidationIssue } from '../../shared/domain-types'
import { getDb } from '../db/connection'
import { validateProject } from '../validation/engine'

let lastIssues: ValidationIssue[] = []

export function registerValidationHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.VALIDATION_RUN, (): ValidationIssue[] => {
    lastIssues = validateProject(getDb())
    return lastIssues
  })
  ipcMain.handle(IPC_CHANNELS.VALIDATION_GET_ISSUES, (): ValidationIssue[] => lastIssues)
}

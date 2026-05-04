import { IPC_CHANNELS } from '../../shared/ipc-channels'
import { safeHandle } from './safe-handle'
import type { ValidationIssue } from '../../shared/domain-types'
import { logDebug } from '../logging/app-logger'
import { getDb } from '../db/connection'
import { validateProject } from '../validation/engine'

let lastIssues: ValidationIssue[] = []

export function registerValidationHandlers(): void {
  safeHandle(IPC_CHANNELS.VALIDATION_RUN, (): ValidationIssue[] => {
    lastIssues = validateProject(getDb())
    logDebug(`Validation completed: ${lastIssues.length} issues`)
    return lastIssues
  })
  safeHandle(IPC_CHANNELS.VALIDATION_GET_ISSUES, (): ValidationIssue[] => lastIssues)
}

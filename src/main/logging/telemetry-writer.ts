import { app } from 'electron'
import { appendFileSync, existsSync, mkdirSync } from 'node:fs'
import { join } from 'node:path'
import type { TelemetryEvent } from '../../shared/telemetry-types'
import { rotateIfNeeded } from './log-rotation'

export function writeTelemetrySessionStart(): void {
  writeTelemetryBatch([{
    ts: new Date().toISOString(),
    type: 'session-start',
    data: {
      version: __APP_VERSION__,
      gitSha: __GIT_SHA__,
      buildDate: __BUILD_DATE__,
      platform: process.platform,
    },
  }])
}

export function writeTelemetryBatch(events: TelemetryEvent[]): void {
  if (events.length === 0) return

  const dir = resolveLogDir()
  if (!dir) return

  try {
    if (!existsSync(dir)) mkdirSync(dir, { recursive: true })
    const filePath = join(dir, 'anvil-telemetry.jsonl')
    const lines = events.map((e) => JSON.stringify(e)).join('\n') + '\n'
    rotateIfNeeded(filePath)
    appendFileSync(filePath, lines, 'utf-8')
  } catch {
    // telemetry must never crash the app
  }
}

function resolveLogDir(): string | null {
  try {
    return join(app.getPath('userData'), 'logs')
  } catch {
    return null
  }
}

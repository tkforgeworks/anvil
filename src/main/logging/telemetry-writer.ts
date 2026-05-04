import { app } from 'electron'
import { appendFileSync, existsSync, mkdirSync } from 'node:fs'
import { join } from 'node:path'
import type { TelemetryEvent } from '../../shared/telemetry-types'

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
    const filename = `anvil-telemetry-${new Date().toISOString().slice(0, 10)}.jsonl`
    const lines = events.map((e) => JSON.stringify(e)).join('\n') + '\n'
    appendFileSync(join(dir, filename), lines, 'utf-8')
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

import { app } from 'electron'
import { appendFileSync, existsSync, mkdirSync } from 'node:fs'
import { join } from 'node:path'

export type LogLevel = 'error' | 'warn' | 'info' | 'debug'

const LEVEL_PRIORITY: Record<LogLevel, number> = { error: 0, warn: 1, info: 2, debug: 3 }
const LEVEL_TAGS: Record<LogLevel, string> = { error: 'ERROR', warn: 'WARN ', info: 'INFO ', debug: 'DEBUG' }

let minLevel: LogLevel = 'info'

export function initLogger(): void {
  minLevel = app.isPackaged ? 'info' : 'debug'
}

export function logError(message: string, error?: unknown): void {
  if (error instanceof Error) {
    writeLog('error', `${message} — ${error.message}`)
  } else {
    writeLog('error', message)
  }
}

export function logWarn(message: string): void {
  writeLog('warn', message)
}

export function logInfo(message: string): void {
  writeLog('info', message)
}

export function logDebug(message: string): void {
  writeLog('debug', message)
}

function writeLog(level: LogLevel, message: string): void {
  if (LEVEL_PRIORITY[level] > LEVEL_PRIORITY[minLevel]) return

  const now = new Date()
  const line = `${now.toISOString()} [${LEVEL_TAGS[level]}] ${message}\n`

  const dir = resolveLogDir()
  if (!dir) return

  try {
    if (!existsSync(dir)) mkdirSync(dir, { recursive: true })
    const filename = `anvil-${now.toISOString().slice(0, 10)}.log`
    appendFileSync(join(dir, filename), line, 'utf-8')
  } catch {
    // logging must never crash the app
  }
}

function resolveLogDir(): string | null {
  try {
    return join(app.getPath('userData'), 'logs')
  } catch {
    return null
  }
}

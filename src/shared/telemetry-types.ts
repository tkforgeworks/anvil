export type TelemetryEventType = 'session-start' | 'navigation' | 'click' | 'ipc'

export interface TelemetryEvent {
  ts: string
  type: TelemetryEventType
  data: SessionStartData | NavigationData | ClickData | IpcData
}

export interface SessionStartData {
  version: string
  gitSha: string
  buildDate: string
  platform: string
}

export interface NavigationData {
  from: string | null
  to: string
  dwellMs: number | null
}

export interface ClickData {
  tid: string | null
  tag: string
  text: string
  selector: string
}

export interface IpcData {
  channel: string
  durationMs: number
}

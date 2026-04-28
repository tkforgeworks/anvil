import { getDb } from '../db/connection'
import type { SaveHistoryEntry } from '../../shared/project-types'
import { drainChanges, generateSaveDescription } from './change-accumulator'

const MAX_ENTRIES = 50

export function recordSave(isAutoSave: boolean): void {
  const description = generateSaveDescription(drainChanges())
  const db = getDb()
  db.prepare(
    'INSERT INTO save_history (saved_at, description, is_auto_save) VALUES (datetime(\'now\'), ?, ?)'
  ).run(description, isAutoSave ? 1 : 0)

  const count = (db.prepare('SELECT COUNT(*) as cnt FROM save_history').get() as { cnt: number }).cnt
  if (count > MAX_ENTRIES) {
    db.prepare(
      `DELETE FROM save_history WHERE id IN (
        SELECT id FROM save_history ORDER BY saved_at ASC LIMIT ?
      )`
    ).run(count - MAX_ENTRIES)
  }
}

export function getRecentSaves(limit: number = 50): SaveHistoryEntry[] {
  const db = getDb()
  const rows = db.prepare(
    'SELECT id, saved_at, description, is_auto_save FROM save_history ORDER BY saved_at DESC LIMIT ?'
  ).all(limit) as Array<{ id: number; saved_at: string; description: string; is_auto_save: number }>

  return rows.map((row) => ({
    id: row.id,
    savedAt: row.saved_at.replace(' ', 'T') + 'Z',
    description: row.description,
    isAutoSave: row.is_auto_save === 1,
  }))
}

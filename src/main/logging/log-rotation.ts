import { existsSync, renameSync, statSync, unlinkSync } from 'node:fs'

const MAX_FILE_SIZE = 5 * 1024 * 1024 // 5 MB
const MAX_ROTATIONS = 3

export function rotateIfNeeded(filePath: string): void {
  try {
    if (!existsSync(filePath)) return
    if (statSync(filePath).size < MAX_FILE_SIZE) return

    const oldest = `${filePath}.${MAX_ROTATIONS}`
    if (existsSync(oldest)) unlinkSync(oldest)

    for (let i = MAX_ROTATIONS - 1; i >= 1; i--) {
      const from = `${filePath}.${i}`
      const to = `${filePath}.${i + 1}`
      if (existsSync(from)) renameSync(from, to)
    }

    renameSync(filePath, `${filePath}.1`)
  } catch {
    // rotation must never crash the app
  }
}

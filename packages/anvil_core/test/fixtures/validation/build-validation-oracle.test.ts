// Throwaway oracle: runs the Electron 0.1.6 validation engine over the 0.1.6
// fixture, before and after validation-mutations.sql, and writes the issue
// lists (without ids) that packages/anvil_core/lib/src/validation/ must match.
// See README.md beside this file.
import Database from 'better-sqlite3'
import { copyFileSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'fs'
import { tmpdir } from 'os'
import { join } from 'path'
import { it, vi } from 'vitest'

// The formula engine logs through app-logger, which pulls in Electron.
vi.mock('../logging/app-logger', () => ({
  logWarn: () => {},
  logError: () => {},
  logInfo: () => {},
  logDebug: () => {},
}))

import { validateProject } from '../validation/engine'

const OUT = process.env.FIXTURE_DIR!
// This directory (holding validation-mutations.sql); its parent holds the
// 0.1.6 fixture. Defaults to the checkout the oracle is run from.
const HERE =
  process.env.VALIDATION_FIXTURES ??
  join(process.cwd(), 'packages/anvil_core/test/fixtures/validation')
const SAMPLE = join(HERE, '..', 'sample-0.1.6.anvil')
const MUTATIONS = join(HERE, 'validation-mutations.sql')

function issuesOf(db: Database.Database): object[] {
  return validateProject(db).map(({ id: _id, ...rest }) => rest)
}

function withCopy<T>(body: (db: Database.Database) => T): T {
  const dir = mkdtempSync(join(tmpdir(), 'anvil-validation-oracle-'))
  const path = join(dir, 'project.anvil')
  copyFileSync(SAMPLE, path)
  const db = new Database(path)
  try {
    db.pragma('foreign_keys = ON')
    return body(db)
  } finally {
    db.close()
    rmSync(dir, { recursive: true, force: true })
  }
}

function write(name: string, issues: object[]): void {
  writeFileSync(join(OUT, name), JSON.stringify(issues, null, 2) + '\n')
}

it('writes the validation oracle for the fixture and its mutated copy', () => {
  write('validation-issues-fixture.json', withCopy((db) => issuesOf(db)))

  const statements = readFileSync(MUTATIONS, 'utf8')
    .split(';\n')
    .map((s) => s.trim())
    .filter((s) => s.length > 0)
  write(
    'validation-issues-mutated.json',
    withCopy((db) => {
      for (const sql of statements) db.exec(sql)
      return issuesOf(db)
    }),
  )
})

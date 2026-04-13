'use strict'
/**
 * Test runner wrapper.
 *
 * better-sqlite3 is a native module. `npm run rebuild` compiles it against
 * Electron's ABI so the app runs under Electron. That binary is incompatible
 * with plain Node.js, which is what Vitest uses.
 *
 * This script:
 *   1. Recompiles better-sqlite3 for the current Node.js ABI
 *   2. Runs Vitest (forwarding any CLI args, e.g. a test file filter)
 *   3. Always restores the Electron-compatible binary afterwards, whether
 *      tests passed or failed
 *
 * Usage: npm test [-- <vitest args>]
 *   e.g. npm test -- src/main/repositories/__tests__/class.repository.test.ts
 */

const { execSync, spawnSync } = require('node:child_process')

execSync('npm rebuild better-sqlite3', { stdio: 'inherit' })

const result = spawnSync('npx', ['vitest', 'run', ...process.argv.slice(2)], {
  stdio: 'inherit',
  shell: true,
})

execSync('npm run rebuild', { stdio: 'inherit' })

process.exit(result.status ?? 0)

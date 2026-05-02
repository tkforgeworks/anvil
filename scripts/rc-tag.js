#!/usr/bin/env node

const { execSync } = require('child_process')
const { readFileSync } = require('fs')
const { resolve } = require('path')

const bumpType = process.argv[2]
if (!['patch', 'minor', 'major'].includes(bumpType)) {
  console.error('Usage: node scripts/rc-tag.js <patch|minor|major>')
  process.exit(1)
}

const pkg = JSON.parse(readFileSync(resolve(__dirname, '..', 'package.json'), 'utf8'))
const current = pkg.version.replace(/-rc\.\d+$/, '')
const parts = current.split('.').map(Number)

let next
if (bumpType === 'major') {
  next = `${parts[0] + 1}.0.0`
} else if (bumpType === 'minor') {
  next = `${parts[0]}.${parts[1] + 1}.0`
} else {
  next = `${parts[0]}.${parts[1]}.${parts[2] + 1}`
}

// If the current version is already an RC for the same base, keep that base
const currentBase = current
if (pkg.version.includes('-rc.') && currentBase === next) {
  // Already on an RC for this version — the tag scan below handles incrementing
} else if (pkg.version.includes('-rc.')) {
  // Current version is an RC but for a different base — use the new base
} else {
  // Current version is stable — bump to next
}

let highestRc = 0
try {
  const tags = execSync(`git tag --list "v${next}-rc.*"`, { encoding: 'utf8' }).trim()
  if (tags) {
    for (const tag of tags.split('\n')) {
      const match = tag.match(/-rc\.(\d+)$/)
      if (match) {
        const num = parseInt(match[1], 10)
        if (num > highestRc) highestRc = num
      }
    }
  }
} catch {
  // No tags found — start at rc.1
}

const rcVersion = `${next}-rc.${highestRc + 1}`

console.log(`Bumping to ${rcVersion}`)
execSync(`npm version ${rcVersion} -m "Release candidate %s"`, { stdio: 'inherit' })
execSync('git push', { stdio: 'inherit' })
execSync('git push --tags', { stdio: 'inherit' })

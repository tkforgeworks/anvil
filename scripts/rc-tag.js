#!/usr/bin/env node

const { execSync } = require('child_process')
const { readFileSync } = require('fs')
const { resolve } = require('path')

const bumpType = process.argv[2]
if (!['patch', 'minor', 'major'].includes(bumpType)) {
  console.error('Usage: node scripts/rc-tag.js <patch|minor|major>')
  process.exit(1)
}

function git(cmd, opts) {
  return execSync(`git ${cmd}`, { encoding: 'utf8', ...opts }).trim()
}

function ghPrExists(branch) {
  try {
    const out = execSync(`gh pr list --head "${branch}" --json number --jq length`, {
      encoding: 'utf8'
    }).trim()
    return parseInt(out, 10) > 0
  } catch {
    return false
  }
}

const pkg = JSON.parse(readFileSync(resolve(__dirname, '..', 'package.json'), 'utf8'))
const currentVersion = pkg.version
const currentRcMatch = currentVersion.match(/-rc\.(\d+)$/)
const currentRcNum = currentRcMatch ? parseInt(currentRcMatch[1], 10) : 0

const isAlreadyRc = currentVersion.includes('-rc.')

let base
if (isAlreadyRc) {
  base = currentVersion.replace(/-rc\.\d+$/, '')
} else {
  const parts = currentVersion.split('.').map(Number)
  if (bumpType === 'major') {
    base = `${parts[0] + 1}.0.0`
  } else if (bumpType === 'minor') {
    base = `${parts[0]}.${parts[1] + 1}.0`
  } else {
    base = `${parts[0]}.${parts[1]}.${parts[2] + 1}`
  }
}

let highestTagRc = 0
try {
  const tags = execSync(`git tag --list "v${base}-rc.*"`, { encoding: 'utf8' }).trim()
  if (tags) {
    for (const tag of tags.split('\n')) {
      const match = tag.match(/-rc\.(\d+)$/)
      if (match) {
        const num = parseInt(match[1], 10)
        if (num > highestTagRc) highestTagRc = num
      }
    }
  }
} catch {
  // No tags found
}

const nextRc = Math.max(highestTagRc, currentRcNum) + 1
const rcVersion = `${base}-rc.${nextRc}`
const branchName = `release/v${rcVersion}`

const currentBranch = git('rev-parse --abbrev-ref HEAD')
if (currentBranch === 'master' || currentBranch === 'main') {
  console.log(`Creating branch ${branchName}`)
  git(`checkout -b ${branchName}`)
}

console.log(`Bumping to ${rcVersion}`)
execSync(`npm version ${rcVersion} --no-git-tag-version`, { stdio: 'inherit' })
execSync('git add package.json package-lock.json', { stdio: 'inherit' })
execSync(`git commit -m "Release candidate ${rcVersion}"`, { stdio: 'inherit' })

const activeBranch = git('rev-parse --abbrev-ref HEAD')
console.log(`Pushing ${activeBranch}`)
execSync(`git push -u origin ${activeBranch}`, { stdio: 'inherit' })

if (!ghPrExists(activeBranch)) {
  console.log('Creating pull request')
  execSync(`gh pr create --title "Release ${rcVersion}" --body "Release candidate ${rcVersion}"`, {
    stdio: 'inherit'
  })
} else {
  console.log('Pull request already exists — pushed update')
}

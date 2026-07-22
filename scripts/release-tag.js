#!/usr/bin/env node

const { execSync } = require('child_process')
const { readFileSync } = require('fs')
const { resolve } = require('path')

const bumpType = process.argv[2]
if (!['patch', 'minor', 'major', 'final'].includes(bumpType)) {
  console.error('Usage: node scripts/release-tag.js <patch|minor|major|final>')
  process.exit(1)
}

function git(cmd) {
  return execSync(`git ${cmd}`, { encoding: 'utf8' }).trim()
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

// 'final' promotes the current RC to its stable version (0.1.4-rc.2 → 0.1.4)
// so the stable tag shares its base with the RC tags and release notes can
// report the RC range it rolls up. patch/minor/major are for direct stable
// releases with no RC phase.
let nextVersion
if (bumpType === 'final') {
  if (!/-rc\.\d+$/.test(pkg.version)) {
    console.error(`Current version ${pkg.version} is not a release candidate — nothing to finalize`)
    process.exit(1)
  }
  nextVersion = pkg.version.replace(/-rc\.\d+$/, '')
} else {
  const currentVersion = pkg.version.replace(/-rc\.\d+$/, '')
  const parts = currentVersion.split('.').map(Number)
  if (bumpType === 'major') {
    nextVersion = `${parts[0] + 1}.0.0`
  } else if (bumpType === 'minor') {
    nextVersion = `${parts[0]}.${parts[1] + 1}.0`
  } else {
    nextVersion = `${parts[0]}.${parts[1]}.${parts[2] + 1}`
  }
}

const branchName = `release/v${nextVersion}`

const currentBranch = git('rev-parse --abbrev-ref HEAD')
if (currentBranch === 'master' || currentBranch === 'main') {
  console.log(`Creating branch ${branchName}`)
  git(`checkout -b ${branchName}`)
}

console.log(`Bumping to ${nextVersion}`)
execSync(`npm version ${nextVersion} --no-git-tag-version`, { stdio: 'inherit' })
execSync('git add package.json package-lock.json', { stdio: 'inherit' })
execSync(`git commit -m "${nextVersion}"`, { stdio: 'inherit' })

const activeBranch = git('rev-parse --abbrev-ref HEAD')
console.log(`Pushing ${activeBranch}`)
execSync(`git push -u origin ${activeBranch}`, { stdio: 'inherit' })

if (!ghPrExists(activeBranch)) {
  console.log('Creating pull request')
  execSync(`gh pr create --title "Release ${nextVersion}" --body "Release ${nextVersion}"`, {
    stdio: 'inherit'
  })
} else {
  console.log('Pull request already exists — pushed update')
}

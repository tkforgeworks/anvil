#!/usr/bin/env node

const { execSync } = require('child_process')

const JIRA_BASE = process.env.JIRA_BASE_URL || ''

function git(cmd) {
  return execSync(`git ${cmd}`, { encoding: 'utf-8' }).trim()
}

function isPrerelease(version) {
  return /-(rc|alpha|beta)/.test(version)
}

function getAllTags() {
  try {
    return git('tag --sort=-v:refname').split('\n').filter(Boolean)
  } catch {
    return []
  }
}

function findPreviousTag() {
  const tags = getAllTags()
  if (tags.length === 0) return null

  const releaseVersion = process.env.RELEASE_VERSION

  if (releaseVersion && !isPrerelease(releaseVersion)) {
    const stableTags = tags.filter((t) => !isPrerelease(t))
    return stableTags.length > 0 ? stableTags[0] : null
  }

  if (releaseVersion) {
    const idx = tags.indexOf(releaseVersion)
    if (idx >= 0 && idx < tags.length - 1) return tags[idx + 1]
    return tags[0]
  }

  const current = process.env.GITHUB_REF_NAME || tags[0]
  const idx = tags.indexOf(current)
  return idx >= 0 && idx < tags.length - 1 ? tags[idx + 1] : tags.length > 1 ? tags[1] : null
}

function findIncludedRcTags() {
  const releaseVersion = process.env.RELEASE_VERSION
  if (!releaseVersion || isPrerelease(releaseVersion)) return []

  const base = releaseVersion.replace(/^v/, '')
  const tags = getAllTags()
  return tags.filter((t) => t.startsWith(`v${base}-rc.`))
}

function getCommits(since) {
  const range = since ? `${since}..HEAD` : 'HEAD'
  const raw = git(`log ${range} --format="%h|||%s"`)
  if (!raw) return []
  return raw.split('\n').map((line) => {
    const [hash, ...rest] = line.split('|||')
    return { hash, message: rest.join('|||') }
  })
}

function isReleaseBump(msg) {
  return /^Release\b/i.test(msg) || /^\d+\.\d+\.\d+/i.test(msg)
}

function isFix(msg) {
  return /^fix\b/i.test(msg)
}

function linkTickets(msg) {
  if (!JIRA_BASE) return msg
  const base = JIRA_BASE.replace(/\/$/, '')
  return msg.replace(/\b(ANV-\d+)\b/g, `[$1](${base}/$1)`)
}

function categorize(commits) {
  const fixes = []
  const changes = []
  for (const c of commits) {
    if (isFix(c.message)) {
      fixes.push(c)
    } else {
      changes.push(c)
    }
  }
  return { fixes, changes }
}

function formatRcNotes(commits) {
  const filtered = commits.filter((c) => !isReleaseBump(c.message))
  if (filtered.length === 0) {
    return 'No notable changes in this release.'
  }

  const { fixes, changes } = categorize(filtered)
  const lines = ["## What's Changed", '']
  if (changes.length > 0) {
    lines.push('### Changes')
    for (const c of changes) lines.push(`- ${linkTickets(c.message)}`)
    lines.push('')
  }
  if (fixes.length > 0) {
    lines.push('### Bug Fixes')
    for (const c of fixes) lines.push(`- ${linkTickets(c.message)}`)
    lines.push('')
  }
  return lines.join('\n')
}

function formatStableNotes(commits) {
  const filtered = commits.filter((c) => !isReleaseBump(c.message))
  if (filtered.length === 0) {
    return 'No notable changes in this release.'
  }

  const rcTags = findIncludedRcTags()
  const { fixes, changes } = categorize(filtered)

  const lines = ["## What's Changed", '']
  if (rcTags.length > 0) {
    lines.push(`This release includes changes from ${rcTags[rcTags.length - 1]} through ${rcTags[0]}.`)
    lines.push('')
  }
  if (changes.length > 0) {
    lines.push('### Changes')
    for (const c of changes) lines.push(`- ${linkTickets(c.message)}`)
    lines.push('')
  }
  if (fixes.length > 0) {
    lines.push('### Bug Fixes')
    for (const c of fixes) lines.push(`- ${linkTickets(c.message)}`)
    lines.push('')
  }
  return lines.join('\n')
}

function run() {
  const prevTag = findPreviousTag()
  const commits = getCommits(prevTag)
  const releaseVersion = process.env.RELEASE_VERSION
  const isStable = releaseVersion && !isPrerelease(releaseVersion)

  console.log(isStable ? formatStableNotes(commits) : formatRcNotes(commits))
}

run()

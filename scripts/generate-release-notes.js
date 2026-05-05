#!/usr/bin/env node

const { execSync } = require('child_process')

const JIRA_BASE = process.env.JIRA_BASE_URL || ''

function git(cmd) {
  return execSync(`git ${cmd}`, { encoding: 'utf-8' }).trim()
}

function findPreviousTag() {
  try {
    const tags = git('tag --sort=-v:refname').split('\n').filter(Boolean)
    const current = process.env.GITHUB_REF_NAME || tags[0]
    const idx = tags.indexOf(current)
    return idx >= 0 && idx < tags.length - 1 ? tags[idx + 1] : tags.length > 1 ? tags[1] : null
  } catch {
    return null
  }
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
  return /^Release candidate/i.test(msg) || /^\d+\.\d+\.\d+/i.test(msg)
}

function isFix(msg) {
  return /^fix\b/i.test(msg)
}

function linkTickets(msg) {
  if (!JIRA_BASE) return msg
  const base = JIRA_BASE.replace(/\/$/, '')
  return msg.replace(/\b(ANV-\d+)\b/g, `[$1](${base}/$1)`)
}

function run() {
  const prevTag = findPreviousTag()
  const commits = getCommits(prevTag)
  const filtered = commits.filter((c) => !isReleaseBump(c.message))

  if (filtered.length === 0) {
    console.log('No notable changes in this release.')
    return
  }

  const fixes = []
  const changes = []
  for (const c of filtered) {
    if (isFix(c.message)) {
      fixes.push(c)
    } else {
      changes.push(c)
    }
  }

  const lines = ['## What\'s Changed', '']
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

  console.log(lines.join('\n'))
}

run()

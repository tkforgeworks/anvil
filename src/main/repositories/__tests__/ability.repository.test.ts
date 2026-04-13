import Database from 'better-sqlite3'
import { describe, it, expect, beforeEach } from 'vitest'
import { runMigrations } from '../../db/migrations/runner'
import { AbilityRepository } from '../ability.repository'

function makeDb(): Database.Database {
  const db = new Database(':memory:')
  db.pragma('foreign_keys = ON')
  runMigrations(db)
  return db
}

describe('AbilityRepository', () => {
  let repo: AbilityRepository

  beforeEach(() => {
    const db = makeDb()
    repo = new AbilityRepository(() => db)
  })

  // ── create + get ─────────────────────────────────────────────────────────

  it('create: returns the record and makes it retrievable via get', () => {
    const record = repo.create({
      displayName: 'Strike',
      exportKey: 'strike',
      abilityType: 'active',
      resourceCost: 10,
      cooldown: 2,
    })

    expect(record.id).toBeTruthy()
    expect(record.displayName).toBe('Strike')
    expect(record.abilityType).toBe('active')
    expect(record.resourceCost).toBe(10)
    expect(record.deletedAt).toBeNull()

    const fetched = repo.get(record.id)
    expect(fetched).not.toBeNull()
    expect(fetched!.id).toBe(record.id)
  })

  it('get: returns null for a non-existent id', () => {
    expect(repo.get('does-not-exist')).toBeNull()
  })

  // ── list ─────────────────────────────────────────────────────────────────

  it('list: active record appears in default list', () => {
    repo.create({ displayName: 'Strike', exportKey: 'strike' })
    expect(repo.list()).toHaveLength(1)
  })

  it('list: soft-deleted record is excluded by default', () => {
    const record = repo.create({ displayName: 'Strike', exportKey: 'strike' })
    repo.softDelete(record.id)
    expect(repo.list()).toHaveLength(0)
  })

  it('list: soft-deleted record appears when includeDeleted is true', () => {
    const record = repo.create({ displayName: 'Strike', exportKey: 'strike' })
    repo.softDelete(record.id)
    expect(repo.list(true)).toHaveLength(1)
  })

  // ── update ───────────────────────────────────────────────────────────────

  it('update: persists changed fields', () => {
    const record = repo.create({
      displayName: 'Strike',
      exportKey: 'strike',
      resourceCost: 10,
      cooldown: 2,
    })
    const updated = repo.update(record.id, {
      displayName: 'Power Strike',
      exportKey: 'power_strike',
      resourceCost: 20,
    })
    expect(updated!.displayName).toBe('Power Strike')
    expect(updated!.exportKey).toBe('power_strike')
    expect(updated!.resourceCost).toBe(20)
  })

  it('update: unspecified fields retain their previous values', () => {
    const record = repo.create({
      displayName: 'Strike',
      exportKey: 'strike',
      resourceCost: 10,
      cooldown: 5,
    })
    // cooldown and statModifiers are not passed
    const updated = repo.update(record.id, { displayName: 'Strike', exportKey: record.exportKey })
    expect(updated!.cooldown).toBe(5)
    expect(updated!.resourceCost).toBe(10)
  })

  it('update: returns null for a non-existent id', () => {
    expect(repo.update('does-not-exist', { displayName: 'X', exportKey: 'x' })).toBeNull()
  })

  // ── softDelete + restore ─────────────────────────────────────────────────

  it('softDelete: sets deletedAt and excludes record from default list', () => {
    const record = repo.create({ displayName: 'Strike', exportKey: 'strike' })
    repo.softDelete(record.id)

    expect(repo.get(record.id)!.deletedAt).not.toBeNull()
    expect(repo.list()).toHaveLength(0)
  })

  it('restore: clears deletedAt and record reappears in default list', () => {
    const record = repo.create({ displayName: 'Strike', exportKey: 'strike' })
    repo.softDelete(record.id)
    repo.restore(record.id)

    expect(repo.get(record.id)!.deletedAt).toBeNull()
    expect(repo.list()).toHaveLength(1)
  })
})

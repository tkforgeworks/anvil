import Database from 'better-sqlite3'
import { describe, it, expect, beforeEach } from 'vitest'
import { runMigrations } from '../../db/migrations/runner'
import { ClassRepository } from '../class.repository'

function makeDb(): Database.Database {
  const db = new Database(':memory:')
  db.pragma('foreign_keys = ON')
  runMigrations(db)
  return db
}

describe('ClassRepository', () => {
  let db: Database.Database
  let repo: ClassRepository

  beforeEach(() => {
    db = makeDb()
    repo = new ClassRepository(() => db)
  })

  // ── create + get ─────────────────────────────────────────────────────────

  it('create: returns the record and makes it retrievable via get', () => {
    const record = repo.create({ displayName: 'Warrior', exportKey: 'warrior' })

    expect(record.id).toBeTruthy()
    expect(record.displayName).toBe('Warrior')
    expect(record.exportKey).toBe('warrior')
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
    repo.create({ displayName: 'Warrior', exportKey: 'warrior' })
    expect(repo.list()).toHaveLength(1)
  })

  it('list: soft-deleted record is excluded by default', () => {
    const record = repo.create({ displayName: 'Warrior', exportKey: 'warrior' })
    repo.softDelete(record.id)
    expect(repo.list()).toHaveLength(0)
  })

  it('list: soft-deleted record appears when includeDeleted is true', () => {
    const record = repo.create({ displayName: 'Warrior', exportKey: 'warrior' })
    repo.softDelete(record.id)
    expect(repo.list(true)).toHaveLength(1)
  })

  // ── update ───────────────────────────────────────────────────────────────

  it('update: persists changed fields', () => {
    const record = repo.create({ displayName: 'Warrior', exportKey: 'warrior', resourceMultiplier: 1 })
    const updated = repo.update(record.id, {
      displayName: 'Knight',
      exportKey: 'knight',
      resourceMultiplier: 1.5,
    })
    expect(updated!.displayName).toBe('Knight')
    expect(updated!.exportKey).toBe('knight')
    expect(updated!.resourceMultiplier).toBe(1.5)
  })

  it('update: unspecified fields retain their previous values', () => {
    const record = repo.create({ displayName: 'Warrior', exportKey: 'warrior', resourceMultiplier: 2 })
    // Only change displayName; resourceMultiplier is not passed
    const updated = repo.update(record.id, { displayName: 'Knight', exportKey: record.exportKey })
    expect(updated!.resourceMultiplier).toBe(2)
  })

  it('update: returns null for a non-existent id', () => {
    expect(repo.update('does-not-exist', { displayName: 'X', exportKey: 'x' })).toBeNull()
  })

  // ── softDelete + restore ─────────────────────────────────────────────────

  it('softDelete: sets deletedAt and excludes record from default list', () => {
    const record = repo.create({ displayName: 'Warrior', exportKey: 'warrior' })
    repo.softDelete(record.id)

    expect(repo.get(record.id)!.deletedAt).not.toBeNull()
    expect(repo.list()).toHaveLength(0)
  })

  it('softDelete: is idempotent — repeated calls preserve the original timestamp', () => {
    const record = repo.create({ displayName: 'Warrior', exportKey: 'warrior' })
    repo.softDelete(record.id)
    const first = repo.get(record.id)!.deletedAt

    repo.softDelete(record.id)
    expect(repo.get(record.id)!.deletedAt).toBe(first)
  })

  it('restore: clears deletedAt and record reappears in default list', () => {
    const record = repo.create({ displayName: 'Warrior', exportKey: 'warrior' })
    repo.softDelete(record.id)
    repo.restore(record.id)

    expect(repo.get(record.id)!.deletedAt).toBeNull()
    expect(repo.list()).toHaveLength(1)
  })

  // ── DomainRepository base class ──────────────────────────────────────────

  it('countActive: counts only non-deleted records', () => {
    const a = repo.create({ displayName: 'Warrior', exportKey: 'warrior' })
    repo.create({ displayName: 'Mage', exportKey: 'mage' })
    repo.softDelete(a.id)

    expect(repo.countActive()).toBe(1)
  })

  it('hardDelete: removes the record permanently', () => {
    const record = repo.create({ displayName: 'Warrior', exportKey: 'warrior' })
    repo.hardDelete(record.id)

    expect(repo.get(record.id)).toBeNull()
    expect(repo.list(true)).toHaveLength(0)
  })

  // ── stat growth sub-table ─────────────────────────────────────────────────

  it('getStatGrowth: returns empty array before any entries are set', () => {
    const record = repo.create({ displayName: 'Warrior', exportKey: 'warrior' })
    expect(repo.getStatGrowth(record.id)).toEqual([])
  })

  it('setStatGrowth / getStatGrowth: round-trips entries', () => {
    const record = repo.create({ displayName: 'Warrior', exportKey: 'warrior' })
    const entries = [
      { statId: 'stat-strength', level: 1, value: 10 },
      { statId: 'stat-strength', level: 2, value: 12 },
    ]
    repo.setStatGrowth(record.id, entries)
    expect(repo.getStatGrowth(record.id)).toEqual(entries)
  })

  it('setStatGrowth: replaces all existing entries', () => {
    const record = repo.create({ displayName: 'Warrior', exportKey: 'warrior' })
    repo.setStatGrowth(record.id, [{ statId: 'stat-strength', level: 1, value: 10 }])
    repo.setStatGrowth(record.id, [{ statId: 'stat-constitution', level: 1, value: 20 }])

    const result = repo.getStatGrowth(record.id)
    expect(result).toHaveLength(1)
    expect(result[0].statId).toBe('stat-constitution')
  })

  // ── ability assignments sub-table ─────────────────────────────────────────

  it('setAbilityAssignments / getAbilityAssignments: round-trips assignments', () => {
    const classRecord = repo.create({ displayName: 'Warrior', exportKey: 'warrior' })
    db.prepare(
      `INSERT INTO abilities (id, display_name, export_key, description, ability_type, resource_cost, cooldown, stat_modifiers_json)
       VALUES ('ability-strike', 'Strike', 'strike', '', 'active', 0, 0, '{}')`,
    ).run()

    const assignments = [{ abilityId: 'ability-strike', sortOrder: 0 }]
    repo.setAbilityAssignments(classRecord.id, assignments)
    expect(repo.getAbilityAssignments(classRecord.id)).toEqual(assignments)
  })

  it('setAbilityAssignments: replaces all existing assignments', () => {
    const classRecord = repo.create({ displayName: 'Warrior', exportKey: 'warrior' })
    db.prepare(
      `INSERT INTO abilities (id, display_name, export_key, description, ability_type, resource_cost, cooldown, stat_modifiers_json)
       VALUES ('ability-strike', 'Strike', 'strike', '', 'active', 0, 0, '{}'),
              ('ability-block',  'Block',  'block',  '', 'active', 0, 0, '{}')`,
    ).run()

    repo.setAbilityAssignments(classRecord.id, [{ abilityId: 'ability-strike', sortOrder: 0 }])
    repo.setAbilityAssignments(classRecord.id, [{ abilityId: 'ability-block', sortOrder: 0 }])

    const result = repo.getAbilityAssignments(classRecord.id)
    expect(result).toHaveLength(1)
    expect(result[0].abilityId).toBe('ability-block')
  })
})

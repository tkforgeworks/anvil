import Database from 'better-sqlite3'
import { describe, it, expect, beforeEach } from 'vitest'
import { runMigrations } from '../../db/migrations/runner'
import { NpcRepository } from '../npc.repository'

// npc_type_id is seeded by migration002
const NPC_TYPE_ID = 'npc-type-enemy'

function makeDb(): Database.Database {
  const db = new Database(':memory:')
  db.pragma('foreign_keys = ON')
  runMigrations(db)
  return db
}

describe('NpcRepository', () => {
  let db: Database.Database
  let repo: NpcRepository

  beforeEach(() => {
    db = makeDb()
    repo = new NpcRepository(() => db)
  })

  // ── create + get ─────────────────────────────────────────────────────────

  it('create: returns the record and makes it retrievable via get', () => {
    const record = repo.create({
      displayName: 'Goblin Scout',
      exportKey: 'goblin_scout',
      npcTypeId: NPC_TYPE_ID,
    })

    expect(record.id).toBeTruthy()
    expect(record.displayName).toBe('Goblin Scout')
    expect(record.npcTypeId).toBe(NPC_TYPE_ID)
    expect(record.lootTableId).toBeNull()
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
    repo.create({ displayName: 'Goblin Scout', exportKey: 'goblin_scout', npcTypeId: NPC_TYPE_ID })
    expect(repo.list()).toHaveLength(1)
  })

  it('list: soft-deleted record is excluded by default', () => {
    const record = repo.create({ displayName: 'Goblin Scout', exportKey: 'goblin_scout', npcTypeId: NPC_TYPE_ID })
    repo.softDelete(record.id)
    expect(repo.list()).toHaveLength(0)
  })

  it('list: soft-deleted record appears when includeDeleted is true', () => {
    const record = repo.create({ displayName: 'Goblin Scout', exportKey: 'goblin_scout', npcTypeId: NPC_TYPE_ID })
    repo.softDelete(record.id)
    expect(repo.list(true)).toHaveLength(1)
  })

  // ── update ───────────────────────────────────────────────────────────────

  it('update: persists changed fields', () => {
    const record = repo.create({
      displayName: 'Goblin Scout',
      exportKey: 'goblin_scout',
      npcTypeId: NPC_TYPE_ID,
      combatStats: { hp: 50 },
    })
    const updated = repo.update(record.id, {
      displayName: 'Goblin Warrior',
      exportKey: 'goblin_warrior',
      npcTypeId: NPC_TYPE_ID,
      combatStats: { hp: 100 },
    })
    expect(updated!.displayName).toBe('Goblin Warrior')
    expect(updated!.combatStats).toEqual({ hp: 100 })
  })

  it('update: unspecified fields retain their previous values', () => {
    const record = repo.create({
      displayName: 'Goblin Scout',
      exportKey: 'goblin_scout',
      npcTypeId: NPC_TYPE_ID,
      description: 'A small goblin',
    })
    // description is not passed
    const updated = repo.update(record.id, { displayName: 'Goblin Scout', exportKey: record.exportKey, npcTypeId: NPC_TYPE_ID })
    expect(updated!.description).toBe('A small goblin')
  })

  it('update: returns null for a non-existent id', () => {
    expect(repo.update('does-not-exist', { displayName: 'X', exportKey: 'x', npcTypeId: NPC_TYPE_ID })).toBeNull()
  })

  it('update: removes custom field values outside the new NPC type scope', () => {
    const record = repo.create({ displayName: 'Goblin Scout', exportKey: 'goblin_scout', npcTypeId: NPC_TYPE_ID })
    db.prepare(
      `INSERT INTO custom_field_definitions
         (id, scope_type, scope_id, field_name, field_type, enum_options_json)
       VALUES
         ('field-enemy', 'npc_type', 'npc-type-enemy', 'Aggression', 'text', '[]'),
         ('field-merchant', 'npc_type', 'npc-type-merchant', 'Shop Name', 'text', '[]')`,
    ).run()
    repo.setCustomFieldValues(record.id, [
      { fieldDefinitionId: 'field-enemy', value: 'High' },
      { fieldDefinitionId: 'field-merchant', value: 'Bad Data' },
    ])

    repo.update(record.id, { npcTypeId: 'npc-type-merchant' })

    expect(repo.getCustomFieldValues(record.id)).toEqual([
      { fieldDefinitionId: 'field-merchant', value: 'Bad Data' },
    ])
  })

  it('duplicate: copies base fields, assignments, and custom field values', () => {
    const record = repo.create({
      displayName: 'Goblin Scout',
      exportKey: 'goblin_scout',
      description: 'A small goblin',
      npcTypeId: NPC_TYPE_ID,
      combatStats: { hp: 50 },
    })
    db.prepare(
      `INSERT INTO classes (id, display_name, export_key, description, resource_multiplier)
       VALUES ('class-fighter', 'Fighter', 'fighter', '', 1)`,
    ).run()
    db.prepare(
      `INSERT INTO abilities (id, display_name, export_key, description, ability_type, resource_cost, cooldown, stat_modifiers_json)
       VALUES ('ability-slash', 'Slash', 'slash', '', 'active', 0, 0, '{}')`,
    ).run()
    db.prepare(
      `INSERT INTO custom_field_definitions
         (id, scope_type, scope_id, field_name, field_type, enum_options_json)
       VALUES ('field-enemy', 'npc_type', 'npc-type-enemy', 'Aggression', 'text', '[]')`,
    ).run()
    repo.setClassAssignments(record.id, [{ classId: 'class-fighter', level: 5, sortOrder: 0 }])
    repo.setAbilityAssignments(record.id, [{ abilityId: 'ability-slash', sortOrder: 0 }])
    repo.setCustomFieldValues(record.id, [{ fieldDefinitionId: 'field-enemy', value: 'High' }])

    const copy = repo.duplicate(record.id)

    expect(copy).not.toBeNull()
    expect(copy!.id).not.toBe(record.id)
    expect(copy!.displayName).toBe('Goblin Scout (Copy)')
    expect(copy!.exportKey).toBe('goblin-scout-copy')
    expect(copy!.description).toBe('A small goblin')
    expect(copy!.npcTypeId).toBe(NPC_TYPE_ID)
    expect(copy!.combatStats).toEqual({ hp: 50 })
    expect(repo.getClassAssignments(copy!.id)).toEqual([{ classId: 'class-fighter', level: 5, sortOrder: 0 }])
    expect(repo.getAbilityAssignments(copy!.id)).toEqual([{ abilityId: 'ability-slash', sortOrder: 0 }])
    expect(repo.getCustomFieldValues(copy!.id)).toEqual([{ fieldDefinitionId: 'field-enemy', value: 'High' }])
  })

  it('duplicate: returns null for a non-existent id', () => {
    expect(repo.duplicate('does-not-exist')).toBeNull()
  })

  // ── softDelete + restore ─────────────────────────────────────────────────

  it('softDelete: sets deletedAt and excludes record from default list', () => {
    const record = repo.create({ displayName: 'Goblin Scout', exportKey: 'goblin_scout', npcTypeId: NPC_TYPE_ID })
    repo.softDelete(record.id)

    expect(repo.get(record.id)!.deletedAt).not.toBeNull()
    expect(repo.list()).toHaveLength(0)
  })

  it('restore: clears deletedAt and record reappears in default list', () => {
    const record = repo.create({ displayName: 'Goblin Scout', exportKey: 'goblin_scout', npcTypeId: NPC_TYPE_ID })
    repo.softDelete(record.id)
    repo.restore(record.id)

    expect(repo.get(record.id)!.deletedAt).toBeNull()
    expect(repo.list()).toHaveLength(1)
  })

  // ── class assignments sub-table ───────────────────────────────────────────

  it('setClassAssignments / getClassAssignments: round-trips assignments', () => {
    const npc = repo.create({ displayName: 'Goblin Scout', exportKey: 'goblin_scout', npcTypeId: NPC_TYPE_ID })
    db.prepare(
      `INSERT INTO classes (id, display_name, export_key, description, resource_multiplier)
       VALUES ('class-fighter', 'Fighter', 'fighter', '', 1)`,
    ).run()

    const assignments = [{ classId: 'class-fighter', level: 5, sortOrder: 0 }]
    repo.setClassAssignments(npc.id, assignments)
    expect(repo.getClassAssignments(npc.id)).toEqual(assignments)
  })

  it('setClassAssignments: replaces all existing assignments', () => {
    const npc = repo.create({ displayName: 'Goblin Scout', exportKey: 'goblin_scout', npcTypeId: NPC_TYPE_ID })
    db.prepare(
      `INSERT INTO classes (id, display_name, export_key, description, resource_multiplier)
       VALUES ('class-fighter', 'Fighter', 'fighter', '', 1),
              ('class-rogue',   'Rogue',   'rogue',   '', 1)`,
    ).run()

    repo.setClassAssignments(npc.id, [{ classId: 'class-fighter', level: 3, sortOrder: 0 }])
    repo.setClassAssignments(npc.id, [{ classId: 'class-rogue', level: 7, sortOrder: 0 }])

    const result = repo.getClassAssignments(npc.id)
    expect(result).toHaveLength(1)
    expect(result[0].classId).toBe('class-rogue')
  })

  // ── ability assignments sub-table ─────────────────────────────────────────

  it('setAbilityAssignments / getAbilityAssignments: round-trips assignments', () => {
    const npc = repo.create({ displayName: 'Goblin Scout', exportKey: 'goblin_scout', npcTypeId: NPC_TYPE_ID })
    db.prepare(
      `INSERT INTO abilities (id, display_name, export_key, description, ability_type, resource_cost, cooldown, stat_modifiers_json)
       VALUES ('ability-slash', 'Slash', 'slash', '', 'active', 0, 0, '{}')`,
    ).run()

    const assignments = [{ abilityId: 'ability-slash', sortOrder: 0 }]
    repo.setAbilityAssignments(npc.id, assignments)
    expect(repo.getAbilityAssignments(npc.id)).toEqual(assignments)
  })
})

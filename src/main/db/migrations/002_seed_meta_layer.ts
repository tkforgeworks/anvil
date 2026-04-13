import type { DbConnection } from '../connection'
import { up as ensureInitialSchema } from './001_init'

interface SeedRow {
  id: string
  displayName: string
  exportKey: string
  description?: string
  sortOrder: number
}

const STATS: SeedRow[] = [
  { id: 'stat-strength', displayName: 'Strength', exportKey: 'str', sortOrder: 10 },
  { id: 'stat-constitution', displayName: 'Constitution', exportKey: 'con', sortOrder: 20 },
  { id: 'stat-dexterity', displayName: 'Dexterity', exportKey: 'dex', sortOrder: 30 },
  { id: 'stat-intelligence', displayName: 'Intelligence', exportKey: 'int', sortOrder: 40 },
  { id: 'stat-wisdom', displayName: 'Wisdom', exportKey: 'wis', sortOrder: 50 },
  { id: 'stat-resilience', displayName: 'Resilience', exportKey: 'res', sortOrder: 60 },
  { id: 'stat-charisma', displayName: 'Charisma', exportKey: 'cha', sortOrder: 70 },
]

const RARITIES = [
  { id: 'rarity-common', displayName: 'Common', exportKey: 'common', colorHex: '#D8DEE9', sortOrder: 10 },
  { id: 'rarity-uncommon', displayName: 'Uncommon', exportKey: 'uncommon', colorHex: '#A3BE8C', sortOrder: 20 },
  { id: 'rarity-rare', displayName: 'Rare', exportKey: 'rare', colorHex: '#5E81AC', sortOrder: 30 },
  { id: 'rarity-epic', displayName: 'Epic', exportKey: 'epic', colorHex: '#B48EAD', sortOrder: 40 },
  { id: 'rarity-legendary', displayName: 'Legendary', exportKey: 'legendary', colorHex: '#EBCB8B', sortOrder: 50 },
]

const ITEM_CATEGORIES: SeedRow[] = [
  { id: 'item-category-weapon', displayName: 'Weapon', exportKey: 'weapon', sortOrder: 10 },
  { id: 'item-category-armor', displayName: 'Armor', exportKey: 'armor', sortOrder: 20 },
  { id: 'item-category-accessory', displayName: 'Accessory', exportKey: 'accessory', sortOrder: 30 },
  { id: 'item-category-consumable', displayName: 'Consumable', exportKey: 'consumable', sortOrder: 40 },
  { id: 'item-category-quest-item', displayName: 'Quest Item', exportKey: 'quest_item', sortOrder: 50 },
  {
    id: 'item-category-crafting-resource',
    displayName: 'Crafting Resource',
    exportKey: 'crafting_resource',
    sortOrder: 60,
  },
  { id: 'item-category-blueprint', displayName: 'Blueprint', exportKey: 'blueprint', sortOrder: 70 },
]

const NPC_TYPES: SeedRow[] = [
  { id: 'npc-type-enemy', displayName: 'Enemy', exportKey: 'enemy', sortOrder: 10 },
  { id: 'npc-type-merchant', displayName: 'Merchant', exportKey: 'merchant', sortOrder: 20 },
  { id: 'npc-type-quest-giver', displayName: 'Quest Giver', exportKey: 'quest_giver', sortOrder: 30 },
]

const CRAFTING_STATIONS: SeedRow[] = [
  { id: 'crafting-station-forge', displayName: 'Forge', exportKey: 'forge', sortOrder: 10 },
  { id: 'crafting-station-workbench', displayName: 'Workbench', exportKey: 'workbench', sortOrder: 20 },
  { id: 'crafting-station-alchemy-table', displayName: 'Alchemy Table', exportKey: 'alchemy_table', sortOrder: 30 },
  {
    id: 'crafting-station-enchanting-table',
    displayName: 'Enchanting Table',
    exportKey: 'enchanting_table',
    sortOrder: 40,
  },
]

const CRAFTING_SPECIALIZATIONS: SeedRow[] = [
  { id: 'crafting-specialization-blacksmithing', displayName: 'Blacksmithing', exportKey: 'blacksmithing', sortOrder: 10 },
  { id: 'crafting-specialization-carpentry', displayName: 'Carpentry', exportKey: 'carpentry', sortOrder: 20 },
  { id: 'crafting-specialization-alchemy', displayName: 'Alchemy', exportKey: 'alchemy', sortOrder: 30 },
  { id: 'crafting-specialization-enchanting', displayName: 'Enchanting', exportKey: 'enchanting', sortOrder: 40 },
]

const DERIVED_STATS = [
  {
    id: 'derived-stat-max-hp',
    displayName: 'Max HP',
    exportKey: 'max_hp',
    formula: 'con * 10',
    outputType: 'integer',
    roundingMode: 'round',
    sortOrder: 10,
  },
  {
    id: 'derived-stat-attack-power',
    displayName: 'Attack Power',
    exportKey: 'attack_power',
    formula: 'str * 2',
    outputType: 'integer',
    roundingMode: 'round',
    sortOrder: 20,
  },
  {
    id: 'derived-stat-magic-power',
    displayName: 'Magic Power',
    exportKey: 'magic_power',
    formula: 'int * 2',
    outputType: 'integer',
    roundingMode: 'round',
    sortOrder: 30,
  },
]

function seedRows(db: DbConnection, tableName: string, rows: SeedRow[]): void {
  const insert = db.prepare(`
    INSERT INTO ${tableName} (id, display_name, export_key, description, sort_order)
    VALUES (@id, @displayName, @exportKey, @description, @sortOrder)
    ON CONFLICT(id) DO UPDATE SET
      display_name = excluded.display_name,
      export_key = excluded.export_key,
      description = excluded.description,
      sort_order = excluded.sort_order,
      updated_at = datetime('now')
  `)

  for (const row of rows) {
    insert.run({ ...row, description: row.description ?? '' })
  }
}

export function up(db: DbConnection): void {
  // Makes this migration safe for development databases created before ANV-6
  // expanded migration 001.
  ensureInitialSchema(db)

  db.prepare(
    `INSERT INTO project_info (id, schema_version, max_level, soft_delete_reference_severity)
     VALUES (1, 2, 50, 'Warning')
     ON CONFLICT(id) DO UPDATE SET
       schema_version = excluded.schema_version,
       max_level = excluded.max_level,
       soft_delete_reference_severity = excluded.soft_delete_reference_severity,
       updated_at = datetime('now')`,
  ).run()

  seedRows(db, 'stats', STATS)
  seedRows(db, 'item_categories', ITEM_CATEGORIES)
  seedRows(db, 'npc_types', NPC_TYPES)
  seedRows(db, 'crafting_stations', CRAFTING_STATIONS)
  seedRows(db, 'crafting_specializations', CRAFTING_SPECIALIZATIONS)

  const insertRarity = db.prepare(`
    INSERT INTO rarities (id, display_name, export_key, color_hex, sort_order)
    VALUES (@id, @displayName, @exportKey, @colorHex, @sortOrder)
    ON CONFLICT(id) DO UPDATE SET
      display_name = excluded.display_name,
      export_key = excluded.export_key,
      color_hex = excluded.color_hex,
      sort_order = excluded.sort_order,
      updated_at = datetime('now')
  `)
  for (const rarity of RARITIES) {
    insertRarity.run(rarity)
  }

  const insertDerivedStat = db.prepare(`
    INSERT INTO derived_stat_definitions (
      id,
      display_name,
      export_key,
      formula,
      output_type,
      rounding_mode,
      sort_order
    )
    VALUES (
      @id,
      @displayName,
      @exportKey,
      @formula,
      @outputType,
      @roundingMode,
      @sortOrder
    )
    ON CONFLICT(id) DO UPDATE SET
      display_name = excluded.display_name,
      export_key = excluded.export_key,
      formula = excluded.formula,
      output_type = excluded.output_type,
      rounding_mode = excluded.rounding_mode,
      sort_order = excluded.sort_order,
      updated_at = datetime('now')
  `)
  for (const derivedStat of DERIVED_STATS) {
    insertDerivedStat.run(derivedStat)
  }
}

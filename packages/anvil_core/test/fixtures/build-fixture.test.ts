// Throwaway: builds a seeded .anvil fixture with the Electron 0.1.6 code and
// captures the export context plus every preset/custom-template output.
import Database from 'better-sqlite3'
import { mkdirSync, rmSync, writeFileSync, existsSync } from 'fs'
import { join } from 'path'
import { it } from 'vitest'
import { runMigrations } from '../db/migrations/runner'
import { ClassRepository } from '../repositories/class.repository'
import { AbilityRepository } from '../repositories/ability.repository'
import { ItemRepository } from '../repositories/item.repository'
import { RecipeRepository } from '../repositories/recipe.repository'
import { NpcRepository } from '../repositories/npc.repository'
import { LootTableRepository } from '../repositories/loot-table.repository'
import { CustomFieldDefinitionRepository } from '../repositories/custom-field-definition.repository'
import * as migration001 from '../db/migrations/001_init'
import * as migration002 from '../db/migrations/002_seed_meta_layer'
import * as migration003 from '../db/migrations/003_class_overrides_and_metadata'
import * as migration004 from '../db/migrations/004_ability_resource_type'
import * as migration005 from '../db/migrations/005_custom_templates'
import * as migration006 from '../db/migrations/006_stat_growth_formulas'
import * as migration007 from '../db/migrations/007_save_history'
import { assembleExportContext } from '../export/context-assembler'
import { renderExport, renderCustomTemplate } from '../export/renderer'

const OUT = process.env.FIXTURE_DIR!

const GUIDE_TEMPLATE = `# {{ project.game_title }} - Items
{% for item in items %}
## {{ item.display_name }} ({{ item.export_key }})
Category: {{ item.item_category_id | export_key }}
Rarity: {{ item.rarity_id | export_key }}
{{ item.description }}
{% endfor %}`

const RECIPE_BOOK_TEMPLATE = `{% set title = project.game_title %}
RECIPE BOOK: {{ title }} (schema {{ project.schema_version }}, max level {{ project.max_level }})
{% for recipe in recipes %}
= {{ recipe.display_name }} [{{ recipe.export_key }}] x{{ recipe.output_quantity }} -> {{ recipe.output_item_id | export_key }}
{% if recipe.crafting_station_id %}  station: {{ recipe.crafting_station_id | export_key }}{% endif %}
{% for ing in recipe.ingredients %}  - {{ ing.quantity }} x {{ ing.item_id | export_key }}
{% endfor %}{% endfor %}
NPC DROPS
{% for npc in npcs %}{% if npc.loot_table_id %}{{ npc.export_key }} drops {{ npc.loot_table_id | export_key }}
{% endif %}{% endfor %}
CLASS JSON
{{ classes | json }}
COMPACT
{{ meta.rarities | json(0) }}`

// Deliberately beyond the writing guide: common Nunjucks idioms a user might
// reach for. Used to probe how each candidate engine copes.
const BEYOND_GUIDE_TEMPLATE = `{% for c in classes %}{{ loop.index }}/{{ classes | length }} {{ c.display_name | upper }}{% if not loop.last %}, {% endif %}{% endfor %}
{% for a in abilities %}{{ a.export_key }}={{ a.resource_cost if a.resource_cost > 0 else "free" }} {% endfor %}
{{ "x" ~ 1 }} {{ items[0].display_name }} {{ items | length > 2 }} {{ project.name | default("unnamed") }} {{ "a,b" | replace(",", ";") }}
{%- if items | length %}
has items
{%- endif %}
{{ meta.stats[0].export_key }} {{ meta.stats | first | dump }} {{ project.max_level + 5 }} {{ (1.5 + 1.5) }} {{ [1,2,3] | join("-") }}`

it('builds the 0.1.6 fixture and captures exports', () => {
  mkdirSync(OUT, { recursive: true })
  const file = join(OUT, 'sample-0.1.6.anvil')
  for (const p of [file, file + '-wal', file + '-shm']) if (existsSync(p)) rmSync(p)

  const db = new Database(file)
  db.pragma('foreign_keys = ON')
  runMigrations(db)
  db.prepare(`UPDATE project_info SET project_name = @n, game_title = @g, max_level = 20 WHERE id = 1`)
    .run({ n: 'Spike Fixture', g: 'Forge & Fable' })

  const provider = () => db
  const classes = new ClassRepository(provider)
  const abilities = new AbilityRepository(provider)
  const items = new ItemRepository(provider)
  const recipes = new RecipeRepository(provider)
  const npcs = new NpcRepository(provider)
  const lootTables = new LootTableRepository(provider)
  const customFields = new CustomFieldDefinitionRepository(provider)

  // Abilities (one soft-deleted later)
  const slash = abilities.create({ displayName: 'Slash', exportKey: 'slash', description: 'A basic melee strike, "quick" & cheap.', abilityType: 'active', resourceType: 'stamina', resourceCost: 5, cooldown: 1, statModifiers: { strength: 2 } })
  const fireball = abilities.create({ displayName: 'Fireball', exportKey: 'fireball', description: 'Hurls a ball of fire.\nBurns.', abilityType: 'active', resourceType: 'mana', resourceCost: 12, cooldown: 3, statModifiers: { intelligence: 3, wisdom: 1 } })
  const oldAbility = abilities.create({ displayName: 'Retired Move', exportKey: 'retired_move', abilityType: 'passive' })

  // Classes with manual growth, formula growth, override, metadata, abilities
  const warrior = classes.create({ displayName: 'Warrior', exportKey: 'warrior', description: 'Front-line fighter', resourceMultiplier: 1.25 })
  const mage = classes.create({ displayName: 'Mage', exportKey: 'mage', description: 'Glass cannon, comma, "quoted"', resourceMultiplier: 0.8 })
  classes.setStatGrowth(warrior.id, [1, 2, 3, 4, 5].map((level) => ({ statId: 'stat-strength', level, value: 10 + level * 2 })))
  classes.setStatGrowthFormulas(warrior.id, [{ statId: 'stat-constitution', formula: '12 + level * 3' }])
  classes.setStatGrowthFormulas(mage.id, [{ statId: 'stat-intelligence', formula: '8 + level * 4' }, { statId: 'stat-wisdom', formula: 'max_level - level' }])
  classes.setDerivedStatOverrides(warrior.id, [{ derivedStatId: 'derived-stat-max-hp', formula: 'constitution * 12' }])
  classes.setMetadataFields(warrior.id, [{ fieldKey: 'base_speed', value: 4 }])
  classes.setAbilityAssignments(warrior.id, [{ abilityId: slash.id, sortOrder: 0 }])
  classes.setAbilityAssignments(mage.id, [{ abilityId: fireball.id, sortOrder: 0 }, { abilityId: slash.id, sortOrder: 1 }])

  // Items + custom field on weapons
  const damageField = customFields.create({ scopeType: 'item_category', scopeId: 'item-category-weapon', fieldName: 'damage', fieldType: 'integer', isRequired: true, sortOrder: 0 })
  const handedField = customFields.create({ scopeType: 'item_category', scopeId: 'item-category-weapon', fieldName: 'handedness', fieldType: 'enum', enumOptions: ['one-handed', 'two-handed'], defaultValue: 'one-handed', sortOrder: 1 })
  const ironIngot = items.create({ displayName: 'Iron Ingot', exportKey: 'iron_ingot', description: 'Smelted iron.', itemCategoryId: 'item-category-crafting-resource', rarityId: 'rarity-common' })
  const leather = items.create({ displayName: 'Leather Strip', exportKey: 'leather_strip', itemCategoryId: 'item-category-crafting-resource', rarityId: 'rarity-common' })
  const ironSword = items.create({ displayName: 'Iron Sword', exportKey: 'iron_sword', description: 'A sturdy, reliable blade', itemCategoryId: 'item-category-weapon', rarityId: 'rarity-uncommon' })
  items.setCustomFieldValues(ironSword.id, [{ fieldDefinitionId: damageField.id, value: '14' }, { fieldDefinitionId: handedField.id, value: 'one-handed' }])
  const herb = items.create({ displayName: 'Moonpetal Herb', exportKey: 'moonpetal_herb', itemCategoryId: 'item-category-crafting-resource', rarityId: 'rarity-rare' })
  const potion = items.create({ displayName: 'Healing Potion', exportKey: 'healing_potion', description: 'Restores 50 HP', itemCategoryId: 'item-category-consumable', rarityId: 'rarity-common' })
  const oldItem = items.create({ displayName: 'Cursed Dagger', exportKey: 'cursed_dagger', itemCategoryId: 'item-category-weapon', rarityId: 'rarity-epic' })

  // Recipes
  const swordRecipe = recipes.create({ displayName: 'Forge Iron Sword', exportKey: 'forge_iron_sword', description: 'Two ingots and a strip.', outputItemId: ironSword.id, outputQuantity: 1, craftingStationId: 'crafting-station-forge', craftingSpecializationId: 'crafting-specialization-blacksmithing' })
  recipes.setIngredients(swordRecipe.id, [{ itemId: ironIngot.id, quantity: 2, sortOrder: 0 }, { itemId: leather.id, quantity: 1, sortOrder: 1 }])
  const potionRecipe = recipes.create({ displayName: 'Brew Healing Potion', exportKey: 'brew_healing_potion', outputItemId: potion.id, outputQuantity: 3, craftingStationId: 'crafting-station-alchemy-table' })
  recipes.setIngredients(potionRecipe.id, [{ itemId: herb.id, quantity: 2, sortOrder: 0 }])

  // Loot table
  const goblinLoot = lootTables.create({ displayName: 'Goblin Drops', exportKey: 'goblin_drops', description: 'What goblins carry' })
  lootTables.setEntries(goblinLoot.id, [
    { itemId: ironIngot.id, weight: 60, quantityMin: 1, quantityMax: 3, sortOrder: 0 },
    { itemId: potion.id, weight: 30, sortOrder: 1 },
    { itemId: ironSword.id, weight: 10, conditionalFlags: { boss_only: true }, sortOrder: 2 },
  ])

  // NPCs + custom field on enemies
  const aggroField = customFields.create({ scopeType: 'npc_type', scopeId: 'npc-type-enemy', fieldName: 'aggression', fieldType: 'enum', enumOptions: ['passive', 'hostile'], defaultValue: 'hostile' })
  const goblin = npcs.create({ displayName: 'Goblin Raider', exportKey: 'goblin_raider', description: 'Small, mean, numerous', npcTypeId: 'npc-type-enemy', lootTableId: goblinLoot.id, combatStats: { hp: 35, armor: 2 } })
  npcs.setClassAssignments(goblin.id, [{ classId: warrior.id, level: 3, sortOrder: 0 }])
  npcs.setAbilityAssignments(goblin.id, [{ abilityId: slash.id, sortOrder: 0 }])
  npcs.setCustomFieldValues(goblin.id, [{ fieldDefinitionId: aggroField.id, value: 'hostile' }])
  const merchant = npcs.create({ displayName: 'Marla the Merchant', exportKey: 'marla_merchant', npcTypeId: 'npc-type-merchant', combatStats: { hp: 20 } })
  npcs.setClassAssignments(merchant.id, [{ classId: mage.id, level: 2, sortOrder: 0 }, { classId: warrior.id, level: 1, sortOrder: 1 }])

  // Soft deletes, custom templates, save history
  items.softDelete(oldItem.id)
  abilities.softDelete(oldAbility.id)
  const insTpl = db.prepare(`INSERT INTO custom_templates (id, name, description, template_source, format) VALUES (?, ?, ?, ?, ?)`)
  insTpl.run('tpl-guide', 'Items (guide example)', 'The example from the writing guide', GUIDE_TEMPLATE, 'text')
  insTpl.run('tpl-recipe-book', 'Recipe Book', 'Nested loops, set, json filter', RECIPE_BOOK_TEMPLATE, 'text')
  insTpl.run('tpl-beyond', 'Beyond the guide', 'Nunjucks idioms outside the documented subset', BEYOND_GUIDE_TEMPLATE, 'text')
  const insHist = db.prepare(`INSERT INTO save_history (saved_at, description, is_auto_save) VALUES (?, ?, ?)`)
  insHist.run('2026-10-30 18:00:00', 'Project created', 0)
  insHist.run('2026-10-30 18:05:00', 'Warrior class changed, Iron Sword item changed', 1)

  // Capture exports
  const ctx = assembleExportContext(db, { mode: 'full' })
  writeFileSync(join(OUT, 'context-full.json'), JSON.stringify(ctx, null, 2))
  for (const preset of ['nested-json', 'flat-json', 'csv']) {
    const r = renderExport(preset, ctx, { mode: 'full' })
    writeFileSync(join(OUT, `preset-${preset}.txt`), r.output)
    for (const f of r.files ?? []) writeFileSync(join(OUT, `preset-csv-${f.filename}`), f.content)
  }
  const sel = assembleExportContext(db, { mode: 'selection', domain: 'items', recordIds: [ironSword.id, potion.id] })
  writeFileSync(join(OUT, 'context-selection-items.json'), JSON.stringify(sel, null, 2))
  writeFileSync(join(OUT, 'preset-flat-json-selection.txt'), renderExport('flat-json', sel, { mode: 'selection', domain: 'items', recordIds: [ironSword.id, potion.id] }).output)
  for (const [name, src] of [['guide', GUIDE_TEMPLATE], ['recipe-book', RECIPE_BOOK_TEMPLATE], ['beyond-guide', BEYOND_GUIDE_TEMPLATE]] as const) {
    writeFileSync(join(OUT, `template-${name}.njk`), src)
    try {
      writeFileSync(join(OUT, `template-${name}.expected.txt`), renderCustomTemplate(src, ctx).output)
    } catch (e) {
      writeFileSync(join(OUT, `template-${name}.error.txt`), String(e))
    }
  }
  const schema = db.prepare(`SELECT type, name, sql FROM sqlite_master WHERE sql IS NOT NULL ORDER BY type, name`).all()
  writeFileSync(join(OUT, 'schema-sqlite-master.json'), JSON.stringify(schema, null, 2))
  db.close()
})

// Mirrors MIGRATIONS in src/main/db/migrations/runner.ts (private there), same order.
const STEP_MIGRATIONS = [
  { filename: '001_init', up: migration001.up },
  { filename: '002_seed_meta_layer', up: migration002.up },
  { filename: '003_class_overrides_and_metadata', up: migration003.up },
  { filename: '004_ability_resource_type', up: migration004.up },
  { filename: '005_custom_templates', up: migration005.up },
  { filename: '006_stat_growth_formulas', up: migration006.up },
  { filename: '007_save_history', up: migration007.up },
]

it('dumps sqlite_master after each migration step', () => {
  mkdirSync(OUT, { recursive: true })
  const file = join(OUT, 'schema-steps.sqlite')
  for (const p of [file, file + '-wal', file + '-shm']) if (existsSync(p)) rmSync(p)

  const db = new Database(file)
  db.pragma('foreign_keys = ON')
  db.exec(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      filename   TEXT PRIMARY KEY,
      applied_at TEXT NOT NULL
    )
  `)
  const insertApplied = db.prepare(
    'INSERT INTO schema_migrations (filename, applied_at) VALUES (?, ?)',
  )
  STEP_MIGRATIONS.forEach((migration, i) => {
    db.transaction(() => {
      migration.up(db)
      insertApplied.run(migration.filename, new Date().toISOString())
    })()
    const rows = db
      .prepare(
        `SELECT type, name, tbl_name, sql FROM sqlite_master WHERE sql IS NOT NULL ORDER BY type, name`,
      )
      .all()
    const n = String(i + 1).padStart(2, '0')
    writeFileSync(join(OUT, `schema-step-${n}.json`), JSON.stringify(rows, null, 2) + '\n')
  })
  db.close()
})

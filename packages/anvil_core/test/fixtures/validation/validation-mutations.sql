-- Applied to a copy of ../sample-0.1.6.anvil, statement by statement (the file
-- is split on ";\n"), to provoke every 0.1.6 validation message. Ids are
-- literal so the oracle output is deterministic. See README.md.
PRAGMA foreign_keys = OFF;

-- Soft-delete references become errors.
UPDATE project_info SET soft_delete_reference_severity = 'Error' WHERE id = 1;

-- Supporting rows: a soft-deleted class and a soft-deleted loot table.
INSERT INTO classes (id, display_name, export_key, resource_multiplier, deleted_at)
VALUES ('mut-class-retired', 'Retired Class', 'mut_retired_class', 1, '2026-11-01 00:00:00');
INSERT INTO loot_tables (id, display_name, export_key, deleted_at)
VALUES ('mut-loot-retired', 'Retired Drops', 'mut_retired_drops', '2026-11-01 00:00:00');

-- ─── Direct references ──────────────────────────────────────────────────────
-- Items (inserted out of id order, to pin SQLite row order).
INSERT INTO items (id, display_name, export_key, item_category_id, rarity_id)
VALUES ('mut-item-z-broken-category', 'Broken Category Item', 'mut_broken_category', 'missing-category', 'rarity-common');
INSERT INTO items (id, display_name, export_key, item_category_id, rarity_id)
VALUES ('mut-item-a-broken-rarity', 'Broken Rarity Item', 'mut_broken_rarity', 'item-category-armor', 'missing-rarity');
-- A soft-deleted owner with a broken reference: never reported.
INSERT INTO items (id, display_name, export_key, item_category_id, rarity_id, deleted_at)
VALUES ('mut-item-deleted-broken', 'Deleted Broken Item', 'mut_deleted_broken', 'missing-category', 'missing-rarity', '2026-11-01 00:00:00');

-- Recipes: one with every reference broken, one whose output item is soft-deleted.
INSERT INTO recipes (id, display_name, export_key, output_item_id, crafting_station_id, crafting_specialization_id)
VALUES ('mut-recipe-broken', 'Broken Recipe', 'mut_broken_recipe', 'missing-item', 'missing-station', 'missing-specialization');
INSERT INTO recipes (id, display_name, export_key, output_item_id, crafting_station_id)
VALUES ('mut-recipe-cursed', 'Cursed Recipe', 'mut_cursed_recipe', '436aa413-a7d6-4671-b067-28139fc1fa05', 'crafting-station-forge');

-- NPCs: broken type and loot table; a soft-deleted loot table; plain enemies
-- for the required custom field.
INSERT INTO npcs (id, display_name, export_key, npc_type_id, loot_table_id)
VALUES ('mut-npc-broken', 'Broken NPC', 'mut_broken_npc', 'missing-npc-type', 'missing-loot-table');
INSERT INTO npcs (id, display_name, export_key, npc_type_id, loot_table_id)
VALUES ('mut-npc-retired-loot', 'Retired Loot NPC', 'mut_retired_loot_npc', 'npc-type-enemy', 'mut-loot-retired');
INSERT INTO npcs (id, display_name, export_key, npc_type_id)
VALUES ('mut-npc-blank', 'Blank Aggression NPC', 'mut_blank_npc', 'npc-type-enemy');

-- ─── Junction references (missing target, then soft-deleted target) ────────
INSERT INTO class_ability_assignments (class_id, ability_id, sort_order)
VALUES ('8cb0cf2e-a3f2-47ad-ad82-158dc9eb3d8a', 'missing-ability', 5);
INSERT INTO class_ability_assignments (class_id, ability_id, sort_order)
VALUES ('8cb0cf2e-a3f2-47ad-ad82-158dc9eb3d8a', 'b252cd54-6b6e-4534-b5dc-5b5c2d53262b', 6);
-- Two missing abilities on the Mage, inserted out of id order.
INSERT INTO class_ability_assignments (class_id, ability_id, sort_order)
VALUES ('a7b87a4c-f898-4ebd-bfca-a8163101fc77', 'missing-ability-z', 2);
INSERT INTO class_ability_assignments (class_id, ability_id, sort_order)
VALUES ('a7b87a4c-f898-4ebd-bfca-a8163101fc77', 'missing-ability-b', 3);
INSERT INTO recipe_ingredients (recipe_id, item_id, quantity, sort_order)
VALUES ('a7a5c929-8193-457c-bedd-eea367abf255', 'missing-ingredient', 1, 2);
INSERT INTO recipe_ingredients (recipe_id, item_id, quantity, sort_order)
VALUES ('a7a5c929-8193-457c-bedd-eea367abf255', '436aa413-a7d6-4671-b067-28139fc1fa05', 1, 3);
INSERT INTO npc_class_assignments (npc_id, class_id, level, sort_order)
VALUES ('9516c484-83f0-488a-a9d5-a7ce0f006d7f', 'missing-class', 1, 1);
INSERT INTO npc_class_assignments (npc_id, class_id, level, sort_order)
VALUES ('9516c484-83f0-488a-a9d5-a7ce0f006d7f', 'mut-class-retired', 1, 2);
INSERT INTO npc_ability_assignments (npc_id, ability_id, sort_order)
VALUES ('1fdfd4c3-bf59-405d-9a77-f4ad056d82b4', 'missing-ability', 0);
INSERT INTO npc_ability_assignments (npc_id, ability_id, sort_order)
VALUES ('1fdfd4c3-bf59-405d-9a77-f4ad056d82b4', 'b252cd54-6b6e-4534-b5dc-5b5c2d53262b', 1);
INSERT INTO loot_table_entries (id, loot_table_id, item_id, weight, sort_order)
VALUES ('mut-entry-missing', '1e11b296-71a9-4976-887b-d0f32e25becb', 'missing-loot-item', 5, 3);
INSERT INTO loot_table_entries (id, loot_table_id, item_id, weight, sort_order)
VALUES ('mut-entry-cursed', '1e11b296-71a9-4976-887b-d0f32e25becb', '436aa413-a7d6-4671-b067-28139fc1fa05', 5, 4);
-- Entries of a soft-deleted loot table: never reported.
INSERT INTO loot_table_entries (id, loot_table_id, item_id, weight, sort_order)
VALUES ('mut-entry-retired', 'mut-loot-retired', 'missing-loot-item', 5, 0);

-- ─── Required custom fields ─────────────────────────────────────────────────
-- Weapons already require 'damage'; one new weapon has no value, one an empty one.
INSERT INTO items (id, display_name, export_key, item_category_id, rarity_id)
VALUES ('mut-item-weapon-novalue', 'Unfinished Axe', 'mut_unfinished_axe', 'item-category-weapon', 'rarity-common');
INSERT INTO items (id, display_name, export_key, item_category_id, rarity_id)
VALUES ('mut-item-weapon-empty', 'Blank Bow', 'mut_blank_bow', 'item-category-weapon', 'rarity-common');
INSERT INTO custom_field_values (domain, record_id, field_definition_id, value)
VALUES ('items', 'mut-item-weapon-empty', '18790df6-c2dc-4597-b0b2-679b538d7729', '');
-- Enemy NPCs now require 'aggression' (Goblin Raider has a value).
UPDATE custom_field_definitions SET is_required = 1 WHERE id = '3789fc46-bc57-4677-ad44-73d9b334788f';

-- ─── Derived stats ──────────────────────────────────────────────────────────
-- An acyclic chain that a Warrior override turns into a cycle (inserted before
-- the base cycle, so the Warrior graph meets this cycle first).
INSERT INTO derived_stat_definitions (id, display_name, export_key, formula, sort_order)
VALUES ('mut-ds-chain-x', 'Chain X', 'chain_x', '1', 3);
INSERT INTO derived_stat_definitions (id, display_name, export_key, formula, sort_order)
VALUES ('mut-ds-chain-y', 'Chain Y', 'chain_y', 'chain_x + 1', 4);
INSERT INTO class_derived_stat_overrides (class_id, derived_stat_id, formula)
VALUES ('8cb0cf2e-a3f2-47ad-ad82-158dc9eb3d8a', 'mut-ds-chain-x', 'chain_y * 2');
-- A base cycle.
INSERT INTO derived_stat_definitions (id, display_name, export_key, formula, sort_order)
VALUES ('mut-ds-cycle-a', 'Cycle A', 'cycle_a', 'cycle_b + 1', 5);
INSERT INTO derived_stat_definitions (id, display_name, export_key, formula, sort_order)
VALUES ('mut-ds-cycle-b', 'Cycle B', 'cycle_b', 'cycle_a + 1', 6);
-- A base syntax error, and an override syntax error on the Mage.
INSERT INTO derived_stat_definitions (id, display_name, export_key, formula, sort_order)
VALUES ('mut-ds-broken', 'Broken Stat', 'broken_stat', 'con *', 7);
INSERT INTO class_derived_stat_overrides (class_id, derived_stat_id, formula)
VALUES ('a7b87a4c-f898-4ebd-bfca-a8163101fc77', 'derived-stat-magic-power', '/ broken');
-- Level-1 runtime failure: the Mage's base_speed metadata field is 0.
INSERT INTO derived_stat_definitions (id, display_name, export_key, formula, sort_order)
VALUES ('mut-ds-speed-ratio', 'Speed Ratio', 'speed_ratio', '100 / base_speed', 8);
INSERT INTO class_metadata_fields (class_id, field_key, value)
VALUES ('a7b87a4c-f898-4ebd-bfca-a8163101fc77', 'base_speed', 0);
-- The soft-deleted class's overrides are never checked.
INSERT INTO class_derived_stat_overrides (class_id, derived_stat_id, formula)
VALUES ('mut-class-retired', 'derived-stat-max-hp', '(((');

-- ─── Stat growth formulas ───────────────────────────────────────────────────
-- Syntax error (Mage), unknown variable (Warrior), failure at level 3 (Warrior).
INSERT INTO class_stat_growth_formulas (class_id, stat_id, formula)
VALUES ('a7b87a4c-f898-4ebd-bfca-a8163101fc77', 'stat-strength', '3 +');
INSERT INTO class_stat_growth_formulas (class_id, stat_id, formula)
VALUES ('8cb0cf2e-a3f2-47ad-ad82-158dc9eb3d8a', 'stat-strength', 'level * bonus + extra');
INSERT INTO class_stat_growth_formulas (class_id, stat_id, formula)
VALUES ('8cb0cf2e-a3f2-47ad-ad82-158dc9eb3d8a', 'stat-dexterity', '10 / (level - 3)');
INSERT INTO class_stat_growth_formulas (class_id, stat_id, formula)
VALUES ('mut-class-retired', 'stat-strength', '3 +');

PRAGMA foreign_keys = ON;

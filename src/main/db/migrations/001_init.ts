import type { DbConnection } from '../connection'

function tableExists(db: DbConnection, tableName: string): boolean {
  const row = db
    .prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?")
    .get(tableName)
  return Boolean(row)
}

function copyLegacyProjectMeta(db: DbConnection): void {
  if (!tableExists(db, 'project_meta')) return

  db.exec(`
    INSERT INTO project_info (
      id,
      project_name,
      game_title,
      schema_version,
      max_level,
      soft_delete_reference_severity,
      created_at,
      updated_at
    )
    SELECT
      id,
      project_name,
      game_title,
      schema_version,
      max_level,
      'warning',
      created_at,
      updated_at
    FROM project_meta
    WHERE id = 1
    ON CONFLICT(id) DO NOTHING
  `)
}

/**
 * Initial migration - establishes the full project schema foundation.
 */
export function up(db: DbConnection): void {
  db.exec(`
    CREATE TABLE IF NOT EXISTS project_info (
      id          INTEGER PRIMARY KEY CHECK (id = 1),
      project_name   TEXT    NOT NULL DEFAULT '',
      game_title     TEXT    NOT NULL DEFAULT '',
      schema_version INTEGER NOT NULL DEFAULT 1,
      max_level      INTEGER NOT NULL DEFAULT 50,
      soft_delete_reference_severity TEXT NOT NULL DEFAULT 'warning'
        CHECK (soft_delete_reference_severity IN ('warning', 'error')),
      created_at     TEXT    NOT NULL DEFAULT (datetime('now')),
      updated_at     TEXT    NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS stats (
      id          TEXT PRIMARY KEY,
      display_name TEXT NOT NULL,
      export_key TEXT NOT NULL UNIQUE,
      description TEXT NOT NULL DEFAULT '',
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS rarities (
      id          TEXT PRIMARY KEY,
      display_name TEXT NOT NULL,
      export_key TEXT NOT NULL UNIQUE,
      color_hex   TEXT NOT NULL DEFAULT '#FFFFFF',
      sort_order  INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS affinities (
      id          TEXT PRIMARY KEY,
      display_name TEXT NOT NULL,
      export_key TEXT NOT NULL UNIQUE,
      description TEXT NOT NULL DEFAULT '',
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS item_categories (
      id          TEXT PRIMARY KEY,
      display_name TEXT NOT NULL,
      export_key TEXT NOT NULL UNIQUE,
      description TEXT NOT NULL DEFAULT '',
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS npc_types (
      id          TEXT PRIMARY KEY,
      display_name TEXT NOT NULL,
      export_key TEXT NOT NULL UNIQUE,
      description TEXT NOT NULL DEFAULT '',
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS crafting_stations (
      id          TEXT PRIMARY KEY,
      display_name TEXT NOT NULL,
      export_key TEXT NOT NULL UNIQUE,
      description TEXT NOT NULL DEFAULT '',
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS crafting_specializations (
      id          TEXT PRIMARY KEY,
      display_name TEXT NOT NULL,
      export_key TEXT NOT NULL UNIQUE,
      description TEXT NOT NULL DEFAULT '',
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS derived_stat_definitions (
      id          TEXT PRIMARY KEY,
      display_name TEXT NOT NULL,
      export_key TEXT NOT NULL UNIQUE,
      formula     TEXT NOT NULL,
      output_type TEXT NOT NULL DEFAULT 'integer' CHECK (output_type IN ('integer', 'float')),
      rounding_mode TEXT NOT NULL DEFAULT 'round' CHECK (rounding_mode IN ('floor', 'round', 'none')),
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS classes (
      id          TEXT PRIMARY KEY,
      display_name TEXT NOT NULL,
      export_key TEXT NOT NULL UNIQUE,
      description TEXT NOT NULL DEFAULT '',
      resource_multiplier REAL NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      deleted_at TEXT
    );

    CREATE TABLE IF NOT EXISTS abilities (
      id          TEXT PRIMARY KEY,
      display_name TEXT NOT NULL,
      export_key TEXT NOT NULL UNIQUE,
      description TEXT NOT NULL DEFAULT '',
      ability_type TEXT NOT NULL DEFAULT '',
      resource_cost REAL NOT NULL DEFAULT 0,
      cooldown REAL NOT NULL DEFAULT 0,
      stat_modifiers_json TEXT NOT NULL DEFAULT '{}',
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      deleted_at TEXT
    );

    CREATE TABLE IF NOT EXISTS items (
      id          TEXT PRIMARY KEY,
      display_name TEXT NOT NULL,
      export_key TEXT NOT NULL UNIQUE,
      description TEXT NOT NULL DEFAULT '',
      item_category_id TEXT NOT NULL REFERENCES item_categories(id),
      rarity_id TEXT NOT NULL REFERENCES rarities(id),
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      deleted_at TEXT
    );

    CREATE TABLE IF NOT EXISTS recipes (
      id          TEXT PRIMARY KEY,
      display_name TEXT NOT NULL,
      export_key TEXT NOT NULL UNIQUE,
      description TEXT NOT NULL DEFAULT '',
      output_item_id TEXT NOT NULL REFERENCES items(id),
      output_quantity INTEGER NOT NULL DEFAULT 1 CHECK (output_quantity > 0),
      crafting_station_id TEXT REFERENCES crafting_stations(id),
      crafting_specialization_id TEXT REFERENCES crafting_specializations(id),
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      deleted_at TEXT
    );

    CREATE TABLE IF NOT EXISTS npcs (
      id          TEXT PRIMARY KEY,
      display_name TEXT NOT NULL,
      export_key TEXT NOT NULL UNIQUE,
      description TEXT NOT NULL DEFAULT '',
      npc_type_id TEXT NOT NULL REFERENCES npc_types(id),
      loot_table_id TEXT REFERENCES loot_tables(id),
      combat_stats_json TEXT NOT NULL DEFAULT '{}',
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      deleted_at TEXT
    );

    CREATE TABLE IF NOT EXISTS loot_tables (
      id          TEXT PRIMARY KEY,
      display_name TEXT NOT NULL,
      export_key TEXT NOT NULL UNIQUE,
      description TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      deleted_at TEXT
    );

    CREATE TABLE IF NOT EXISTS class_stat_growth (
      class_id TEXT NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
      stat_id TEXT NOT NULL REFERENCES stats(id),
      level INTEGER NOT NULL CHECK (level > 0),
      value REAL NOT NULL,
      PRIMARY KEY (class_id, stat_id, level)
    );

    CREATE TABLE IF NOT EXISTS class_ability_assignments (
      class_id TEXT NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
      ability_id TEXT NOT NULL REFERENCES abilities(id),
      sort_order INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (class_id, ability_id)
    );

    CREATE TABLE IF NOT EXISTS recipe_ingredients (
      recipe_id TEXT NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
      item_id TEXT NOT NULL REFERENCES items(id),
      quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
      sort_order INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (recipe_id, item_id)
    );

    CREATE TABLE IF NOT EXISTS loot_table_entries (
      id TEXT PRIMARY KEY,
      loot_table_id TEXT NOT NULL REFERENCES loot_tables(id) ON DELETE CASCADE,
      item_id TEXT NOT NULL REFERENCES items(id),
      weight INTEGER NOT NULL CHECK (weight > 0),
      quantity_min INTEGER NOT NULL DEFAULT 1 CHECK (quantity_min > 0),
      quantity_max INTEGER NOT NULL DEFAULT 1 CHECK (quantity_max >= quantity_min),
      conditional_flags TEXT NOT NULL DEFAULT '{}',
      sort_order INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS npc_class_assignments (
      npc_id TEXT NOT NULL REFERENCES npcs(id) ON DELETE CASCADE,
      class_id TEXT NOT NULL REFERENCES classes(id),
      level INTEGER NOT NULL CHECK (level > 0),
      sort_order INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (npc_id, class_id)
    );

    CREATE TABLE IF NOT EXISTS npc_ability_assignments (
      npc_id TEXT NOT NULL REFERENCES npcs(id) ON DELETE CASCADE,
      ability_id TEXT NOT NULL REFERENCES abilities(id),
      sort_order INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (npc_id, ability_id)
    );

    CREATE TABLE IF NOT EXISTS custom_field_definitions (
      id TEXT PRIMARY KEY,
      scope_type TEXT NOT NULL CHECK (scope_type IN ('item_category', 'npc_type')),
      scope_id TEXT NOT NULL,
      field_name TEXT NOT NULL,
      field_type TEXT NOT NULL CHECK (field_type IN ('text', 'integer', 'decimal', 'boolean', 'enum')),
      default_value TEXT,
      enum_options_json TEXT,
      is_required INTEGER NOT NULL DEFAULT 0 CHECK (is_required IN (0, 1)),
      is_searchable INTEGER NOT NULL DEFAULT 0 CHECK (is_searchable IN (0, 1)),
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      UNIQUE (scope_type, scope_id, field_name)
    );

    CREATE TABLE IF NOT EXISTS custom_field_values (
      domain TEXT NOT NULL CHECK (domain IN ('items', 'npcs')),
      record_id TEXT NOT NULL,
      field_definition_id TEXT NOT NULL REFERENCES custom_field_definitions(id) ON DELETE CASCADE,
      value TEXT,
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      PRIMARY KEY (domain, record_id, field_definition_id)
    );

    CREATE INDEX IF NOT EXISTS idx_classes_active ON classes(deleted_at);
    CREATE INDEX IF NOT EXISTS idx_abilities_active ON abilities(deleted_at);
    CREATE INDEX IF NOT EXISTS idx_items_active ON items(deleted_at);
    CREATE INDEX IF NOT EXISTS idx_recipes_active ON recipes(deleted_at);
    CREATE INDEX IF NOT EXISTS idx_npcs_active ON npcs(deleted_at);
    CREATE INDEX IF NOT EXISTS idx_loot_tables_active ON loot_tables(deleted_at);
    CREATE INDEX IF NOT EXISTS idx_custom_field_values_record
      ON custom_field_values(domain, record_id);
  `)

  copyLegacyProjectMeta(db)
}

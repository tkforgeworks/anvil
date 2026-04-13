// IPC channel name constants — typed surface defined in ANV-20

export const IPC_CHANNELS = {
  // Project lifecycle
  PROJECT_CREATE: 'project:create',
  PROJECT_OPEN: 'project:open',
  PROJECT_SAVE: 'project:save',
  PROJECT_SAVE_AS: 'project:save-as',
  PROJECT_CLOSE: 'project:close',
  PROJECT_GET_STATE: 'project:get-state',
  PROJECT_REMOVE_RECENT: 'project:remove-recent',

  // Character Classes
  CLASSES_LIST: 'classes:list',
  CLASSES_GET: 'classes:get',
  CLASSES_CREATE: 'classes:create',
  CLASSES_UPDATE: 'classes:update',
  CLASSES_DELETE: 'classes:delete',
  CLASSES_RESTORE: 'classes:restore',

  // Abilities
  ABILITIES_LIST: 'abilities:list',
  ABILITIES_GET: 'abilities:get',
  ABILITIES_CREATE: 'abilities:create',
  ABILITIES_UPDATE: 'abilities:update',
  ABILITIES_DELETE: 'abilities:delete',
  ABILITIES_RESTORE: 'abilities:restore',

  // Items
  ITEMS_LIST: 'items:list',
  ITEMS_GET: 'items:get',
  ITEMS_CREATE: 'items:create',
  ITEMS_UPDATE: 'items:update',
  ITEMS_DELETE: 'items:delete',
  ITEMS_RESTORE: 'items:restore',

  // Crafting Recipes
  RECIPES_LIST: 'recipes:list',
  RECIPES_GET: 'recipes:get',
  RECIPES_CREATE: 'recipes:create',
  RECIPES_UPDATE: 'recipes:update',
  RECIPES_DELETE: 'recipes:delete',
  RECIPES_RESTORE: 'recipes:restore',

  // NPCs
  NPCS_LIST: 'npcs:list',
  NPCS_GET: 'npcs:get',
  NPCS_CREATE: 'npcs:create',
  NPCS_UPDATE: 'npcs:update',
  NPCS_DELETE: 'npcs:delete',
  NPCS_RESTORE: 'npcs:restore',

  // Loot Tables
  LOOT_TABLES_LIST: 'loot-tables:list',
  LOOT_TABLES_GET: 'loot-tables:get',
  LOOT_TABLES_CREATE: 'loot-tables:create',
  LOOT_TABLES_UPDATE: 'loot-tables:update',
  LOOT_TABLES_DELETE: 'loot-tables:delete',
  LOOT_TABLES_RESTORE: 'loot-tables:restore',

  // Validation
  VALIDATION_RUN: 'validation:run',
  VALIDATION_GET_ISSUES: 'validation:get-issues',

  // Export
  EXPORT_PREVIEW: 'export:preview',
  EXPORT_EXECUTE: 'export:execute',
  EXPORT_GET_TEMPLATES: 'export:get-templates',

  // Settings
  SETTINGS_GET_APP: 'settings:get-app',
  SETTINGS_SET_APP: 'settings:set-app',
  SETTINGS_GET_PROJECT: 'settings:get-project',
  SETTINGS_SET_PROJECT: 'settings:set-project',

  // Meta-layer reference data (read-only lookups for UI)
  META_LIST_ITEM_CATEGORIES: 'meta:list-item-categories',
  META_LIST_NPC_TYPES: 'meta:list-npc-types',

  // Custom field definitions
  CUSTOM_FIELDS_LIST_DEFINITIONS: 'custom-fields:list-definitions',
  CUSTOM_FIELDS_CREATE_DEFINITION: 'custom-fields:create-definition',
  CUSTOM_FIELDS_UPDATE_DEFINITION: 'custom-fields:update-definition',
  CUSTOM_FIELDS_DELETE_DEFINITION: 'custom-fields:delete-definition',

  // Custom field values (EAV read/write)
  CUSTOM_FIELDS_GET_VALUES: 'custom-fields:get-values',
  CUSTOM_FIELDS_SET_VALUES: 'custom-fields:set-values',
} as const

export type IpcChannel = (typeof IPC_CHANNELS)[keyof typeof IPC_CHANNELS]

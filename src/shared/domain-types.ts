/**
 * Base identity fields present on every domain record.
 * Domain-specific record types extend this interface.
 */
export interface BaseRecord {
  id: string
  displayName: string
  exportKey: string
  description: string
  createdAt: string
  updatedAt: string
  deletedAt: string | null
}

// ─── Character Classes ────────────────────────────────────────────────────────

export interface ClassRecord extends BaseRecord {
  resourceMultiplier: number
}

export interface CreateClassInput {
  displayName: string
  exportKey: string
  description?: string
  resourceMultiplier?: number
}

export interface UpdateClassInput {
  displayName?: string
  exportKey?: string
  description?: string
  resourceMultiplier?: number
}

export interface StatGrowthEntry {
  statId: string
  level: number
  value: number
}

export interface ClassAbilityAssignment {
  abilityId: string
  sortOrder: number
}

// ─── Abilities ────────────────────────────────────────────────────────────────

export interface AbilityRecord extends BaseRecord {
  abilityType: string
  resourceCost: number
  cooldown: number
  statModifiers: Record<string, number>
}

export interface CreateAbilityInput {
  displayName: string
  exportKey: string
  description?: string
  abilityType?: string
  resourceCost?: number
  cooldown?: number
  statModifiers?: Record<string, number>
}

export interface UpdateAbilityInput {
  displayName?: string
  exportKey?: string
  description?: string
  abilityType?: string
  resourceCost?: number
  cooldown?: number
  statModifiers?: Record<string, number>
}

// ─── Items ────────────────────────────────────────────────────────────────────

export interface ItemRecord extends BaseRecord {
  itemCategoryId: string
  rarityId: string
}

export interface CreateItemInput {
  displayName: string
  exportKey: string
  description?: string
  itemCategoryId: string
  rarityId: string
}

export interface UpdateItemInput {
  displayName?: string
  exportKey?: string
  description?: string
  itemCategoryId?: string
  rarityId?: string
}

export interface CustomFieldValue {
  fieldDefinitionId: string
  value: string | null
}

// ─── Custom Field Definitions ─────────────────────────────────────────────────

export type CustomFieldScope = 'item_category' | 'npc_type'
export type CustomFieldType = 'text' | 'integer' | 'decimal' | 'boolean' | 'enum'

export interface CustomFieldDefinition {
  id: string
  scopeType: CustomFieldScope
  scopeId: string
  fieldName: string
  fieldType: CustomFieldType
  defaultValue: string | null
  enumOptions: string[]
  isRequired: boolean
  isSearchable: boolean
  sortOrder: number
  createdAt: string
  updatedAt: string
}

export interface CreateCustomFieldDefinitionInput {
  scopeType: CustomFieldScope
  scopeId: string
  fieldName: string
  fieldType: CustomFieldType
  defaultValue?: string | null
  enumOptions?: string[]
  isRequired?: boolean
  isSearchable?: boolean
  sortOrder?: number
}

export interface UpdateCustomFieldDefinitionInput {
  fieldName?: string
  defaultValue?: string | null
  enumOptions?: string[]  // field_type is immutable after creation
  isRequired?: boolean
  isSearchable?: boolean
  sortOrder?: number
}

export interface DeleteDefinitionResult {
  deleted: boolean
  affectedCount: number  // 0 when deleted; N when blocked (N records have values)
}

// ─── Meta-layer reference types ───────────────────────────────────────────────

export interface MetaItemCategory {
  id: string
  displayName: string
  exportKey: string
  description: string
  sortOrder: number
}

export interface MetaNpcType {
  id: string
  displayName: string
  exportKey: string
  description: string
  sortOrder: number
}

export interface MetaStat {
  id: string
  displayName: string
  exportKey: string
  sortOrder: number
}

export interface ProjectSettings {
  maxLevel: number
}

// ─── Crafting Recipes ─────────────────────────────────────────────────────────

export interface RecipeRecord extends BaseRecord {
  outputItemId: string
  outputQuantity: number
  craftingStationId: string | null
  craftingSpecializationId: string | null
}

export interface RecipeIngredient {
  itemId: string
  quantity: number
  sortOrder: number
}

export interface CreateRecipeInput {
  displayName: string
  exportKey: string
  description?: string
  outputItemId: string
  outputQuantity?: number
  craftingStationId?: string | null
  craftingSpecializationId?: string | null
}

export interface UpdateRecipeInput {
  displayName?: string
  exportKey?: string
  description?: string
  outputItemId?: string
  outputQuantity?: number
  craftingStationId?: string | null
  craftingSpecializationId?: string | null
}

// ─── NPCs ─────────────────────────────────────────────────────────────────────

export interface NpcRecord extends BaseRecord {
  npcTypeId: string
  lootTableId: string | null
  combatStats: Record<string, number>
}

export interface NpcClassAssignment {
  classId: string
  level: number
  sortOrder: number
}

export interface NpcAbilityAssignment {
  abilityId: string
  sortOrder: number
}

export interface CreateNpcInput {
  displayName: string
  exportKey: string
  description?: string
  npcTypeId: string
  lootTableId?: string | null
  combatStats?: Record<string, number>
}

export interface UpdateNpcInput {
  displayName?: string
  exportKey?: string
  description?: string
  npcTypeId?: string
  lootTableId?: string | null
  combatStats?: Record<string, number>
}

// ─── Loot Tables ──────────────────────────────────────────────────────────────

// No extra columns beyond the base — the domain data lives in loot_table_entries.
export type LootTableRecord = BaseRecord

export interface LootTableEntry {
  id: string
  lootTableId: string
  itemId: string
  weight: number
  quantityMin: number
  quantityMax: number
  conditionalFlags: Record<string, unknown>
  sortOrder: number
}

export interface CreateLootTableInput {
  displayName: string
  exportKey: string
  description?: string
}

export interface UpdateLootTableInput {
  displayName?: string
  exportKey?: string
  description?: string
}

export interface CreateLootTableEntryInput {
  itemId: string
  weight: number
  quantityMin?: number
  quantityMax?: number
  conditionalFlags?: Record<string, unknown>
  sortOrder?: number
}

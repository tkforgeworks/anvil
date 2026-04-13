import { ClassRepository } from './class.repository'
import { AbilityRepository } from './ability.repository'
import { ItemRepository } from './item.repository'
import { RecipeRepository } from './recipe.repository'
import { NpcRepository } from './npc.repository'
import { LootTableRepository } from './loot-table.repository'

export const classRepository = new ClassRepository()
export const abilityRepository = new AbilityRepository()
export const itemRepository = new ItemRepository()
export const recipeRepository = new RecipeRepository()
export const npcRepository = new NpcRepository()
export const lootTableRepository = new LootTableRepository()

export type { DomainRecordRow } from './domain-repository'

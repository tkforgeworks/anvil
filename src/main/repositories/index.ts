import { DomainRepository } from './domain-repository'

export const classRepository = new DomainRepository('classes')
export const abilityRepository = new DomainRepository('abilities')
export const itemRepository = new DomainRepository('items')
export const recipeRepository = new DomainRepository('recipes')
export const npcRepository = new DomainRepository('npcs')
export const lootTableRepository = new DomainRepository('loot_tables')

export type { DomainRecordRow } from './domain-repository'

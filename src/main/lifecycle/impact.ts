import type { DbConnection } from '../db/connection'
import type {
  DeleteImpactReference,
  DeleteImpactSummary,
  LifecycleDomain,
} from '../../shared/domain-types'

interface ReverseDirectRef {
  type: 'direct'
  affectedDomain: LifecycleDomain
  affectedTable: string
  fkCol: string
  description: string
}

interface ReverseJunctionRef {
  type: 'junction'
  affectedDomain: LifecycleDomain
  affectedTable: string
  junction: string
  junctionTargetFk: string
  junctionOwnerFk: string
  description: string
}

type ReverseRef = ReverseDirectRef | ReverseJunctionRef

const REVERSE_REFS: Record<LifecycleDomain, ReverseRef[]> = {
  'classes': [
    {
      type: 'junction', affectedDomain: 'npcs', affectedTable: 'npcs',
      junction: 'npc_class_assignments', junctionTargetFk: 'class_id',
      junctionOwnerFk: 'npc_id', description: 'NPC class assignments',
    },
  ],
  'abilities': [
    {
      type: 'junction', affectedDomain: 'classes', affectedTable: 'classes',
      junction: 'class_ability_assignments', junctionTargetFk: 'ability_id',
      junctionOwnerFk: 'class_id', description: 'class ability assignments',
    },
    {
      type: 'junction', affectedDomain: 'npcs', affectedTable: 'npcs',
      junction: 'npc_ability_assignments', junctionTargetFk: 'ability_id',
      junctionOwnerFk: 'npc_id', description: 'NPC ability assignments',
    },
  ],
  'items': [
    {
      type: 'direct', affectedDomain: 'recipes', affectedTable: 'recipes',
      fkCol: 'output_item_id', description: 'recipe output items',
    },
    {
      type: 'junction', affectedDomain: 'recipes', affectedTable: 'recipes',
      junction: 'recipe_ingredients', junctionTargetFk: 'item_id',
      junctionOwnerFk: 'recipe_id', description: 'recipe ingredients',
    },
    {
      type: 'junction', affectedDomain: 'loot-tables', affectedTable: 'loot_tables',
      junction: 'loot_table_entries', junctionTargetFk: 'item_id',
      junctionOwnerFk: 'loot_table_id', description: 'loot table entries',
    },
  ],
  'recipes': [],
  'npcs': [],
  'loot-tables': [
    {
      type: 'direct', affectedDomain: 'npcs', affectedTable: 'npcs',
      fkCol: 'loot_table_id', description: 'NPC loot table references',
    },
  ],
}

export function computeDeleteImpact(
  db: DbConnection,
  domain: LifecycleDomain,
  ids: string[],
): DeleteImpactSummary {
  if (ids.length === 0) return { recordCount: 0, references: [] }

  const placeholders = ids.map(() => '?').join(', ')
  const refs = REVERSE_REFS[domain]
  const references: DeleteImpactReference[] = []

  for (const ref of refs) {
    let count: number
    if (ref.type === 'direct') {
      const row = db
        .prepare(
          `SELECT COUNT(DISTINCT id) AS cnt FROM ${ref.affectedTable}
           WHERE ${ref.fkCol} IN (${placeholders}) AND deleted_at IS NULL`,
        )
        .get(...ids) as { cnt: number }
      count = row.cnt
    } else {
      const row = db
        .prepare(
          `SELECT COUNT(DISTINCT j.${ref.junctionOwnerFk}) AS cnt
           FROM ${ref.junction} j
           JOIN ${ref.affectedTable} o ON o.id = j.${ref.junctionOwnerFk}
           WHERE j.${ref.junctionTargetFk} IN (${placeholders}) AND o.deleted_at IS NULL`,
        )
        .get(...ids) as { cnt: number }
      count = row.cnt
    }

    if (count > 0) {
      references.push({
        domain: ref.affectedDomain,
        field: ref.type === 'direct' ? ref.fkCol : ref.junction,
        recordCount: count,
        description: ref.description,
      })
    }
  }

  return { recordCount: ids.length, references }
}

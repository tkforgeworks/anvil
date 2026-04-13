import { randomUUID } from 'crypto'
import { getDb, type DbConnection } from '../db/connection'
import type {
  CreateCustomFieldDefinitionInput,
  CustomFieldDefinition,
  DeleteDefinitionResult,
  UpdateCustomFieldDefinitionInput,
} from '../../shared/domain-types'

interface DefinitionDbRow {
  id: string
  scope_type: string
  scope_id: string
  field_name: string
  field_type: string
  default_value: string | null
  enum_options_json: string | null
  is_required: number
  is_searchable: number
  sort_order: number
  created_at: string
  updated_at: string
}

function toDefinition(row: DefinitionDbRow): CustomFieldDefinition {
  return {
    id: row.id,
    scopeType: row.scope_type as CustomFieldDefinition['scopeType'],
    scopeId: row.scope_id,
    fieldName: row.field_name,
    fieldType: row.field_type as CustomFieldDefinition['fieldType'],
    defaultValue: row.default_value,
    enumOptions: row.enum_options_json
      ? (JSON.parse(row.enum_options_json) as string[])
      : [],
    isRequired: row.is_required === 1,
    isSearchable: row.is_searchable === 1,
    sortOrder: row.sort_order,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  }
}

export class CustomFieldDefinitionRepository {
  constructor(private dbProvider: () => DbConnection = getDb) {}

  listByScope(scopeType: string, scopeId: string): CustomFieldDefinition[] {
    const rows = this.dbProvider()
      .prepare(
        `SELECT * FROM custom_field_definitions
         WHERE scope_type = ? AND scope_id = ?
         ORDER BY sort_order, field_name COLLATE NOCASE`,
      )
      .all(scopeType, scopeId) as DefinitionDbRow[]
    return rows.map(toDefinition)
  }

  get(id: string): CustomFieldDefinition | null {
    const row = this.dbProvider()
      .prepare('SELECT * FROM custom_field_definitions WHERE id = ?')
      .get(id) as DefinitionDbRow | undefined
    return row ? toDefinition(row) : null
  }

  create(input: CreateCustomFieldDefinitionInput): CustomFieldDefinition {
    const id = randomUUID()
    this.dbProvider()
      .prepare(
        `INSERT INTO custom_field_definitions
           (id, scope_type, scope_id, field_name, field_type,
            default_value, enum_options_json, is_required, is_searchable, sort_order)
         VALUES
           (@id, @scopeType, @scopeId, @fieldName, @fieldType,
            @defaultValue, @enumOptionsJson, @isRequired, @isSearchable, @sortOrder)`,
      )
      .run({
        id,
        scopeType: input.scopeType,
        scopeId: input.scopeId,
        fieldName: input.fieldName,
        fieldType: input.fieldType,
        defaultValue: input.defaultValue ?? null,
        enumOptionsJson:
          input.enumOptions && input.enumOptions.length > 0
            ? JSON.stringify(input.enumOptions)
            : null,
        isRequired: input.isRequired ? 1 : 0,
        isSearchable: input.isSearchable ? 1 : 0,
        sortOrder: input.sortOrder ?? 0,
      })
    return this.get(id)!
  }

  update(id: string, input: UpdateCustomFieldDefinitionInput): CustomFieldDefinition | null {
    const current = this.get(id)
    if (!current) return null

    // Enum option removal is blocked if any record currently uses the removed value.
    if (input.enumOptions !== undefined && current.fieldType === 'enum') {
      const newOptions = new Set(input.enumOptions)
      const usedValues = this.getUsedEnumValues(id)
      const blockedRemovals = usedValues.filter((v) => !newOptions.has(v))
      if (blockedRemovals.length > 0) {
        throw new Error(
          `Cannot remove enum option(s) that are in use: ${blockedRemovals.join(', ')}`,
        )
      }
    }

    const newEnumOptions =
      input.enumOptions !== undefined ? input.enumOptions : current.enumOptions

    this.dbProvider()
      .prepare(
        `UPDATE custom_field_definitions
         SET field_name        = @fieldName,
             default_value     = @defaultValue,
             enum_options_json = @enumOptionsJson,
             is_required       = @isRequired,
             is_searchable     = @isSearchable,
             sort_order        = @sortOrder,
             updated_at        = datetime('now')
         WHERE id = @id`,
      )
      .run({
        id,
        fieldName: input.fieldName ?? current.fieldName,
        defaultValue:
          input.defaultValue !== undefined ? input.defaultValue : current.defaultValue,
        enumOptionsJson:
          newEnumOptions.length > 0 ? JSON.stringify(newEnumOptions) : null,
        isRequired: (input.isRequired ?? current.isRequired) ? 1 : 0,
        isSearchable: (input.isSearchable ?? current.isSearchable) ? 1 : 0,
        sortOrder: input.sortOrder ?? current.sortOrder,
      })
    return this.get(id)
  }

  /**
   * Returns the number of records that have a non-empty value for this field.
   * Used to block deletion and enum option removal.
   */
  getValueCount(fieldDefinitionId: string): number {
    const row = this.dbProvider()
      .prepare(
        `SELECT COUNT(*) AS count FROM custom_field_values
         WHERE field_definition_id = ? AND value IS NOT NULL AND value != ''`,
      )
      .get(fieldDefinitionId) as { count: number }
    return row.count
  }

  /**
   * Returns the distinct enum values currently stored for this field.
   * Used to determine which options are safe to remove.
   */
  getUsedEnumValues(fieldDefinitionId: string): string[] {
    const rows = this.dbProvider()
      .prepare(
        `SELECT DISTINCT value FROM custom_field_values
         WHERE field_definition_id = ? AND value IS NOT NULL AND value != ''`,
      )
      .all(fieldDefinitionId) as { value: string }[]
    return rows.map((r) => r.value)
  }

  /**
   * Deletes a field definition. Blocked (returns deleted: false) if any record
   * has a non-empty value for this field. The FK ON DELETE CASCADE in the schema
   * cleans up any remaining null/empty value rows automatically.
   */
  delete(id: string): DeleteDefinitionResult {
    const affectedCount = this.getValueCount(id)
    if (affectedCount > 0) {
      return { deleted: false, affectedCount }
    }
    this.dbProvider()
      .prepare('DELETE FROM custom_field_definitions WHERE id = ?')
      .run(id)
    return { deleted: true, affectedCount: 0 }
  }
}

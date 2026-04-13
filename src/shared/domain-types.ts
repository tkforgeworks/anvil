/**
 * Base identity fields present on every domain record.
 * Domain epics extend this with their specific fields.
 */
export interface BaseRecord {
  id: string
  displayName: string
  exportKey: string
  createdAt: string
  updatedAt: string
  deletedAt: string | null
}

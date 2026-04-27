export const PROJECT_TEMPLATES = ['blank', 'fantasy-rpg', 'sci-fi-rpg'] as const

export type ProjectTemplateId = (typeof PROJECT_TEMPLATES)[number]

export type ProjectSaveStatus = 'saved' | 'saving' | 'unsaved' | 'error'

export interface RecordCounts {
  classes: number
  abilities: number
  items: number
  recipes: number
  npcs: number
  lootTables: number
}

export interface ProjectFolderPaths {
  root: string
  database: string
  exports: string
  temp: string
  logs: string
}

export interface ProjectMetadata {
  projectName: string
  gameTitle: string
  filePath: string
  projectFolder: ProjectFolderPaths | null
  schemaVersion: number
  lastModifiedAt: string
  fileSize: number
  recordCounts: RecordCounts
}

export interface RecentProject extends ProjectMetadata {
  exists: boolean
  isArchived?: boolean
}

export interface ProjectStateSnapshot {
  activeProject: ProjectMetadata | null
  recentProjects: RecentProject[]
  isDirty: boolean
  isRecoveryMode: boolean
  recoveryMessage: string | null
  saveStatus: ProjectSaveStatus
  saveError: string | null
}

export interface CreateProjectInput {
  projectName: string
  gameTitle: string
  templateId: ProjectTemplateId
  filePath?: string
}

export interface SaveHistoryEntry {
  id: number
  savedAt: string
  description: string
  isAutoSave: boolean
}

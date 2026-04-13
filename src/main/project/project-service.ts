import Database from 'better-sqlite3'
import { app, dialog, type BrowserWindow } from 'electron'
import {
  copyFileSync,
  existsSync,
  mkdirSync,
  readFileSync,
  statSync,
  unlinkSync,
  writeFileSync,
} from 'fs'
import { basename, dirname, extname, join } from 'path'
import { closeDatabase, getDb, openDatabase, type DbConnection } from '../db/connection'
import { runMigrations } from '../db/migrations/runner'
import type {
  CreateProjectInput,
  ProjectMetadata,
  ProjectStateSnapshot,
  RecentProject,
  RecordCounts,
} from '../../shared/project-types'

const EXPECTED_SCHEMA_VERSION = 1
const RECENT_PROJECTS_FILENAME = 'recent-projects.json'
const EMPTY_RECORD_COUNTS: RecordCounts = {
  classes: 0,
  abilities: 0,
  items: 0,
  recipes: 0,
  npcs: 0,
  lootTables: 0,
}

interface ProjectMetaRow {
  project_name: string
  game_title: string
  schema_version: number
}

let activeProject: ProjectMetadata | null = null
let isDirty = false
let isRecoveryMode = false

function recentProjectsPath(): string {
  return join(app.getPath('userData'), RECENT_PROJECTS_FILENAME)
}

function normalizeAnvilPath(filePath: string): string {
  const trimmedPath = filePath.trim()
  return extname(trimmedPath).toLowerCase() === '.anvil' ? trimmedPath : `${trimmedPath}.anvil`
}

function sanitizeFilename(value: string): string {
  const sanitized = value.replace(/[<>:"/\\|?*\u0000-\u001F]/g, '').trim()
  return sanitized.length > 0 ? sanitized : 'Untitled Project'
}

function readRecentProjects(): RecentProject[] {
  const filePath = recentProjectsPath()
  if (!existsSync(filePath)) return []

  try {
    const parsed = JSON.parse(readFileSync(filePath, 'utf8')) as RecentProject[]
    if (!Array.isArray(parsed)) return []

    return parsed
      .filter((project) => typeof project.filePath === 'string')
      .map((project) => {
        const exists = existsSync(project.filePath)
        return {
          ...project,
          exists,
          lastModifiedAt: exists ? getLastModifiedAt(project.filePath) : project.lastModifiedAt,
          recordCounts: { ...EMPTY_RECORD_COUNTS, ...project.recordCounts },
        }
      })
  } catch {
    return []
  }
}

function writeRecentProjects(projects: RecentProject[]): void {
  const filePath = recentProjectsPath()
  mkdirSync(dirname(filePath), { recursive: true })
  writeFileSync(filePath, JSON.stringify(projects.slice(0, 10), null, 2))
}

function updateRecentProjects(project: ProjectMetadata): RecentProject[] {
  const normalizedPath = project.filePath.toLowerCase()
  const updated = [
    { ...project, exists: true },
    ...readRecentProjects().filter((recent) => recent.filePath.toLowerCase() !== normalizedPath),
  ]
  writeRecentProjects(updated)
  return updated.slice(0, 10)
}

function getLastModifiedAt(filePath: string): string {
  return statSync(filePath).mtime.toISOString()
}

function tableExists(db: DbConnection | Database.Database, tableName: string): boolean {
  const row = db
    .prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?")
    .get(tableName)
  return Boolean(row)
}

function countActiveRows(db: DbConnection, tableName: string): number {
  if (!tableExists(db, tableName)) return 0

  const hasDeletedAt = db
    .prepare(`PRAGMA table_info(${tableName})`)
    .all()
    .some((column) => (column as { name: string }).name === 'deleted_at')

  const sql = hasDeletedAt
    ? `SELECT COUNT(*) AS count FROM ${tableName} WHERE deleted_at IS NULL`
    : `SELECT COUNT(*) AS count FROM ${tableName}`
  return (db.prepare(sql).get() as { count: number }).count
}

function getRecordCounts(db: DbConnection): RecordCounts {
  return {
    classes: countActiveRows(db, 'classes'),
    abilities: countActiveRows(db, 'abilities'),
    items: countActiveRows(db, 'items'),
    recipes: countActiveRows(db, 'recipes'),
    npcs: countActiveRows(db, 'npcs'),
    lootTables: countActiveRows(db, 'loot_tables'),
  }
}

function readProjectMeta(db: DbConnection): ProjectMetaRow {
  const row = db.prepare('SELECT project_name, game_title, schema_version FROM project_info WHERE id = 1').get()

  if (row) {
    return row as ProjectMetaRow
  }

  db.prepare(
    `INSERT INTO project_info (id, project_name, game_title, schema_version)
     VALUES (1, '', '', ?)`,
  ).run(EXPECTED_SCHEMA_VERSION)

  return {
    project_name: '',
    game_title: '',
    schema_version: EXPECTED_SCHEMA_VERSION,
  }
}

function buildProjectMetadata(db: DbConnection, filePath: string): ProjectMetadata {
  const meta = readProjectMeta(db)
  const fallbackName = basename(filePath, extname(filePath))

  return {
    projectName: meta.project_name || fallbackName,
    gameTitle: meta.game_title || fallbackName,
    filePath,
    schemaVersion: meta.schema_version,
    lastModifiedAt: getLastModifiedAt(filePath),
    recordCounts: getRecordCounts(db),
  }
}

function closeExistingDatabase(): void {
  try {
    closeDatabase(getDb())
  } catch {
    // No project database is open yet.
  }
}

async function promptForCreatePath(owner: BrowserWindow | null, projectName: string): Promise<string | null> {
  const options = {
    title: 'Create Anvil Project',
    defaultPath: `${sanitizeFilename(projectName)}.anvil`,
    filters: [{ name: 'Anvil Projects', extensions: ['anvil'] }],
    properties: ['createDirectory'],
  } satisfies Electron.SaveDialogOptions
  const result = owner ? await dialog.showSaveDialog(owner, options) : await dialog.showSaveDialog(options)

  if (result.canceled || !result.filePath) return null
  return normalizeAnvilPath(result.filePath)
}

async function promptForOpenPath(owner: BrowserWindow | null): Promise<string | null> {
  const options = {
    title: 'Open Anvil Project',
    filters: [{ name: 'Anvil Projects', extensions: ['anvil'] }],
    properties: ['openFile'],
  } satisfies Electron.OpenDialogOptions
  const result = owner ? await dialog.showOpenDialog(owner, options) : await dialog.showOpenDialog(options)

  if (result.canceled || result.filePaths.length === 0) return null
  return result.filePaths[0]
}

async function promptForSaveAsPath(owner: BrowserWindow | null, currentPath: string): Promise<string | null> {
  const options = {
    title: 'Save Anvil Project As',
    defaultPath: currentPath,
    filters: [{ name: 'Anvil Projects', extensions: ['anvil'] }],
    properties: ['createDirectory'],
  } satisfies Electron.SaveDialogOptions
  const result = owner ? await dialog.showSaveDialog(owner, options) : await dialog.showSaveDialog(options)

  if (result.canceled || !result.filePath) return null
  return normalizeAnvilPath(result.filePath)
}

export async function createProject(
  input: CreateProjectInput,
  owner: BrowserWindow | null,
): Promise<ProjectStateSnapshot> {
  const projectName = input.projectName.trim()
  const gameTitle = input.gameTitle.trim()

  if (!projectName) throw new Error('Project name is required.')
  if (!gameTitle) throw new Error('Game title is required.')

  const filePath = input.filePath
    ? normalizeAnvilPath(input.filePath)
    : await promptForCreatePath(owner, projectName)

  if (!filePath) return getProjectState()
  if (existsSync(filePath)) throw new Error('A project file already exists at that path.')

  mkdirSync(dirname(filePath), { recursive: true })
  closeExistingDatabase()

  try {
    const db = openDatabase(filePath)
    runMigrations(db)
    db.prepare(
      `INSERT INTO project_info (id, project_name, game_title, schema_version, updated_at)
       VALUES (1, ?, ?, ?, datetime('now'))
       ON CONFLICT(id) DO UPDATE SET
         project_name = excluded.project_name,
         game_title = excluded.game_title,
         schema_version = excluded.schema_version,
         updated_at = excluded.updated_at`,
    ).run(projectName, gameTitle, EXPECTED_SCHEMA_VERSION)

    activeProject = buildProjectMetadata(db, filePath)
    isDirty = false
    isRecoveryMode = false
    updateRecentProjects(activeProject)
    return getProjectState()
  } catch (error) {
    closeExistingDatabase()
    if (existsSync(filePath)) unlinkSync(filePath)
    throw error
  }
}

export async function openProject(
  filePath: string | undefined,
  owner: BrowserWindow | null,
): Promise<ProjectStateSnapshot> {
  const selectedPath = filePath?.trim() || (await promptForOpenPath(owner))
  if (!selectedPath) return getProjectState()

  if (!existsSync(selectedPath)) {
    throw new Error('The selected project file does not exist.')
  }

  closeExistingDatabase()
  const db = openDatabase(selectedPath)
  runMigrations(db)

  activeProject = buildProjectMetadata(db, selectedPath)
  isDirty = false
  isRecoveryMode = false
  updateRecentProjects(activeProject)
  return getProjectState()
}

export function saveProject(): ProjectStateSnapshot {
  if (!activeProject) return getProjectState()

  const db = getDb()
  db.pragma('wal_checkpoint(TRUNCATE)')
  activeProject = buildProjectMetadata(db, activeProject.filePath)
  isDirty = false
  updateRecentProjects(activeProject)
  return getProjectState()
}

export async function saveProjectAs(owner: BrowserWindow | null): Promise<ProjectStateSnapshot> {
  if (!activeProject) return getProjectState()

  saveProject()
  const targetPath = await promptForSaveAsPath(owner, activeProject.filePath)
  if (!targetPath) return getProjectState()
  if (targetPath.toLowerCase() === activeProject.filePath.toLowerCase()) return getProjectState()
  if (existsSync(targetPath)) throw new Error('A project file already exists at that path.')

  copyFileSync(activeProject.filePath, targetPath)
  closeExistingDatabase()
  const db = openDatabase(targetPath)
  activeProject = buildProjectMetadata(db, targetPath)
  isDirty = false
  isRecoveryMode = false
  updateRecentProjects(activeProject)
  return getProjectState()
}

export function closeActiveProject(): ProjectStateSnapshot {
  closeExistingDatabase()
  activeProject = null
  isDirty = false
  isRecoveryMode = false
  return getProjectState()
}

export function removeRecentProject(filePath: string): ProjectStateSnapshot {
  const normalizedPath = filePath.toLowerCase()
  const updated = readRecentProjects().filter(
    (project) => project.filePath.toLowerCase() !== normalizedPath,
  )
  writeRecentProjects(updated)
  return getProjectState()
}

export function getProjectState(): ProjectStateSnapshot {
  return {
    activeProject,
    recentProjects: readRecentProjects(),
    isDirty,
    isRecoveryMode,
  }
}

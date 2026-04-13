import Database from 'better-sqlite3'
import { app, dialog, type BrowserWindow } from 'electron'
import {
  copyFileSync,
  existsSync,
  closeSync,
  mkdirSync,
  openSync,
  readFileSync,
  statSync,
  unlinkSync,
  writeFileSync,
} from 'fs'
import { basename, dirname, extname, join, parse } from 'path'
import { closeDatabase, getDb, openDatabase, type DbConnection } from '../db/connection'
import { CURRENT_SCHEMA_VERSION, runMigrations } from '../db/migrations/runner'
import { getAppSettings } from '../settings/app-settings-service'
import type {
  CreateProjectInput,
  ProjectMetadata,
  ProjectSaveStatus,
  ProjectStateSnapshot,
  RecentProject,
  RecordCounts,
} from '../../shared/project-types'

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
let recoveryMessage: string | null = null
let saveStatus: ProjectSaveStatus = 'saved'
let saveError: string | null = null
let autoSaveTimer: NodeJS.Timeout | null = null
let activeLock: { filePath: string; lockPath: string; fd: number } | null = null

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

function getLockPath(filePath: string): string {
  return `${filePath}.lock`
}

function acquireProjectLock(filePath: string): void {
  if (activeLock?.filePath.toLowerCase() === filePath.toLowerCase()) return

  const lockPath = getLockPath(filePath)
  try {
    const fd = openSync(lockPath, 'wx')
    writeFileSync(fd, JSON.stringify({ pid: process.pid, lockedAt: new Date().toISOString(), filePath }))
    activeLock = { filePath, lockPath, fd }
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === 'EEXIST') {
      throw new ProjectLockError('This project is already open in another Anvil window.')
    }
    throw error
  }
}

function releaseProjectLock(): void {
  if (!activeLock) return

  const { fd, lockPath } = activeLock
  activeLock = null
  try {
    closeSync(fd)
  } catch {
    // Best effort release.
  }
  try {
    if (existsSync(lockPath)) unlinkSync(lockPath)
  } catch {
    // Best effort release.
  }
}

function createBackupPath(filePath: string): string {
  const parsed = parse(filePath)
  const timestamp = new Date().toISOString().replace(/[-:.TZ]/g, '')
  return join(parsed.dir, `${parsed.name}_backup_${timestamp}${parsed.ext || '.anvil'}`)
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
  ).run(CURRENT_SCHEMA_VERSION)

  return {
    project_name: '',
    game_title: '',
    schema_version: CURRENT_SCHEMA_VERSION,
  }
}

function readProjectSchemaVersion(db: DbConnection): number {
  if (tableExists(db, 'project_info')) {
    const row = db.prepare('SELECT schema_version FROM project_info WHERE id = 1').get() as
      | { schema_version: number }
      | undefined
    return row?.schema_version ?? 0
  }

  if (tableExists(db, 'project_meta')) {
    const row = db.prepare('SELECT schema_version FROM project_meta WHERE id = 1').get() as
      | { schema_version: number }
      | undefined
    return row?.schema_version ?? 0
  }

  return 0
}

function assertIntegrity(db: DbConnection): void {
  const row = db.prepare('PRAGMA integrity_check').get() as { integrity_check: string }
  if (row.integrity_check !== 'ok') {
    throw new Error(`SQLite integrity check failed: ${row.integrity_check}`)
  }
}

async function migrateIfNeeded(filePath: string, owner: BrowserWindow | null): Promise<string | null> {
  let db: DbConnection | null = null
  try {
    db = openDatabase(filePath)
    assertIntegrity(db)
    const schemaVersion = readProjectSchemaVersion(db)
    closeDatabase(db)
    db = null

    if (schemaVersion >= CURRENT_SCHEMA_VERSION) return filePath

    const messageBoxOptions = {
      type: 'question',
      buttons: ['Upgrade Copy', 'Cancel'],
      defaultId: 0,
      cancelId: 1,
      title: 'Upgrade Project Schema',
      message: 'This project was created with an older Anvil schema.',
      detail:
        'Anvil will create an upgraded backup copy and leave the original project file unchanged.',
    } satisfies Electron.MessageBoxOptions
    const migrationPrompt = owner
      ? await dialog.showMessageBox(owner, messageBoxOptions)
      : await dialog.showMessageBox(messageBoxOptions)
    if (migrationPrompt.response !== 0) return null

    const backupPath = createBackupPath(filePath)
    copyFileSync(filePath, backupPath)
    db = openDatabase(backupPath)
    runMigrations(db)
    assertIntegrity(db)
    db.pragma('wal_checkpoint(TRUNCATE)')
    closeDatabase(db)
    db = null
    return backupPath
  } finally {
    if (db?.open) {
      closeDatabase(db)
    }
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

function refreshActiveProject(): void {
  if (!activeProject) return
  if (isRecoveryMode) return

  try {
    activeProject = buildProjectMetadata(getDb(), activeProject.filePath)
  } catch {
    activeProject = null
    isDirty = false
    isRecoveryMode = false
    recoveryMessage = null
    saveStatus = 'saved'
    saveError = null
  }
}

class ProjectLockError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'ProjectLockError'
  }
}

function setCleanState(project: ProjectMetadata | null): void {
  activeProject = project
  isDirty = false
  saveStatus = 'saved'
  saveError = null
  if (project) {
    recoveryMessage = null
  }
}

function setRecoveryState(filePath: string, error: unknown): ProjectStateSnapshot {
  closeExistingDatabase()
  releaseProjectLock()
  stopAutoSaveTimer()

  const fallbackName = basename(filePath, extname(filePath))
  activeProject = {
    projectName: fallbackName,
    gameTitle: fallbackName,
    filePath,
    schemaVersion: 0,
    lastModifiedAt: existsSync(filePath) ? getLastModifiedAt(filePath) : new Date().toISOString(),
    recordCounts: EMPTY_RECORD_COUNTS,
  }
  isDirty = false
  isRecoveryMode = true
  recoveryMessage = error instanceof Error ? error.message : 'Unable to open project file.'
  saveStatus = 'saved'
  saveError = null
  return getProjectState()
}

function setSaveFailure(error: unknown): void {
  saveStatus = 'error'
  saveError = error instanceof Error ? error.message : 'Unable to save project.'
}

function stopAutoSaveTimer(): void {
  if (!autoSaveTimer) return

  clearInterval(autoSaveTimer)
  autoSaveTimer = null
}

function startAutoSaveTimer(): void {
  stopAutoSaveTimer()
  const intervalMs = getAppSettings().autoSaveIntervalMs
  autoSaveTimer = setInterval(() => {
    if (!activeProject || !isDirty || saveStatus === 'saving' || isRecoveryMode) return

    try {
      saveProject()
    } catch {
      // saveProject updates saveStatus/saveError before rethrowing.
    }
  }, intervalMs)
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
  releaseProjectLock()
  acquireProjectLock(filePath)

  try {
    const db = openDatabase(filePath)
    runMigrations(db)
    assertIntegrity(db)
    db.prepare(
      `INSERT INTO project_info (id, project_name, game_title, schema_version, updated_at)
       VALUES (1, ?, ?, ?, datetime('now'))
       ON CONFLICT(id) DO UPDATE SET
         project_name = excluded.project_name,
         game_title = excluded.game_title,
         schema_version = excluded.schema_version,
         updated_at = excluded.updated_at`,
    ).run(projectName, gameTitle, CURRENT_SCHEMA_VERSION)

    const project = buildProjectMetadata(db, filePath)
    setCleanState(project)
    isRecoveryMode = false
    startAutoSaveTimer()
    updateRecentProjects(project)
    return getProjectState()
  } catch (error) {
    closeExistingDatabase()
    releaseProjectLock()
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

  try {
    closeExistingDatabase()
    releaseProjectLock()
    acquireProjectLock(selectedPath)
    const activePath = await migrateIfNeeded(selectedPath, owner)
    if (!activePath) {
      releaseProjectLock()
      return getProjectState()
    }
    if (activePath.toLowerCase() !== selectedPath.toLowerCase()) {
      releaseProjectLock()
      acquireProjectLock(activePath)
    }
    const db = openDatabase(activePath)
    assertIntegrity(db)

    const project = buildProjectMetadata(db, activePath)
    setCleanState(project)
    isRecoveryMode = false
    recoveryMessage = null
    startAutoSaveTimer()
    updateRecentProjects(project)
    return getProjectState()
  } catch (error) {
    if (error instanceof ProjectLockError) {
      throw error
    }
    return setRecoveryState(selectedPath, error)
  }
}

export function saveProject(): ProjectStateSnapshot {
  if (!activeProject || isRecoveryMode) return getProjectState()

  saveStatus = 'saving'
  saveError = null

  try {
    const db = getDb()
    db.pragma('wal_checkpoint(TRUNCATE)')
    setCleanState(buildProjectMetadata(db, activeProject.filePath))
    updateRecentProjects(activeProject)
    return getProjectState()
  } catch (error) {
    setSaveFailure(error)
    throw error
  }
}

export async function saveProjectAs(owner: BrowserWindow | null): Promise<ProjectStateSnapshot> {
  if (!activeProject || isRecoveryMode) return getProjectState()

  saveProject()
  const sourcePath = activeProject.filePath
  const targetPath = await promptForSaveAsPath(owner, sourcePath)
  if (!targetPath) return getProjectState()
  if (targetPath.toLowerCase() === sourcePath.toLowerCase()) return getProjectState()
  if (existsSync(targetPath)) throw new Error('A project file already exists at that path.')

  let switchedDatabase = false
  try {
    copyFileSync(sourcePath, targetPath)
    closeExistingDatabase()
    releaseProjectLock()
    switchedDatabase = true
    acquireProjectLock(targetPath)
    const db = openDatabase(targetPath)
    assertIntegrity(db)
    setCleanState(buildProjectMetadata(db, targetPath))
    isRecoveryMode = false
    startAutoSaveTimer()
    updateRecentProjects(activeProject)
    return getProjectState()
  } catch (error) {
    if (switchedDatabase) {
      try {
        releaseProjectLock()
        acquireProjectLock(sourcePath)
        const db = openDatabase(sourcePath)
        setCleanState(buildProjectMetadata(db, sourcePath))
        startAutoSaveTimer()
      } catch {
        // Preserve the original save failure as the user-facing error.
      }
    }
    setSaveFailure(error)
    throw error
  }
}

export function closeActiveProject(): ProjectStateSnapshot {
  stopAutoSaveTimer()
  closeExistingDatabase()
  releaseProjectLock()
  setCleanState(null)
  isRecoveryMode = false
  recoveryMessage = null
  return getProjectState()
}

export function markProjectDirty(): ProjectStateSnapshot {
  if (!activeProject || isRecoveryMode) return getProjectState()

  isDirty = true
  saveStatus = 'unsaved'
  saveError = null
  return getProjectState()
}

export function restartAutoSaveTimer(): void {
  if (activeProject) {
    startAutoSaveTimer()
  }
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
  refreshActiveProject()

  return {
    activeProject,
    recentProjects: readRecentProjects(),
    isDirty,
    isRecoveryMode,
    recoveryMessage,
    saveStatus,
    saveError,
  }
}
